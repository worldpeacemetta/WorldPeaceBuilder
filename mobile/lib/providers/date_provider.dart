import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils.dart';

// ---------------------------------------------------------------------------
// Log date — drives Daily Log screen.
// ---------------------------------------------------------------------------
final logDateProvider = StateProvider<String>((ref) => todayISO());

// ---------------------------------------------------------------------------
// Dashboard date — drives Dashboard screen.
// ---------------------------------------------------------------------------
final dashboardDateProvider = StateProvider<String>((ref) => todayISO());

// ---------------------------------------------------------------------------
// Week nav date — drives the weekly chart.
// When logDate changes, dashboard and week sync to it.
// ---------------------------------------------------------------------------
final weekNavDateProvider = StateProvider<String>((ref) => todayISO());

// ---------------------------------------------------------------------------
// Helper: set all three to the same date (e.g. "Today" button).
// ---------------------------------------------------------------------------
void setAllDates(WidgetRef ref, String iso) {
  ref.read(logDateProvider.notifier).state = iso;
  ref.read(dashboardDateProvider.notifier).state = iso;
  ref.read(weekNavDateProvider.notifier).state = iso;
}

// ---------------------------------------------------------------------------
// Dashboard activation counter — incremented each time the Dashboard tab is
// selected. ActivityRingsPanel watches this to replay its fill animation.
// ---------------------------------------------------------------------------
final dashboardActivationProvider = StateProvider<int>((ref) => 0);
