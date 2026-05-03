import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils.dart';
import '../../providers/date_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/weekly_report_provider.dart';
import '../../theme.dart';
import '../../widgets/activity_rings_panel.dart';
import '../../widgets/mode_pill.dart';
import '../../widgets/weekly_report_sheet.dart';

import 'widgets/food_logging_card.dart';
import 'widgets/weekly_nutrition_chart.dart';
import 'widgets/weight_trend_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date    = ref.watch(dashboardDateProvider);
    final totals  = ref.watch(macroTotalsProvider(date));
    final goals   = ref.watch(settingsProvider).goalsForDate(date);
    final isToday = date == todayISO();

    final cs = AppColorScheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Row(
              children: [
                Text(
                  formatDateFull(date),
                  style: TextStyle(fontSize: 12, color: cs.textMuted, fontWeight: FontWeight.w400),
                ),
                const SizedBox(width: 8),
                ModePill(date: date),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final dt = DateTime.parse(date).subtract(const Duration(days: 1));
              ref.read(dashboardDateProvider.notifier).state =
                  '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
            },
          ),
          if (!isToday)
            TextButton(
              onPressed: () => ref.read(dashboardDateProvider.notifier).state = todayISO(),
              child: const Text('Today', style: TextStyle(fontSize: 12)),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: isToday
                ? null
                : () {
                    final dt = DateTime.parse(date).add(const Duration(days: 1));
                    ref.read(dashboardDateProvider.notifier).state =
                        '${dt.year.toString().padLeft(4,'0')}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Weekly report banner — appears on Mondays when last week has data
          const _WeeklyReportBanner(),

          // Concentric rings
          Card(
            margin: EdgeInsets.zero,
            child: ActivityRingsPanel(totals: totals, goals: goals),
          ),
          const SizedBox(height: 16),

          // Avg per Meal (rolling period × macro)
          const FoodLoggingCard(),
          const SizedBox(height: 16),

          // Weekly Nutrition (multi-macro toggle)
          WeeklyNutritionChart(date: date),
          const SizedBox(height: 16),

          // Weight Trend
          const WeightTrendCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Weekly report Monday banner ───────────────────────────────────────────────

class _WeeklyReportBanner extends ConsumerStatefulWidget {
  const _WeeklyReportBanner();

  @override
  ConsumerState<_WeeklyReportBanner> createState() => _WeeklyReportBannerState();
}

class _WeeklyReportBannerState extends ConsumerState<_WeeklyReportBanner> {
  static const _kPrefKey = 'weekly_report_dismissed';

  bool _dismissed = false;
  bool _loaded    = false;

  @override
  void initState() {
    super.initState();
    _loadDismissed();
  }

  /// Start of the most-recently completed week (always a Monday, regardless
  /// of what day of the week today is). Used as the per-week dismissal key so
  /// the banner auto-resets when a new week's report becomes available.
  String get _reportMondayISO {
    final now           = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    return isoDate(currentMonday.subtract(const Duration(days: 7)));
  }

  Future<void> _loadDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _dismissed = prefs.getString(_kPrefKey) == _reportMondayISO;
        _loaded    = true;
      });
    }
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, _reportMondayISO);
    if (mounted) setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed) return const SizedBox.shrink();

    final mondayISO   = _reportMondayISO;
    final reportAsync = ref.watch(weeklyReportProvider(mondayISO));

    // Only show when data is available and qualifies (≥1 logged day).
    final report = reportAsync.valueOrNull;
    if (report == null) return const SizedBox.shrink();

    final cs = AppColorScheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => showWeeklyReportSheet(context, ref, mondayISO),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                cs.kcalColor.withValues(alpha: 0.18),
                AppColors.protein.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end:   Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.kcalColor.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color:        cs.kcalColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.bar_chart_rounded, color: cs.kcalColor, size: 22),
              ),
              const SizedBox(width: 12),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Report Ready',
                      style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: cs.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${report.daysLogged}/7 days · ${weekRangeLabel(mondayISO)}',
                      style: TextStyle(fontSize: 12, color: cs.textMuted),
                    ),
                  ],
                ),
              ),

              // Dismiss
              GestureDetector(
                onTap: _dismiss,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, size: 16, color: cs.textMuted),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, size: 20, color: cs.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
