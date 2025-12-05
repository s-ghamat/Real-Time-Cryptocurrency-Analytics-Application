import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/crypto_model.dart';

class ApiGatewayService {
  static const String _baseUrl = 'http://localhost:3000';
  
  /// Récupère le top des cryptomonnaies depuis l'API Gateway
  Future<List<CryptoModel>> getTopCryptos({int limit = 50}) async {
    try {
      final url = Uri.parse('$_baseUrl/api/crypto/prices?limit=$limit');
      
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (kDebugMode) {
          print('📦 Réponse API Gateway: success=${data['success']}, data length=${data['data']?.length ?? 0}');
          if (data['data'] != null && (data['data'] as List).isNotEmpty) {
            print('📦 Premier élément: ${data['data'][0]}');
          }
        }
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> prices = data['data'];
          
          if (prices.isEmpty) {
            throw Exception('Aucune donnée dans l\'API Gateway. Vérifiez que le producer Kafka fonctionne.');
          }
          
          // Convertir les données de l'API Gateway au format CryptoModel
          return prices.asMap().entries.map((entry) {
            final index = entry.key;
            final price = entry.value;
            
            final symbol = price['symbol']?.toString() ?? '';
            final symbolUpper = symbol.toUpperCase();
            
            // Mapper les noms de cryptos
            final nameMap = {
              'bitcoin': 'Bitcoin',
              'ethereum': 'Ethereum',
              'solana': 'Solana',
              'cardano': 'Cardano',
              'polkadot': 'Polkadot',
            };
            final name = nameMap[symbol.toLowerCase()] ?? symbolUpper;
            
            final priceUsd = (price['price_usd'] ?? price['price'] ?? 0).toDouble();
            final change24h = (price['change_24h'] ?? 0).toDouble();
            
            if (kDebugMode && index == 0) {
              print('📦 Mapping prix: symbol=$symbol, price_usd=$priceUsd, change_24h=$change24h');
              print('📦 Tous les champs: ${price.keys.toList()}');
            }
            
            return CryptoModel(
              id: symbol.toLowerCase(),
              symbol: symbolUpper,
              name: name,
              currentPrice: priceUsd,
              priceChange24h: change24h,
              priceChangePercentage24h: change24h, // Le change_24h est déjà en pourcentage
              marketCap: (price['market_cap_usd'] ?? price['market_cap'] ?? 0).toDouble(),
              totalVolume: (price['volume_24h_usd'] ?? price['volume_24h'] ?? 0).toDouble(),
              image: price['image'] ?? '',
              marketCapRank: price['rank'] ?? 0,
            );
          }).toList();
        } else {
          throw Exception('Réponse API invalide: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('Erreur API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur réseau API Gateway: $e');
    }
  }

  /// Récupère les cryptos trending
  Future<List<String>> getTrendingCryptos() async {
    try {
      final url = Uri.parse('$_baseUrl/api/crypto/trending');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> trending = data['data'];
          return trending.map((crypto) => crypto['symbol']?.toString().toLowerCase() ?? '').toList();
        }
      }
      return [];
    } catch (e) {
      throw Exception('Erreur trending: $e');
    }
  }

  /// Vérifie si l'API Gateway est disponible
  Future<bool> isAvailable() async {
    try {
      final url = Uri.parse('$_baseUrl/health');
      final response = await http.get(url).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Vérifier qu'il y a des données en cache
        final cachedPrices = data['cached_prices'] ?? 0;
        return cachedPrices > 0;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

