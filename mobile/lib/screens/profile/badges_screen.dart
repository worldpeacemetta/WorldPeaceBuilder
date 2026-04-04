import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/badge.dart';
import '../../providers/badges_provider.dart';
import '../../theme.dart';
import '../../widgets/badge_widget.dart';

class BadgesScreen extends ConsumerWidget {
  const BadgesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesState = ref.watch(badgesProvider);
    final earned = badgesState.earned;
    final total  = kBadges.length;
    final count  = kBadges.where((b) => earned.contains(b.stringId)).length;

    // Group badges by category
    final categories = <String, List<BadgeDef>>{};
    for (final b in kBadges) {
      categories.putIfAbsent(b.category, () => []).add(b);
    }

    final cs = AppColorScheme.of(context);
    return Scaffold(
      backgroundColor: cs.bg,
      appBar: AppBar(
        backgroundColor: cs.card,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: cs.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Achievements',
          style: TextStyle(
            color: cs.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$count / $total',
                style: TextStyle(
                  color: cs.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: badgesState.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ProgressBar(count: count, total: total),
                ),
                const SizedBox(height: 20),
                // Categories
                ...categories.entries.map((entry) => _CategorySection(
                      category: entry.key,
                      badges: entry.value,
                      earned: earned,
                    )),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.count, required this.total});
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final pct = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$count unlocked',
              style: TextStyle(
                color: cs.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(pct * 100).round()}%',
              style: TextStyle(
                color: cs.textMuted,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 6,
            backgroundColor: cs.border,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.protein),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.badges,
    required this.earned,
  });
  final String category;
  final List<BadgeDef> badges;
  final Set<String> earned;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Text(
            category.toUpperCase(),
            style: TextStyle(
              color: AppColorScheme.of(context).textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        ...badges.map((b) => _BadgeRow(def: b, unlocked: earned.contains(b.stringId))),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.def, required this.unlocked});
  final BadgeDef def;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    return GestureDetector(
      onTap: () => _showBadgeDetail(context, def),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(12),
          border: unlocked
              ? Border.all(
                  color: def.colorEnd.withValues(alpha: 0.4),
                  width: 1,
                )
              : null,
        ),
        child: Row(
          children: [
            BadgeWidget(def: def, size: 48, locked: !unlocked),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          def.name,
                          style: TextStyle(
                            color: unlocked ? cs.textPrimary : cs.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unlocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: def.colorStart.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Unlocked',
                            style: TextStyle(
                              color: def.colorEnd,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    def.desc,
                    style: TextStyle(color: cs.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16,
                color: cs.textMuted.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge detail bottom sheet
// ---------------------------------------------------------------------------

void _showBadgeDetail(BuildContext context, BadgeDef initial) {
  // Gather earned state from the nearest ProviderScope
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _BadgeDetailSheet(initial: initial),
    ),
  );
}

class _BadgeDetailSheet extends ConsumerStatefulWidget {
  const _BadgeDetailSheet({required this.initial});
  final BadgeDef initial;

  @override
  ConsumerState<_BadgeDetailSheet> createState() => _BadgeDetailSheetState();
}

class _BadgeDetailSheetState extends ConsumerState<_BadgeDetailSheet> {
  late final PageController _pageCtrl;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = kBadges.indexWhere((b) => b.stringId == widget.initial.stringId);
    if (_currentIndex < 0) _currentIndex = 0;
    _pageCtrl = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pageCtrl.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final earned = ref.watch(badgesProvider).earned;
    final cs = AppColorScheme.of(context);
    final def = kBadges[_currentIndex];
    final unlocked = earned.contains(def.stringId);

    return Container(
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // PageView — swipeable badges
          SizedBox(
            height: 240,
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: kBadges.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                final b = kBadges[i];
                final isUnlocked = earned.contains(b.stringId);
                return _BadgePage(def: b, unlocked: isUnlocked);
              },
            ),
          ),

          const SizedBox(height: 16),

          // Name + category
          Text(def.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(def.category,
              style: TextStyle(fontSize: 12, color: cs.textMuted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(def.desc,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.textMuted, height: 1.4)),

          const SizedBox(height: 16),

          // Unlocked chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: unlocked
                  ? def.colorStart.withValues(alpha: 0.15)
                  : cs.border.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  size: 13,
                  color: unlocked ? def.colorEnd : cs.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  unlocked ? 'Unlocked' : 'Locked',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: unlocked ? def.colorEnd : cs.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Arrow navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _currentIndex > 0
                    ? () => _goTo(_currentIndex - 1)
                    : null,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                iconSize: 20,
                color: _currentIndex > 0 ? cs.textPrimary : cs.border,
              ),
              const SizedBox(width: 8),
              Text(
                '${_currentIndex + 1} / ${kBadges.length}',
                style: TextStyle(fontSize: 12, color: cs.textMuted),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _currentIndex < kBadges.length - 1
                    ? () => _goTo(_currentIndex + 1)
                    : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded),
                iconSize: 20,
                color: _currentIndex < kBadges.length - 1
                    ? cs.textPrimary
                    : cs.border,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgePage extends StatelessWidget {
  const _BadgePage({required this.def, required this.unlocked});
  final BadgeDef def;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: unlocked
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: def.colorStart.withValues(alpha: 0.35),
                      blurRadius: 40,
                      spreadRadius: 12,
                    ),
                  ],
                )
              : null,
          child: Center(
            child: BadgeWidget(def: def, size: 140, locked: !unlocked),
          ),
        ),
      ],
    );
  }
}
