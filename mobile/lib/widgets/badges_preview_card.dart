import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/badge.dart';
import '../providers/badges_provider.dart';
import '../theme.dart';
import 'badge_widget.dart';

// ---------------------------------------------------------------------------
// BadgesPreviewCard
//
// Add this widget inside your ProfileScreen to show the achievements section.
// Tapping "See all" navigates to /badges.
// ---------------------------------------------------------------------------
class BadgesPreviewCard extends ConsumerWidget {
  const BadgesPreviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badgesState  = ref.watch(badgesProvider);
    final recentBadges = ref.watch(recentBadgesProvider);
    final earnedCount  = ref.watch(earnedBadgeCountProvider);
    final total        = kBadges.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Text(
                'Achievements',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push('/badges'),
                child: const Text(
                  'See all →',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: total > 0 ? earnedCount / total : 0,
              minHeight: 5,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.protein),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$earnedCount / $total unlocked',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 14),

          // Badge previews
          badgesState.loading
              ? const SizedBox(
                  height: 56,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : recentBadges.isEmpty
                  ? _EmptyState()
                  : _BadgeRow(badges: recentBadges),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({required this.badges});
  final List<BadgeDef> badges;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: badges
          .map((b) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BadgeWidget(def: b, size: 48, locked: false),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 52,
                      child: Text(
                        b.name,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.emoji_events_outlined, color: AppColors.textMuted, size: 28),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'Log meals to start earning badges',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
