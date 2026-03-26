import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils.dart';
import '../providers/date_provider.dart';
import '../widgets/add_entry_sheet.dart';
import '../theme.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Left side: Log (0), Dashboard (1)
    // Right side: Foods (2), Profile (3)
    const leftItems = [
      _NavItem(icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note_rounded, label: 'Log', index: 0),
      _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Dashboard', index: 1),
    ];
    const rightItems = [
      _NavItem(icon: Icons.restaurant_menu_outlined, activeIcon: Icons.restaurant_menu_rounded, label: 'Foods', index: 2),
      _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'Profile', index: 3),
    ];

    return Scaffold(
      body: shell,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final logDate = ref.read(logDateProvider);
          showAddEntrySheet(context, ref, logDate);
        },
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: AppColors.card,
        elevation: 8,
        height: 64,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            ...leftItems.map((item) => _NavButton(
              item: item,
              selected: shell.currentIndex == item.index,
              onTap: () => shell.goBranch(
                item.index,
                initialLocation: item.index == shell.currentIndex,
              ),
            )),
            // Centre gap for FAB notch
            const SizedBox(width: 56),
            ...rightItems.map((item) => _NavButton(
              item: item,
              selected: shell.currentIndex == item.index,
              onTap: () => shell.goBranch(
                item.index,
                initialLocation: item.index == shell.currentIndex,
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
}

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.activeIcon : item.icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
