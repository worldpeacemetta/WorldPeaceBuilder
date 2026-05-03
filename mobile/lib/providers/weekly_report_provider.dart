import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';
import '../models/entry.dart';
import '../models/food.dart';
import 'settings_provider.dart';

final _db = Supabase.instance.client;

// ── DayReport — data for a single day within the weekly report ────────────────

class DayReport {
  const DayReport({
    required this.date,
    required this.modeLabel,
    required this.totals,
    required this.goals,
    required this.logged,
  });

  final String     date;
  final String     modeLabel;
  final MacroValues totals;
  final MacroGoals  goals;
  final bool        logged;

  /// Average hit fraction across 4 macros (0 = not logged, 1 = all goals met).
  double get score {
    if (!logged) return 0;
    double s = 0, n = 0;
    void check(double actual, double goal) {
      if (goal > 0) {
        s += (actual / goal).clamp(0.0, 1.0);
        n++;
      }
    }
    check(totals.kcal,    goals.kcal);
    check(totals.protein, goals.protein);
    check(totals.carbs,   goals.carbs);
    check(totals.fat,     goals.fat);
    return n > 0 ? s / n : 0;
  }

  // Kcal/carbs/fat: within ±10% of goal. Protein: at or above 90% only (overshoot is fine).
  bool get hitKcal    => logged && goals.kcal    > 0 && totals.kcal    >= goals.kcal    * 0.9 && totals.kcal    <= goals.kcal    * 1.1;
  bool get hitProtein => logged && goals.protein > 0 && totals.protein >= goals.protein * 0.9;
  bool get hitCarbs   => logged && goals.carbs   > 0 && totals.carbs   >= goals.carbs   * 0.9 && totals.carbs   <= goals.carbs   * 1.1;
  bool get hitFat     => logged && goals.fat     > 0 && totals.fat     >= goals.fat     * 0.9 && totals.fat     <= goals.fat     * 1.1;
  bool get hitAll     => hitKcal && hitProtein && hitCarbs && hitFat;
}

// ── WeeklyReportData — the complete weekly report payload ─────────────────────

class WeeklyReportData {
  const WeeklyReportData({
    required this.weekStart,
    required this.weekEnd,
    required this.days,
    required this.avgActual,
    required this.avgGoal,
    required this.daysHitKcal,
    required this.daysHitProtein,
    required this.daysHitCarbs,
    required this.daysHitFat,
    this.bestDayIndex,
    required this.cumulativeBalance,
    required this.totalSurplus,
    required this.kcalBySlot,
    required this.proteinBySlot,
    required this.weekdayAvg,
    required this.weekendAvg,
    required this.weekdayLogged,
    required this.weekendLogged,
    this.prevWeekAvg,
    required this.prevWeekLogged,
    required this.uniqueFoodsCount,
    this.topFoodName,
    required this.topFoodFrequency,
    required this.weightEntries,
    required this.hadPerfectDay,
    required this.proteinEveryLoggedDay,
    required this.allDaysLogged,
  });

  final String          weekStart;          // YYYY-MM-DD (Monday)
  final String          weekEnd;            // YYYY-MM-DD (Sunday)
  final List<DayReport> days;               // 7 items: Mon(0) … Sun(6)

  final MacroValues avgActual;              // average over logged days
  final MacroValues avgGoal;               // average goal over logged days
  final int daysHitKcal;
  final int daysHitProtein;
  final int daysHitCarbs;
  final int daysHitFat;

  final int? bestDayIndex;                  // 0-6, highest macro score

  final List<double> cumulativeBalance;     // running kcal surplus per day
  final double totalSurplus;               // total (+ = surplus, − = deficit)

  final Map<String, double> kcalBySlot;
  final Map<String, double> proteinBySlot;

  final MacroValues weekdayAvg;            // Mon–Fri average (logged days)
  final MacroValues weekendAvg;            // Sat–Sun average (logged days)
  final int weekdayLogged;
  final int weekendLogged;

  final MacroValues? prevWeekAvg;
  final int prevWeekLogged;

  final int     uniqueFoodsCount;
  final String? topFoodName;
  final int     topFoodFrequency;

  final List<WeightEntry> weightEntries;   // weight entries within ±7-day window

  final bool hadPerfectDay;               // ≥1 day where all 4 macros hit ≥90%
  final bool proteinEveryLoggedDay;
  final bool allDaysLogged;

  int    get daysLogged       => days.where((d) => d.logged).length;
  double get consistencyPct   => daysLogged / 7 * 100;
}

// ── Helper ────────────────────────────────────────────────────────────────────

MacroValues _divideBy(MacroValues sum, double n) => MacroValues(
  kcal:    sum.kcal    / n,
  protein: sum.protein / n,
  carbs:   sum.carbs   / n,
  fat:     sum.fat     / n,
);

// ── Provider — parameterised by the Monday ISO date of the REPORT week ────────

final weeklyReportProvider = FutureProvider.autoDispose
    .family<WeeklyReportData?, String>((ref, mondayISO) async {
  final user = _db.auth.currentUser;
  if (user == null) return null;

  final settings = ref.read(settingsProvider);

  final mondayDt     = DateTime.parse(mondayISO);
  final sundayDt     = mondayDt.add(const Duration(days: 6));
  final prevMondayDt = mondayDt.subtract(const Duration(days: 7));
  final prevSundayDt = prevMondayDt.add(const Duration(days: 6));

  final sundayISO     = isoDate(sundayDt);
  final prevMondayISO = isoDate(prevMondayDt);
  final prevSundayISO = isoDate(prevSundayDt);

  // Single query for 14 days (report week + comparison week).
  final raw = await _db
      .from('entries')
      .select('*, food:foods(*)')
      .gte('date', prevMondayISO)
      .lte('date', sundayISO)
      .order('date');

  final all = (raw as List)
      .map((j) => Entry.fromJson(j as Map<String, dynamic>))
      .toList();

  final reportEntries = all
      .where((e) => e.date.compareTo(mondayISO)  >= 0 && e.date.compareTo(sundayISO)     <= 0)
      .toList();
  final prevEntries = all
      .where((e) => e.date.compareTo(prevMondayISO) >= 0 && e.date.compareTo(prevSundayISO) <= 0)
      .toList();

  // Require at least 1 logged day in the report week.
  final reportDates = List.generate(7, (i) => isoDate(mondayDt.add(Duration(days: i))));
  final anyLogged   = reportDates.any((d) => reportEntries.any((e) => e.date == d));
  if (!anyLogged) return null;

  // ── Per-day reports ──────────────────────────────────────────────────────
  final dayReports = <DayReport>[];
  for (int i = 0; i < 7; i++) {
    final date       = reportDates[i];
    final dayEntries = reportEntries.where((e) => e.date == date).toList();
    final logged     = dayEntries.isNotEmpty;
    dayReports.add(DayReport(
      date:      date,
      modeLabel: settings.modeLabelForDate(date),
      totals:    logged ? MacroValues.sum(dayEntries.map((e) => e.macros)) : const MacroValues(),
      goals:     settings.goalsForDate(date),
      logged:    logged,
    ));
  }

  // ── Aggregates ───────────────────────────────────────────────────────────
  final logged = dayReports.where((d) => d.logged).toList();
  final n      = logged.length.toDouble();

  MacroValues avgActual = const MacroValues();
  MacroValues avgGoal   = const MacroValues();
  if (n > 0) {
    avgActual = _divideBy(MacroValues.sum(logged.map((d) => d.totals)), n);
    final gk = logged.fold(0.0, (s, d) => s + d.goals.kcal)    / n;
    final gp = logged.fold(0.0, (s, d) => s + d.goals.protein) / n;
    final gc = logged.fold(0.0, (s, d) => s + d.goals.carbs)   / n;
    final gf = logged.fold(0.0, (s, d) => s + d.goals.fat)     / n;
    avgGoal = MacroValues(kcal: gk, protein: gp, carbs: gc, fat: gf);
  }

  // ── Best day ─────────────────────────────────────────────────────────────
  int? bestDayIndex;
  double bestScore = -1;
  for (int i = 0; i < 7; i++) {
    if (dayReports[i].logged && dayReports[i].score > bestScore) {
      bestScore    = dayReports[i].score;
      bestDayIndex = i;
    }
  }

  // ── Cumulative calorie balance ────────────────────────────────────────────
  double running      = 0;
  double totalSurplus = 0;
  final cumulativeBalance = <double>[];
  for (final day in dayReports) {
    final delta = day.logged ? day.totals.kcal - day.goals.kcal : 0.0;
    running     += delta;
    totalSurplus += delta;
    cumulativeBalance.add(running);
  }

  // ── Meal slot distribution ───────────────────────────────────────────────
  const slots = ['breakfast', 'lunch', 'dinner', 'snack', 'other'];
  final kcalBySlot    = <String, double>{};
  final proteinBySlot = <String, double>{};
  for (final s in slots) {
    final es = reportEntries.where((e) => e.meal == s).toList();
    kcalBySlot[s]    = es.fold(0.0, (acc, e) => acc + e.macros.kcal);
    proteinBySlot[s] = es.fold(0.0, (acc, e) => acc + e.macros.protein);
  }

  // ── Weekday (Mon–Fri) vs weekend (Sat–Sun) ───────────────────────────────
  MacroValues calcSliceAvg(List<DayReport> slice) {
    final ld = slice.where((d) => d.logged).toList();
    if (ld.isEmpty) return const MacroValues();
    return _divideBy(MacroValues.sum(ld.map((d) => d.totals)), ld.length.toDouble());
  }
  final wdDays     = dayReports.sublist(0, 5);
  final weDays     = dayReports.sublist(5, 7);
  final weekdayAvg = calcSliceAvg(wdDays);
  final weekendAvg = calcSliceAvg(weDays);

  // ── Previous week average ─────────────────────────────────────────────────
  final prevDates  = List.generate(7, (i) => isoDate(prevMondayDt.add(Duration(days: i))));
  final prevLogged = prevDates.where((d) => prevEntries.any((e) => e.date == d)).toList();
  MacroValues? prevWeekAvg;
  if (prevLogged.isNotEmpty) {
    final pe  = prevEntries.where((e) => prevLogged.contains(e.date)).toList();
    final sum = MacroValues.sum(pe.map((e) => e.macros));
    prevWeekAvg = _divideBy(sum, prevLogged.length.toDouble());
  }

  // ── Food variety ─────────────────────────────────────────────────────────
  final foodCount = <String, int>{};
  final foodNames = <String, String>{};
  for (final e in reportEntries) {
    foodCount[e.foodId] = (foodCount[e.foodId] ?? 0) + 1;
    if (e.food != null) foodNames[e.foodId] = e.food!.name;
  }
  String? topFoodName;
  int topFoodFrequency = 0;
  if (foodCount.isNotEmpty) {
    final topId      = foodCount.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    topFoodFrequency = foodCount[topId]!;
    topFoodName      = foodNames[topId];
  }

  // ── Weight entries within the 14-day window ───────────────────────────────
  final weightEntries = settings.weightHistory
      .where((w) => w.date.compareTo(prevMondayISO) >= 0 && w.date.compareTo(sundayISO) <= 0)
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  return WeeklyReportData(
    weekStart:       mondayISO,
    weekEnd:         sundayISO,
    days:            dayReports,
    avgActual:       avgActual,
    avgGoal:         avgGoal,
    daysHitKcal:    logged.where((d) => d.hitKcal).length,
    daysHitProtein: logged.where((d) => d.hitProtein).length,
    daysHitCarbs:   logged.where((d) => d.hitCarbs).length,
    daysHitFat:     logged.where((d) => d.hitFat).length,
    bestDayIndex:        bestDayIndex,
    cumulativeBalance:   cumulativeBalance,
    totalSurplus:        totalSurplus,
    kcalBySlot:          kcalBySlot,
    proteinBySlot:       proteinBySlot,
    weekdayAvg:          weekdayAvg,
    weekendAvg:          weekendAvg,
    weekdayLogged:       wdDays.where((d) => d.logged).length,
    weekendLogged:       weDays.where((d) => d.logged).length,
    prevWeekAvg:         prevWeekAvg,
    prevWeekLogged:      prevLogged.length,
    uniqueFoodsCount:    foodCount.length,
    topFoodName:         topFoodName,
    topFoodFrequency:    topFoodFrequency,
    weightEntries:       weightEntries,
    hadPerfectDay:         logged.any((d) => d.hitAll),
    proteinEveryLoggedDay: logged.isNotEmpty && logged.every((d) => d.hitProtein),
    allDaysLogged:         logged.length == 7,
  );
});
