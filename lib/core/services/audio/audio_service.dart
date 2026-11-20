import 'dart:async';
import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Every sound effect (files in assets/audio/, synthesized by
/// tool/audio/gen_audio.py).
enum Sfx {
  drop('drop.wav', maxPlayers: 2, minGapMs: 40),
  bounce('bounce.wav', maxPlayers: 3, minGapMs: 70),
  merge1('merge_1.wav', maxPlayers: 3, minGapMs: 40),
  merge2('merge_2.wav', maxPlayers: 3, minGapMs: 40),
  merge3('merge_3.wav', maxPlayers: 2, minGapMs: 40),
  merge4('merge_4.wav', maxPlayers: 2, minGapMs: 40),
  chain('chain.wav', maxPlayers: 2, minGapMs: 90),
  tap('tap.wav', maxPlayers: 2, minGapMs: 30),
  powerUp('powerup.wav', maxPlayers: 1, minGapMs: 150),
  gameOver('gameover.wav', maxPlayers: 1, minGapMs: 500),
  reward('reward.wav', maxPlayers: 2, minGapMs: 120);

  const Sfx(this.file, {required this.maxPlayers, required this.minGapMs});

  final String file;

  /// Simultaneous copies allowed (a pile landing shouldn't be a wall of
  /// sound).
  final int maxPlayers;

  /// Ignore repeats closer together than this.
  final int minGapMs;
}

/// Audio API used by the whole app.
abstract interface class AudioService {
  Future<void> init();
  void playSfx(Sfx sfx, {double volume = 1});
  Future<void> playMusic();
  Future<void> stopMusic();
  void setMusicVolume(double v);
  void setSfxVolume(double v);

  /// Turns sound effects / music on or off (from Settings).
  void setSfxEnabled(bool on);
  void setMusicEnabled(bool on);

  /// Silences everything at once without changing the saved settings.
  void mute(bool muted);
  Future<void> dispose();
}

/// Real audio through audioplayers: a small low-latency pool per sound
/// effect plus one looping music player.
class AudioPlayersService with WidgetsBindingObserver implements AudioService {
  final Map<Sfx, AudioPool> _pools = {};
  final Map<Sfx, int> _lastPlayedMs = {};
  final AudioPlayer _music = AudioPlayer(playerId: 'music');
  final Stopwatch _clock = Stopwatch()..start();

  bool _ready = false;
  bool _musicWanted = false;
  bool _musicPlaying = false;
  bool _sfxOn = true;
  bool _musicOn = true;
  bool _muted = false;
  double _sfxVolume = 0.8;
  double _musicVolume = 0.6;

  @override
  Future<void> init() async {
    if (_ready) return;
    WidgetsBinding.instance.addObserver(this);
    try {
      // A casual game: mix with the player's own music/podcasts and
      // respect the iPhone's silent switch. On iOS that's exactly the
      // "ambient" category (audioplayers' generic config can't express it);
      // on Android we play as game audio without taking audio focus.
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.sonification,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
      // Load all sound effects at once (not one after another), so sound
      // and music are ready sooner after launch.
      final pools = await Future.wait([
        for (final s in Sfx.values)
          AudioPool.createFromAsset(
            path: 'audio/${s.file}',
            maxPlayers: s.maxPlayers,
            playerMode: PlayerMode.lowLatency,
          ),
      ]);
      for (final (i, s) in Sfx.values.indexed) {
        _pools[s] = pools[i];
      }
      await _music.setReleaseMode(ReleaseMode.loop);
      await _music.setVolume(_musicVolume);
      _ready = true;
      if (_musicWanted) await _startMusic();
    } catch (e) {
      // Sound is never worth a crash: carry on silently.
      debugPrint('Audio unavailable: $e');
    }
  }

  @override
  void playSfx(Sfx sfx, {double volume = 1}) {
    if (!_ready || !_sfxOn || _muted) return;
    final now = _clock.elapsedMilliseconds;
    final last = _lastPlayedMs[sfx];
    if (last != null && now - last < sfx.minGapMs) return;
    _lastPlayedMs[sfx] = now;
    final v = (_sfxVolume * volume).clamp(0.0, 1.0);
    if (v <= 0) return;
    unawaited(_pools[sfx]?.start(volume: v).catchError((_) => () async {}));
  }

  @override
  Future<void> playMusic() async {
    _musicWanted = true;
    await _startMusic();
  }

  Future<void> _startMusic() async {
    if (!_ready || !_musicOn || _muted || _musicPlaying) return;
    try {
      _musicPlaying = true;
      await _music.play(
        AssetSource('audio/music_loop.m4a'),
        volume: _musicVolume,
      );
    } catch (e) {
      _musicPlaying = false;
      debugPrint('Music failed: $e');
    }
  }

  Future<void> _pauseMusic() async {
    if (!_musicPlaying) return;
    _musicPlaying = false;
    try {
      await _music.pause();
    } catch (_) {}
  }

  @override
  Future<void> stopMusic() async {
    _musicWanted = false;
    await _pauseMusic();
  }

  @override
  void setMusicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    if (_ready) unawaited(_music.setVolume(_musicVolume).catchError((_) {}));
  }

  @override
  void setSfxVolume(double v) => _sfxVolume = v.clamp(0.0, 1.0);

  @override
  void setSfxEnabled(bool on) => _sfxOn = on;

  @override
  void setMusicEnabled(bool on) {
    _musicOn = on;
    _syncMusic();
  }

  @override
  void mute(bool muted) {
    _muted = muted;
    _syncMusic();
  }

  void _syncMusic() {
    if (_musicWanted && _musicOn && !_muted) {
      unawaited(_startMusic());
    } else {
      unawaited(_pauseMusic());
    }
  }

  /// Pause the music while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncMusic();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(_pauseMusic());
    }
  }

  @override
  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    for (final p in _pools.values) {
      await p.dispose();
    }
    await _music.dispose();
  }
}

/// No sound (widget tests, or when audio can't start). Records what would
/// have played so tests can assert on it.
class SilentAudioService implements AudioService {
  final List<Sfx> played = [];
  bool musicPlaying = false;
  bool sfxOn = true;
  bool musicOn = true;
  bool muted = false;
  double sfxVolume = 0.8;
  double musicVolume = 0.6;

  @override
  Future<void> init() async {}

  @override
  void playSfx(Sfx sfx, {double volume = 1}) {
    if (sfxOn && !muted) played.add(sfx);
  }

  @override
  Future<void> playMusic() async => musicPlaying = musicOn && !muted;

  @override
  Future<void> stopMusic() async => musicPlaying = false;

  @override
  void setMusicVolume(double v) => musicVolume = v;

  @override
  void setSfxVolume(double v) => sfxVolume = v;

  @override
  void setSfxEnabled(bool on) => sfxOn = on;

  @override
  void setMusicEnabled(bool on) {
    musicOn = on;
    if (!on) musicPlaying = false;
  }

  @override
  void mute(bool m) {
    muted = m;
    if (m) musicPlaying = false;
  }

  @override
  Future<void> dispose() async {}
}

/// True inside `flutter test`, where platform audio plugins don't exist.
bool get runningInTest =>
    !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
