import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils.dart';
import '../providers/settings_provider.dart';
import '../theme.dart';

// ---------------------------------------------------------------------------
// Colour + icon for each mode label
// ---------------------------------------------------------------------------
Color modeColor(String label) => switch (label) {
  'Train Day'   => AppColors.protein,
  'Rest Day'    => AppColors.carbs,
  'Bulking'     => const Color(0xFFFBBF24),
  'Cutting'     => AppColors.danger,
  _             => AppColors.textMuted,
};

IconData modeIcon(String label) => switch (label) {
  'Train Day'   => Icons.fitness_center,
  'Rest Day'    => Icons.self_improvement,
  'Bulking'     => Icons.trending_up,
  'Cutting'     => Icons.trending_down,
  _             => Icons.balance,
};

// ---------------------------------------------------------------------------
// The tappable pill shown in AppBar titles
// ---------------------------------------------------------------------------
class ModePill extends ConsumerWidget {
  const ModePill({super.key, required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final label = settings.modeLabelForDate(date);
    final color = modeColor(label);

    return GestureDetector(
      onTap: () => _showModeSheet(context, ref, date, settings),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(modeIcon(label), size: 11, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet to change / clear the mode for a specific date
// ---------------------------------------------------------------------------
void _showModeSheet(
    BuildContext context, WidgetRef ref, String date, AppSettings settings) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).extension<AppColorScheme>()!.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => ProviderScope(
      parent: ProviderScope.containerOf(context),
      child: _ModeSheet(date: date),
    ),
  );
}

class _ModeSheet extends ConsumerStatefulWidget {
  const _ModeSheet({required this.date});
  final String date;

  @override
  ConsumerState<_ModeSheet> createState() => _ModeSheetState();
}

class _ModeSheetState extends ConsumerState<_ModeSheet> {
  late String _setup;
  late String _profile;

  @override
  void initState() {
    super.initState();
    final entry = ref.read(settingsProvider).modeEntryForDate(widget.date);
    _setup   = entry['setup']   ?? 'maintenance';
    _profile = entry['profile'] ?? 'train';
  }

  Future<void> _save() async {
    await ref.read(settingsProvider.notifier)
        .setDateOverride(widget.date, _setup, _profile);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _clear() async {
    await ref.read(settingsProvider.notifier).clearDateOverride(widget.date);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = AppColorScheme.of(context);
    final settings = ref.watch(settingsProvider);
    final hasOverride = settings.hasDateOverride(widget.date);
    final isToday = widget.date == todayISO();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Goal Mode — ${formatDateFull(widget.date)}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 4),
          if (!isToday)
            const Text(
              'Sets the goal mode for this day only',
              style: TextStyle(fontSize: 12, color: cs.textMuted),
            ),
          const SizedBox(height: 16),

          // Mode options
          ...['maintenance', 'dual', 'bulking', 'cutting'].map((mode) {
            final label = _labelFor(mode, mode == 'dual' ? _profile : null);
            final color = modeColor(label);
            return InkWell(
              onTap: () => setState(() => _setup = mode),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _setup == mode
                      ? color.withValues(alpha: 0.12)
                      : cs.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _setup == mode ? color : cs.border,
                    width: _setup == mode ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(modeIcon(label), size: 16, color: _setup == mode ? color : cs.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _titleFor(mode),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: _setup == mode ? FontWeight.w600 : FontWeight.w400,
                          color: _setup == mode ? color : cs.textPrimary,
                        ),
                      ),
                    ),
                    if (_setup == mode)
                      Icon(Icons.check_circle, size: 18, color: color),
                  ],
                ),
              ),
            );
          }),

          // Train / Rest sub-toggle (dual only)
          if (_setup == 'dual') ...[
            const SizedBox(height: 4),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'train', label: Text('Train Day')),
                ButtonSegment(value: 'rest',  label: Text('Rest Day')),
              ],
              selected: {_profile},
              onSelectionChanged: (v) => setState(() => _profile = v.first),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 4),

          // Save
          ElevatedButton(
            onPressed: _save,
            child: const Text('Save'),
          ),

          // Clear override (only if there is one)
          if (hasOverride) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _clear,
              child: Text(
                'Clear override (use default)',
                style: TextStyle(color: cs.textMuted, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _titleFor(String mode) => switch (mode) {
    'dual'        => 'Train / Rest Days',
    'bulking'     => 'Bulking',
    'cutting'     => 'Cutting',
    _             => 'Maintenance',
  };

  String _labelFor(String mode, String? profile) {
    if (mode == 'dual') return profile == 'rest' ? 'Rest Day' : 'Train Day';
    return switch (mode) {
      'bulking'  => 'Bulking',
      'cutting'  => 'Cutting',
      _          => 'Maintenance',
    };
  }
}
