import 'dart:convert';

import 'package:fluffy_merge/data/local/save_data.dart';
import 'package:fluffy_merge/data/local/save_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reads the versioned save document straight from SharedPreferences
/// (what would survive an app restart).
SaveData readSave(SharedPreferences prefs) {
  final raw = prefs.getString(SaveStore.primaryKey);
  if (raw == null) throw StateError('No save written yet');
  return SaveData.fromJson(
    (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', v)),
  );
}
