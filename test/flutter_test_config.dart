import 'dart:async';

/// Runs before every test file.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
