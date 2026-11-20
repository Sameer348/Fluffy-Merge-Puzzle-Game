import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/save_data.dart';
import '../../data/repositories/save_controller.dart';
import 'audio/audio_service.dart';

/// Haptic patterns used by the game.
enum Haptic { light, medium, heavy, selection }

/// Wraps Flutter's HapticFeedback behind the Settings toggle.
class HapticsService {
  bool enabled = true;

  /// Recorded in tests (the platform call is a no-op there).
  final List<Haptic> fired = [];

  void play(Haptic h) {
    if (!enabled) return;
    fired.add(h);
    if (fired.length > 64) fired.removeAt(0);
    switch (h) {
      case Haptic.light:
        HapticFeedback.lightImpact();
      case Haptic.medium:
        HapticFeedback.mediumImpact();
      case Haptic.heavy:
        HapticFeedback.heavyImpact();
      case Haptic.selection:
        HapticFeedback.selectionClick();
    }
  }
}

/// One place that turns game moments into sound + haptics, so screens and
/// the game never talk to audio or vibration directly.
class FeedbackService {
  FeedbackService(this.audio, this.haptics);

  final AudioService audio;
  final HapticsService haptics;

  void apply(GameSettings s) {
    audio
      ..setSfxEnabled(s.sfx)
      ..setMusicEnabled(s.music)
      ..setSfxVolume(s.sfxVolume)
      ..setMusicVolume(s.musicVolume);
    haptics.enabled = s.haptics;
  }

  /// Button press: light tick.
  void tap() {
    audio.playSfx(Sfx.tap, volume: 0.6);
    haptics.play(Haptic.light);
  }

  void drop() {
    audio.playSfx(Sfx.drop, volume: 0.7);
    haptics.play(Haptic.selection);
  }

  /// [strength] 0..1 from impact speed: louder for harder landings.
  void bounce(double strength) {
    if (strength < 0.15) return;
    audio.playSfx(Sfx.bounce, volume: 0.25 + 0.6 * strength.clamp(0.0, 1.0));
  }

  /// Merge: pitch rises with level; chains add an arpeggio; big moments
  /// get a heavy haptic, normal merges a medium one.
  void merge({required int level, required int combo, bool rainbow = false}) {
    final sfx = rainbow
        ? Sfx.merge4
        : switch (level) {
            <= 3 => Sfx.merge1,
            <= 6 => Sfx.merge2,
            <= 9 => Sfx.merge3,
            _ => Sfx.merge4,
          };
    audio.playSfx(sfx);
    if (combo >= 2 || rainbow) audio.playSfx(Sfx.chain, volume: 0.8);
    final big = rainbow || combo >= 4 || level >= 8;
    haptics.play(big ? Haptic.heavy : Haptic.medium);
  }

  void powerUp() {
    audio.playSfx(Sfx.powerUp);
    haptics.play(Haptic.medium);
  }

  void gameOver() {
    audio.playSfx(Sfx.gameOver);
    haptics.play(Haptic.heavy);
  }

  void reward() {
    audio.playSfx(Sfx.reward);
    haptics.play(Haptic.medium);
  }
}

/// Real audio in the app, a silent recorder under `flutter test`.
final audioServiceProvider = Provider<AudioService>((ref) {
  final AudioService a = runningInTest
      ? SilentAudioService()
      : AudioPlayersService();
  ref.onDispose(a.dispose);
  return a;
});

final hapticsServiceProvider = Provider<HapticsService>(
  (ref) => HapticsService(),
);

/// Feedback wired to the saved settings: toggles and volumes apply live.
final feedbackProvider = Provider<FeedbackService>((ref) {
  final f = FeedbackService(
    ref.watch(audioServiceProvider),
    ref.watch(hapticsServiceProvider),
  )..apply(ref.read(saveProvider).settings);
  ref.listen(
    saveProvider.select((s) => s.settings),
    (_, next) => f.apply(next),
  );
  f.audio
    ..init()
    ..playMusic();
  return f;
});
