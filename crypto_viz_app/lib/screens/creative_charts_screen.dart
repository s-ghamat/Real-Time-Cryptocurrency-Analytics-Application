import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/crypto_provider.dart';
import '../models/crypto_model.dart';

class CreativeChartsScreen extends StatelessWidget {
  const CreativeChartsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<CryptoProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.cryptos.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
                      ),
                    );
                  }

                  if (provider.cryptos.isEmpty) {
                    return const Center(
                      child: Text(
                        'No crypto data available.\nCheck your connection or backend.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 14,
                        ),
                      ),
                    );
                  }

                  final cryptos = provider.cryptos;

                  // Sorts
                  final byCap = [...cryptos]
                    ..sort((a, b) => b.marketCap.compareTo(a.marketCap));
                  final byChange = [...cryptos]
                    ..sort((a, b) => b.priceChangePercentage24h
                        .compareTo(a.priceChangePercentage24h));

                  // Selections
                  final top5 = byCap.take(5).toList();
                  final avgChange = cryptos.fold<double>(
                          0,
                          (s, c) =>
                              s + c.priceChangePercentage24h) /
                      cryptos.length;

                  List<CryptoModel> topForPie;
                  if (byCap.length <= 10) {
                    topForPie = byCap;
                  } else {
                    final mid = byCap.sublist(5, math.min(byCap.length, 25));
                    mid.shuffle(math.Random(42));
                    topForPie = [...byCap.take(4), ...mid.take(6)];
                  }

                  // Liquidity top 15
                  final liquidityTop = [...cryptos]
                    ..sort((a, b) =>
                        liquidityScore(b).compareTo(liquidityScore(a)));
                  if (liquidityTop.length > 15) {
                    liquidityTop.removeRange(15, liquidityTop.length);
                  }

                  // Emerging movers: biggest movers outside top 5 by cap
                  final top5Ids = top5.map((c) => c.id).toSet();
                  final emerging = byChange
                      .where((c) => !top5Ids.contains(c.id))
                      .take(6)
                      .toList();

                  final topForMatrix = byCap.take(6).toList();
                  final topForScatter = byCap.take(12).toList();
                  final topForNetFlow = byCap.take(12).toList();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _title(
                          icon: Icons.auto_graph_rounded,
                          label: 'Multi-Asset Rhythm',
                          subtitle:
                              'Normalized motion of top assets (24h inspired)',
                        ),
                        const SizedBox(height: 12),
                        _MultiAssetLineChart(cryptos: top5),
                        const SizedBox(height: 28),

                        _title(
                          icon: Icons.thermostat_rounded,
                          label: 'Market Temperature',
                          subtitle:
                              'Average 24h performance of the whole market',
                        ),
                        const SizedBox(height: 12),
                        _MarketTemperatureGauge(avgChange: avgChange),
                        const SizedBox(height: 28),

                        _title(
                          icon: Icons.pie_chart_rounded,
                          label: 'Market Cap Galaxy',
                          subtitle: 'Share of top assets in the universe',
                        ),
                        const SizedBox(height: 12),
                        _MarketCapPie(cryptos: topForPie),
                        const SizedBox(height: 28),

                        _title(
                          icon: Icons.bar_chart_rounded,
                          label: 'Liquidity Pulse',
                          subtitle:
                              'Volume / Market Cap ratio – how “alive” each asset is',
                        ),
                        const SizedBox(height: 12),
                        _LiquidityBarChart(cryptos: liquidityTop),
                        const SizedBox(height: 28),

                        _title(
                          icon: Icons.stacked_bar_chart_rounded,
                          label: 'Dominance Buckets',
                          subtitle:
                              'Large caps vs mid caps vs the rest of the market',
                        ),
                        const SizedBox(height: 12),
                        _DominanceBucketsChart(cryptos: cryptos),
                        const SizedBox(height: 28),

                        _title(
                          icon: Icons.grid_on_rounded,
                          label: 'Correlation Matrix',
                          subtitle:
                              'Synthetic correlation between recent price paths of top assets',
                        ),
                        const SizedBox(height: 12),
                        _CorrelationMatrix(cryptos: topForMatrix),
                        const SizedBox(height: 28),
                        const SizedBox(height: 12),
                        const SizedBox(height: 28),

                        _title(
                          icon: Icons.trending_up_rounded,
                          label: 'Net Flow Bars',
                          subtitle:
                              'Directional flow proxy = change × (volume/market cap)',
                        ),
                        const SizedBox(height: 12),
                        _NetFlowBars(cryptos: topForNetFlow),
                        const SizedBox(height: 28),

                        _title(
                          icon: Icons.grid_view_rounded,
                          label: 'Momentum Heatmap',
                          subtitle:
                              'Performance snapshot for top movers across timeframes',
                        ),
                        const SizedBox(height: 12),
                        _MomentumHeatmap(cryptos: byChange),
                        const SizedBox(height: 28),

                        _title(
                          icon: Icons.flash_on_rounded,
                          label: 'Emerging Movers',
                          subtitle:
                              'Strong daily movers outside the top 5 by market cap',
                        ),
                        const SizedBox(height: 12),
                        _EmergingMoversList(cryptos: emerging),
                        const SizedBox(height: 40),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E2139),
        border: Border(
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
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
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
                  'Creative Analytics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Special visualisations of the market',
                  style: TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _title({
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2D47),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF4A90E2), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8B93A7),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// Helpers shared by several charts
/// ---------------------------------------------------------------------------

double liquidityScore(CryptoModel c) {
  if (c.marketCap <= 0) return 0;
  final ratio = c.totalVolume / c.marketCap;
  return (ratio * 100).clamp(0.0, 20.0);
}

/// Generates a synthetic “price” series for a coin (length = [count]).
/// We use 24h change to bias the drift. Returns raw values (not normalized).
List<double> _syntheticSeries(CryptoModel c, {int count = 20}) {
  final rnd = math.Random(c.id.hashCode);
  final base = c.currentPrice;
  final changePct = c.priceChangePercentage24h;

  double price = base / (1 + (changePct / 100.0) * 0.5);
  final List<double> out = [];
  for (int i = 0; i < count; i++) {
    final t = i / (count - 1);
    final drift = 1 + (changePct / 100.0) * (t - 0.5) * 0.8;
    final noise = (rnd.nextDouble() - 0.5) * 0.04; // ±4 %
    price *= (drift + noise).clamp(0.9, 1.1);
    out.add(price);
  }
  return out;
}

/// Normalize a series to 0..1 range.
List<double> _normalize(List<double> s) {
  final minV = s.reduce(math.min);
  final maxV = s.reduce(math.max);
  final range = (maxV - minV).abs() < 1e-9 ? 1.0 : (maxV - minV);
  return s.map((v) => (v - minV) / range).toList(growable: false);
}

/// Pearson correlation between two equal-length lists.
double _pearson(List<double> a, List<double> b) {
  final n = math.min(a.length, b.length);
  if (n == 0) return 0;
  final mA = a.take(n).reduce((x, y) => x + y) / n;
  final mB = b.take(n).reduce((x, y) => x + y) / n;

  double num = 0, dA = 0, dB = 0;
  for (int i = 0; i < n; i++) {
    final da = a[i] - mA;
    final db = b[i] - mB;
    num += da * db;
    dA += da * da;
    dB += db * db;
  }
  final den = math.sqrt(dA * dB);
  return den == 0 ? 0 : (num / den).clamp(-1.0, 1.0);
}

/// Std-dev of a series.
double _stdDev(List<double> s) {
  if (s.isEmpty) return 0;
  final mean = s.reduce((a, b) => a + b) / s.length;
  final varSum = s.fold<double>(0, (sum, v) => sum + (v - mean) * (v - mean));
  return math.sqrt(varSum / s.length);
}

/// ---------------------------------------------------------------------------
/// 1) Multi-Asset normalized line chart   (tooltip kept inside)
/// ---------------------------------------------------------------------------

class _MultiAssetLineChart extends StatelessWidget {
  final List<CryptoModel> cryptos;
  const _MultiAssetLineChart({required this.cryptos});

  static const _palette = <Color>[
    Color(0xFF4FC3F7),
    Color(0xFF80CBC4),
    Color(0xFF9575CD),
    Color(0xFFFFB74D),
    Color(0xFFE57373),
  ];

  @override
  Widget build(BuildContext context) {
    final series = cryptos.map((c) {
      final values = _normalize(_syntheticSeries(c));
      return List<FlSpot>.generate(
        values.length,
        (i) => FlSpot(i.toDouble(), values[i]),
      );
    }).toList(growable: false);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: (series.first.length - 1).toDouble(),
          minY: 0,
          maxY: 1,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipMargin: 12,
              getTooltipItems: (spots) => spots
                  .map(
                    (s) => LineTooltipItem(
                      '${cryptos[s.barIndex].symbol.toUpperCase()}\n'
                      '${(s.y * 100).toStringAsFixed(1)}%',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          lineBarsData: [
            for (int i = 0; i < series.length; i++)
              LineChartBarData(
                spots: series[i],
                isCurved: true,
                barWidth: 2.2,
                color: _palette[i % _palette.length],
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(show: false),
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 2) Market Temperature gauge
/// ---------------------------------------------------------------------------

class _MarketTemperatureGauge extends StatelessWidget {
  final double avgChange;
  const _MarketTemperatureGauge({required this.avgChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: CustomPaint(painter: _TemperaturePainter(avgChange))),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${avgChange >= 0 ? '+' : ''}${avgChange.toStringAsFixed(2)}%',
                style: TextStyle(
                  color: avgChange >= 0
                      ? const Color(0xFF4CAF50)
                      : const Color(0xFFFF5252),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _desc(avgChange),
                style: const TextStyle(color: Color(0xFF8B93A7), fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _desc(double v) {
    if (v > 5) return 'Hot bullish day';
    if (v > 1) return 'Warm & optimistic';
    if (v > -1) return 'Neutral / sideways';
    if (v > -5) return 'Cool & cautious';
    return 'Cold bearish day';
  }
}

class _TemperaturePainter extends CustomPainter {
  final double avg;
  _TemperaturePainter(this.avg);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, size.height / 3, size.width, 16);
    final gradient = LinearGradient(
      colors: const [Color(0xFFFF5252), Color(0xFFFFC107), Color(0xFF4CAF50)],
      stops: const [0.0, 0.5, 1.0],
    );
    final bg = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.fill;
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(r, bg);

    final clamped = avg.clamp(-15.0, 15.0);
    final t = (clamped + 15) / 30; // 0..1
    final x = rect.left + rect.width * t;

    final pointer = Paint()..color = Colors.white;
    final p = Path()
      ..moveTo(x, rect.top - 4)
      ..lineTo(x - 5, rect.top)
      ..lineTo(x + 5, rect.top)
      ..close();
    canvas.drawPath(p, pointer);
  }

  @override
  bool shouldRepaint(covariant _TemperaturePainter old) => old.avg != avg;
}

/// ---------------------------------------------------------------------------
/// 3) Market Cap Galaxy (pie)
/// ---------------------------------------------------------------------------

class _MarketCapPie extends StatelessWidget {
  final List<CryptoModel> cryptos;
  const _MarketCapPie({required this.cryptos});

  @override
  Widget build(BuildContext context) {
    if (cryptos.isEmpty) return const SizedBox.shrink();

    final total = cryptos.fold<double>(0, (s, c) => s + c.marketCap);
    if (total <= 0) return const SizedBox.shrink();
    const double labelThreshold = 4;

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 1,
                centerSpaceRadius: 55,
                startDegreeOffset: -90,
                sections: [
                  for (final c in cryptos)
                    PieChartSectionData(
                      value: c.marketCap,
                      radius: 55,
                      title: (c.marketCap / total * 100) >= labelThreshold
                          ? c.symbol.toUpperCase()
                          : '',
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      titlePositionPercentageOffset: 0.7,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Top market cap “galaxy”',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: cryptos.length,
                    itemBuilder: (context, i) {
                      final c = cryptos[i];
                      final share =
                          (c.marketCap / total * 100).toStringAsFixed(1);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              c.symbol.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                c.name,
                                style: const TextStyle(
                                  color: Color(0xFF8B93A7),
                                  fontSize: 10,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$share%',
                              style: const TextStyle(
                                color: Color(0xFF4A90E2),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 4) Liquidity Pulse (bar)
/// ---------------------------------------------------------------------------

class _LiquidityBarChart extends StatelessWidget {
  final List<CryptoModel> cryptos;
  const _LiquidityBarChart({required this.cryptos});

  @override
  Widget build(BuildContext context) {
    if (cryptos.isEmpty) return const SizedBox.shrink();

    final sorted = [...cryptos]
      ..sort((a, b) => liquidityScore(b).compareTo(liquidityScore(a)));
    final maxScore =
        sorted.map(liquidityScore).reduce((a, b) => a > b ? a : b);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, m) => Text(
                  v.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= sorted.length) return const SizedBox();
                  final c = sorted[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      c.symbol.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final c = sorted[group.x.toInt()];
                final score = liquidityScore(c);
                return BarTooltipItem(
                  '${c.name}\nScore: ${score.toStringAsFixed(2)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          barGroups: [
            for (int i = 0; i < sorted.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (liquidityScore(sorted[i]) /
                            (maxScore == 0 ? 1 : maxScore))
                        .clamp(0.0, 1.0) *
                        10,
                    width: 10,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 5) Dominance Buckets
/// ---------------------------------------------------------------------------

class _DominanceBucketsChart extends StatelessWidget {
  final List<CryptoModel> cryptos;
  const _DominanceBucketsChart({required this.cryptos});

  @override
  Widget build(BuildContext context) {
    if (cryptos.isEmpty) return const SizedBox.shrink();

    final sorted = [...cryptos]
      ..sort((a, b) => b.marketCap.compareTo(a.marketCap));
    final total = sorted.fold<double>(0, (s, c) => s + c.marketCap);
    if (total <= 0) return const SizedBox.shrink();

    final large = sorted.take(3).toList();
    final mid = sorted.skip(3).take(7).toList();
    final others =
        sorted.length > 10 ? sorted.skip(10).toList() : <CryptoModel>[];

    final buckets = [
      _Bucket('Large Caps', large.fold(0, (s, c) => s + c.marketCap), large),
      _Bucket('Mid Caps', mid.fold(0, (s, c) => s + c.marketCap), mid),
      _Bucket(
          'Others', others.fold(0, (s, c) => s + c.marketCap), others),
    ];

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, m) => Text(
                        '${v.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (v, m) {
                        final i = v.toInt();
                        if (i < 0 || i >= buckets.length) {
                          return const SizedBox();
                        }
                        final text = buckets[i].name.split(' ').first;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            text,
                            style: const TextStyle(
                              color: Color(0xFF8B93A7),
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (int i = 0; i < buckets.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: (buckets[i].cap / total * 100),
                          width: 16,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in buckets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _BucketLegendRow(
                      label: b.name,
                      percentage: b.cap / total * 100,
                      cryptos: b.cryptos,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bucket {
  final String name;
  final double cap;
  final List<CryptoModel> cryptos;
  _Bucket(this.name, this.cap, this.cryptos);
}

class _BucketLegendRow extends StatelessWidget {
  final String label;
  final double percentage;
  final List<CryptoModel> cryptos;
  const _BucketLegendRow(
      {required this.label, required this.percentage, required this.cryptos});

  @override
  Widget build(BuildContext context) {
    final display =
        cryptos.take(3).map((c) => c.symbol.toUpperCase()).join(', ');
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                display.isEmpty ? '—' : display,
                style: const TextStyle(
                  color: Color(0xFF8B93A7),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        Text(
          '${percentage.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Color(0xFF4A90E2),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// ---------------------------------------------------------------------------
/// 6) Correlation Matrix (heatmap)
/// ---------------------------------------------------------------------------

class _CorrelationMatrix extends StatelessWidget {
  final List<CryptoModel> cryptos;
  const _CorrelationMatrix({required this.cryptos});

  @override
  Widget build(BuildContext context) {
    if (cryptos.length < 2) return const SizedBox.shrink();

    final n = cryptos.length;
    final series = [
      for (final c in cryptos) _normalize(_syntheticSeries(c, count: 24))
    ];
    final matrix = List.generate(
      n,
      (i) => List.generate(n, (j) => _pearson(series[i], series[j])),
    );

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (_, constraints) {
          final size = math.min(constraints.maxWidth, 200.0);
          return Row(
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _CorrelationPainter(matrix, cryptos),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Correlation (synthetic)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final c in cryptos.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${c.symbol.toUpperCase()} – ${c.name}',
                          style: const TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    const Spacer(),
                    Row(
                      children: const [
                        Text(
                          '−1',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 10,
                          ),
                        ),
                        Expanded(
                          child: _GradBar(
                            left: Color(0xFFFF5252),
                            right: Color(0xFF4CAF50),
                          ),
                        ),
                        Text(
                          '+1',
                          style: TextStyle(
                            color: Color(0xFF8B93A7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CorrelationPainter extends CustomPainter {
  final List<List<double>> m;
  final List<CryptoModel> cryptos;
  _CorrelationPainter(this.m, this.cryptos);

  @override
  void paint(Canvas canvas, Size size) {
    final n = m.length;
    if (n == 0) return;

    final cell = size.width / n;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    // Draw heat cells
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        final v = m[i][j]; // -1..1
        Color color;
        if (v < 0) {
          final t = (-v).clamp(0.0, 1.0);
          color = Color.lerp(
            const Color(0xFF424A5E),
            const Color(0xFFFF5252),
            t,
          )!;
        } else {
          final t = v.clamp(0.0, 1.0);
          color = Color.lerp(
            const Color(0xFF424A5E),
            const Color(0xFF4CAF50),
            t,
          )!;
        }
        final r = Rect.fromLTWH(j * cell, i * cell, cell - 1, cell - 1);
        final paint = Paint()..color = color.withOpacity(0.9);
        canvas.drawRect(r, paint);
      }
    }

    // Row labels (inside first column cells)
    for (int i = 0; i < n; i++) {
      final sym = cryptos[i].symbol.toUpperCase();
      textPainter.text = TextSpan(
        text: sym,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      final dx = 4.0;
      final dy = i * cell + (cell - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(dx, dy));
    }

    // Column labels (inside top row cells)
    for (int j = 0; j < n; j++) {
      final sym = cryptos[j].symbol.toUpperCase();
      textPainter.text = TextSpan(
        text: sym,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      final dx = j * cell + (cell - textPainter.width) / 2;
      const dy = 2.0;
      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant _CorrelationPainter oldDelegate) => false;
}

class _GradBar extends StatelessWidget {
  final Color left, right;
  const _GradBar({required this.left, required this.right});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        gradient:
            LinearGradient(colors: [left, const Color(0xFF424A5E), right]),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 7) Net Flow Bars (positive/negative)
/// ---------------------------------------------------------------------------

class _NetFlowBars extends StatelessWidget {
  final List<CryptoModel> cryptos;
  const _NetFlowBars({required this.cryptos});

  @override
  Widget build(BuildContext context) {
    if (cryptos.isEmpty) return const SizedBox.shrink();

    double flow(CryptoModel c) =>
        (c.priceChangePercentage24h) *
        (c.marketCap == 0 ? 0 : (c.totalVolume / c.marketCap) * 100);

    final items = [
      for (final c in cryptos) _FlowItem(c, flow(c)),
    ]..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    final maxAbs = items
        .map((e) => e.value.abs())
        .fold<double>(0, (mx, v) => v > mx ? v : mx);

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: BarChart(
        BarChartData(
          minY: -maxAbs,
          maxY: maxAbs,
          gridData: FlGridData(show: true, horizontalInterval: maxAbs / 4),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                getTitlesWidget: (v, m) => Text(
                  v.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 9,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                reservedSize: 32,
                showTitles: true,
                getTitlesWidget: (v, m) {
                  final i = v.toInt();
                  if (i < 0 || i >= items.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      items[i].c.symbol.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) {
                final it = items[group.x.toInt()];
                return BarTooltipItem(
                  '${it.c.name}\nFlow: ${it.value.toStringAsFixed(2)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          barGroups: [
            for (int i = 0; i < items.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: items[i].value,
                    color: items[i].value >= 0
                        ? const Color(0xFF4CAF50)
                        : const Color(0xFFFF5252),
                    width: 12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FlowItem {
  final CryptoModel c;
  final double value;
  _FlowItem(this.c, this.value);
}

/// ---------------------------------------------------------------------------
/// 9) Momentum Heatmap
/// ---------------------------------------------------------------------------

class _MomentumHeatmap extends StatelessWidget {
  final List<CryptoModel> cryptos;
  const _MomentumHeatmap({required this.cryptos});

  static const _timeframes = ['1H', '4H', '24H', '7D', '30D'];

  @override
  Widget build(BuildContext context) {
    if (cryptos.isEmpty) return const SizedBox.shrink();
    final rows = cryptos.take(8).toList();

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(width: 60),
              const SizedBox(width: 4),
              for (final tf in _timeframes)
                Expanded(
                  child: Center(
                    child: Text(
                      tf,
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final c = rows[index];
                return _MomentumRow(crypto: c);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MomentumRow extends StatelessWidget {
  final CryptoModel crypto;
  static const _timeframes = ['1H', '4H', '24H', '7D', '30D'];
  const _MomentumRow({required this.crypto});

  @override
  Widget build(BuildContext context) {
    final rnd = math.Random(crypto.id.hashCode);
    final base24h = crypto.priceChangePercentage24h;

    final List<double> values = [];
    for (final tf in _timeframes) {
      double factor;
      switch (tf) {
        case '1H':
          factor = 0.25;
          break;
        case '4H':
          factor = 0.6;
          break;
        case '24H':
          factor = 1.0;
          break;
        case '7D':
          factor = 2.5;
          break;
        case '30D':
          factor = 4.0;
          break;
        default:
          factor = 1.0;
      }
      final noise = (rnd.nextDouble() - 0.5) * 2; // ±2 pts
      values.add(base24h * factor + noise);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crypto.symbol.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  crypto.name,
                  style: const TextStyle(
                    color: Color(0xFF8B93A7),
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          for (final v in values) Expanded(child: _HeatCell(value: v)),
        ],
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  final double value;
  const _HeatCell({required this.value});

  Color _color(double v) {
    const minV = -20.0, maxV = 20.0;
    final t = ((v.clamp(minV, maxV) - minV) / (maxV - minV)); // 0..1
    if (t < 0.5) {
      final k = t / 0.5;
      return Color.lerp(
        const Color(0xFFFF5252),
        const Color(0xFF424A5E),
        k,
      )!
          .withOpacity(0.9);
    } else {
      final k = (t - 0.5) / 0.5;
      return Color.lerp(
        const Color(0xFF424A5E),
        const Color(0xFF4CAF50),
        k,
      )!
          .withOpacity(0.9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      height: 26,
      decoration: BoxDecoration(
        color: _color(value),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// 10) Emerging Movers list
/// ---------------------------------------------------------------------------

class _EmergingMoversList extends StatelessWidget {
  final List<CryptoModel> cryptos;
  const _EmergingMoversList({required this.cryptos});

  @override
  Widget build(BuildContext context) {
    if (cryptos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF151827),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2D47)),
        ),
        child: const Text(
          'No emerging movers detected for now.',
          style: TextStyle(
            color: Color(0xFF8B93A7),
            fontSize: 12,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151827),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2D47)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: cryptos.map((c) => _MoverRow(crypto: c)).toList(),
      ),
    );
  }
}

class _MoverRow extends StatelessWidget {
  final CryptoModel crypto;
  const _MoverRow({required this.crypto});

  @override
  Widget build(BuildContext context) {
    final change = crypto.priceChangePercentage24h;
    final isUp = change >= 0;
    final color = isUp ? const Color(0xFF4CAF50) : const Color(0xFFFF5252);
    final v2c =
        crypto.marketCap == 0 ? 0 : crypto.totalVolume / crypto.marketCap;

    String label;
    if (v2c > 0.2) {
      label = 'High liquidity';
    } else if (v2c > 0.05) {
      label = 'Active';
    } else {
      label = 'Thinly traded';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1E2139),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                crypto.symbol.toUpperCase(),
                style: const TextStyle(
                  color: Color(0xFF4A90E2),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  crypto.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2D47),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Color(0xFF8B93A7),
                          fontSize: 9,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Vol/MCap ${(v2c * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Color(0xFF8B93A7),
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${crypto.currentPrice.toStringAsFixed(crypto.currentPrice < 1 ? 4 : 2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isUp ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${isUp ? '+' : ''}${change.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
