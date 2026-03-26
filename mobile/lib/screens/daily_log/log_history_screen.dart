import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils.dart';
import '../../models/entry.dart';
import '../../providers/entries_provider.dart';
import '../../providers/log_history_provider.dart';
import '../../theme.dart';
import '../../widgets/mode_pill.dart';

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

  String _isoFor(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _weekLabel() {
    final end = _weekStart.add(const Duration(days: 6));
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (_weekStart.month == end.month) {
      return '${months[_weekStart.month]} ${_weekStart.day} – ${end.day}';
    }
    return '${months[_weekStart.month]} ${_weekStart.day} – ${months[end.month]} ${end.day}';
  }

  @override
  Widget build(BuildContext context) {
    final loggedDatesAsync = ref.watch(loggedDatesProvider);
    final loggedDates = loggedDatesAsync.valueOrNull ?? [];

    final today = todayISO();
    final todayDate = DateTime.now();
    final todayNorm = DateTime(todayDate.year, todayDate.month, todayDate.day);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text(
          'Log',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _WeekStrip(
            weekStart: _weekStart,
            weekLabel: _weekLabel(),
            loggedDates: loggedDates,
            today: today,
            todayNorm: todayNorm,
            isoFor: _isoFor,
            onPrev: () => setState(() {
              _weekStart = _weekStart.subtract(const Duration(days: 7));
            }),
            onNext: () => setState(() {
              _weekStart = _weekStart.add(const Duration(days: 7));
            }),
          ),
          Expanded(
            child: loggedDatesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.protein),
              ),
              error: (_, __) => const Center(
                child: Text(
                  'Failed to load history',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              data: (dates) {
                if (dates.isEmpty) {
                  return const Center(
                    child: Text(
                      'No logged days yet',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Past Logs (${dates.length})',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: dates.length,
                        itemBuilder: (context, index) {
                          return _DayCard(date: dates[index]);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
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
  Widget build(BuildContext context) {
    const dayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final loggedSet = loggedDates.toSet();

    return Container(
      color: AppColors.card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.textMuted),
                onPressed: onPrev,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
              Text(
                weekLabel,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                onPressed: onNext,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final day = weekStart.add(Duration(days: i));
              final iso = isoFor(day);
              final isToday = iso == today;
              final hasEntries = loggedSet.contains(iso);

              return GestureDetector(
                onTap: () => context.push('/log/$iso'),
                child: Column(
                  children: [
                    Text(
                      dayLetters[i],
                      style: TextStyle(
                        color: isToday ? AppColors.textPrimary : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: isToday
                          ? const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            )
                          : null,
                      alignment: Alignment.center,
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          color: isToday ? AppColors.bg : AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: hasEntries ? AppColors.protein : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
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

class _DayCard extends ConsumerWidget {
  final String date;

  const _DayCard({required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(entriesProvider(date)).valueOrNull ?? [];

    if (entries.isEmpty) return const SizedBox.shrink();

    final totals = MacroValues.sum(entries.map((e) => e.macros));
    final mealCount = entries.map((e) => e.meal).toSet().length;

    return GestureDetector(
      onTap: () => context.push('/log/$date'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: AppColors.protein, width: 3),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  formatDateFull(date),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ModePill(date: date),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${totals.kcal.round()} kcal  ·  P ${totals.protein.round()}  C ${totals.carbs.round()}  F ${totals.fat.round()} g',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              '$mealCount meal${mealCount == 1 ? '' : 's'}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
