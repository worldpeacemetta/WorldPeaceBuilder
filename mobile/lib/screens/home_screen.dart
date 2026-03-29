import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils.dart';
import '../providers/date_provider.dart';
import '../widgets/add_entry_sheet.dart';
import '../theme.dart';

// ── Nav item descriptor ───────────────────────────────────────────────────────

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

const _leftItems = [
  _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded,   label: 'Dashboard', index: 1),
  _NavItem(icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note_rounded,   label: 'Log',       index: 0),
];
const _rightItems = [
  _NavItem(icon: Icons.restaurant_menu_outlined, activeIcon: Icons.restaurant_menu_rounded, label: 'Foods',   index: 2),
  _NavItem(icon: Icons.person_outline_rounded,   activeIcon: Icons.person_rounded,           label: 'Profile', index: 3),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: shell,
      // No floatingActionButton — FAB lives inside the arch bar
      bottomNavigationBar: _ArchNavBar(
        currentIndex: shell.currentIndex,
        onTabSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        onFabTap: () {
          final logDate = ref.read(logDateProvider);
          showAddEntrySheet(context, ref, logDate);
        },
      ),
    );
  }
}

// ── Arch nav bar ──────────────────────────────────────────────────────────────

class _ArchNavBar extends StatelessWidget {
  const _ArchNavBar({
    required this.currentIndex,
    required this.onTabSelected,
    required this.onFabTap,
  });

  final int currentIndex;
  final void Function(int) onTabSelected;
  final VoidCallback onFabTap;

  static const _archRise   = 22.0;  // how much center lifts above edges
  static const _barH       = 62.0;  // nav content height (excl. safe area)
  static const _fabD       = 52.0;  // FAB diameter
  static const _fabHalf    = _fabD / 2;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // Total arch-bar height: rise + content + safe-area
    final archBarH = _archRise + _barH + bottomPad;
    // Widget height adds top half of FAB so it isn't clipped
    final widgetH = archBarH + _fabHalf;

    return SizedBox(
      height: widgetH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Arch background + nav buttons ──────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: archBarH,
            child: CustomPaint(
              painter: _ArchPainter(archRise: _archRise),
              child: Padding(
                padding: EdgeInsets.only(
                  top: _archRise,
                  bottom: bottomPad,
                ),
                child: Row(
                  children: [
                    // Left items
                    ..._leftItems.map((item) => Expanded(
                      child: _NavBtn(
                        item: item,
                        selected: currentIndex == item.index,
                        onTap: () => onTabSelected(item.index),
                      ),
                    )),
                    // Centre gap for FAB
                    const SizedBox(width: _fabD + 16),
                    // Right items
                    ..._rightItems.map((item) => Expanded(
                      child: _NavBtn(
                        item: item,
                        selected: currentIndex == item.index,
                        onTap: () => onTabSelected(item.index),
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ),

          // ── FAB at arch peak ───────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onFabTap,
                child: Container(
                  width: _fabD,
                  height: _fabD,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.black, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nav button ────────────────────────────────────────────────────────────────

class _NavBtn extends StatelessWidget {
  const _NavBtn({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
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
    );
  }
}

// ── Arch painter ──────────────────────────────────────────────────────────────

class _ArchPainter extends CustomPainter {
  const _ArchPainter({required this.archRise});
  final double archRise;

  @override
  void paint(Canvas canvas, Size size) {
    // Path: bottom-left → left arch base → arch peak (center top) → right arch
    // base → bottom-right → close
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, archRise)
      // Quadratic bezier: control at (width/2, -archRise) ensures the peak
      // passes exactly through (width/2, 0) — i.e. the very top of the area.
      ..quadraticBezierTo(
        size.width / 2, -archRise,
        size.width, archRise,
      )
      ..lineTo(size.width, size.height)
      ..close();

    // Shadow
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.6), 12, true);

    // Fill
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.card
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_ArchPainter old) => old.archRise != archRise;
}
