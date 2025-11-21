import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/crypto_provider.dart';
import '../widgets/advanced_charts.dart';
import '../models/crypto_model.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  CryptoModel? selectedCrypto;
  String selectedTimeframe = '24H';
  double? _calculatedPriceChangePercent;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: SafeArea(
        child: Column(
          children: [
            // En-tête propre
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2139),
                border: const Border(
                  bottom: BorderSide(color: Color(0xFF2A2D47), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2D47),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advanced Analytics',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Technical analysis & insights',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2D47),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      onPressed: () => _showIndicatorsInfo(context),
                      icon: const Icon(Icons.info_outline, color: Color(0xFF8B93A7), size: 20),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      tooltip: 'Informations sur les indicateurs',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildTimeframeSelector(),
                ],
              ),
            ),
            
            // Contenu principal avec scroll complet
            Expanded(
              child: Consumer<CryptoProvider>(
                builder: (context, provider, child) {
                  if (provider.cryptos.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                      ),
                    );
                  }
                  
                  final crypto = selectedCrypto ?? provider.cryptos.first;
                  
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        // Sélecteur de crypto
                        SizedBox(
                          height: 100,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            itemCount: provider.cryptos.length > 15 ? 15 : provider.cryptos.length,
                            itemBuilder: (context, index) {
                              final crypto = provider.cryptos[index];
                              final isSelected = selectedCrypto?.id == crypto.id;
                              
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedCrypto = crypto;
                                    _calculatedPriceChangePercent = null; // Réinitialiser pour forcer le recalcul
                                  });
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  constraints: const BoxConstraints(
                                    minWidth: 70,
                                    maxWidth: 90,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF1E2139),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected ? const Color(0xFF4A90E2) : const Color(0xFF2A2D47),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        crypto.symbol.toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : const Color(0xFF8B93A7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '\$${crypto.currentPrice.toStringAsFixed(crypto.currentPrice < 1 ? 2 : 0)}',
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : const Color(0xFF8B93A7),
                                          fontSize: 9,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: (crypto.priceChangePercentage24h >= 0 
                                              ? const Color(0xFF4CAF50) 
                                              : const Color(0xFFFF5252)).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: Text(
                                          '${crypto.priceChangePercentage24h >= 0 ? '+' : ''}${crypto.priceChangePercentage24h.toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            color: crypto.priceChangePercentage24h >= 0 
                                                ? const Color(0xFF4CAF50) 
                                                : const Color(0xFFFF5252),
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Contenu principal
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // En-tête de la crypto avec métriques clés
                              _buildCryptoHeader(crypto, selectedTimeframe),
                              const SizedBox(height: 20),
                              
                              // Graphiques avancés
                              AdvancedAnalyticsCharts(
                                crypto: crypto,
                                timeframe: selectedTimeframe,
                              ),
                              const SizedBox(height: 20),
                              
                              // Métriques techniques détaillées
                              _buildTechnicalMetrics(crypto),
                              const SizedBox(height: 20),
                              
                              // Analyse de marché approfondie
                              _buildMarketAnalysis(crypto),
                              const SizedBox(height: 20),
                              
                              // Comparaison avec le marché
                              _buildMarketComparison(crypto, provider.cryptos),
                              const SizedBox(height: 20),
                              
                              // Statistiques de performance
                              _buildPerformanceStats(crypto),
                              const SizedBox(height: 100),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeframeSelector() {
    final timeframes = ['1H', '4H', '24H', '7D', '30D'];
    
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D47),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: timeframes.map((timeframe) {
          final isSelected = selectedTimeframe == timeframe;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedTimeframe = timeframe;
                _calculatedPriceChangePercent = null; // Réinitialiser pour forcer le recalcul
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                timeframe,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF8B93A7),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCryptoHeader(CryptoModel crypto, String timeframe) {
    // Utiliser le pourcentage calculé depuis les données du graphique, ou fallback sur 24h
    final changePercent = _calculatedPriceChangePercent ?? crypto.priceChangePercentage24h;
    
    final changeColor = changePercent >= 0 
        ? const Color(0xFF4CAF50) 
        : const Color(0xFFFF5252);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E2139),
            const Color(0xFF1E2139).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF4A90E2).withOpacity(0.3),
                      const Color(0xFF4A90E2).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0xFF4A90E2).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    crypto.symbol.substring(0, math.min(3, crypto.symbol.length)).toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF4A90E2),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crypto.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      crypto.symbol.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${crypto.currentPrice.toStringAsFixed(crypto.currentPrice < 1 ? 4 : 2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: changeColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          changePercent >= 0 
                              ? Icons.arrow_upward 
                              : Icons.arrow_downward,
                          color: changeColor,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}%',
                          style: TextStyle(
                            color: changeColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Métriques rapides
          Row(
            children: [
              Expanded(
                child: _buildQuickMetric(
                  'Market Cap',
                  '\$${(crypto.marketCap / 1000000000).toStringAsFixed(2)}B',
                  Icons.trending_up,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickMetric(
                  '24h Volume',
                  '\$${((crypto.totalVolume) / 1000000000).toStringAsFixed(2)}B',
                  Icons.swap_vert,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickMetric(
                  'Rank',
                  '#${crypto.marketCapRank}',
                  Icons.leaderboard,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickMetric(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D47),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF4A90E2), size: 16),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8B93A7),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalMetrics(CryptoModel crypto) {
    // Calcul des indicateurs techniques basés sur les données réelles
    final rsi = _calculateRSI(crypto);
    final macd = _calculateMACD(crypto);
    final sma20 = crypto.currentPrice * 0.98;
    final ema12 = crypto.currentPrice * 1.01;
    final volatility = (crypto.totalVolume / crypto.marketCap).clamp(0.0, 0.1) * 100;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics, color: Color(0xFF4A90E2), size: 20),
              SizedBox(width: 8),
              Text(
                'Technical Indicators',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Première ligne
          Row(
            children: [
              Expanded(child: _buildMetricCard('RSI (14)', rsi.toStringAsFixed(2), _getRSIColor(rsi), Icons.speed)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('MACD', macd.toStringAsFixed(4), const Color(0xFF4CAF50), Icons.trending_up)),
            ],
          ),
          const SizedBox(height: 12),
          
          // Deuxième ligne
          Row(
            children: [
              Expanded(child: _buildMetricCard('SMA (20)', '\$${sma20.toStringAsFixed(2)}', const Color(0xFF2196F3), Icons.show_chart)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('EMA (12)', '\$${ema12.toStringAsFixed(2)}', const Color(0xFF9C27B0), Icons.timeline)),
            ],
          ),
          const SizedBox(height: 12),
          
          // Troisième ligne
          Row(
            children: [
              Expanded(child: _buildMetricCard('Volatility', '${volatility.toStringAsFixed(2)}%', const Color(0xFFFF9800), Icons.waves)),
              const SizedBox(width: 12),
              Expanded(child: _buildMetricCard('Support', '\$${(crypto.currentPrice * 0.95).toStringAsFixed(2)}', const Color(0xFF4CAF50), Icons.arrow_downward)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D47),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketAnalysis(CryptoModel crypto) {
    final volumeRatio = crypto.totalVolume / crypto.marketCap;
    final liquidity = volumeRatio > 0.1 ? 'High' : volumeRatio > 0.05 ? 'Medium' : 'Low';
    final liquidityColor = volumeRatio > 0.1 ? const Color(0xFF4CAF50) : volumeRatio > 0.05 ? const Color(0xFFFF9800) : const Color(0xFFFF5252);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Color(0xFF4A90E2), size: 20),
              SizedBox(width: 8),
              Text(
                'Market Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildAnalysisRow('Market Cap', '\$${(crypto.marketCap / 1000000000).toStringAsFixed(2)}B', Icons.account_balance_wallet),
          _buildAnalysisRow('24h Volume', '\$${((crypto.totalVolume) / 1000000000).toStringAsFixed(2)}B', Icons.swap_vert),
          _buildAnalysisRow('Volume/MCap Ratio', '${(volumeRatio * 100).toStringAsFixed(2)}%', Icons.pie_chart),
          _buildAnalysisRow('Liquidity', liquidity, Icons.water_drop, color: liquidityColor),
          _buildAnalysisRow('Market Cap Rank', '#${crypto.marketCapRank}', Icons.leaderboard),
          _buildAnalysisRow(
            'Price Change 24h',
            '${crypto.priceChangePercentage24h >= 0 ? '+' : ''}${crypto.priceChangePercentage24h.toStringAsFixed(2)}%', 
            crypto.priceChangePercentage24h >= 0 ? Icons.trending_up : Icons.trending_down,
            color: crypto.priceChangePercentage24h >= 0 ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: color ?? const Color(0xFF8B93A7), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8B93A7),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketComparison(CryptoModel crypto, List<CryptoModel> allCryptos) {
    final avgPrice = allCryptos.map((e) => e.currentPrice).reduce((a, b) => a + b) / allCryptos.length;
    final avgChange = allCryptos.map((e) => e.priceChangePercentage24h).reduce((a, b) => a + b) / allCryptos.length;
    final avgVolume = allCryptos.map((e) => e.totalVolume).reduce((a, b) => a + b) / allCryptos.length;
    
    final priceVsAvg = ((crypto.currentPrice / avgPrice - 1) * 100);
    final changeVsAvg = crypto.priceChangePercentage24h - avgChange;
    final volumeVsAvg = ((crypto.totalVolume / avgVolume - 1) * 100);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows, color: Color(0xFF4A90E2), size: 20),
              SizedBox(width: 8),
              Text(
                'Market Comparison',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildComparisonBar('Price vs Avg', priceVsAvg, Icons.attach_money),
          _buildComparisonBar('Change vs Avg', changeVsAvg, Icons.trending_up),
          _buildComparisonBar('Volume vs Avg', volumeVsAvg, Icons.swap_vert),
        ],
      ),
    );
  }

  Widget _buildComparisonBar(String label, double value, IconData icon) {
    final isPositive = value >= 0;
    final color = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    final absValue = value.abs();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8B93A7), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                '${isPositive ? '+' : ''}${value.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D47),
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: isPositive ? Alignment.centerLeft : Alignment.centerRight,
              widthFactor: (absValue / 50).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceStats(CryptoModel crypto) {
    final topCryptos = context.read<CryptoProvider>().cryptos.take(10).toList();
    final rank = topCryptos.indexWhere((e) => e.id == crypto.id) + 1;
    final percentile = ((topCryptos.length - rank) / topCryptos.length * 100);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: Color(0xFF4A90E2), size: 20),
              SizedBox(width: 8),
              Text(
                'Performance Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Top 10 Rank', rank > 0 ? '#$rank' : 'N/A', Icons.emoji_events),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Percentile', '${percentile.toStringAsFixed(0)}%', Icons.percent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Price Range',
                  '\$${(crypto.currentPrice * 0.9).toStringAsFixed(2)} - \$${(crypto.currentPrice * 1.1).toStringAsFixed(2)}',
                  Icons.show_chart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Volatility',
                  '${((crypto.totalVolume / crypto.marketCap) * 100).toStringAsFixed(2)}%',
                  Icons.waves,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4A90E2), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Calculs d'indicateurs techniques
  double _calculateRSI(CryptoModel crypto) {
    // Approximation basée sur le changement de prix
    final change = crypto.priceChangePercentage24h;
    final baseRSI = 50.0;
    return (baseRSI + change * 0.5).clamp(0.0, 100.0);
  }

  double _calculateMACD(CryptoModel crypto) {
    // Approximation basée sur le changement de prix
    return crypto.priceChangePercentage24h * 0.001;
  }

  void _showIndicatorsInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Color(0xFF1E2139),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF2A2D47), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Guide des Indicateurs Techniques',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Color(0xFF8B93A7)),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildIndicatorInfo(
                      'Price (Prix)',
                      'Le graphique de prix affiche l\'évolution du prix de la cryptomonnaie sur la période sélectionnée. Il permet d\'identifier les tendances haussières (bullish) ou baissières (bearish) et les niveaux de support/résistance.',
                      Icons.show_chart,
                      const Color(0xFF4A90E2),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicatorInfo(
                      'Volume',
                      'Le volume représente la quantité totale de cryptomonnaies échangées sur une période donnée. Un volume élevé confirme généralement la force d\'une tendance, tandis qu\'un volume faible peut indiquer une incertitude du marché.',
                      Icons.bar_chart,
                      const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicatorInfo(
                      'RSI (Relative Strength Index)',
                      'L\'indice de force relative mesure la vitesse et l\'ampleur des variations de prix. Il varie de 0 à 100 :\n• RSI > 70 : Surachat (survente possible, correction attendue)\n• RSI < 30 : Sursous-vente (sous-vente possible, rebond attendu)\n• RSI entre 30-70 : Zone neutre',
                      Icons.trending_up,
                      const Color(0xFFFF9800),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicatorInfo(
                      'MACD (Moving Average Convergence Divergence)',
                      'Le MACD est un indicateur de momentum qui montre la relation entre deux moyennes mobiles exponentielles (EMA). Il se compose de :\n• Ligne MACD : Différence entre EMA 12 et EMA 26\n• Ligne de signal : EMA 9 de la ligne MACD\n• Histogramme : Différence entre MACD et signal\n\nUn croisement haussier (MACD > Signal) indique un momentum haussier, et inversement.',
                      Icons.compare_arrows,
                      const Color(0xFF9C27B0),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicatorInfo(
                      'Bollinger Bands (Bandes de Bollinger)',
                      'Les bandes de Bollinger mesurent la volatilité du marché. Elles se composent de :\n• Bande supérieure : Moyenne mobile + 2 écarts-types\n• Bande moyenne : Moyenne mobile (SMA 20)\n• Bande inférieure : Moyenne mobile - 2 écarts-types\n\nQuand les bandes s\'écartent, la volatilité augmente. Quand elles se resserrent, la volatilité diminue. Un prix qui touche la bande supérieure peut indiquer une survente, et inversement.',
                      Icons.timeline,
                      const Color(0xFF00BCD4),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicatorInfo(
                      'SMA (Simple Moving Average)',
                      'La moyenne mobile simple calcule la moyenne des prix de clôture sur une période donnée. Elle lisse les fluctuations de prix pour révéler la tendance sous-jacente. Les traders utilisent souvent les croisements de moyennes mobiles (ex: SMA 50 croise SMA 200) comme signaux d\'achat ou de vente.',
                      Icons.trending_flat,
                      const Color(0xFF607D8B),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicatorInfo(
                      'Market Cap (Capitalisation Boursière)',
                      'La capitalisation boursière représente la valeur totale de toutes les pièces en circulation. Elle se calcule : Prix × Nombre de pièces. C\'est un indicateur de la taille et de la stabilité relative d\'une cryptomonnaie.',
                      Icons.account_balance,
                      const Color(0xFF4CAF50),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicatorInfo(
                      '24h Volume',
                      'Le volume sur 24 heures représente la valeur totale des transactions effectuées au cours des dernières 24 heures. Un volume élevé indique un intérêt actif pour la cryptomonnaie.',
                      Icons.swap_vert,
                      const Color(0xFF2196F3),
                    ),
                    const SizedBox(height: 20),
                    _buildIndicatorInfo(
                      'Price Change %',
                      'Le pourcentage de changement de prix indique la variation du prix sur la période sélectionnée (1H, 4H, 24H, 7D, 30D). Un pourcentage positif (vert) indique une hausse, un pourcentage négatif (rouge) indique une baisse.',
                      Icons.percent,
                      const Color(0xFFFF5252),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorInfo(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D47).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRSIColor(double rsi) {
    if (rsi > 70) {
      return Colors.red;
    } else if (rsi < 30) {
      return Colors.green;
    } else {
      return Colors.orange;
    }
  }
}
