import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/crypto_model.dart';
import '../models/news_model.dart';
import '../services/crypto_service.dart';
import '../services/crypto_news_service.dart';
import '../services/coingecko_service.dart';

class CryptoProvider with ChangeNotifier {
  final CoinGeckoService _coinGeckoService = CoinGeckoService();
  final CryptoService _cryptoService = CryptoService();
  final CryptoNewsService _newsService = CryptoNewsService();
  
  List<CryptoModel> _cryptos = [];
  List<CryptoModel> _filteredCryptos = [];
  List<String> _trendingCryptos = [];
  List<NewsModel> _news = [];
  bool _isLoading = false;
  bool _isLoadingNews = false;
  String _error = '';
  String _searchQuery = '';
  
  // Getters
  List<CryptoModel> get cryptos => _cryptos;
  List<CryptoModel> get filteredCryptos => _filteredCryptos;
  List<String> get trendingCryptos => _trendingCryptos;
  List<NewsModel> get news => _news;
  bool get isLoading => _isLoading;
  bool get isLoadingNews => _isLoadingNews;
  String get error => _error;
  
  // Statistiques calculées
  double get totalMarketCap =>
      _cryptos.fold(0, (sum, crypto) => sum + crypto.marketCap);

  double get averageChange => _cryptos.isEmpty
      ? 0
      : _cryptos.fold(
              0.0, (sum, crypto) => sum + crypto.priceChangePercentage24h) /
          _cryptos.length;
  
  List<CryptoModel> get topGainers => _cryptos
      .where((crypto) => crypto.priceChangePercentage24h > 0)
      .toList()
    ..sort((a, b) =>
        b.priceChangePercentage24h.compareTo(a.priceChangePercentage24h));
    
  List<CryptoModel> get topLosers => _cryptos
      .where((crypto) => crypto.priceChangePercentage24h < 0)
      .toList()
    ..sort((a, b) =>
        a.priceChangePercentage24h.compareTo(b.priceChangePercentage24h));

  /// Recherche des cryptomonnaies
  void searchCryptos(String query) {
    _searchQuery = query.toLowerCase();
    _filterCryptos();
    notifyListeners();
  }

  /// Filtre les cryptomonnaies selon la recherche
  void _filterCryptos() {
    if (_searchQuery.isEmpty) {
      _filteredCryptos = List.from(_cryptos);
    } else {
      _filteredCryptos = _cryptos.where((crypto) {
        return crypto.name.toLowerCase().contains(_searchQuery) ||
            crypto.symbol.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  /// Charge les données initiales
  Future<void> loadInitialData() async {
    await Future.wait([
      fetchTopCryptos(),
      fetchTrendingCryptos(),
      fetchCryptoNews(),
    ]);
  }

  /// Récupère les actualités crypto
  Future<void> fetchCryptoNews({int limit = 20, bool forceRefresh = false}) async {
    try {
      _isLoadingNews = true;
      notifyListeners();
      
      if (forceRefresh) {
        _newsService.forceRefresh();
      }
      
      final news = await _newsService.getCryptoNews(limit: limit);
      _news = news;
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Erreur actualités: $e');
      }
    } finally {
      _isLoadingNews = false;
      notifyListeners();
    }
  }

  /// Récupère le top des cryptomonnaies
  Future<void> fetchTopCryptos({int limit = 50}) async {
    try {
      _setLoading(true);
      _error = '';
      
      // 1) Essayer d'abord le service principal (API interne / Gateway)
      try {
        if (kDebugMode) {
          print('🔄 Chargement des cryptos depuis CryptoService (API interne)...');
        }

        final cryptos = await _cryptoService.getTopCryptos(limit: limit);

        if (cryptos.isEmpty) {
          throw Exception('Aucune crypto retournée par CryptoService');
        }

        _cryptos = cryptos;
        _filterCryptos();
        if (kDebugMode) {
          print('✅ ${cryptos.length} cryptos chargées depuis CryptoService');
        }
        notifyListeners();
        return;
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Erreur CryptoService, fallback vers CoinGecko: $e');
        }
      }
      
      // 2) Fallback vers CoinGecko
      if (kDebugMode) {
        print('🔄 Chargement des cryptos depuis CoinGecko...');
      }
      
      final cryptos = await _coinGeckoService.getTopCryptos(limit: limit);
      
      if (cryptos.isEmpty) {
        _error = 'Aucune crypto trouvée';
        if (kDebugMode) {
          print('⚠️ Aucune crypto trouvée');
        }
      } else {
        _cryptos = cryptos;
        _filterCryptos(); // Applique le filtre après avoir chargé les données
        if (kDebugMode) {
          print('✅ ${cryptos.length} cryptos chargées depuis CoinGecko');
        }
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) {
        print('❌ Erreur lors du chargement des cryptos: $e');
        print('Stack trace: ${StackTrace.current}');
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Récupère les cryptos trending
  Future<void> fetchTrendingCryptos() async {
    try {
      final trending = await _coinGeckoService.getTrendingCryptos();
      _trendingCryptos = trending;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Erreur trending: $e');
      }
    }
  }

  /// Actualise les données (pull to refresh)
  Future<void> refreshData() async {
    await loadInitialData();
  }

  /// Filtre les cryptos par critères
  List<CryptoModel> filterCryptos({
    double? minPrice,
    double? maxPrice,
    bool? onlyGainers,
    bool? onlyLosers,
  }) {
    var filtered = List<CryptoModel>.from(_cryptos);
    
    if (minPrice != null) {
      filtered = filtered
          .where((crypto) => crypto.currentPrice >= minPrice)
          .toList();
    }
    
    if (maxPrice != null) {
      filtered = filtered
          .where((crypto) => crypto.currentPrice <= maxPrice)
          .toList();
    }
    
    if (onlyGainers == true) {
      filtered = filtered
          .where((crypto) => crypto.priceChangePercentage24h > 0)
          .toList();
    }
    
    if (onlyLosers == true) {
      filtered = filtered
          .where((crypto) => crypto.priceChangePercentage24h < 0)
          .toList();
    }
    
    return filtered;
  }

  /// Obtient une crypto par son ID
  CryptoModel? getCryptoById(String id) {
    try {
      return _cryptos.firstWhere((crypto) => crypto.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Met à jour l'état de chargement
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Nettoie les erreurs
  void clearError() {
    _error = '';
    notifyListeners();
  }
}
