import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'router.dart';
import 'theme.dart';
import 'providers/settings_provider.dart';

// Supabase credentials — anon key is safe to embed in client code.
const _supabaseUrl = 'https://cyngucsrcouldnsrtvml.supabase.co';
const _supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN5bmd1Y3NyY291bGRuc3J0dm1sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM1NjA3NTAsImV4cCI6MjA3OTEzNjc1MH0'
    '.xOTe7_R48fWxh68Q13DLK2hABmQwEaFNARtieiwXR4U';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: _supabaseUrl, anonKey: _supabaseAnonKey);
  runApp(const ProviderScope(child: MacroTrackerApp()));
}

class MacroTrackerApp extends ConsumerStatefulWidget {
  const MacroTrackerApp({super.key});

  @override
  ConsumerState<MacroTrackerApp> createState() => _MacroTrackerAppState();
}

class _MacroTrackerAppState extends ConsumerState<MacroTrackerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-sync from Supabase whenever the app returns to the foreground so
  /// changes made on the web app (goal schedule, body stats, goals) are
  /// picked up without a full restart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      ref.read(settingsProvider.notifier).syncFromSupabase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MacroTracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
