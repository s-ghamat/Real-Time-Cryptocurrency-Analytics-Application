import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/crypto_model.dart';
import '../services/coingecko_service.dart';

class AdvancedAnalyticsCharts extends StatefulWidget {
  final CryptoModel crypto;
  final String timeframe;
  final ValueChanged<double?>? onPriceChangeCalculated;

  const AdvancedAnalyticsCharts({
    super.key,
    required this.crypto,
    required this.timeframe,
    this.onPriceChangeCalculated,
  });

  @override
  State<AdvancedAnalyticsCharts> createState() => _AdvancedAnalyticsChartsState();
}

class _AdvancedAnalyticsChartsState extends State<AdvancedAnalyticsCharts>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FlSpot>? _priceData;
  List<FlSpot>? _volumeData;
  List<FlSpot>? _rsiData;
  List<FlSpot>? _macdData;
  bool _isLoading = true;
  int _selectedChartIndex = 0;
  final CoinGeckoService _coinGeckoService = CoinGeckoService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadChartData();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedChartIndex = _tabController.index;
      });
    }
  }

  @override
  void didUpdateWidget(AdvancedAnalyticsCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.crypto.id != widget.crypto.id || oldWidget.timeframe != widget.timeframe) {
      _loadChartData();
    }
  }

  Future<void> _loadChartData() async {
    setState(() => _isLoading = true);
    
    try {
      // Générer des données basées sur les vraies valeurs de la crypto
      _priceData = _generatePriceData();
      _volumeData = _generateVolumeData();
      _rsiData = _generateRSIData();
      _macdData = _generateMACDData();
    } catch (e) {
      // En cas d'erreur, utiliser des données par défaut
      _priceData = _generatePriceData();
      _volumeData = _generateVolumeData();
      _rsiData = _generateRSIData();
      _macdData = _generateMACDData();
    }
    
    setState(() => _isLoading = false);
    
    // Notifier le parent du pourcentage calculé (après le build)
    if (widget.onPriceChangeCalculated != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final changePercent = getPriceChangePercentage();
        widget.onPriceChangeCalculated!(changePercent);
      });
    }
  }

  /// Calcule le pourcentage de changement de prix pour la timeframe sélectionnée
  double? getPriceChangePercentage() {
    if (_priceData == null || _priceData!.isEmpty) {
      return null;
    }
    
    final firstPrice = _priceData!.first.y;
    final lastPrice = _priceData!.last.y;
    
    if (firstPrice == 0) return null;
    
    final change = ((lastPrice - firstPrice) / firstPrice) * 100;
    return change;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2139),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2D47)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
        ),
      );
    }

    return Container(
      height: 450,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2139),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      child: Column(
        children: [
          // En-tête avec sélecteur de graphique
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF2A2D47), width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.crypto.symbol.toUpperCase()} Charts',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.timeframe,
                            style: const TextStyle(
                              color: Color(0xFF8B93A7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Boutons de sélection de graphique propres
                _buildChartSelector(),
              ],
            ),
          ),
          
          // Contenu des graphiques
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPriceChart(),
                _buildVolumeChart(),
                _buildRSIChart(),
                _buildMACDChart(),
                _buildBollingerChart(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart() {
    if (_priceData == null || _priceData!.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white)));
    }

    final minPrice = _priceData!.map((e) => e.y).reduce(math.min);
    final maxPrice = _priceData!.map((e) => e.y).reduce(math.max);
    final priceRange = maxPrice - minPrice;
    final dates = _generateDates();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: priceRange / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: const Color(0xFF2A2D47),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _priceData!.length / 5,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < dates.length) {
                    return Text(
                      _formatDateForAxis(dates[index]),
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 10,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '\$${value.toStringAsFixed(value < 1 ? 2 : 0)}',
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: _priceData!.length.toDouble(),
          minY: minPrice - priceRange * 0.1,
          maxY: maxPrice + priceRange * 0.1,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final index = touchedSpot.x.toInt();
                  if (index >= 0 && index < dates.length) {
                    return LineTooltipItem(
                      '${_formatDateForTooltip(dates[index])}\n\$${touchedSpot.y.toStringAsFixed(touchedSpot.y < 1 ? 4 : 2)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(12),
              tooltipMargin: 16,
            ),
            handleBuiltInTouches: true,
            getTouchLineStart: (data, index) => 0,
            getTouchLineEnd: (data, index) => double.infinity,
            touchSpotThreshold: 20,
          ),
          lineBarsData: [
            LineChartBarData(
              spots: _priceData!,
              isCurved: true,
              gradient: LinearGradient(
                colors: widget.crypto.priceChangePercentage24h >= 0
                    ? [const Color(0xFF4CAF50), const Color(0xFF4CAF50).withOpacity(0.3)]
                    : [const Color(0xFFFF5252), const Color(0xFFFF5252).withOpacity(0.3)],
              ),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: false,
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (widget.crypto.priceChangePercentage24h >= 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5252)).withOpacity(0.3),
                    (widget.crypto.priceChangePercentage24h >= 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5252)).withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeChart() {
    if (_volumeData == null || _volumeData!.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white)));
    }

    final maxVolume = _volumeData!.map((e) => e.y).reduce(math.max);
    final dates = _generateDates();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxVolume * 1.2,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVolume / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: const Color(0xFF2A2D47),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _volumeData!.length / 5,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < dates.length) {
                    return Text(
                      _formatDateForAxis(dates[index]),
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 10,
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  if (value >= 1000000000) {
                    return Text(
                      '\$${(value / 1000000000).toStringAsFixed(1)}B',
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 10,
                      ),
                    );
                  } else if (value >= 1000000) {
                    return Text(
                      '\$${(value / 1000000).toStringAsFixed(1)}M',
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 10,
                      ),
                    );
                  }
                  return Text(
                    '\$${(value / 1000).toStringAsFixed(0)}K',
                    style: const TextStyle(
                      color: Color(0xFF8B93A7),
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final index = group.x.toInt();
                if (index >= 0 && index < dates.length) {
                  final volume = rod.toY;
                  String volumeStr;
                  if (volume >= 1000000000) {
                    volumeStr = '\$${(volume / 1000000000).toStringAsFixed(2)}B';
                  } else if (volume >= 1000000) {
                    volumeStr = '\$${(volume / 1000000).toStringAsFixed(2)}M';
                  } else {
                    volumeStr = '\$${(volume / 1000).toStringAsFixed(0)}K';
                  }
                  
                  return BarTooltipItem(
                    '${_formatDateForTooltip(dates[index])}\n$volumeStr',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return null;
              },
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(12),
              tooltipMargin: 16,
            ),
          ),
          barGroups: _volumeData!.asMap().entries.map((entry) {
            final index = entry.key;
            final spot = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: spot.y,
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      const Color(0xFF4A90E2).withOpacity(0.8),
                      const Color(0xFF4A90E2).withOpacity(0.4),
                    ],
                  ),
                  width: 8,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildRSIChart() {
    if (_rsiData == null || _rsiData!.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white)));
    }

    final currentRSI = _rsiData!.last.y;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Indicateurs RSI
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2D47),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRSIIndicator('RSI (14)', currentRSI),
                _buildRSIIndicator('Status', currentRSI, showStatus: true),
                _buildRSIIndicator('Signal', currentRSI > 50 ? 'BUY' : 'SELL'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Graphique RSI
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) {
                    Color lineColor = const Color(0xFF2A2D47);
                    if (value == 70 || value == 30) {
                      lineColor = value == 70 
                          ? Colors.red.withOpacity(0.5) 
                          : Colors.green.withOpacity(0.5);
                    }
                    return FlLine(color: lineColor, strokeWidth: value == 70 || value == 30 ? 2 : 1);
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: _rsiData!.length / 5,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        final dates = _generateDates();
                        if (index >= 0 && index < dates.length) {
                          return Text(
                            _formatDateForAxis(dates[index]),
                            style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: _rsiData!.length.toDouble(),
                minY: 0,
                maxY: 100,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      final dates = _generateDates();
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final index = touchedSpot.x.toInt();
                        if (index >= 0 && index < dates.length) {
                          return LineTooltipItem(
                            '${_formatDateForTooltip(dates[index])}\nRSI: ${touchedSpot.y.toStringAsFixed(2)}',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(12),
                    tooltipMargin: 12,
                  ),
                  handleBuiltInTouches: true,
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _rsiData!,
                    isCurved: true,
                    color: _getRSIColor(currentRSI),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMACDChart() {
    if (_macdData == null || _macdData!.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white)));
    }

    final macdValues = _macdData!.map((e) => e.y).toList();
    final signalValues = _generateSignalLine(macdValues);
    final histogramValues = _generateHistogram(macdValues, signalValues);
    
    final allValues = [...macdValues, ...signalValues, ...histogramValues];
    final minY = allValues.reduce(math.min);
    final maxY = allValues.reduce(math.max);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: value == 0 
                    ? const Color(0xFF8B93A7) 
                    : const Color(0xFF2A2D47),
                strokeWidth: value == 0 ? 2 : 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _macdData!.length / 5,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  final dates = _generateDates();
                  if (index >= 0 && index < dates.length) {
                    return Text(
                      _formatDateForAxis(dates[index]),
                      style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(2),
                    style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: _macdData!.length.toDouble(),
          minY: minY - (maxY - minY) * 0.1,
          maxY: maxY + (maxY - minY) * 0.1,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                final dates = _generateDates();
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final index = touchedSpot.x.toInt();
                  if (index >= 0 && index < dates.length) {
                    return LineTooltipItem(
                      '${_formatDateForTooltip(dates[index])}\nMACD: ${touchedSpot.y.toStringAsFixed(4)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(12),
              tooltipMargin: 12,
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            // MACD Line
            LineChartBarData(
              spots: _macdData!,
              isCurved: true,
              color: const Color(0xFF4A90E2),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
            // Signal Line
            LineChartBarData(
              spots: signalValues.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: const Color(0xFFFF9800),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
          extraLinesData: ExtraLinesData(
            verticalLines: [],
            horizontalLines: [
              HorizontalLine(
                y: 0,
                color: const Color(0xFF8B93A7),
                strokeWidth: 2,
                dashArray: [5, 5],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBollingerChart() {
    if (_priceData == null || _priceData!.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Colors.white)));
    }

    final prices = _priceData!.map((e) => e.y).toList();
    final sma = _calculateSMA(prices, 20);
    final stdDev = _calculateStdDev(prices, 20);
    final upperBand = sma.map((e) => e + 2 * stdDev[sma.indexOf(e)]).toList();
    final lowerBand = sma.map((e) => e - 2 * stdDev[sma.indexOf(e)]).toList();
    final dates = _generateDates();
    
    final minPrice = prices.reduce(math.min);
    final maxPrice = prices.reduce(math.max);
    final priceRange = maxPrice - minPrice;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: priceRange / 5,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: const Color(0xFF2A2D47),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _priceData!.length / 5,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < dates.length) {
                    return Text(
                      _formatDateForAxis(dates[index]),
                      style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '\$${value.toStringAsFixed(value < 1 ? 2 : 0)}',
                    style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 10),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: _priceData!.length.toDouble(),
          minY: minPrice - priceRange * 0.1,
          maxY: maxPrice + priceRange * 0.1,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final index = touchedSpot.x.toInt();
                  if (index >= 0 && index < dates.length) {
                    return LineTooltipItem(
                      '${_formatDateForTooltip(dates[index])}\nPrice: \$${touchedSpot.y.toStringAsFixed(touchedSpot.y < 1 ? 4 : 2)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.all(12),
              tooltipMargin: 12,
            ),
            handleBuiltInTouches: true,
          ),
          lineBarsData: [
            // Price Line
            LineChartBarData(
              spots: _priceData!,
              isCurved: true,
              color: const Color(0xFF4A90E2),
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
            // Upper Band
            LineChartBarData(
              spots: upperBand.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: const Color(0xFFFF5252).withOpacity(0.5),
              barWidth: 1,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
            // Lower Band
            LineChartBarData(
              spots: lowerBand.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: const Color(0xFF4CAF50).withOpacity(0.5),
              barWidth: 1,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
            // SMA
            LineChartBarData(
              spots: sma.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
              isCurved: true,
              color: const Color(0xFFFF9800).withOpacity(0.7),
              barWidth: 1,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRSIIndicator(String label, dynamic value, {bool showStatus = false}) {
    Color valueColor = const Color(0xFF8B93A7);
    String displayValue = '';
    
    if (showStatus && value is double) {
      if (value > 70) {
        valueColor = Colors.red;
        displayValue = 'OVERSOLD';
      } else if (value < 30) {
        valueColor = Colors.green;
        displayValue = 'OVERSOLD';
      } else {
        valueColor = const Color(0xFF4A90E2);
        displayValue = 'NEUTRAL';
      }
    } else if (value is String) {
      displayValue = value;
      valueColor = value == 'BUY' ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    } else if (value is double) {
      displayValue = value.toStringAsFixed(2);
      if (value > 70) {
        valueColor = Colors.red;
      } else if (value < 30) {
        valueColor = Colors.green;
      }
    }
    
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B93A7),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          displayValue,
          style: TextStyle(
            color: valueColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // Génération de données basées sur les vraies valeurs de la crypto
  List<FlSpot> _generatePriceData() {
    final basePrice = widget.crypto.currentPrice;
    final changePercent = widget.crypto.priceChangePercentage24h / 100;
    final volatility = (widget.crypto.totalVolume / widget.crypto.marketCap).clamp(0.0, 0.1);
    
    final dataPoints = _getDataPointsForTimeframe();
    final List<FlSpot> spots = [];
    
    double currentPrice = basePrice;
    final random = math.Random(widget.crypto.id.hashCode);
    
    for (int i = 0; i < dataPoints; i++) {
      // Variation basée sur le changement 24h et la volatilité
      final trend = changePercent * (i / dataPoints);
      final noise = (random.nextDouble() - 0.5) * volatility * 2;
      currentPrice = basePrice * (1 + trend + noise);
      
      spots.add(FlSpot(i.toDouble(), currentPrice));
    }
    
    return spots;
  }

  List<FlSpot> _generateVolumeData() {
    final baseVolume = widget.crypto.totalVolume;
    final dataPoints = _getDataPointsForTimeframe();
    final List<FlSpot> spots = [];
    
    final random = math.Random(widget.crypto.id.hashCode + 1000);
    
    for (int i = 0; i < dataPoints; i++) {
      // Variation de volume avec pics aléatoires
      final variation = 0.3 + (random.nextDouble() * 0.7);
      final volume = baseVolume * variation;
      
      spots.add(FlSpot(i.toDouble(), volume));
    }
    
    return spots;
  }

  List<FlSpot> _generateRSIData() {
    final changePercent = widget.crypto.priceChangePercentage24h;
    // RSI basé sur le changement de prix (approximation)
    final baseRSI = 50 + (changePercent * 2).clamp(-30.0, 30.0);
    
    final dataPoints = _getDataPointsForTimeframe();
    final List<FlSpot> spots = [];
    
    final random = math.Random(widget.crypto.id.hashCode + 2000);
    
    for (int i = 0; i < dataPoints; i++) {
      final variation = (random.nextDouble() - 0.5) * 20;
      final rsi = (baseRSI + variation).clamp(0.0, 100.0);
      
      spots.add(FlSpot(i.toDouble(), rsi));
    }
    
    return spots;
  }

  List<FlSpot> _generateMACDData() {
    final changePercent = widget.crypto.priceChangePercentage24h;
    final baseMACD = changePercent * 0.01; // Approximation
    
    final dataPoints = _getDataPointsForTimeframe();
    final List<FlSpot> spots = [];
    
    final random = math.Random(widget.crypto.id.hashCode + 3000);
    
    for (int i = 0; i < dataPoints; i++) {
      final variation = (random.nextDouble() - 0.5) * 0.05;
      final macd = baseMACD + variation;
      
      spots.add(FlSpot(i.toDouble(), macd));
    }
    
    return spots;
  }

  List<double> _generateSignalLine(List<double> macdValues) {
    // Signal line = EMA de MACD (simplifié)
    return macdValues.map((macd) => macd * 0.9).toList();
  }

  List<double> _generateHistogram(List<double> macdValues, List<double> signalValues) {
    return macdValues.asMap().entries.map((e) {
      final index = e.key;
      return e.value - signalValues[index];
    }).toList();
  }

  List<double> _calculateSMA(List<double> prices, int period) {
    final List<double> sma = [];
    for (int i = period - 1; i < prices.length; i++) {
      final sum = prices.sublist(i - period + 1, i + 1).reduce((a, b) => a + b);
      sma.add(sum / period);
    }
    // Padding pour avoir la même longueur
    while (sma.length < prices.length) {
      sma.insert(0, prices.first);
    }
    return sma;
  }

  List<double> _calculateStdDev(List<double> prices, int period) {
    final sma = _calculateSMA(prices, period);
    final List<double> stdDev = [];
    
    for (int i = period - 1; i < prices.length; i++) {
      final window = prices.sublist(i - period + 1, i + 1);
      final mean = sma[i];
      final variance = window.map((p) => math.pow(p - mean, 2)).reduce((a, b) => a + b) / period;
      stdDev.add(math.sqrt(variance));
    }
    
    while (stdDev.length < prices.length) {
      stdDev.insert(0, stdDev.isNotEmpty ? stdDev.first : 0.0);
    }
    
    return stdDev;
  }

  int _getDataPointsForTimeframe() {
    switch (widget.timeframe) {
      case '1H':
        return 60;
      case '4H':
        return 48;
      case '24H':
        return 24;
      case '7D':
        return 168;
      case '30D':
        return 720;
      default:
        return 24;
    }
  }

  // Génère les dates pour le timeframe
  List<DateTime> _generateDates() {
    final dataPoints = _getDataPointsForTimeframe();
    final now = DateTime.now();
    final List<DateTime> dates = [];
    
    Duration interval;
    switch (widget.timeframe) {
      case '1H':
        interval = const Duration(minutes: 1);
        break;
      case '4H':
        interval = const Duration(minutes: 5);
        break;
      case '24H':
        interval = const Duration(hours: 1);
        break;
      case '7D':
        interval = const Duration(hours: 1);
        break;
      case '30D':
        interval = const Duration(hours: 1);
        break;
      default:
        interval = const Duration(hours: 1);
    }
    
    for (int i = dataPoints - 1; i >= 0; i--) {
      dates.add(now.subtract(interval * i));
    }
    
    return dates;
  }

  // Formate une date pour l'affichage sur l'axe X
  String _formatDateForAxis(DateTime date) {
    switch (widget.timeframe) {
      case '1H':
        return DateFormat('HH:mm').format(date);
      case '4H':
        return DateFormat('HH:mm').format(date);
      case '24H':
        return DateFormat('HH:mm').format(date);
      case '7D':
        return DateFormat('MMM d').format(date);
      case '30D':
        return DateFormat('MMM d').format(date);
      default:
        return DateFormat('MMM d').format(date);
    }
  }

  // Formate une date pour le tooltip
  String _formatDateForTooltip(DateTime date) {
    switch (widget.timeframe) {
      case '1H':
        return DateFormat('MMM d, HH:mm').format(date);
      case '4H':
        return DateFormat('MMM d, HH:mm').format(date);
      case '24H':
        return DateFormat('MMM d, HH:mm').format(date);
      case '7D':
        return DateFormat('MMM d, yyyy HH:mm').format(date);
      case '30D':
        return DateFormat('MMM d, yyyy').format(date);
      default:
        return DateFormat('MMM d, yyyy').format(date);
    }
  }

  Color _getRSIColor(double rsi) {
    if (rsi > 70) {
      return Colors.red;
    } else if (rsi < 30) {
      return Colors.green;
    } else {
      return const Color(0xFFFF9800);
    }
  }

  Widget _buildChartSelector() {
    final chartTypes = [
      {'name': 'Price', 'icon': Icons.show_chart},
      {'name': 'Volume', 'icon': Icons.bar_chart},
      {'name': 'RSI', 'icon': Icons.speed},
      {'name': 'MACD', 'icon': Icons.trending_up},
      {'name': 'Bollinger', 'icon': Icons.timeline},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D47),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: chartTypes.asMap().entries.map((entry) {
          final index = entry.key;
          final chart = entry.value;
          final isSelected = _selectedChartIndex == index;
          
          return GestureDetector(
            onTap: () {
              _tabController.animateTo(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF4A90E2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    chart['icon'] as IconData,
                    size: 14,
                    color: isSelected 
                        ? Colors.white 
                        : const Color(0xFF8B93A7),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    chart['name'] as String,
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white 
                          : const Color(0xFF8B93A7),
                      fontSize: 12,
                      fontWeight: isSelected 
                          ? FontWeight.w700 
                          : FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

