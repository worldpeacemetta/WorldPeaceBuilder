import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme.dart';

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
    final bf     = double.tryParse(_bfCtrl.text);
    final today  = todayISO();
    final settings = ref.read(settingsProvider);

    // Replace today's entry if already present, otherwise append.
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
      backgroundColor: AppColors.card,
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
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Weight (kg)', suffixText: 'kg'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bfCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Body fat % (opt)', suffixText: '%'),
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

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(settingsProvider).weightHistory;
    // Show last 30 entries max
    final recent = history.length > 30
        ? history.sublist(history.length - 30)
        : history;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              const Center(
                child: Text('No weight data yet.\nTap Log to add your first entry.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ),
              const SizedBox(height: 8),
            ] else ...[
              const SizedBox(height: 4),
              // Latest reading pill
              if (recent.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      '${recent.last.weight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.carbs,
                      ),
                    ),
                    if (recent.last.bodyFat != null) ...[
                      const SizedBox(width: 10),
                      Text(
                        '${recent.last.bodyFat!.toStringAsFixed(1)}% BF',
                        style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      formatDateDisplay(recent.last.date),
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: AppColors.border, strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles  : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles   : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 20,
                          interval: (recent.length / 4).ceilToDouble(),
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i < 0 || i >= recent.length) return const SizedBox.shrink();
                            return Text(
                              DateFormat('M/d').format(DateTime.parse(recent[i].date)),
                              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
                            );
                          },
                        ),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          recent.length,
                          (i) => FlSpot(i.toDouble(), recent[i].weight),
                        ),
                        isCurved: true,
                        color: AppColors.carbs,
                        barWidth: 2,
                        dotData: FlDotData(
                          show: recent.length <= 10,
                          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                            radius: 3, color: AppColors.carbs, strokeWidth: 0,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: AppColors.carbs.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((s) {
                          final i = s.x.toInt();
                          final entry = i < recent.length ? recent[i] : null;
                          return LineTooltipItem(
                            '${s.y.toStringAsFixed(1)} kg'
                            '${entry?.bodyFat != null ? '\n${entry!.bodyFat!.toStringAsFixed(1)}% BF' : ''}',
                            const TextStyle(
                              color: AppColors.carbs, fontWeight: FontWeight.w600, fontSize: 12,
                            ),
                          );
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
