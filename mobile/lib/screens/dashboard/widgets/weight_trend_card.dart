import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme.dart';

const _kBFColor = AppColors.fat;

class WeightTrendCard extends ConsumerStatefulWidget {
  const WeightTrendCard({super.key});

  @override
  ConsumerState<WeightTrendCard> createState() => _WeightTrendCardState();
}

class _WeightTrendCardState extends ConsumerState<WeightTrendCard> {
  final _weightCtrl = TextEditingController();
  final _bfCtrl     = TextEditingController();

  @override
  void dispose() {
    _weightCtrl.dispose();
    _bfCtrl.dispose();
    super.dispose();
  }

  Future<void> _logWeight() async {
    final weight = double.tryParse(_weightCtrl.text);
    if (weight == null || weight <= 0) return;
    final bf    = double.tryParse(_bfCtrl.text);
    final today = todayISO();
    final settings = ref.read(settingsProvider);

    final history = [...settings.weightHistory];
    final idx = history.indexWhere((e) => e.date == today);
    final entry = WeightEntry(date: today, weight: weight, bodyFat: bf);
    if (idx >= 0) {
      history[idx] = entry;
    } else {
      history.add(entry);
    }
    history.sort((a, b) => a.date.compareTo(b.date));

    await ref.read(settingsProvider.notifier).update(
      settings.copyWith(
        weightHistory: history,
        bodyStats: settings.bodyStats.copyWith(weightKg: weight, bodyFatPct: bf),
      ),
    );
    _weightCtrl.clear();
    _bfCtrl.clear();
    if (mounted) Navigator.pop(context);
  }

  void _showLogSheet() {
    final current = ref.read(settingsProvider).bodyStats;
    _weightCtrl.text = current.weightKg?.toStringAsFixed(1) ?? '';
    _bfCtrl.text     = current.bodyFatPct?.toStringAsFixed(1) ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).extension<AppColorScheme>()!.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          left: 16, right: 16, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Log Weight',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightCtrl,
                    autofocus: true,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Weight (kg)', suffixText: 'kg'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bfCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Body fat % (opt)', suffixText: '%'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _logWeight, child: const Text('Save')),
          ],
        ),
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /// Padded [min, max] domain for a list of values.
  static List<double> _domain(List<double> values, double fallbackPad) {
    if (values.isEmpty) return [0, 1];
    final mn = values.reduce(min);
    final mx = values.reduce(max);
    if (mn == mx) return [mn - fallbackPad, mx + fallbackPad];
    final pad = max((mx - mn) * 0.1, fallbackPad);
    return [mn - pad, mx + pad];
  }

  /// Map a body-fat value into the weight Y-axis coordinate space so both
  /// series can share a single fl_chart canvas.
  static double _bfToY(double bf,
      {required double wMin, required double wMax,
       required double bfMin, required double bfMax}) {
    if (bfMax == bfMin) return (wMin + wMax) / 2;
    return wMin + (bf - bfMin) / (bfMax - bfMin) * (wMax - wMin);
  }

  /// Reverse mapping: weight-scale Y → body-fat percentage (for axis labels
  /// and tooltip).
  static double _yToBF(double y,
      {required double wMin, required double wMax,
       required double bfMin, required double bfMax}) {
    if (wMax == wMin) return (bfMin + bfMax) / 2;
    return bfMin + (y - wMin) / (wMax - wMin) * (bfMax - bfMin);
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final kWeightColor = cs.kcalColor;
    final history = ref.watch(settingsProvider).weightHistory;
    final recent  = history.length > 30
        ? history.sublist(history.length - 30)
        : history;
    final latest  = recent.isNotEmpty ? recent.last : null;
    final hasBF   = recent.any((e) => e.bodyFat != null);

    // Domains
    final wDomain = _domain(recent.map((e) => e.weight).toList(), 0.5);
    final bfDomain = hasBF
        ? _domain(
            recent.where((e) => e.bodyFat != null).map((e) => e.bodyFat!).toList(),
            0.3)
        : [0.0, 1.0];

    final wMin = wDomain[0];  final wMax = wDomain[1];
    final bfMin = bfDomain[0]; final bfMax = bfDomain[1];

    // Spots
    final weightSpots = List.generate(
      recent.length,
      (i) => FlSpot(i.toDouble(), recent[i].weight),
    );

    final bfSpots = <FlSpot>[
      for (int i = 0; i < recent.length; i++)
        if (recent[i].bodyFat != null)
          FlSpot(i.toDouble(),
              _bfToY(recent[i].bodyFat!, wMin: wMin, wMax: wMax, bfMin: bfMin, bfMax: bfMax)),
    ];

    // How many x-ticks to show
    final xInterval = max(1, (recent.length / 4).ceil()).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── header ──
            Row(
              children: [
                const Text('Weight Trend',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _showLogSheet,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Log', style: TextStyle(fontSize: 13)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),

            if (recent.isEmpty) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'No weight data yet.\nTap Log to add your first entry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.textMuted, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[

              // ── legend ──
              Row(
                children: [
                  Container(width: 16, height: 2, color: kWeightColor),
                  const SizedBox(width: 4),
                  Text('Weight',
                      style: TextStyle(fontSize: 11, color: cs.textMuted)),
                  if (hasBF) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 20,
                      height: 10,
                      child: CustomPaint(
                          painter: _DashLinePainter(color: _kBFColor)),
                    ),
                    const SizedBox(width: 4),
                    Text('Body Fat',
                        style: TextStyle(fontSize: 11, color: cs.textMuted)),
                  ],
                ],
              ),
              const SizedBox(height: 6),

              // ── latest reading ──
              Row(
                children: [
                  Text(
                    '${latest!.weight.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w700,
                      color: kWeightColor,
                    ),
                  ),
                  if (latest.bodyFat != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      '${latest.bodyFat!.toStringAsFixed(1)}% BF',
                      style: TextStyle(
                          fontSize: 13, color: cs.textMuted),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    formatDateDisplay(latest.date),
                    style: TextStyle(
                        fontSize: 12, color: cs.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── chart ──
              SizedBox(
                height: 150,
                child: LineChart(
                  LineChartData(
                    minY: wMin,
                    maxY: wMax,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: cs.border, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      // Left axis — weight (kg)
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 48,
                          interval: (wMax - wMin) / 3,
                          getTitlesWidget: (v, _) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '${v.toStringAsFixed(1)} kg',
                              style: TextStyle(
                                  fontSize: 9, color: cs.textMuted),
                            ),
                          ),
                        ),
                      ),
                      // Right axis — body fat (%)
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: hasBF,
                          reservedSize: 38,
                          interval: (wMax - wMin) / 3,
                          getTitlesWidget: (v, _) {
                            final bf = _yToBF(v,
                                wMin: wMin, wMax: wMax,
                                bfMin: bfMin, bfMax: bfMax);
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                '${bf.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                    fontSize: 9, color: _kBFColor),
                              ),
                            );
                          },
                        ),
                      ),
                      // Bottom axis — dates
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          interval: xInterval,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= recent.length) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              DateFormat('M/d')
                                  .format(DateTime.parse(recent[i].date)),
                              style: TextStyle(
                                  fontSize: 9, color: cs.textMuted),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      // Weight line (solid, purple, filled below)
                      LineChartBarData(
                        spots: weightSpots,
                        isCurved: true,
                        color: kWeightColor,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: recent.length <= 10,
                          getDotPainter: (_, __, ___, ____) =>
                              FlDotCirclePainter(
                                  radius: 3,
                                  color: kWeightColor,
                                  strokeWidth: 0),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              kWeightColor.withValues(alpha: 0.4),
                              kWeightColor.withValues(alpha: 0.02),
                            ],
                          ),
                        ),
                      ),
                      // Body fat line (dashed, cyan)
                      if (hasBF)
                        LineChartBarData(
                          spots: bfSpots,
                          isCurved: true,
                          color: _kBFColor,
                          barWidth: 2,
                          dashArray: [4, 2],
                          dotData: FlDotData(
                            show: bfSpots.length <= 10,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                                    radius: 3,
                                    color: _kBFColor,
                                    strokeWidth: 0),
                          ),
                          belowBarData: BarAreaData(show: false),
                        ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((s) {
                          final i = s.x.toInt();
                          if (s.barIndex == 0) {
                            // Weight tooltip
                            return LineTooltipItem(
                              '${s.y.toStringAsFixed(1)} kg',
                              TextStyle(
                                color: kWeightColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          } else {
                            // Body fat tooltip — convert back to real %
                            final bf = _yToBF(s.y,
                                wMin: wMin, wMax: wMax,
                                bfMin: bfMin, bfMax: bfMax);
                            return LineTooltipItem(
                              '${bf.toStringAsFixed(1)}%',
                              const TextStyle(
                                color: _kBFColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            );
                          }
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Draws a short dashed line — used in the legend.
class _DashLinePainter extends CustomPainter {
  final Color color;
  const _DashLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    double x = 0;
    const dashW = 4.0, gap = 2.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(min(x + dashW, size.width), y), paint);
      x += dashW + gap;
    }
  }

  @override
  bool shouldRepaint(_DashLinePainter old) => old.color != color;
}
