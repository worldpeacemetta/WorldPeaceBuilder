import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final loggedDatesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];
  try {
    final data = await Supabase.instance.client
        .from('entries')
        .select('date')
        .order('date', ascending: false);
    final seen = <String>{};
    return (data as List)
        .map((e) => e['date'] as String)
        .where(seen.add)
        .toList();
  } catch (_) {
    return [];
  }
});
