import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/badge.dart';
import '../providers/foods_provider.dart';
import '../providers/settings_provider.dart';

// ---------------------------------------------------------------------------
// BadgesState
// ---------------------------------------------------------------------------
class BadgesState {
  /// String IDs of all badges earned so far (write-once, never removed).
  final Set<String> earned;
  final bool loading;
  /// Queue of newly-earned badge stringIds waiting to be shown as popups.
  final List<String> newlyEarnedQueue;

  const BadgesState({
    this.earned = const {},
    this.loading = true,
    this.newlyEarnedQueue = const [],
  });

  BadgesState copyWith({
    Set<String>? earned,
    bool? loading,
    List<String>? newlyEarnedQueue,
  }) =>
      BadgesState(
        earned: earned ?? this.earned,
        loading: loading ?? this.loading,
        newlyEarnedQueue: newlyEarnedQueue ?? this.newlyEarnedQueue,
      );
}

// ---------------------------------------------------------------------------
// BadgesNotifier
// ---------------------------------------------------------------------------
class BadgesNotifier extends StateNotifier<BadgesState> {
  BadgesNotifier(this._ref) : super(const BadgesState()) {
    load();
  }

  final Ref _ref;
  final _supabase = Supabase.instance.client;

  // Whether the first DB load has completed (prevents popup-on-first-load).
  bool _initialLoadDone = false;

  Future<void> load() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      state = state.copyWith(loading: false);
      return;
    }

    // 1. Load already-earned badges from Supabase (source of truth).
    Set<String> dbEarned = {};
    try {
      final rows = await _supabase
          .from('user_badges')
          .select('badge_id')
          .eq('user_id', user.id);
      dbEarned = (rows as List)
          .map((r) => r['badge_id'] as String)
          .toSet();
    } catch (_) {}

    _initialLoadDone = true;

    // 2. Compute earned badges from current data.
    final computed = await _computeFromData();

    // 3. Merge — write-once, never remove.
    final merged = {...dbEarned, ...computed};

    // 4. Upsert only newly computed badges that aren't in DB yet.
    final toSave = computed.difference(dbEarned);
    if (toSave.isNotEmpty) {
      try {
        final rows = toSave
            .map((id) => {'user_id': user.id, 'badge_id': id})
            .toList();
        await _supabase
            .from('user_badges')
            .upsert(rows, onConflict: 'user_id,badge_id');
      } catch (_) {}
    }

    state = BadgesState(earned: merged, loading: false);
  }

  Future<Set<String>> _computeFromData() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return {};

    // Fetch all entries with food macro data.
    List<RawBadgeEntry> entries = [];
    try {
      final rows = await _supabase
          .from('entries')
          .select('date, qty, foods(kcal, protein, carbs, fat, unit, category)')
          .eq('user_id', user.id);
      entries = (rows as List)
          .map((r) => RawBadgeEntry.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (_) {}

    // Get foods list from provider.
    final foods = _ref.read(foodListProvider);
    final userFoodsCount = foods.length;
    final hasHomeRecipe = foods.any((f) => f.category == 'homeRecipe');

    // Goals resolver.
    final settings = _ref.read(settingsProvider);
    ({double kcal, double protein, double carbs, double fat}) goalsForDate(String date) {
      final g = settings.goalsForDate(date);
      return (kcal: g.kcal, protein: g.protein, carbs: g.carbs, fat: g.fat);
    }

    return computeEarnedBadgeStringIds(
      entries: entries,
      userFoodsCount: userFoodsCount,
      hasHomeRecipe: hasHomeRecipe,
      goalsForDate: goalsForDate,
    );
  }

  /// Call after new entries or foods are added to recompute badges.
  Future<void> recompute() async {
    if (!_initialLoadDone) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final computed = await _computeFromData();
    final newlyEarned = computed.difference(state.earned);
    if (newlyEarned.isEmpty) return;

    final merged = {...state.earned, ...newlyEarned};
    // Sort newly earned by badge id so popups appear in logical order.
    final queue = [
      ...state.newlyEarnedQueue,
      ...kBadges
          .where((b) => newlyEarned.contains(b.stringId))
          .map((b) => b.stringId),
    ];
    state = state.copyWith(earned: merged, newlyEarnedQueue: queue);

    try {
      final rows = newlyEarned
          .map((id) => {'user_id': user.id, 'badge_id': id})
          .toList();
      await _supabase
          .from('user_badges')
          .upsert(rows, onConflict: 'user_id,badge_id');
    } catch (_) {}
  }

  /// Removes the first badge from the popup queue (call after dialog is dismissed).
  void popQueue() {
    if (state.newlyEarnedQueue.isEmpty) return;
    state = state.copyWith(
      newlyEarnedQueue: state.newlyEarnedQueue.sublist(1),
    );
  }

  /// Returns the 3 most recently earned badges (by kBadges list order, latest id first).
  List<BadgeDef> get recentBadges {
    final earnedDefs = kBadges
        .where((b) => state.earned.contains(b.stringId))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));
    return earnedDefs.take(3).toList();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------
final badgesProvider =
    StateNotifierProvider<BadgesNotifier, BadgesState>((ref) {
  return BadgesNotifier(ref);
});

/// Convenience: how many badges have been earned.
final earnedBadgeCountProvider = Provider<int>((ref) {
  return ref.watch(badgesProvider).earned.length;
});

/// First badge in the unlock popup queue (null when queue is empty).
final badgeUnlockQueueProvider = Provider<BadgeDef?>((ref) {
  final queue = ref.watch(badgesProvider).newlyEarnedQueue;
  if (queue.isEmpty) return null;
  try {
    return kBadges.firstWhere((b) => b.stringId == queue.first);
  } catch (_) {
    return null;
  }
});

/// Convenience: 3 most recently earned BadgeDefs.
final recentBadgesProvider = Provider<List<BadgeDef>>((ref) {
  final earned = ref.watch(badgesProvider).earned;
  return (kBadges.where((b) => earned.contains(b.stringId)).toList()
        ..sort((a, b) => b.id.compareTo(a.id)))
      .take(3)
      .toList();
});
