import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils.dart';
import '../../models/entry.dart';
import '../../models/food.dart';
import '../../providers/badges_provider.dart';
import '../../providers/entries_provider.dart';
import '../../providers/log_history_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme.dart';
import '../../widgets/badge_widget.dart';
import '../../widgets/mode_pill.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

String _isoFromDT(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _computeStreak(List<String> sortedDesc) {
  if (sortedDesc.isEmpty) return 0;
  final set = sortedDesc.toSet();
  var check = DateTime.now();
  int streak = 0;
  bool startedFromYesterday = false;

  while (true) {
    final iso = _isoFromDT(check);
    if (set.contains(iso)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    } else {
      // If today has no entry yet, try from yesterday
      if (streak == 0 && !startedFromYesterday) {
        startedFromYesterday = true;
        check = check.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
  }
  return streak;
}

int _thisWeekCount(List<String> dates) {
  final set = dates.toSet();
  final now = DateTime.now();
  final monday = DateTime(now.year, now.month, now.day)
      .subtract(Duration(days: now.weekday - 1));
  int count = 0;
  for (int i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    if (d.isAfter(now)) break;
    if (set.contains(_isoFromDT(d))) count++;
  }
  return count;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class LogHistoryScreen extends ConsumerStatefulWidget {
  const LogHistoryScreen({super.key});

  @override
  ConsumerState<LogHistoryScreen> createState() => _LogHistoryScreenState();
}

class _LogHistoryScreenState extends ConsumerState<LogHistoryScreen> {
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
  }

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (_weekStart.month == end.month) {
      return '${months[_weekStart.month]} ${_weekStart.day}–${end.day}';
    }
    return '${months[_weekStart.month]} ${_weekStart.day} – ${months[end.month]} ${end.day}';
  }

  @override
  Widget build(BuildContext context) {
    final loggedDatesAsync = ref.watch(loggedDatesProvider);
    final loggedDates = loggedDatesAsync.valueOrNull ?? [];
    final today = todayISO();
    final todayNorm = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Log',
        ),
      ),
      body: Column(
        children: [
          // ── Stats panel ────────────────────────────────────────────
          _StatsPanel(dates: loggedDates),

          // ── Week strip / calendar ──────────────────────────────────
          _WeekStrip(
            weekStart: _weekStart,
            weekLabel: _weekLabel(),
            loggedDates: loggedDates,
            today: today,
            todayNorm: todayNorm,
            isoFor: _isoFromDT,
            onPrev: () => setState(
                () => _weekStart = _weekStart.subtract(const Duration(days: 7))),
            onNext: () => setState(
                () => _weekStart = _weekStart.add(const Duration(days: 7))),
          ),

          // ── Log history list ───────────────────────────────────────
          Expanded(
            child: loggedDatesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.protein),
              ),
              error: (_, __) => Center(
                child: Text('Failed to load history',
                    style: TextStyle(color: AppColorScheme.of(context).textMuted)),
              ),
              data: (dates) {
                if (dates.isEmpty) {
                  return Center(
                    child: Text('No logged days yet',
                        style: TextStyle(color: AppColorScheme.of(context).textMuted)),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: dates.length,
                  itemBuilder: (ctx, i) => _TimelineDayCard(
                    date: dates[i],
                    isLast: i == dates.length - 1,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats panel ───────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.dates});
  final List<String> dates;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final streak = _computeStreak(dates);
    final weekCount = _thisWeekCount(dates);
    final daysThisWeekSoFar = DateTime.now().weekday; // 1=Mon … 7=Sun

    return Container(
      color: cs.card,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          // Days logged
          Expanded(
            child: _StatCell(
              label: 'DAYS LOGGED',
              value: '${dates.length}',
            ),
          ),
          _Divider(),
          // Current streak
          Expanded(
            child: _StatCell(
              label: 'STREAK',
              value: streak == 0 ? '—' : '$streak',
              unit: streak > 0 ? (streak == 1 ? 'day' : 'days') : null,
            ),
          ),
          _Divider(),
          // This week
          Expanded(
            child: _StatCell(
              label: 'THIS WEEK',
              value: '$weekCount/$daysThisWeekSoFar',
              unit: 'days',
            ),
          ),
          _Divider(),
          // Badges placeholder (tappable later)
          Expanded(
            child: _BadgesCell(),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.unit});
  final String label;
  final String value;
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: cs.textMuted,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: cs.textPrimary,
                ),
              ),
              if (unit != null)
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.textMuted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BadgesCell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = AppColorScheme.of(context);
    final recent = ref.watch(recentBadgesProvider);
    final count  = ref.watch(earnedBadgeCountProvider);

    return GestureDetector(
      onTap: () => context.push('/badges'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            count > 0 ? 'BADGES · $count' : 'BADGES',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: cs.textMuted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          recent.isEmpty
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: cs.border,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(Icons.lock_outline,
                            size: 12, color: cs.textMuted),
                      ),
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: recent
                      .map((b) => Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: BadgeWidget(def: b, size: 22),
                          ))
                      .toList(),
                ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppColorScheme.of(context).border,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ── Week strip ────────────────────────────────────────────────────────────────

class _WeekStrip extends ConsumerWidget {
  final DateTime weekStart;
  final String weekLabel;
  final List<String> loggedDates;
  final String today;
  final DateTime todayNorm;
  final String Function(DateTime) isoFor;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _WeekStrip({
    required this.weekStart,
    required this.weekLabel,
    required this.loggedDates,
    required this.today,
    required this.todayNorm,
    required this.isoFor,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = AppColorScheme.of(context);
    final settings = ref.watch(settingsProvider);
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final loggedSet = loggedDates.toSet();

    return Container(
      color: cs.card,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: cs.textMuted),
                onPressed: onPrev,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
              Text(
                weekLabel,
                style: TextStyle(
                  color: cs.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: cs.textMuted),
                onPressed: onNext,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day = weekStart.add(Duration(days: i));
              final iso = isoFor(day);
              final isToday = iso == today;
              final hasEntries = loggedSet.contains(iso);

              // Achievement ring
              final totals = ref.watch(macroTotalsProvider(iso));
              final goals  = settings.goalsForDate(iso);
              final proteinHit = goals.protein > 0 && totals.protein >= goals.protein;
              final isPerfect  = proteinHit &&
                  goals.kcal > 0 && goals.carbs > 0 && goals.fat > 0 &&
                  totals.kcal  >= goals.kcal  * 0.95 && totals.kcal  <= goals.kcal  * 1.05 &&
                  totals.carbs >= goals.carbs * 0.95 && totals.carbs <= goals.carbs * 1.05 &&
                  totals.fat   >= goals.fat   * 0.95 && totals.fat   <= goals.fat   * 1.05;

              final ringColor = isPerfect
                  ? const Color(0xFFFBBF24)   // gold — all macros in range
                  : proteinHit
                      ? AppColors.protein      // green — protein goal hit
                      : null;

              return GestureDetector(
                onTap: () => context.push('/log/$iso'),
                child: Column(
                  children: [
                    Text(
                      dayLetters[i],
                      style: TextStyle(
                        color: isToday ? cs.textPrimary : cs.textMuted,
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: isToday ? Colors.white : Colors.transparent,
                        shape: BoxShape.circle,
                        border: ringColor != null
                            ? Border.all(color: ringColor, width: 2)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isToday ? cs.bg : cs.textPrimary,
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      child: hasEntries
                          ? Builder(builder: (ctx) {
                              final label = settings.modeLabelForDate(iso);
                              return Icon(
                                modeIcon(label),
                                size: 13,
                                color: modeColor(label, ctx),
                              );
                            })
                          : null,
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Timeline wrapper ──────────────────────────────────────────────────────────

class _TimelineDayCard extends ConsumerWidget {
  const _TimelineDayCard({required this.date, required this.isLast});
  final String date;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dotColor = modeColor(
        ref.watch(settingsProvider).modeLabelForDate(date), context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline column: dot + line
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: AppColorScheme.of(context).border,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Card
          Expanded(
            child: _DayCard(date: date),
          ),
        ],
      ),
    );
  }
}

// ── Day card ──────────────────────────────────────────────────────────────────

class _DayCard extends ConsumerWidget {
  const _DayCard({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = AppColorScheme.of(context);
    final entries = ref.watch(entriesProvider(date)).valueOrNull ?? [];
    if (entries.isEmpty) return const SizedBox.shrink();

    final totals = MacroValues.sum(entries.map((e) => e.macros));
    final mealCount = entries.map((e) => e.meal).toSet().length;
    final settings = ref.watch(settingsProvider);
    final goals = settings.goalsForDate(date);
    // Goal achievements
    final proteinHit = totals.protein >= goals.protein;
    final kcalOk = goals.kcal > 0 && totals.kcal >= goals.kcal * 0.95 && totals.kcal <= goals.kcal * 1.05;
    final carbsOk = goals.carbs > 0 && totals.carbs >= goals.carbs * 0.95 && totals.carbs <= goals.carbs * 1.05;
    final fatOk = goals.fat > 0 && totals.fat >= goals.fat * 0.95 && totals.fat <= goals.fat * 1.05;
    final perfectDay = proteinHit && kcalOk && carbsOk && fatOk;

    return GestureDetector(
      onTap: () => context.push('/log/$date'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 0),
              child: Row(
                children: [
                  // Date
                  Expanded(
                    child: Text(
                      formatDateFull(date),
                      style: TextStyle(
                        color: cs.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  // Perfect day fire
                  if (perfectDay) ...[
                    const Text('🔥', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  ModePill(date: date),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      size: 16, color: cs.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Macro row — colored values
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  _MacroStat(
                    label: 'KCAL',
                    value: '${totals.kcal.round()}',
                    color: AppColorScheme.of(context).kcalColor,
                    hit: kcalOk,
                  ),
                  const SizedBox(width: 16),
                  _MacroStat(
                    label: 'PROTEIN',
                    value: '${totals.protein.round()}g',
                    color: AppColors.protein,
                    hit: proteinHit,
                  ),
                  const SizedBox(width: 16),
                  _MacroStat(
                    label: 'CARBS',
                    value: '${totals.carbs.round()}g',
                    color: AppColors.carbs,
                    hit: carbsOk,
                  ),
                  const SizedBox(width: 16),
                  _MacroStat(
                    label: 'FAT',
                    value: '${totals.fat.round()}g',
                    color: AppColors.fat,
                    hit: fatOk,
                  ),
                  const Spacer(),
                  Text(
                    '$mealCount meal${mealCount == 1 ? '' : 's'}',
                    style: TextStyle(
                        fontSize: 11, color: cs.textMuted),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ── Macro stat cell ───────────────────────────────────────────────────────────

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.value,
    required this.color,
    required this.hit,
  });
  final String label;
  final String value;
  final Color color;
  final bool hit;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: cs.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            if (hit) ...[
              const SizedBox(width: 3),
              Icon(Icons.check_circle_rounded, size: 9, color: color),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
