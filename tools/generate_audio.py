"""
Generates every sound in Magic War from code -- no samples, no installs.

    python tools/generate_audio.py        (run from the project folder)

Writes audio/sfx/*.wav and audio/music/*.wav; Godot re-imports them
automatically. To change a sound, edit its function below and re-run.
To use a real recording instead, just drop a .wav/.ogg with the same name
into the folder (and stop running this script for that file).

Style: medieval-fantasy chiptune. Plucked "lute" (Karplus-Strong string
synthesis), soft square/triangle leads, simple noise drums, D minor.
"""
import math
import os
import random
import struct

SR = 44100
random.seed(42)  # Same output every run
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "audio"))


# ---------------------------------------------------------------- basics

def midi(note):
    """MIDI note number -> frequency in Hz (69 = A4 = 440 Hz)."""
    return 440.0 * 2 ** ((note - 69) / 12.0)


def mix_into(dst, src, at=0.0, gain=1.0):
    """Add `src` into `dst` starting at `at` seconds (grows dst if needed)."""
    start = int(at * SR)
    end = start + len(src)
    if end > len(dst):
        dst.extend([0.0] * (end - len(dst)))
    for i, s in enumerate(src):
        dst[start + i] += s * gain
    return dst


def envelope(t, dur, attack, decay, sustain, release):
    a = min(1.0, t / attack) if attack > 0 else 1.0
    d = 1.0
    if decay and t > attack:
        d = sustain + (1.0 - sustain) * math.exp(-(t - attack) / decay)
    r = min(1.0, (dur - t) / release) if release > 0 else 1.0
    return a * d * max(0.0, r)


def tone(freq, dur, shape="sine", vol=1.0, attack=0.005, decay=None,
         sustain=1.0, release=0.03, vibrato=0.0, vib_rate=5.5, duty=0.5,
         slide_to=None):
    """One oscillator note. shape: sine / square / tri / saw.
    slide_to = end frequency for a pitch sweep."""
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    two_pi = 2 * math.pi
    for i in range(n):
        t = i / SR
        f = freq if slide_to is None else freq * (slide_to / freq) ** (t / dur)
        if vibrato:
            # Vibrato fades in, like a real player would add it.
            f *= 1.0 + vibrato * min(1.0, t / 0.15) * math.sin(two_pi * vib_rate * t)
        phase += f / SR
        p = phase % 1.0
        if shape == "sine":
            s = math.sin(two_pi * p)
        elif shape == "square":
            s = 1.0 if p < duty else -1.0
        elif shape == "tri":
            s = 4.0 * abs(p - 0.5) - 1.0
        else:  # saw
            s = 2.0 * p - 1.0
        out[i] = s * vol * envelope(t, dur, attack, decay, sustain, release)
    return out


def noise(dur, vol=1.0, decay=None, attack=0.001, release=0.01):
    n = int(dur * SR)
    return [random.uniform(-1, 1) * vol * envelope(i / SR, dur, attack, decay, 0.0, release)
            for i in range(n)]


def lowpass(sig, cutoff):
    rc = 1.0 / (2 * math.pi * cutoff)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    out, y = [0.0] * len(sig), 0.0
    for i, x in enumerate(sig):
        y += a * (x - y)
        out[i] = y
    return out


def highpass(sig, cutoff):
    low = lowpass(sig, cutoff)
    return [x - l for x, l in zip(sig, low)]


def pluck(freq, dur, vol=1.0, damping=0.996, warmth=2):
    """Karplus-Strong plucked string -- our lute / harp."""
    n = int(dur * SR)
    period = max(2, int(SR / freq))
    buf = [random.uniform(-1, 1) for _ in range(period)]
    for _ in range(warmth):  # Smooth the initial burst = softer, rounder tone
        buf = [(buf[i] + buf[i - 1]) * 0.5 for i in range(period)]
    out = [0.0] * n
    idx = 0
    for i in range(n):
        cur = buf[idx]
        nxt = buf[(idx + 1) % period]
        buf[idx] = damping * 0.5 * (cur + nxt)
        out[i] = cur * vol
        idx = (idx + 1) % period
    fade = min(n, int(0.02 * SR))
    for i in range(fade):
        out[n - 1 - i] *= i / fade
    return out


def echo(sig, delay, feedback, wet):
    """Feedback delay (adds a tail of len ~ several repeats)."""
    d = int(delay * SR)
    tail = int(delay * SR * 6)
    out = sig + [0.0] * tail
    buf = [0.0] * len(out)
    for i in range(len(out)):
        delayed = buf[i - d] if i >= d else 0.0
        buf[i] = out[i] + delayed * feedback
    return [o + (b - o) * wet for o, b in zip(out, buf)]


def room(sig, wet=0.25):
    """Cheap reverb: a few echoes at unrelated delay times."""
    out = sig
    for delay, fb in ((0.031, 0.45), (0.047, 0.4), (0.071, 0.35), (0.113, 0.3)):
        out = echo(out, delay, fb, wet * 0.5)
    return out


def finish(sig, peak=0.89):
    """Normalise and gently soft-clip."""
    m = max(1e-9, max(abs(s) for s in sig))
    k = peak / m
    return [math.tanh(s * k * 1.2) / math.tanh(1.2) for s in sig]


def write_wav(path, sig, loop=False):
    """16-bit mono WAV. loop=True adds a 'smpl' chunk with loop points,
    which Godot reads on import, so music loops with no extra setup."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = struct.pack("<%dh" % len(sig), *[int(max(-1.0, min(1.0, s)) * 32767) for s in sig])
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(data)) + data
    if loop:
        smpl = struct.pack("<9I", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(sig) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)
    print("wrote %-28s %5.2fs" % (os.path.relpath(path, OUT), len(sig) / SR))


def wrap_loop(sig, loop_len):
    """Fold anything past the loop end (reverb tails) back onto the start,
    so the loop point is seamless."""
    n = int(loop_len * SR)
    out = sig[:n] + [0.0] * max(0, n - len(sig))
    for i in range(n, len(sig)):
        out[i - n] += sig[i]
    return out


# ----------------------------------------------------------------- drums

def kick(vol=1.0):
    body = tone(130, 0.3, "sine", vol, attack=0.001, decay=0.09, sustain=0.0, slide_to=42)
    click = noise(0.01, vol * 0.4)
    return mix_into(body, click)


def snare(vol=1.0):
    rattle = highpass(noise(0.2, vol * 0.8, decay=0.06), 1200)
    body = tone(190, 0.12, "tri", vol * 0.5, decay=0.04, sustain=0.0)
    return mix_into(rattle, body)


def hat(vol=1.0, open_=False):
    return highpass(noise(0.25 if open_ else 0.06, vol * 0.5, decay=0.08 if open_ else 0.015), 6000)


def tom(note, vol=1.0):
    f = midi(note)
    return tone(f, 0.3, "sine", vol, decay=0.1, sustain=0.0, slide_to=f * 0.6)


# ------------------------------------------------------------------- music

# Chord = MIDI notes of a triad around octave 3.
DM, BB, C, AM, A, F, GM = ([50, 53, 57], [46, 50, 53], [48, 52, 55], [45, 48, 52],
                           [45, 49, 52], [41, 45, 48], [43, 46, 50])


def battle_music():
    """In-game loop: driving D-minor march, 140 BPM, 16 bars (~27 s).
    Bars 1-8 = lighter, bars 9-16 = full band with brass pad."""
    bpm = 140
    beat = 60.0 / bpm
    bar = beat * 4
    chords = [DM, BB, C, AM, DM, BB, C, A]
    # (beat in bar, length in beats, MIDI note) for each of the 8 bars
    melody = [
        [(0, 1, 74), (1, .5, 77), (1.5, .5, 76), (2, 1, 74), (3, 1, 69)],
        [(0, 1, 77), (1, .5, 74), (1.5, .5, 70), (2, 1, 72), (3, 1, 74)],
        [(0, 1, 76), (1, .5, 79), (1.5, .5, 77), (2, 1, 76), (3, 1, 72)],
        [(0, 2, 69), (2, 1, 72), (3, 1, 76)],
        [(0, .5, 74), (.5, .5, 76), (1, 1, 77), (2, 1, 81), (3, .5, 79), (3.5, .5, 77)],
        [(0, 1, 77), (1, 1, 74), (2, 1, 70), (3, 1, 74)],
        [(0, 1, 76), (1, .5, 77), (1.5, .5, 79), (2, 1, 76), (3, 1, 72)],
        [(0, 2, 73), (2, 1, 76), (3, 1, 69)],
    ]
    bass, drums, arps, lead, pad = [], [], [], [], []
    for b in range(16):
        t0 = b * bar
        chord = chords[b % 8]
        full = b >= 8
        root = chord[0] - 12
        # Bass: galloping eighths.
        for i, step in enumerate([0, 0, 12, 0, 7, 0, 12, 7]):
            f = midi(root + step)
            note = tone(f, beat * 0.5, "tri", 0.8, decay=0.12, sustain=0.35, release=0.02)
            mix_into(note, tone(f, beat * 0.5, "square", 0.25, decay=0.08, sustain=0.2, release=0.02, duty=0.3))
            mix_into(bass, note, t0 + i * beat * 0.5)
        # Drums.
        kicks = [0, 2, 2.5] + ([3.5] if full else [])
        for k in kicks:
            mix_into(drums, kick(1.0), t0 + k * beat)
        for s in (1, 3):
            mix_into(drums, snare(1.0 if full else 0.55), t0 + s * beat)
        for h in range(8):
            mix_into(drums, hat(0.5 if h % 2 else 0.8, open_=full and h == 7), t0 + h * beat * 0.5)
        if b == 15:  # Tom fill into the loop
            for j, n in enumerate([50, 47, 45, 43]):
                mix_into(drums, tom(n, 0.9), t0 + (2 + j * 0.5) * beat)
        # Lute arpeggios: eighths first half, sixteenths in the full half.
        pattern = [0, 1, 2, 3, 2, 1]
        tones_ = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[0] + 24]
        steps = 16 if full else 8
        for i in range(steps):
            n = tones_[pattern[i % len(pattern)]]
            mix_into(arps, pluck(midi(n), beat * 1.2, 0.5), t0 + i * bar / steps)
        # Lead melody (soft square, a touch of vibrato).
        for (start, length, n) in melody[b % 8]:
            dur = length * beat * 0.95
            note = tone(midi(n), dur, "square", 0.5, attack=0.01, decay=0.25, sustain=0.6,
                        release=0.05, vibrato=0.006, duty=0.25)
            if full:  # Doubled an octave down on triangle = fuller sound
                mix_into(note, tone(midi(n - 12), dur, "tri", 0.45, attack=0.01, release=0.05))
            mix_into(lead, note, t0 + start * beat)
        # Brass-ish pad holds the chord in the full half.
        if full:
            for n in chord + [chord[0] + 12]:
                mix_into(pad, tone(midi(n), bar, "saw", 0.3, attack=0.25, release=0.25), t0)

    loop_len = 16 * bar
    lead = echo(lowpass(lead, 3500), beat * 0.75, 0.3, 0.3)
    arps = echo(lowpass(arps, 4000), beat * 0.75, 0.25, 0.25)
    pad = lowpass(pad, 1100)
    mix = []
    for part, gain in ((bass, 0.32), (drums, 0.42), (arps, 0.22), (lead, 0.2), (pad, 0.07)):
        mix_into(mix, part, 0, gain)
    mix = room(mix, 0.18)
    return finish(wrap_loop(mix, loop_len), 0.8)


def title_music():
    """Menu loop: calm lute + flute, 90 BPM, 8 bars (~21 s)."""
    bpm = 90
    beat = 60.0 / bpm
    bar = beat * 4
    chords = [DM, BB, F, C, DM, GM, BB, A]
    flute = [
        [(0, 2, 74), (2, 2, 77)],
        [(0, 3, 74), (3, 1, 72)],
        [(0, 2, 72), (2, 1, 69), (3, 1, 72)],
        [(0, 4, 76)],
        [(0, 2, 77), (2, 2, 81)],
        [(0, 2, 79), (2, 1, 77), (3, 1, 74)],
        [(0, 2, 77), (2, 2, 74)],
        [(0, 4, 73)],
    ]
    lute, pad, mel, bass = [], [], [], []
    for b in range(8):
        t0 = b * bar
        chord = chords[b]
        for i, idx in enumerate([0, 1, 2, 1, 3, 2, 1, 2]):
            n = (chord + [chord[0] + 12])[idx] + 12
            mix_into(lute, pluck(midi(n), beat * 2.5, 0.6, damping=0.997), t0 + i * beat * 0.5)
        for n in chord:
            mix_into(pad, tone(midi(n), bar, "tri", 0.35, attack=0.6, release=0.6), t0)
        mix_into(bass, tone(midi(chord[0] - 12), bar, "sine", 0.9, attack=0.05, decay=1.5,
                            sustain=0.4, release=0.3), t0)
        for (start, length, n) in flute[b]:
            mix_into(mel, tone(midi(n), length * beat, "sine", 0.6, attack=0.08, release=0.2,
                               vibrato=0.008, vib_rate=5.0), t0 + start * beat)
    loop_len = 8 * bar
    mel = echo(mel, beat * 0.75, 0.35, 0.35)
    mix = []
    for part, gain in ((lute, 0.35), (pad, 0.12), (mel, 0.22), (bass, 0.25)):
        mix_into(mix, part, 0, gain)
    mix = room(mix, 0.35)
    return finish(wrap_loop(mix, loop_len), 0.7)


def jingle(notes, step, shape, final_chord, final_len, room_wet=0.3):
    """Short melody then a held chord (victory / defeat stingers)."""
    out = []
    for i, n in enumerate(notes):
        note = tone(midi(n), step * 1.2, shape, 0.5, decay=0.2, sustain=0.5, release=0.05, duty=0.25)
        mix_into(note, tone(midi(n - 12), step * 1.2, "tri", 0.4, release=0.05))
        mix_into(out, note, i * step)
    t = len(notes) * step
    for n in final_chord:
        mix_into(out, tone(midi(n), final_len, "tri", 0.4, attack=0.02, decay=final_len * 0.5,
                           sustain=0.3, release=0.4, vibrato=0.004), t)
        mix_into(out, pluck(midi(n), final_len, 0.5), t)
    return finish(room(out, room_wet))


# --------------------------------------------------------------------- sfx

def sfx_fireball_cast():
    whoosh = lowpass(noise(0.3, 0.8, decay=0.12, attack=0.03), 2500)
    roar = tone(220, 0.25, "saw", 0.3, decay=0.08, sustain=0.0, slide_to=90)
    return finish(mix_into(whoosh, lowpass(roar, 1200)), 0.8)


def sfx_fireball_hit():
    boom = tone(120, 0.4, "sine", 1.0, decay=0.1, sustain=0.0, slide_to=35)
    crackle = lowpass(noise(0.35, 0.7, decay=0.08), 3000)
    return finish(mix_into(boom, crackle), 0.85)


def sfx_lightning():
    n = int(0.4 * SR)
    out = [0.0] * n
    gate = 1.0
    for i in range(n):  # Noise switched on/off at random = electric crackle
        if i % 220 == 0:
            gate = 1.0 if random.random() < 0.6 else 0.15
        out[i] = random.uniform(-1, 1) * gate * math.exp(-i / SR / 0.12)
    out = highpass(out, 800)
    zap = tone(1400, 0.25, "saw", 0.5, decay=0.06, sustain=0.0, slide_to=200)
    return finish(mix_into(out, zap), 0.85)


def sfx_frost_nova():
    out = lowpass(highpass(noise(0.7, 0.5, decay=0.25, attack=0.02), 1500), 7000)
    for _ in range(7):  # Cluster of icy high bells
        f = random.uniform(1800, 4200)
        mix_into(out, tone(f, 0.6, "sine", 0.25, decay=0.18, sustain=0.0), random.uniform(0, 0.08))
    mix_into(out, tone(600, 0.5, "sine", 0.3, decay=0.15, sustain=0.0, slide_to=1500))
    return finish(room(out, 0.3), 0.8)


def sfx_orb_hit():
    out = tone(880, 0.18, "sine", 0.7, decay=0.05, sustain=0.0)
    mix_into(out, tone(1320, 0.15, "sine", 0.4, decay=0.04, sustain=0.0))
    return finish(out, 0.7)


def sfx_enemy_hit():
    out = highpass(noise(0.05, 0.6, decay=0.01), 2000)
    mix_into(out, tone(260, 0.06, "square", 0.3, decay=0.02, sustain=0.0, slide_to=180))
    return finish(out, 0.6)


def sfx_enemy_die():
    out = tone(420, 0.18, "square", 0.5, decay=0.06, sustain=0.0, slide_to=90, duty=0.3)
    mix_into(out, lowpass(noise(0.15, 0.5, decay=0.04), 2500))
    return finish(lowpass(out, 3500), 0.75)


def sfx_xp():
    return finish(tone(1100, 0.08, "sine", 0.8, decay=0.04, sustain=0.0, slide_to=1700), 0.6)


def sfx_coin():
    out = tone(midi(83), 0.07, "square", 0.4, release=0.01, duty=0.25)         # B5
    mix_into(out, tone(midi(88), 0.3, "square", 0.4, decay=0.1, sustain=0.0, duty=0.25), 0.06)  # E6
    return finish(lowpass(out, 6000), 0.7)


def sfx_level_up():
    out = []
    for i, n in enumerate([74, 78, 81, 86]):  # D F# A D -- bright major arpeggio
        note = tone(midi(n), 0.3, "square", 0.35, decay=0.12, sustain=0.2, duty=0.25)
        mix_into(note, tone(midi(n), 0.3, "tri", 0.5, decay=0.15, sustain=0.2))
        mix_into(out, note, i * 0.075)
    for _ in range(6):  # Sparkle
        mix_into(out, tone(random.uniform(2500, 5000), 0.2, "sine", 0.15, decay=0.05, sustain=0.0),
                 0.25 + random.uniform(0, 0.25))
    return finish(room(out, 0.25), 0.8)


def sfx_player_hurt():
    out = tone(160, 0.25, "square", 0.6, decay=0.08, sustain=0.0, slide_to=70, duty=0.4)
    mix_into(out, lowpass(noise(0.12, 0.6, decay=0.03), 1500))
    return finish(lowpass(out, 2000), 0.85)


def sfx_heal():
    out = []
    for i, n in enumerate([72, 76, 79, 84]):  # C E G C, warm and rising
        mix_into(out, tone(midi(n), 0.6, "sine", 0.5, attack=0.01, decay=0.25, sustain=0.0), i * 0.07)
    return finish(room(out, 0.3), 0.75)


def sfx_magnet():
    out = tone(250, 0.55, "sine", 0.6, attack=0.02, release=0.1, vibrato=0.08, vib_rate=14, slide_to=1100)
    mix_into(out, tone(500, 0.55, "tri", 0.25, attack=0.02, release=0.1, vibrato=0.08, vib_rate=14, slide_to=2200))
    return finish(out, 0.75)


def sfx_nuke():
    boom = tone(70, 1.6, "sine", 1.0, decay=0.5, sustain=0.0, slide_to=22)
    rumble = lowpass(noise(1.6, 0.9, decay=0.45), 600)
    crack = highpass(noise(0.2, 0.6, decay=0.05), 2000)
    out = mix_into(mix_into(boom, rumble), crack)
    return finish(room(out, 0.25), 0.9)


def sfx_ui_click():
    out = tone(900, 0.05, "sine", 0.7, decay=0.015, sustain=0.0)
    mix_into(out, highpass(noise(0.01, 0.3), 3000))
    return finish(out, 0.55)


# --------------------------------------------------------------------- main

if __name__ == "__main__":
    sfx = {
        "fireball_cast": sfx_fireball_cast, "fireball_hit": sfx_fireball_hit,
        "lightning": sfx_lightning, "frost_nova": sfx_frost_nova, "orb_hit": sfx_orb_hit,
        "enemy_hit": sfx_enemy_hit, "enemy_die": sfx_enemy_die, "xp": sfx_xp,
        "coin": sfx_coin, "level_up": sfx_level_up, "player_hurt": sfx_player_hurt,
        "heal": sfx_heal, "magnet": sfx_magnet, "nuke": sfx_nuke, "ui_click": sfx_ui_click,
    }
    for name, fn in sfx.items():
        write_wav(os.path.join(OUT, "sfx", name + ".wav"), fn())
    write_wav(os.path.join(OUT, "sfx", "victory.wav"),
              jingle([74, 78, 81, 78, 81, 86], 0.13, "square", [62, 66, 69, 74], 1.6))
    write_wav(os.path.join(OUT, "sfx", "defeat.wav"),
              jingle([69, 67, 65, 64], 0.32, "tri", [50, 53, 57], 1.8, 0.4))
    write_wav(os.path.join(OUT, "music", "title.wav"), title_music(), loop=True)
    write_wav(os.path.join(OUT, "music", "battle.wav"), battle_music(), loop=True)
