#!/usr/bin/env python3
"""Synthesizes every Fluffy Merge sound from scratch (no samples, no
third-party audio): short WAV sound effects and a seamless cozy lo-fi music
loop (encoded to AAC with macOS `afconvert` when available).

Run from the project root:
    python3 tool/audio/gen_audio.py
Outputs into assets/audio/.
"""
import math
import os
import random
import struct
import subprocess
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'audio')
TAU = 2 * math.pi


def note(n):
    """MIDI note number -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def silence(sec):
    return [0.0] * int(SR * sec)


def mix_into(buf, sig, start_sec, gain=1.0):
    i0 = int(start_sec * SR)
    need = i0 + len(sig) - len(buf)
    if need > 0:
        buf.extend([0.0] * need)
    for i, v in enumerate(sig):
        buf[i0 + i] += v * gain


def tone(freq, dur, *, attack=0.005, decay=6.0, harmonics=((1, 1.0),),
         sweep_to=None, vibrato=0.0):
    """A plucked/bell-ish tone: exponential decay, optional pitch sweep."""
    n = int(SR * dur)
    out = []
    phase = [0.0] * len(harmonics)
    for i in range(n):
        t = i / SR
        f = freq if sweep_to is None else freq + (sweep_to - freq) * (t / dur)
        if vibrato:
            f *= 1 + vibrato * math.sin(TAU * 5.5 * t)
        env = min(1.0, t / attack) * math.exp(-decay * t)
        # Short fade at the very end so nothing clicks.
        env *= min(1.0, (dur - t) / 0.01)
        v = 0.0
        for k, (mult, amp) in enumerate(harmonics):
            phase[k] += TAU * f * mult / SR
            v += amp * math.sin(phase[k])
        out.append(v * env)
    return out


def noise(dur, *, decay=40.0, gain=1.0, seed=1, lowpass=0.35):
    rnd = random.Random(seed)
    out, prev = [], 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        x = rnd.uniform(-1, 1)
        prev += lowpass * (x - prev)  # one-pole low-pass: softer hiss
        out.append(prev * math.exp(-decay * t) * gain)
    return out


def normalize(buf, peak=0.89):
    m = max(1e-9, max(abs(v) for v in buf))
    return [math.tanh(v / m * 1.1) / math.tanh(1.1) * peak for v in buf]


def write_wav(name, buf):
    path = os.path.join(OUT, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(
            struct.pack('<h', int(max(-1, min(1, v)) * 32767)) for v in buf))
    return path


BELL = ((1, 1.0), (2, 0.25), (3, 0.12), (4.2, 0.05))
SOFT = ((1, 1.0), (2, 0.15))


def sfx():
    s = {}
    # Drop: soft "bloop" sliding down.
    s['drop.wav'] = tone(620, 0.16, decay=18, harmonics=SOFT, sweep_to=300)
    # Bounce: tiny cushioned thump.
    b = tone(190, 0.09, decay=40, harmonics=((1, 1.0), (2, 0.3)), sweep_to=140)
    mix_into(b, noise(0.05, decay=80, gain=0.25, seed=3), 0)
    s['bounce.wav'] = b
    # Merge: bright pop + two-note chime; 4 variants rising in pitch.
    for i, base in enumerate([72, 76, 79, 84], start=1):
        m = tone(note(base) * 0.5, 0.06, decay=50, harmonics=SOFT,
                 sweep_to=note(base))
        mix_into(m, tone(note(base), 0.35, decay=9, harmonics=BELL), 0.03)
        mix_into(m, tone(note(base + 7), 0.4, decay=8, harmonics=BELL), 0.08,
                 0.7)
        s[f'merge_{i}.wav'] = m
    # Chain: quick rising arpeggio C-E-G-C.
    c = []
    for k, n in enumerate([84, 88, 91, 96]):
        mix_into(c, tone(note(n), 0.35, decay=9, harmonics=BELL), k * 0.06,
                 0.8)
    s['chain.wav'] = c
    # Tap: short soft click.
    s['tap.wav'] = tone(1250, 0.045, attack=0.002, decay=70, harmonics=SOFT)
    # Power-up: shimmering upward sweep with sparkles.
    p = tone(420, 0.45, decay=4, harmonics=SOFT, sweep_to=1400, vibrato=0.01)
    for k, n in enumerate([91, 95, 98]):
        mix_into(p, tone(note(n), 0.25, decay=12, harmonics=BELL),
                 0.18 + k * 0.07, 0.5)
    s['powerup.wav'] = p
    # Game over: gentle descending G-E-C, not harsh.
    g = []
    for k, n in enumerate([79, 76, 72]):
        mix_into(g, tone(note(n), 0.7, decay=3.5, harmonics=BELL), k * 0.22,
                 0.8)
    s['gameover.wav'] = g
    # Reward: coin "ding-ding".
    r = tone(note(95), 0.3, decay=10, harmonics=BELL)
    mix_into(r, tone(note(100), 0.45, decay=7, harmonics=BELL), 0.09)
    s['reward.wav'] = r
    return {k: normalize(v, 0.8) for k, v in s.items()}


def music():
    """8 bars at 80 BPM (24 s): Cmaj7 - Am7 - Dm7 - G7, twice, with soft
    keys, round bass, a little bell melody and quiet shaker."""
    bpm = 80
    beat = 60 / bpm
    bar = 4 * beat
    bars = 8
    length = bar * bars
    buf = silence(length + 3)
    chords = [
        (48, [64, 67, 71, 76]),  # Cmaj7
        (45, [60, 64, 67, 72]),  # Am7
        (50, [65, 69, 72, 77]),  # Dm7
        (43, [62, 65, 67, 71]),  # G7
    ]
    keys = ((1, 1.0), (2, 0.18), (3, 0.05))
    for b in range(bars):
        root, tones = chords[b % 4]
        t0 = b * bar
        for hit in (0, 2.5):  # comp on 1 and the "and" of 3
            for k, n in enumerate(tones):
                mix_into(buf, tone(note(n), 2.2, attack=0.02, decay=1.4,
                                   harmonics=keys), t0 + hit * beat + k * 0.018,
                         0.11)
        for hit in (0, 2):
            mix_into(buf, tone(note(root), 1.4, attack=0.03, decay=1.6,
                               harmonics=((1, 1.0), (2, 0.2))),
                     t0 + hit * beat, 0.32)
        # Quiet shaker on off-beats.
        for k in range(4):
            mix_into(buf, noise(0.08, decay=45, seed=b * 4 + k),
                     t0 + (k + 0.5) * beat, 0.035)
    # Bell melody (pentatonic), sparse, repeats with a variation.
    melody = [
        (0, 79), (1.5, 76), (2, 79), (3, 81),
        (4, 84), (5.5, 81), (6, 79),
        (8, 77), (9, 79), (10, 81), (11.5, 77),
        (12, 79), (13, 74), (14.5, 76),
    ]
    for rep in range(2):
        for at, n in melody:
            if rep == 1 and at == 14.5:
                n = 72  # resolve home the second time
            mix_into(buf, tone(note(n), 1.1, attack=0.004, decay=3.2,
                               harmonics=BELL), rep * 4 * bar + at * beat,
                     0.12)
    # Wrap the tail into the start so the loop is seamless.
    n = int(length * SR)
    tail = buf[n:]
    loop = buf[:n]
    for i, v in enumerate(tail):
        loop[i] += v
    return normalize(loop, 0.7)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, buf in sfx().items():
        write_wav(name, buf)
        print('wrote', name)
    wav = write_wav('music_loop.wav', music())
    m4a = os.path.join(OUT, 'music_loop.m4a')
    try:
        subprocess.run(['afconvert', '-f', 'm4af', '-d', 'aac', '-b',
                        '96000', wav, m4a], check=True)
        os.remove(wav)
        print('wrote music_loop.m4a')
    except (FileNotFoundError, subprocess.CalledProcessError):
        print('afconvert unavailable: kept music_loop.wav')


if __name__ == '__main__':
    main()
