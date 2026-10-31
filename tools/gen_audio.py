"""All of Bellwater's sound: a small additive synth, the effects, and an original score.

Everything is one motif in D dorian, heard differently in each place. Loops are seamless: reverb is
applied by circular convolution, so tails wrap round to the start of the loop.
"""
import os
import subprocess
import sys
import wave
import numpy as np
from scipy import signal

SR = 44100
OUT_SFX = "assets/audio/sfx"
OUT_MUS = "assets/audio/music"
rng = np.random.default_rng(7)
NOTE = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name):
    """'D5', 'Bb3', 'F#4' to a MIDI number."""
    n = NOTE[name[0]]
    i = 1
    if name[1] == "b":
        n -= 1
        i = 2
    elif name[1] == "#":
        n += 1
        i = 2
    return n + (int(name[i:]) + 1) * 12


def hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def lowpass(x, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff / (SR / 2), 0.99))
    return signal.lfilter(b, a, x)


def highpass(x, cutoff, order=2):
    b, a = signal.butter(order, cutoff / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi):
    b, a = signal.butter(2, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def noise(dur):
    return rng.standard_normal(int(dur * SR))


# --- voices ------------------------------------------------------------------------

BELL_R = [0.5, 1.0, 1.19, 1.5, 2.0, 2.51, 2.67, 3.01, 4.17, 5.43, 6.8]
BELL_A = [0.55, 1.0, 0.55, 0.42, 0.5, 0.26, 0.22, 0.2, 0.12, 0.08, 0.05]
BELL_D = [1.0, 0.8, 0.66, 0.5, 0.42, 0.3, 0.26, 0.22, 0.14, 0.1, 0.07]


def v_bell(f, dur, bright=1.0):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for r, a, d in zip(BELL_R, BELL_A, BELL_D):
        fr = f * r
        if fr > SR / 2.2:
            continue
        beat = 1.0 + 0.0012 * np.sin(r * 7)
        tone = np.sin(2 * np.pi * fr * t) + 0.6 * np.sin(2 * np.pi * fr * beat * t)
        out += a * (bright ** (r - 1)) * tone * np.exp(-t / (d * dur * 0.42))
    out *= 1 - np.exp(-t * 2500)
    return out / 3.0


def v_pluck(f, dur):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k in range(1, 12):
        fr = f * k * (1 + 0.0004 * k * k)
        if fr > SR / 2.2:
            break
        a = (1.0 / k ** 1.3) * np.sin(np.pi * k * 0.23)
        out += a * np.sin(2 * np.pi * fr * t) * np.exp(-t * (1.6 + k * 0.9))
    return out * (1 - np.exp(-t * 900)) * 0.9


def v_marimba(f, dur):
    t = t_axis(dur)
    o = np.sin(2 * np.pi * f * t) * np.exp(-t * 6.0)
    o += 0.35 * np.sin(2 * np.pi * f * 3.93 * t) * np.exp(-t * 22.0)
    o += 0.12 * np.sin(2 * np.pi * f * 9.2 * t) * np.exp(-t * 50.0)
    return o * (1 - np.exp(-t * 1200)) * 0.85


def v_pad(f, dur):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for det in (-0.0032, 0.0, 0.0041):
        ph = rng.random() * 6.28
        for k in range(1, 7):
            fr = f * k * (1 + det)
            if fr > 7000:
                break
            out += np.sin(2 * np.pi * fr * t + ph * k) / (k * k)
    atk = np.clip(t / 0.9, 0, 1)
    rel = np.clip((dur - t) / 1.2, 0, 1)
    wob = 1 + 0.08 * np.sin(2 * np.pi * 0.23 * t + f)
    return out * atk * rel * wob * 0.22


def v_flute(f, dur):
    t = t_axis(dur)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 4.6 * t) * np.clip((t - 0.3) * 2, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    o = np.sin(ph) + 0.25 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
    o = o + lowpass(noise(dur), 3200) * 0.04
    env = np.clip(t / 0.09, 0, 1) * np.clip((dur - t) / 0.2, 0, 1)
    return o * env * 0.5


def v_bass(f, dur):
    t = t_axis(dur)
    o = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) + 0.12 * np.sin(6 * np.pi * f * t)
    env = np.clip(t * 120, 0, 1) * np.exp(-t * 2.2) * np.clip((dur - t) * 30, 0, 1)
    return o * env * 0.8


def v_brass(f, dur):
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k in range(1, 9):
        out += np.sin(2 * np.pi * f * k * t + k) / k
    out = lowpass(out, 1800 + 900 * np.clip(f / 400, 0, 1))
    return out * np.clip(t / 0.03, 0, 1) * np.clip((dur - t) / 0.1, 0, 1) * 0.42


def d_kick(dur=0.4):
    t = t_axis(dur)
    f = 44 + 110 * np.exp(-t * 28)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


def d_tom(dur=0.5):
    t = t_axis(dur)
    f = 80 + 70 * np.exp(-t * 18)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 7) * 0.9


def d_hat(dur=0.09):
    return highpass(noise(dur), 6000) * np.exp(-t_axis(dur) * 90) * 0.1


def d_snare(dur=0.25):
    t = t_axis(dur)
    return (bandpass(noise(dur), 900, 5000) * 0.7 + np.sin(2 * np.pi * 185 * t) * 0.5) * np.exp(-t * 18) * 0.7


VOICES = {"bell": v_bell, "pluck": v_pluck, "marimba": v_marimba, "pad": v_pad, "flute": v_flute,
          "bass": v_bass, "brass": v_brass}


class Mix:
    """A loop of n beats. Notes wrap round so nothing clicks at the seam."""

    def __init__(self, bpm, beats):
        self.spb = 60.0 / bpm
        self.len = int(round(beats * self.spb * SR))
        self.buf = np.zeros((self.len, 2))
        self.bpm = bpm

    def add(self, sig, beat, pan=0.0, gain=1.0):
        start = int(beat * self.spb * SR) % self.len
        l, r = np.sqrt((1 - pan) / 2) * gain, np.sqrt((1 + pan) / 2) * gain
        n = len(sig)
        idx = (start + np.arange(n)) % self.len
        np.add.at(self.buf[:, 0], idx, sig * l)
        np.add.at(self.buf[:, 1], idx, sig * r)

    def note(self, voice, m, beat, beats, vel=1.0, pan=0.0, tail=1.0):
        m = midi(m) if isinstance(m, str) else m
        dur = beats * self.spb + tail
        self.add(VOICES[voice](hz(m), dur), beat, pan, vel)

    def seq(self, voice, text, start=0.0, vel=1.0, pan=0.0, tail=1.0, oct=0):
        """'D5:2 A4:1 r:1 C5+F5:2' -> notes; returns the beat after the last one."""
        b = start
        for tok in text.split():
            name, ln = tok.split(":")
            ln = float(ln)
            if name != "r":
                for nm in name.split("+"):
                    self.note(voice, midi(nm) + oct * 12, b, ln, vel, pan, tail)
            b += ln
        return b

    def hit(self, sig, beat, gain=1.0, pan=0.0):
        self.add(sig, beat, pan, gain)

    def reverb(self, wet=0.3, seconds=2.6, cutoff=3500):
        n = int(seconds * SR)
        out = np.zeros_like(self.buf)
        for ch in range(2):
            ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (n / 5.0))
            ir = lowpass(ir, cutoff)
            ir /= np.sqrt(np.sum(ir ** 2))
            full = np.zeros(self.len)
            m = min(n, self.len)
            full[:m] = ir[:m]
            out[:, ch] = np.fft.irfft(np.fft.rfft(self.buf[:, ch]) * np.fft.rfft(full), self.len)
        self.buf = self.buf * (1 - wet * 0.5) + out * wet


def write_wav(path, x):
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    ch = 1 if x.ndim == 1 else 2
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def to_ogg(wav_path, ogg_path, q):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav_path, "-c:a", "libvorbis", "-q:a", str(q), ogg_path], check=True)
    os.remove(wav_path)


def finish(mix, name, level=0.78):
    x = mix.buf
    x = x / (np.max(np.abs(x)) + 1e-9) * level
    x = x - x.mean(axis=0)
    wav = f"{OUT_MUS}/{name}.wav"
    write_wav(wav, x)
    to_ogg(wav, f"{OUT_MUS}/{name}.ogg", 4)
    print("music", name, round(mix.len / SR, 1), "s")


# --- the score -----------------------------------------------------------------------

THEME = "D5:2 A4:1 C5:1 D5:1 E5:1 F5:2 E5:2 C5:1 A4:1 D5:4 F5:2 E5:1 D5:1 C5:2 A4:2 Bb4:1 C5:1 D5:1 A4:1 D5:4"
CHORDS = [("D3", "A3", "D4", "F4"), ("D3", "A3", "D4", "F4"), ("A2", "E3", "A3", "C4"), ("D3", "A3", "D4", "F4"),
          ("F2", "C3", "F3", "A3"), ("A2", "E3", "A3", "C4"), ("Bb2", "F3", "Bb3", "D4"), ("D3", "A3", "D4", "A4")]


def pad_chords(m, bar_beats, vel=0.5, repeat=1, oct=0):
    for rep in range(repeat):
        for i, ch in enumerate(CHORDS):
            b = (rep * 8 + i) * bar_beats
            for n in ch[1:]:
                m.note("pad", midi(n) + oct * 12, b, bar_beats + 0.5, vel, rng.uniform(-0.3, 0.3))


def wind_bed(m, gain=0.05, cut=700):
    n = m.len
    x = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * np.exp(-np.linspace(0, 1, n // 2 + 1) * 60), n)
    mod = 0.6 + 0.4 * np.sin(2 * np.pi * np.arange(n) / n * 3) * np.sin(2 * np.pi * np.arange(n) / n * 7)
    x = x / np.max(np.abs(x)) * mod
    m.buf[:, 0] += x * gain
    m.buf[:, 1] += np.roll(x, 1200) * gain


def title():
    m = Mix(58, 32)
    pad_chords(m, 4, 0.45)
    m.seq("bell", THEME, 0, 0.5, 0.15, tail=5.0)
    for i, ch in enumerate(CHORDS):
        m.note("pluck", ch[0], i * 4, 3, 0.5, -0.2, 2.0)
        m.note("pluck", ch[2], i * 4 + 2, 2, 0.3, 0.2, 2.0)
    m.reverb(0.42, 3.2, 3000)
    finish(m, "title")


def dry():
    """Almost nothing: wind, one far bell, a guitar remembering the tune."""
    m = Mix(52, 40)
    wind_bed(m, 0.11)
    for b in (0, 16, 28):
        m.note("bell", "D4", b, 3, 0.26, -0.4, 6.0)
    m.seq("pluck", "D4:2 A3:1 C4:1 D4:4 r:8", 4, 0.55, 0.1, tail=2.5)
    m.seq("pluck", "F4:2 E4:1 D4:1 C4:2 A3:6", 20, 0.5, -0.1, tail=2.5)
    m.seq("pluck", "D3:8 A2:8 D3:8 F2:8 A2:8", 0, 0.3, 0.0, tail=4.0)
    m.seq("pluck", "r:32 Bb3:1 C4:1 D4:1 A3:5", 0, 0.4, 0.2, tail=2.5)
    m.reverb(0.5, 3.4, 2600)
    finish(m, "dry", 0.6)


def harbor():
    """A waltz at the water's edge."""
    m = Mix(104, 72)
    bars = [("D3", "A3", "D4", "F4"), ("D3", "A3", "D4", "F4"), ("A2", "E3", "A3", "C4"), ("D3", "A3", "D4", "F4"),
            ("F2", "C3", "F3", "A3"), ("A2", "E3", "A3", "C4"), ("Bb2", "F3", "Bb3", "D4"), ("D3", "A3", "D4", "F4")]
    for rep in range(3):
        for i, ch in enumerate(bars):
            b = (rep * 8 + i) * 3
            m.note("pluck", ch[0], b, 2, 0.8, -0.1, 1.5)
            m.note("pluck", ch[1], b + 1, 1, 0.42, 0.2, 1.0)
            m.note("pluck", ch[2], b + 1, 1, 0.42, 0.2, 1.0)
            m.note("pluck", ch[1], b + 2, 1, 0.38, -0.2, 1.0)
            m.note("pluck", ch[3], b + 2, 1, 0.38, -0.2, 1.0)
    waltz = "D5:1.5 A4:0.5 C5:1 D5:1 E5:1 F5:1 E5:2 C5:1 D5:3 F5:1.5 E5:0.5 D5:1 C5:2 A4:1 Bb4:1 C5:1 D5:1 A4:3"
    b = m.seq("marimba", waltz, 24, 0.75, 0.2)
    m.seq("flute", waltz, 48, 0.28, -0.2, tail=0.4)
    m.seq("marimba", waltz, 48, 0.4, 0.3)
    m.reverb(0.28, 2.0, 4000)
    finish(m, "harbor")


def town():
    """Empty streets. Muted, a little wrong: the tune with holes in it."""
    m = Mix(76, 64)
    prog = ["D3", "Bb2", "F3", "A2"]
    for rep in range(4):
        for i, root in enumerate(prog):
            b = (rep * 4 + i) * 4
            r = midi(root)
            for j, off in enumerate([0, 7, 12, 15, 12, 7, 12, 7]):
                m.note("pluck", r + off, b + j * 0.5, 0.5, 0.36 if j % 4 else 0.56, 0.3 * np.sin(j), 0.9)
    m.seq("bell", "r:16 D6:2 A5:2 C6:4 r:8 F6:2 E6:2 D6:4 r:8", 0, 0.14, 0.3, tail=3)
    m.seq("marimba", "r:32 D5:1 r:1 A4:1 C5:1 D5:4 r:4 F5:1 E5:1 D5:2 A4:4", 0, 0.5, -0.2)
    for i, root in enumerate(prog * 4):
        m.note("pad", midi(root) + 12, i * 4, 4.5, 0.3)
        m.note("pad", midi(root) + 19, i * 4, 4.5, 0.25)
    m.reverb(0.34, 2.4, 3200)
    finish(m, "town", 0.68)


def well():
    """A long drop: slow drips of bell over a low hum."""
    m = Mix(50, 32)
    for b in range(0, 32, 8):
        m.note("pad", "D2", b, 8.5, 0.8)
        m.note("pad", "A2", b, 8.5, 0.5)
    for b, n in [(0, "D5"), (3, "A4"), (7, "C5"), (12, "D5"), (15, "F5"), (20, "E5"), (23, "A4"), (28, "D4")]:
        m.note("bell", n, b, 2, 0.34, rng.uniform(-0.6, 0.6), 6.0)
    m.reverb(0.6, 4.0, 2400)
    finish(m, "well", 0.62)


def deep():
    """Under water. Everything is slow and comes from far away."""
    m = Mix(56, 48)
    for rep in range(3):
        for i, (a, b) in enumerate([("D3", "A3"), ("Bb2", "F3")]):
            bt = (rep * 2 + i) * 8
            m.note("pad", a, bt, 8.5, 0.8)
            m.note("pad", b, bt, 8.5, 0.6)
            m.note("pad", midi(a) + 15, bt, 8.5, 0.28)
            m.note("bass", midi(a) - 12, bt, 4, 0.5, 0, 3)
    for b in (2, 6.5, 11, 18, 22.5, 27, 34, 38.5, 43):
        m.note("bell", int(rng.choice([midi("A5"), midi("D6"), midi("F6"), midi("E6"), midi("C6")])), b, 1, 0.2, rng.uniform(-0.8, 0.8), 4.0)
    m.seq("flute", "r:16 D5:6 A4:2 C5:4 D5:4 r:16 F5:4 E5:4", 0, 0.14, 0, tail=0.6)
    m.reverb(0.62, 4.0, 1600)
    finish(m, "deep", 0.66)


def sump():
    """The bottom of everything. Something is breathing."""
    m = Mix(64, 32)
    wind_bed(m, 0.05)
    for b in range(0, 32, 8):
        m.note("pad", "D2", b, 8.5, 1.0)
        m.note("pad", "Eb3" if (b // 8) % 2 else "A2", b, 8.5, 0.5)
    for b in range(0, 32, 4):
        m.hit(d_kick(), b, 0.5)
        m.hit(d_kick(), b + 0.7, 0.32)
    m.seq("bell", "r:12 D4:4 r:12 Eb4:4", 0, 0.2, 0.2, tail=5.0)
    m.reverb(0.55, 4.0, 1200)
    finish(m, "sump", 0.68)


def boss():
    m = Mix(148, 64)
    riff = ["D2", "D2", "D3", "D2", "F2", "D2", "D3", "C3"]
    roots = [0, 0, -2, -2, 3, 3, -5, -3]
    for bar in range(16):
        tr = roots[bar % 8]
        for i, n in enumerate(riff):
            m.note("bass", midi(n) + tr, bar * 4 + i * 0.5, 0.5, 0.9 if i % 4 == 0 else 0.7, 0, 0.1)
            m.note("pluck", midi(n) + tr + 24, bar * 4 + i * 0.5, 0.5, 0.2, 0.3, 0.3)
        m.hit(d_kick(), bar * 4, 0.9)
        m.hit(d_kick(), bar * 4 + 2.5, 0.7)
        m.hit(d_snare(), bar * 4 + 1, 0.55)
        m.hit(d_snare(), bar * 4 + 3, 0.55)
        for k in range(8):
            m.hit(d_hat(), bar * 4 + k * 0.5, 0.5 if k % 2 else 0.8, 0.3)
    m.seq("brass", "D4:3 A3:1 C4:2 D4:2 E4:3 F4:1 E4:2 C4:2", 16, 0.5, -0.1, tail=0.1)
    m.seq("brass", "D4+F4:3 C4+E4:1 D4+F4:4 F4+A4:3 E4+G4:1 D4+F4:2 A3+C4:2", 32, 0.55, 0.1, tail=0.1)
    m.seq("brass", "D4:3 A3:1 C4:2 D4:2 F4:3 E4:1 D4:2 A3:2", 48, 0.55, -0.1, tail=0.1)
    for b in (0, 8, 16, 24, 32, 40, 48, 56):
        m.note("bell", "D5", b, 1, 0.3, 0.4, 2.5)
    m.reverb(0.16, 1.2, 4500)
    finish(m, "boss", 0.82)


def return_home():
    """The flood, all the way up the Well. Rising, and not stopping."""
    m = Mix(132, 48)
    for bar in range(12):
        base = midi("D3") + [0, 0, 3, 3, 5, 5, 7, 7, 8, 8, 10, 12][bar]
        for i in range(8):
            off = [0, 7, 12, 15, 19, 24, 19, 12][i]
            m.note("marimba", base + off, bar * 4 + i * 0.5, 0.5, 0.5, np.sin(i) * 0.4)
            m.note("pluck", base + off + 12, bar * 4 + i * 0.5 + 0.25, 0.25, 0.26, -np.sin(i) * 0.4, 0.5)
        m.note("pad", base, bar * 4, 4.4, 0.7)
        m.note("pad", base + 7, bar * 4, 4.4, 0.6)
        m.note("pad", base + 15, bar * 4, 4.4, 0.5)
        m.note("bell", base + 24, bar * 4, 2, 0.4, 0.3, 3.0)
        m.hit(d_tom(), bar * 4, 0.6)
        m.hit(d_tom(), bar * 4 + 1.5, 0.45)
        m.hit(d_tom(), bar * 4 + 3, 0.5)
    m.reverb(0.34, 2.5, 4500)
    finish(m, "return", 0.82)


def ending():
    """The theme at last, whole, in the major, every voice together."""
    m = Mix(66, 64)
    ch = [("D3", "A3", "D4", "F#4"), ("A2", "A3", "C#4", "E4"), ("B2", "F#3", "B3", "D4"), ("F#2", "F#3", "A3", "C#4"),
          ("G2", "G3", "B3", "D4"), ("D3", "F#3", "A3", "D4"), ("G2", "G3", "B3", "E4"), ("A2", "G3", "A3", "C#4")]
    for rep in range(2):
        for i, c in enumerate(ch):
            b = (rep * 8 + i) * 4
            for n in c[1:]:
                m.note("pad", n, b, 4.5, 0.55, rng.uniform(-0.4, 0.4))
            m.note("pluck", c[0], b, 3, 0.7, -0.1, 2.5)
            for j, n in enumerate([c[1], c[2], c[3], c[2]]):
                m.note("pluck", n, b + j + 0.5, 0.5, 0.34, 0.25, 1.5)
    melody = "F#5:2 D5:1 E5:1 F#5:1 G5:1 A5:2 G5:2 E5:1 C#5:1 D5:4 A5:2 G5:1 F#5:1 E5:2 C#5:2 D5:1 E5:1 F#5:1 D5:1 D5:4"
    m.seq("bell", melody, 0, 0.42, 0.15, tail=4.0)
    m.seq("flute", melody, 32, 0.34, -0.15, tail=0.7)
    m.seq("bell", melody, 32, 0.3, 0.2, tail=4.0)
    m.seq("marimba", "D6:1 A5:1 F#5:1 D5:1", 60, 0.3, 0.3)
    m.reverb(0.46, 3.4, 3800)
    finish(m, "ending")


# --- effects ---------------------------------------------------------------------------

def sfx(name, x, gain=0.9):
    x = x / (np.max(np.abs(x)) + 1e-9) * gain
    wav = f"{OUT_SFX}/{name}.wav"
    write_wav(wav, x)
    to_ogg(wav, f"{OUT_SFX}/{name}.ogg", 5)


def sweep(f0, f1, dur, shape=2.0):
    t = t_axis(dur)
    f = f1 + (f0 - f1) * (1 - t / dur) ** shape
    return np.sin(2 * np.pi * np.cumsum(f) / SR), t


def env(dur, a, d):
    t = t_axis(dur)
    return np.clip(t / a, 0, 1) * np.exp(-t * d)


def effects():
    x, t = sweep(240, 620, 0.16)
    sfx("jump", x * np.exp(-t * 16) + lowpass(noise(0.16), 1600) * np.exp(-t * 40) * 0.2, 0.4)
    sfx("land", lowpass(noise(0.12), 500) * np.exp(-t_axis(0.12) * 34), 0.42)
    x = bandpass(noise(0.18), 900, 4200)
    sfx("swing", x * np.sin(np.linspace(0, np.pi, len(x))) ** 2, 0.34)
    x, t = sweep(620, 120, 0.1)
    sfx("hit", x * np.exp(-t * 26) + bandpass(noise(0.1), 1200, 5000) * np.exp(-t * 44) * 0.5, 0.6)
    x, t = sweep(380, 60, 0.3)
    sfx("kill", x * np.exp(-t * 12) + bandpass(noise(0.3), 500, 4000) * np.exp(-t * 15) * 0.5, 0.65)
    x, t = sweep(520, 110, 0.32)
    sfx("hurt", np.sign(x) * np.exp(-t * 9) * 0.35 + x * np.exp(-t * 9), 0.62)
    x, t = sweep(330, 50, 1.1, 1.0)
    sfx("die", x * np.exp(-t * 3.2) + v_bell(hz(midi("D3")), 1.1) * 0.6, 0.7)
    d = 0.5
    sfx("splash", bandpass(noise(d), 300, 5000) * env(d, 0.01, 9) + lowpass(noise(d), 350) * env(d, 0.01, 7) * 1.2, 0.6)
    d = 0.3
    sfx("puff", bandpass(noise(d), 200, 1500) * env(d, 0.02, 14), 0.55)
    d = 0.42
    t = t_axis(d)
    click = bandpass(noise(d), 1800, 6000) * (0.5 + 0.5 * signal.square(2 * np.pi * 38 * t)) * np.clip((d - t) * 8, 0, 1)
    sfx("reel", click, 0.34)
    x, t = sweep(1400, 500, 0.14)
    sfx("cast", x * np.exp(-t * 18) * 0.5 + bandpass(noise(0.14), 2500, 7000) * np.exp(-t * 26), 0.32)
    sfx("clink", v_bell(1900, 0.3) + v_bell(2610, 0.3) * 0.6, 0.42)
    d = 0.42
    sfx("break", bandpass(noise(d), 200, 2600) * env(d, 0.002, 11) + lowpass(noise(d), 200) * env(d, 0.002, 8), 0.72)
    b = np.zeros(int(1.2 * SR))
    for i, n in enumerate(("D5", "F5", "A5", "D6")):
        s = v_bell(hz(midi(n)), 0.95)
        st = int(i * 0.09 * SR)
        b[st:st + len(s)] += s[: len(b) - st]
    sfx("pickup", b, 0.62)
    sfx("lamp", v_pluck(hz(midi("A4")), 1.1) + v_pluck(hz(midi("D5")), 1.1) * 0.7, 0.42)
    x, t = sweep(1100, 900, 0.03)
    sfx("text", x * np.exp(-t * 80), 0.1)
    d = 1.0
    t = t_axis(d)
    sfx("door", lowpass(noise(d), 240) * (0.6 + 0.4 * np.sin(t * 62)) * np.clip(t * 9, 0, 1) * np.clip((d - t) * 3, 0, 1), 0.72)
    sfx("clang", v_bell(hz(midi("D4")), 0.8, 1.5) + bandpass(noise(0.8), 1500, 6000) * np.exp(-t_axis(0.8) * 30) * 0.4, 0.62)
    x, t = sweep(120, 34, 0.5)
    sfx("slam", x * np.exp(-t * 7) + lowpass(noise(0.5), 700) * np.exp(-t * 11), 0.86)
    d = 1.3
    t = t_axis(d)
    f = 76 + 34 * np.sin(t * 7.0) * np.exp(-t * 1.5) + 16 * np.sin(t * 41)
    ph = np.cumsum(f) * 2 * np.pi / SR
    sfx("roar", (signal.sawtooth(ph) * 0.8 + lowpass(noise(d), 700) * 0.9) * np.clip(t * 7, 0, 1) * np.clip((d - t) * 2, 0, 1), 0.8)
    x, t = sweep(300, 70, 0.22)
    sfx("bosshit", x * np.exp(-t * 15) + bandpass(noise(0.22), 800, 5000) * np.exp(-t * 26) * 0.7, 0.72)
    d = 2.0
    sfx("bossdie", lowpass(noise(d), 900) * env(d, 0.02, 2.0) + v_bell(hz(midi("D3")), d) * 0.9, 0.86)
    d = 0.3
    t = t_axis(d)
    f = 1500 + 800 * np.sin(t * 44) * np.exp(-t * 6)
    sfx("gull", np.sin(np.cumsum(f) * 2 * np.pi / SR) * np.exp(-t * 8) * signal.square(t * 460, 0.6) * 0.7, 0.26)
    x, t = sweep(300, 900, 0.18)
    sfx("spit", x * np.exp(-t * 14) + bandpass(noise(0.18), 900, 3500) * np.exp(-t * 20), 0.36)
    d = 1.6
    t = t_axis(d)
    gulp = lowpass(noise(d), 220) * (1 - t / d) + lowpass(noise(d), 950) * (t / d)
    sfx("drink", gulp * np.clip(t * 2, 0, 1) * np.clip((d - t) * 3, 0, 1), 0.76)
    sfx("fork", v_bell(880, 1.8) * 0.7 + np.sin(2 * np.pi * 880 * t_axis(1.8)) * np.exp(-t_axis(1.8) * 1.6) * 0.5, 0.55)
    # the tide on the move: a loop of low surf
    n = int(4.0 * SR)
    x = np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * np.exp(-np.linspace(0, 1, n // 2 + 1) * 48), n)
    x = x + np.fft.irfft(np.fft.rfft(rng.standard_normal(n)) * np.exp(-np.linspace(0, 1, n // 2 + 1) * 14), n) * 0.12
    sfx("rumble", x, 0.8)
    # one voice for each tide: the higher the sea, the higher the bell
    for level, note in enumerate(("D3", "A3", "D4", "F4", "A4", "D5")):
        f = hz(midi(note))
        s = v_bell(f, 5.0) + 0.5 * v_bell(f * 2, 3.5 + 1.5) * 0.4
        sfx(f"bell{level}", s, 0.8)
    f = hz(midi("D2"))
    s = v_bell(f, 12.0) + v_bell(f * 2, 12.0) * 0.5 + v_bell(f * 3, 12.0) * 0.2
    sfx("greatbell", s, 0.95)


if __name__ == "__main__":
    os.makedirs(OUT_SFX, exist_ok=True)
    os.makedirs(OUT_MUS, exist_ok=True)
    only = sys.argv[1:]
    all_jobs = {"effects": effects, "title": title, "dry": dry, "harbor": harbor, "town": town, "well": well,
                "deep": deep, "sump": sump, "boss": boss, "return": return_home, "ending": ending}
    for name, fn in all_jobs.items():
        if not only or name in only:
            fn()
