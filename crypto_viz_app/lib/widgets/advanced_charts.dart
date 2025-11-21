import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/crypto_model.dart';

/// Main widget used in AnalyticsScreen
class AdvancedAnalyticsCharts extends StatefulWidget {
  final CryptoModel crypto;
  final String timeframe;
  final ValueChanged<double>? onPriceChangeCalculated;

  const AdvancedAnalyticsCharts({
    super.key,
    required this.crypto,
    required this.timeframe,
    this.onPriceChangeCalculated,
  });

  @override
  State<AdvancedAnalyticsCharts> createState() =>
      _AdvancedAnalyticsChartsState();
}

/// Optional wrapper in case other code uses AdvancedCryptoCharts
class AdvancedCryptoCharts extends AdvancedAnalyticsCharts {
  const AdvancedCryptoCharts({
    super.key,
    required CryptoModel crypto,
    required String timeframe,
    ValueChanged<double>? onPriceChangeCalculated,
  }) : super(
          crypto: crypto,
          timeframe: timeframe,
          onPriceChangeCalculated: onPriceChangeCalculated,
        );
}

class _AdvancedAnalyticsChartsState extends State<AdvancedAnalyticsCharts> {
  late List<CandleData> _candles;

  @override
  void initState() {
    super.initState();
    _generateData();
  }

  @override
  void didUpdateWidget(covariant AdvancedAnalyticsCharts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.crypto.id != widget.crypto.id ||
        oldWidget.timeframe != widget.timeframe) {
      _generateData();
    }
  }

  void _generateData() {
    // Nombre de points selon la période
    int count;
    switch (widget.timeframe) {
      case '1H':
        count = 12; // 5min candles
        break;
      case '4H':
        count = 24; // 10min candles
        break;
      case '7D':
        count = 42; // ~4h candles
        break;
      case '30D':
        count = 60; // ~12h candles
        break;
      case '24H':
      default:
        count = 24; // 1h candles
        break;
    }

    final basePrice = widget.crypto.currentPrice;
    final dailyChangePct = widget.crypto.priceChangePercentage24h;
    final rnd = math.Random(widget.crypto.id.hashCode ^
        widget.timeframe.hashCode ^
        basePrice.toInt());

    final List<CandleData> candles = [];
    double currentPrice = basePrice /
        (1 + (dailyChangePct / 100.0) * 0.5); // point de départ approximatif

    final now = DateTime.now();
    final totalMinutes = _timeframeToMinutes(widget.timeframe);
    final stepMinutes = count == 0 ? 60 : (totalMinutes / count).clamp(5, 720);

    for (int i = 0; i < count; i++) {
      // Trend léger basé sur la variation 24h
      final t = i / math.max(1, count - 1);
      final trendFactor = 1 + (dailyChangePct / 100.0) * (t - 0.5) * 0.6;

      final noise = (rnd.nextDouble() - 0.5) * 0.02; // ±2 %
      final open = currentPrice;
      final close = currentPrice * (trendFactor + noise);

      final high = math.max(open, close) * (1 + rnd.nextDouble() * 0.01);
      final low = math.min(open, close) * (1 - rnd.nextDouble() * 0.01);

      final time = now.subtract(Duration(
          minutes: (totalMinutes - i * stepMinutes).round()));

      candles.add(
        CandleData(
          time: time,
          open: open,
          high: high,
          low: low,
          close: close,
        ),
      );

      currentPrice = close;
    }

    _candles = candles;

    // notifier le changement de prix réel sur la période simulée
    if (_candles.isNotEmpty && widget.onPriceChangeCalculated != null) {
      final first = _candles.first.open;
      final last = _candles.last.close;
      final percent = ((last - first) / first) * 100;
      widget.onPriceChangeCalculated!(percent);
    }

    setState(() {});
  }

  int _timeframeToMinutes(String timeframe) {
    switch (timeframe) {
      case '1H':
        return 60;
      case '4H':
        return 240;
      case '24H':
        return 1440;
      case '7D':
        return 7 * 24 * 60;
      case '30D':
        return 30 * 24 * 60;
      default:
        return 1440;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_candles.isEmpty) {
      return const SizedBox(
        height: 260,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A90E2)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Candlestick chart
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: const Color(0xFF151827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2D47)),
          ),
          padding: const EdgeInsets.all(16),
          child: CustomPaint(
            painter: CandlestickPainter(_candles),
            child: Container(),
          ),
        ),
        const SizedBox(height: 12),
        // Volume / range bar chart (approx)
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF151827),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2D47)),
          ),
          padding:
              const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 8),
          child: BarChart(
            BarChartData(
              borderData: FlBorderData(show: false),
              gridData: FlGridData(show: false),
              titlesData: FlTitlesData(show: false),
              barGroups: _buildVolumeBars(),
            ),
          ),
        ),
      ],
    );
  }

  List<BarChartGroupData> _buildVolumeBars() {
    final ranges =
        _candles.map((c) => (c.high - c.low).abs()).toList(growable: false);
    final maxRange =
        ranges.isEmpty ? 1.0 : ranges.reduce((a, b) => a > b ? a : b);

    return _candles.asMap().entries.map((entry) {
      final index = entry.key;
      final candle = entry.value;
      final range = (candle.high - candle.low).abs();
      final normalized =
          maxRange == 0 ? 0.1 : (range / maxRange).clamp(0.1, 1.0);
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: normalized,
            width: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ],
      );
    }).toList();
  }
}

class CandleData {
  final DateTime time;
  final double open;
  final double high;
  final double low;
  final double close;

  CandleData({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });
}

class CandlestickPainter extends CustomPainter {
  final List<CandleData> candles;

  CandlestickPainter(this.candles);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    final upColor = const Color(0xFF4CAF50);
    final downColor = const Color(0xFFFF5252);

    final minPrice =
        candles.map((c) => c.low).reduce((a, b) => a < b ? a : b);
    final maxPrice =
        candles.map((c) => c.high).reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice == 0 ? 1 : maxPrice - minPrice;

    final candleWidth = size.width / candles.length;

    double priceToY(double price) {
      final normalized = (price - minPrice) / priceRange;
      return size.height - normalized * size.height;
    }

    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final isUp = c.close >= c.open;
      final color = isUp ? upColor : downColor;

      final x = (i + 0.5) * candleWidth;

      final highY = priceToY(c.high);
      final lowY = priceToY(c.low);
      final openY = priceToY(c.open);
      final closeY = priceToY(c.close);

      // Wick
      final wickPaint = Paint()
        ..color = color
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), wickPaint);

      // Body
      final bodyPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final top = isUp ? closeY : openY;
      final bottom = isUp ? openY : closeY;

      final rect = Rect.fromLTRB(
        x - candleWidth * 0.25,
        top,
        x + candleWidth * 0.25,
        bottom == top ? bottom + 1 : bottom,
      );

      canvas.drawRect(rect, bodyPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CandlestickPainter oldDelegate) {
    return oldDelegate.candles != candles;
  }
}
