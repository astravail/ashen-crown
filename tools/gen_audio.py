#!/usr/bin/env python3
"""Synthesises every sound effect and music loop used by Pyrewake.

Standard library only. Run from the repository root:
    python3 tools/gen_audio.py            # everything
    python3 tools/gen_audio.py gore roar  # only the named sounds
Output goes to game/assets/audio/.
"""
import array
import math
import os
import random
import sys
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "assets", "audio")
TAU = math.tau


def buf(seconds):
    return [0.0] * int(seconds * SR)


def write(name, data, gain=1.0):
    peak = max(1e-6, max(abs(s) for s in data))
    scale = gain / peak if peak > gain else 1.0
    pcm = array.array("h", (int(max(-1.0, min(1.0, s * scale)) * 32000) for s in data))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def env(i, n, attack=0.005, curve=3.0):
    t = i / SR
    if t < attack:
        return t / attack
    return (1.0 - i / n) ** curve


class LP:
    def __init__(self, cutoff):
        self.a = 1.0 - math.exp(-TAU * cutoff / SR)
        self.y = 0.0

    def __call__(self, x, cutoff=None):
        if cutoff is not None:
            self.a = 1.0 - math.exp(-TAU * max(20.0, cutoff) / SR)
        self.y += self.a * (x - self.y)
        return self.y


def noise():
    return random.uniform(-1.0, 1.0)


def add(dst, src, offset=0, gain=1.0):
    for i, s in enumerate(src):
        j = i + offset
        if j >= len(dst):
            j %= len(dst)
        dst[j] += s * gain


class BP:
    """RBJ band-pass biquad (0 dB peak). Used for formants and wet, resonant noise."""

    def __init__(self, f, q):
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0
        self.set(f, q)

    def set(self, f, q):
        w = TAU * max(20.0, min(f, SR * 0.45)) / SR
        a = math.sin(w) / (2.0 * q)
        a0 = 1.0 + a
        self.b0 = a / a0
        self.a1 = -2.0 * math.cos(w) / a0
        self.a2 = (1.0 - a) / a0

    def __call__(self, x):
        y = self.b0 * (x - self.x2) - self.a1 * self.y1 - self.a2 * self.y2
        self.x2 = self.x1
        self.x1 = x
        self.y2 = self.y1
        self.y1 = y
        return y


def drive(d, k):
    """Saturate a buffer in place. Higher k = dirtier."""
    norm = math.tanh(k)
    for i in range(len(d)):
        d[i] = math.tanh(d[i] * k) / norm
    return d


def saw(ph):
    return (ph / TAU) % 1.0 * 2.0 - 1.0


def echo(d, delay, feedback, taps=4, damp=0.5):
    """Simple multi-tap echo (wraps, so loops stay seamless)."""
    out = d[:]
    n = int(delay * SR)
    g = feedback
    for k in range(1, taps + 1):
        lp = LP(4000 * damp ** k + 200)
        for i in range(len(d)):
            out[(i + n * k) % len(out)] += lp(d[i]) * g
        g *= feedback
    return out


def loopify(d, xf):
    """Cross-fade the last xf seconds into the start so the buffer loops without a click."""
    n = int(xf * SR)
    body = d[:len(d) - n]
    for i in range(n):
        a = i / n
        body[i] = body[i] * a + d[len(d) - n + i] * (1.0 - a)
    return body


VOWELS = {
    "a": (730, 1090, 2440),
    "o": (570, 840, 2410),
    "u": (300, 870, 2240),
    "e": (530, 1840, 2480),
    "i": (390, 1990, 2550),
}


def voice(seconds, f0, vowels, rough=0.3, breath=0.25, scale=1.0, sub=0.0):
    """Crude formant voice: a buzzing saw through three band-passes.
    f0(x) gives pitch over normalised time x; vowels is a list of vowel keys morphed across the sound.
    rough adds pitch jitter and growl; sub adds an octave-down saw (demonic)."""
    d = buf(seconds)
    bps = [BP(500, 5), BP(1000, 7), BP(2500, 9)]
    gains = (1.0, 0.55, 0.22)
    ph = ph2 = 0.0
    jit = 0.0
    lp = LP(3000)
    segs = len(vowels) - 1
    for i in range(len(d)):
        x = i / len(d)
        if i % 32 == 0:
            if segs > 0:
                s = min(segs - 1e-6, x * segs)
                k = int(s)
                fr = s - k
                va, vb = VOWELS[vowels[k]], VOWELS[vowels[k + 1]]
                F = [va[j] + (vb[j] - va[j]) * fr for j in range(3)]
            else:
                F = VOWELS[vowels[0]]
            for j in range(3):
                bps[j].set(F[j] * scale, (5, 7, 9)[j])
            jit = jit * 0.6 + noise() * 0.4
        f = f0(x) * (1.0 + rough * 0.06 * jit)
        ph += TAU * f / SR
        src = saw(ph) + breath * noise()
        if sub > 0.0:
            ph2 += TAU * f * 0.5 / SR
            src += sub * saw(ph2)
        d[i] = lp(bps[0](src) * gains[0] + bps[1](src) * gains[1] + bps[2](src) * gains[2])
    return d


def squelch(d, start, f, q, decay, gain):
    """One wet, resonant noise grain - the core of every gore sound."""
    bp = BP(f, q)
    s0 = int(start * SR)
    for i in range(int(SR * min(0.4, 6.0 / decay))):
        j = s0 + i
        if j >= len(d):
            break
        t = i / SR
        bp.set(f * (1.0 - 0.5 * min(1.0, t * 8.0)), q)
        d[j] += bp(noise()) * math.exp(-t * decay) * gain


def crunch(d, start, grains, spread, gain):
    """Bone crunch: a cluster of very short, bright clicks."""
    for _ in range(grains):
        s0 = int((start + random.uniform(0, spread)) * SR)
        prev = 0.0
        amp = gain * random.uniform(0.5, 1.0)
        for i in range(int(SR * 0.012)):
            j = s0 + i
            if j >= len(d):
                break
            n = noise()
            d[j] += (n - prev) * math.exp(-i / SR * 400) * amp
            prev = n


def thud(d, start, f0, decay, gain, drop=2.0):
    ph = 0.0
    s0 = int(start * SR)
    for i in range(int(SR * min(1.0, 7.0 / decay))):
        j = s0 + i
        if j >= len(d):
            break
        t = i / SR
        ph += TAU * f0 * (1.0 + drop * math.exp(-t * 35)) / SR
        d[j] += math.sin(ph) * math.exp(-t * decay) * gain


def drips(d, start, n, spread, gain):
    """Blood dripping and spattering on stone after the hit."""
    for _ in range(n):
        s0 = int((start + random.uniform(0, spread)) * SR)
        f = random.uniform(700, 1500)
        ph = 0.0
        for i in range(int(SR * 0.05)):
            j = s0 + i
            if j >= len(d):
                break
            t = i / SR
            ph += TAU * f * (1.0 + 1.5 * t / 0.05) / SR
            d[j] += math.sin(ph) * math.exp(-t * 70) * gain * random.uniform(0.6, 1.0)


# ---------------------------------------------------------------- SFX

def sfx_swing():
    # A heavy blade cutting air: resonant, low whoosh rather than a hiss.
    d = buf(0.3)
    bp = BP(400, 1.4)
    lp = LP(300)
    for i in range(len(d)):
        x = i / len(d)
        e = math.sin(math.pi * min(1.0, x * 1.4)) ** 2
        bp.set(250 + 1300 * math.sin(math.pi * x), 1.4)
        d[i] = (bp(noise()) * 1.6 + lp(noise()) * 0.6) * e
    return d


def sfx_hit(heavy=False):
    # Steel into flesh: low thud, wet squelch, a crack of bone, then saturation.
    n = 0.5 if heavy else 0.3
    d = buf(n)
    thud(d, 0.0, 55 if heavy else 85, 11 if heavy else 18, 1.1 if heavy else 0.8)
    squelch(d, 0.0, random.uniform(900, 1300), 2.5, 22 if heavy else 30, 2.2)
    squelch(d, random.uniform(0.01, 0.03), random.uniform(400, 700), 3.0, 28, 1.6)
    crunch(d, 0.0, 9 if heavy else 4, 0.035, 0.9 if heavy else 0.6)
    if heavy:
        squelch(d, 0.05, 300, 2.0, 14, 1.4)
        drips(d, 0.12, 4, 0.3, 0.12)
    return drive(d, 2.6 if heavy else 2.0)


def sfx_gore():
    # A body bursting: a cascade of wet grains, bones snapping, then blood raining down.
    d = buf(0.9)
    thud(d, 0.0, 48, 9, 1.2, 3.0)
    for _ in range(14):
        squelch(d, random.uniform(0.0, 0.18), random.uniform(250, 1600), random.uniform(1.8, 4.0), random.uniform(18, 40), random.uniform(0.9, 1.8))
    crunch(d, 0.0, 16, 0.12, 0.9)
    drips(d, 0.2, 14, 0.6, 0.18)
    return drive(d, 2.4)


def sfx_growl():
    # An enemy noticing you: low, gurgling, wet throat.
    d = voice(0.9, lambda x: 62 + 18 * math.sin(math.pi * x), ["u", "o", "a", "u"], rough=1.6, breath=0.6, scale=0.75, sub=0.7)
    for i in range(len(d)):
        x = i / len(d)
        t = i / SR
        d[i] *= math.sin(math.pi * min(1.0, x * 1.3)) ** 0.8 * (0.7 + 0.3 * math.sin(TAU * 17 * t))
    return drive(d, 2.0)


def sfx_fire_cast():
    d = buf(0.35)
    lp = LP(1000)
    for i in range(len(d)):
        t = i / len(d)
        e = math.sin(math.pi * min(1.0, t * 3)) * (1 - t) ** 1.5
        d[i] = lp(noise(), 400 + 2500 * (1 - t)) * e
        if random.random() < 0.004:
            d[i] += random.uniform(-0.8, 0.8)
    return d


def sfx_explosion(size=1.0):
    d = buf(0.9 * size)
    lp = LP(600)
    ph = 0.0
    for i in range(len(d)):
        t = i / SR
        ph += TAU * (60 + 90 * math.exp(-t * 8)) / SR
        rumble = math.sin(ph) * math.exp(-t * 4)
        d[i] = lp(noise(), 2400 * math.exp(-t * 5) + 120) * math.exp(-t * 3.2) * 1.4 + rumble
    # Debris and bodies thrown about
    crunch(d, 0.02, int(10 * size), 0.25 * size, 0.5)
    for _ in range(int(4 * size)):
        squelch(d, random.uniform(0.0, 0.15), random.uniform(300, 900), 2.5, 25, 0.6)
    return drive(d, 2.2)


def sfx_bone():
    d = buf(0.3)
    for k in range(5):
        start = int(SR * random.uniform(0, 0.06))
        f = random.uniform(700, 1800)
        for i in range(int(SR * 0.08)):
            j = start + i
            if j < len(d):
                t = i / SR
                d[j] += math.sin(TAU * f * t) * math.exp(-t * 90) * 0.5 + noise() * math.exp(-t * 160) * 0.4
    crunch(d, 0.0, 12, 0.09, 0.8)
    thud(d, 0.0, 110, 30, 0.4)
    return drive(d, 1.8)


def sfx_summon():
    d = buf(0.9)
    lp = LP(400)
    for i in range(len(d)):
        t = i / SR
        x = i / len(d)
        f = 90 + 220 * x
        tone = math.sin(TAU * f * t) * 0.5 + math.sin(TAU * f * 1.5 * t) * 0.3
        d[i] = (tone + lp(noise(), 300 + 1600 * x) * 1.2) * math.sin(math.pi * x) ** 1.5
    return d


def sfx_death():
    # A dying, gurgling groan over a wet collapse. Each call gives a slightly different voice.
    p0 = random.uniform(95, 150)
    vow = random.choice([["a", "o", "u"], ["e", "a", "u"], ["o", "a", "u", "u"]])
    length = random.uniform(0.8, 1.1)
    d = voice(length, lambda x: p0 * (1.0 - 0.45 * x), vow, rough=1.2, breath=0.5, scale=random.uniform(0.8, 0.95), sub=0.35)
    for i in range(len(d)):
        x = i / len(d)
        t = i / SR
        d[i] *= min(1.0, x * 25) * (1 - x) ** 1.6 * (0.75 + 0.25 * math.sin(TAU * 13 * t)) * 0.9
    squelch(d, 0.0, 800, 2.5, 26, 1.5)
    squelch(d, 0.04, 450, 3.0, 22, 1.2)
    thud(d, length * 0.55, 60, 14, 0.7)
    crunch(d, length * 0.55, 5, 0.05, 0.4)
    return drive(d, 2.0)


def sfx_hurt():
    # The player taking a blow: a short grunt and the meat of the hit.
    p0 = random.uniform(105, 125)
    d = voice(0.32, lambda x: p0 * (1.0 + 0.25 * math.exp(-x * 6)) * (1.0 - 0.2 * x), ["u", "a", "o"], rough=0.8, breath=0.45, scale=0.95, sub=0.2)
    for i in range(len(d)):
        x = i / len(d)
        d[i] *= min(1.0, x * 40) * (1 - x) ** 1.8
    thud(d, 0.0, 70, 16, 0.9)
    squelch(d, 0.0, 700, 2.5, 30, 1.4)
    crunch(d, 0.0, 3, 0.02, 0.4)
    return drive(d, 2.2)


def sfx_hurt_voice(kind):
    """The sound each hero makes when struck: a grunt, a wet gurgle, a sharp gasp."""
    if kind == "knight":
        p0 = random.uniform(82, 98)
        d = voice(0.3, lambda x: p0 * (1.0 + 0.18 * math.exp(-x * 7)) * (1.0 - 0.25 * x), ["u", "o"], rough=0.9, breath=0.35, scale=0.9, sub=0.35)
        shape = 1.6
        k = 2.4
    elif kind == "gravecaller":
        p0 = random.uniform(120, 150)
        d = voice(0.5, lambda x: p0 * (1.0 - 0.3 * x) * (1.0 + 0.05 * math.sin(TAU * 17 * x)), ["u", "e", "o"], rough=1.7, breath=0.9, scale=0.85, sub=0.1)
        # the wet rattle in the throat
        squelch(d, 0.02, 900, 3.0, 40, 1.2)
        squelch(d, 0.14, 650, 3.0, 36, 1.0)
        shape = 1.3
        k = 2.8
    else:
        p0 = random.uniform(230, 270)
        d = voice(0.3, lambda x: p0 * (1.0 + 0.4 * math.exp(-x * 5)) * (1.0 - 0.15 * x), ["a", "e", "a"], rough=0.5, breath=0.8, scale=1.1, sub=0.0)
        shape = 1.9
        k = 1.8
    for i in range(len(d)):
        x = i / len(d)
        d[i] *= min(1.0, x * 50) * (1 - x) ** shape
    return drive(d, k)


def sfx_dodge():
    d = buf(0.28)
    lp = LP(500)
    for i in range(len(d)):
        x = i / len(d)
        d[i] = lp(noise(), 300 + 1800 * x) * math.sin(math.pi * x) ** 1.2
    return d


def sfx_levelup():
    d = buf(1.6)
    notes = [293.66, 349.23, 440.0, 587.33]
    for k, f in enumerate(notes):
        off = int(SR * 0.09 * k)
        for i in range(len(d) - off):
            t = i / SR
            v = (math.sin(TAU * f * t) + 0.35 * math.sin(TAU * f * 2.01 * t) + 0.15 * math.sin(TAU * f * 3.98 * t))
            d[i + off] += v * math.exp(-t * 2.4) * 0.35
    return d


def sfx_pickup():
    d = buf(0.18)
    for i in range(len(d)):
        t = i / SR
        f = 900 + 900 * (i / len(d))
        d[i] = math.sin(TAU * f * t) * math.exp(-t * 22) * 0.6
    return d


def sfx_ui_move():
    d = buf(0.06)
    for i in range(len(d)):
        t = i / SR
        d[i] = math.sin(TAU * 1400 * t) * math.exp(-t * 80) * 0.4
    return d


def sfx_ui_select():
    d = buf(0.4)
    for i in range(len(d)):
        t = i / SR
        d[i] = (math.sin(TAU * 220 * t) * 0.6 + math.sin(TAU * 330 * t) * 0.4 + math.sin(TAU * 660 * t) * 0.15) * math.exp(-t * 7)
    return d


def sfx_teleport():
    d = buf(0.45)
    lp = LP(1000)
    for i in range(len(d)):
        t = i / SR
        x = i / len(d)
        d[i] = math.sin(TAU * (1200 - 1000 * x) * t) * (1 - x) ** 2 * 0.4 + lp(noise(), 3000 * (1 - x)) * (1 - x) ** 2
    return d


def sfx_freeze():
    d = buf(0.6)
    lp = LP(3000)
    for i in range(len(d)):
        t = i / SR
        x = i / len(d)
        crackle = noise() if random.random() < 0.05 else 0.0
        d[i] = lp(noise(), 3500) * (1 - x) ** 2 * 0.6 + crackle * (1 - x)
        d[i] += math.sin(TAU * 70 * t) * math.exp(-t * 10) * 0.8
    return d


def sfx_ultimate():
    d = buf(2.0)
    lp = LP(200)
    for i in range(len(d)):
        t = i / SR
        x = i / len(d)
        e = min(1.0, t * 4) * (1 - x) ** 1.4
        tone = sum(math.sin(TAU * f * t) for f in (55, 82.4, 110, 164.8)) * 0.25
        d[i] = (tone + lp(noise(), 200 + 3000 * math.sin(math.pi * x)) * 1.5) * e
    return d


def sfx_roar():
    # Demonic roar: two detuned, throat-shaped voices an octave apart, with a sub growl, driven hard.
    a = voice(2.0, lambda x: 72 + 22 * math.sin(math.pi * x) + 6 * math.sin(TAU * 6 * x), ["u", "o", "a", "a", "o", "u"], rough=1.8, breath=0.7, scale=0.62, sub=0.9)
    b = voice(2.0, lambda x: 109 + 30 * math.sin(math.pi * x), ["o", "a", "e", "a", "u"], rough=1.4, breath=0.5, scale=0.7)
    lp = LP(120)
    d = buf(2.0)
    for i in range(len(d)):
        x = i / len(d)
        e = min(1.0, x * 8) * (1 - x) ** 0.9
        d[i] = (a[i] * 1.2 + b[i] * 0.6 + lp(noise()) * 2.0) * e
    return drive(d, 3.0)


def sfx_flask():
    d = buf(0.7)
    for i in range(len(d)):
        t = i / SR
        f = 400 + 500 * (1 - math.exp(-t * 6))
        d[i] = math.sin(TAU * f * t) * 0.3 * math.exp(-t * 3)
        if random.random() < 0.01:
            d[i] += math.sin(TAU * 1800 * t) * 0.5
    return d


def sfx_fragment():
    d = buf(2.4)
    for f, a in ((146.83, 0.5), (220.0, 0.35), (277.18, 0.25), (440.0, 0.15), (554.37, 0.08)):
        for i in range(len(d)):
            t = i / SR
            d[i] += math.sin(TAU * f * t + 0.3 * math.sin(TAU * 3 * t)) * a * math.exp(-t * 1.3) * min(1.0, t * 30)
    return d


def sfx_wave():
    d = buf(1.6)
    for k in range(2):
        off = int(SR * 0.42 * k)
        add(d, drum(0.9, 50), off, 1.0)
    return d


def sfx_slam():
    d = sfx_explosion(0.6)
    thud(d, 0.0, 42, 7, 1.4, 3.0)
    crunch(d, 0.0, 14, 0.06, 0.8)
    return drive(d, 1.6)


def drum(length=0.6, f0=60):
    d = buf(length)
    lp = LP(400)
    ph = 0.0
    for i in range(len(d)):
        t = i / SR
        ph += TAU * f0 * (1 + 1.6 * math.exp(-t * 30)) / SR
        d[i] = math.sin(ph) * math.exp(-t * 6) + lp(noise(), 600) * math.exp(-t * 40) * 0.8
    return d


def tick():
    d = buf(0.08)
    lp = LP(5000)
    prev = 0.0
    for i in range(len(d)):
        t = i / SR
        n = noise()
        hp = n - prev
        prev = n
        d[i] = lp(hp, 6000) * math.exp(-t * 60) * 0.5
    return d


# ---------------------------------------------------------------- music

def pad(d, freqs, start, length, gain, attack=2.0, release=2.0, bright=600):
    lp = LP(bright)
    n = int(length * SR)
    s0 = int(start * SR)
    phases = [random.random() * TAU for _ in freqs]
    for i in range(n):
        t = i / SR
        e = min(1.0, t / attack) * min(1.0, (length - t) / release)
        v = 0.0
        for k, f in enumerate(freqs):
            ph = phases[k] + TAU * f * t
            v += (math.sin(ph) + 0.4 * math.sin(2 * ph + 0.3) + 0.18 * math.sin(3 * ph)) * (1.0 + 0.004 * math.sin(TAU * 0.3 * t + k))
        j = (s0 + i) % len(d)
        d[j] += lp(v) * e * gain


def bell(d, f, start, gain):
    s0 = int(start * SR)
    for i in range(int(SR * 3.5)):
        t = i / SR
        v = math.sin(TAU * f * t) + 0.5 * math.sin(TAU * f * 2.76 * t) * math.exp(-t * 2) + 0.25 * math.sin(TAU * f * 5.4 * t) * math.exp(-t * 4)
        j = (s0 + i) % len(d)
        d[j] += v * math.exp(-t * 1.3) * gain


def wind(d, gain, rate=0.07):
    lp = LP(300)
    for i in range(len(d)):
        t = i / SR
        c = 260 + 220 * math.sin(TAU * rate * t) + 120 * math.sin(TAU * rate * 2.3 * t + 1)
        d[i] += lp(noise(), c) * gain * (0.7 + 0.3 * math.sin(TAU * rate * 0.5 * t))


def choir(d, freqs, start, length, gain, vowel="o", attack=2.5, release=3.0):
    """Low, wordless monk choir: slightly detuned formant voices holding a chord."""
    s0 = int(start * SR)
    for k, f in enumerate(freqs):
        det = random.uniform(-0.004, 0.004)
        vib = random.uniform(4.5, 5.5)
        v = voice(length, lambda x, f=f: f * (1.0 + det + 0.005 * math.sin(TAU * vib * x * length)), [vowel, vowel], rough=0.05, breath=0.12, scale=0.9 if f < 150 else 1.0)
        for i in range(len(v)):
            t = i / SR
            e = min(1.0, t / attack) * min(1.0, (length - t) / release)
            d[(s0 + i) % len(d)] += v[i] * e * gain


def war_drum(length=0.9, f0=46):
    d = drum(length, f0)
    squelch(d, 0.0, 180, 1.5, 30, 0.8)
    return drive(d, 1.8)


def drone(d, f, gain, bright=220):
    """Bowed low string: a slowly breathing, filtered saw."""
    lp = LP(bright)
    ph = ph2 = 0.0
    for i in range(len(d)):
        t = i / SR
        ph += TAU * f * (1.0 + 0.002 * math.sin(TAU * 0.2 * t)) / SR
        ph2 += TAU * f * 1.003 / SR
        d[i] += lp(saw(ph) + saw(ph2)) * gain * (0.75 + 0.25 * math.sin(TAU * 0.09 * t))


def music_title():
    L = 48.0
    d = buf(L)
    wind(d, 0.55)
    drone(d, 36.71, 0.12, 160)
    D = 73.42
    chords = [(D, D * 1.5, D * 2.378), (D * 0.891, D * 1.335, D * 2.12), (D * 0.749, D * 1.122, D * 1.782), (D * 0.841, D * 1.26, D * 2.0)]
    for k, ch in enumerate(chords):
        pad(d, ch, k * 12.0, 14.0, 0.04, attack=3.0, release=4.0, bright=400)
        choir(d, ch, k * 12.0, 14.0, 0.09, "o" if k % 2 == 0 else "u", 3.0, 4.0)
    # A distant funeral bell, tolling low
    for t in (1.0, 13.0, 25.0, 37.0):
        bell(d, 146.83, t, 0.12)
        bell(d, 73.42, t, 0.08)
    for t, f in ((6.0, 587.33), (19.5, 523.25), (31.0, 466.16), (43.0, 440.0)):
        bell(d, f, t, 0.04)
    return d


def music_combat():
    bpm = 84
    beat = 60.0 / bpm
    bars = 16
    L = bars * 4 * beat
    d = buf(L)
    wind(d, 0.25, 0.11)
    D = 73.42
    drone(d, D / 2, 0.08, 180)
    prog = [D, D * 0.891, D * 0.749, D * 1.059]
    big = war_drum(1.0, 42)
    low = war_drum(0.6, 58)
    for b in range(bars):
        root = prog[(b // 4) % 4]
        if b % 4 == 0:
            pad(d, (root, root * 1.5, root * 2.0), b * 4 * beat, 4 * 4 * beat + 0.5, 0.04, 1.5, 1.5, 400)
            choir(d, (root * 2.0, root * 2.378), b * 4 * beat, 4 * 4 * beat + 0.5, 0.045, "a" if b % 8 == 0 else "o", 1.5, 1.5)
        for q in range(4):
            t = (b * 4 + q) * beat
            if q in (0, 2) or (q == 3 and b % 2 == 1):
                add(d, big, int(t * SR), 0.6)
            if q == 3 and b % 2 == 1:
                add(d, low, int((t + beat * 0.5) * SR), 0.4)
            if q == 1 and b % 4 == 3:
                add(d, low, int((t + beat * 0.5) * SR), 0.35)
            for e in range(2):
                add(d, tick(), int((t + e * beat * 0.5) * SR), 0.14 if e else 0.22)
        # low ostinato
        for e in range(8):
            t = (b * 4 + e * 0.5) * beat
            f = root * (2.0 if e % 4 == 3 else 1.0)
            s0 = int(t * SR)
            for i in range(int(beat * 0.45 * SR)):
                tt = i / SR
                j = (s0 + i) % len(d)
                ph = TAU * f * tt
                d[j] += math.tanh((math.sin(ph) + 0.5 * saw(ph)) * 1.6) * math.exp(-tt * 6) * 0.12
    return d


def music_boss():
    bpm = 112
    beat = 60.0 / bpm
    bars = 16
    L = bars * 4 * beat
    d = buf(L)
    D = 73.42
    drone(d, D / 2, 0.1, 260)
    prog = [D, D * 1.059, D, D * 0.943]
    big = war_drum(0.6, 44)
    hi = war_drum(0.3, 80)
    for b in range(bars):
        root = prog[(b // 2) % 4]
        if b % 2 == 0:
            pad(d, (root, root * 1.414, root * 2.0, root * 2.378), b * 4 * beat, 2 * 4 * beat + 0.3, 0.04, 0.4, 0.8, 600)
            choir(d, (root * 2.0, root * 2.828, root * 4.0), b * 4 * beat, 2 * 4 * beat + 0.3, 0.05, "a", 0.3, 0.8)
        for q in range(4):
            t = (b * 4 + q) * beat
            add(d, big, int(t * SR), 0.65 if q % 2 == 0 else 0.45)
            add(d, tick(), int((t + beat * 0.5) * SR), 0.3)
            if b % 4 == 3 and q >= 2:
                for k in range(3):
                    add(d, hi, int((t + k * beat / 3) * SR), 0.35)
        for e in range(16):
            t = (b * 4 + e * 0.25) * beat
            f = root * (1.0 if e % 3 else 2.0)
            s0 = int(t * SR)
            for i in range(int(beat * 0.22 * SR)):
                tt = i / SR
                j = (s0 + i) % len(d)
                ph = TAU * f * tt
                d[j] += math.tanh(saw(ph) * 2.5) * math.exp(-tt * 14) * 0.07
    return d


# ---------------------------------------------------------------- zone ambience (seamless loops)

AMB_LEN = 40.0
AMB_XF = 3.0


def crow(d, start, gain):
    """A crow's harsh caw, two or three times."""
    for k in range(random.randint(2, 3)):
        c = voice(0.22, lambda x: 520 + 160 * math.sin(math.pi * x), ["a", "e"], rough=2.5, breath=0.8, scale=1.6)
        for i in range(len(c)):
            x = i / len(c)
            c[i] *= math.sin(math.pi * x) ** 0.6
        add(d, c, int((start + k * 0.34) * SR), gain)


def creak(d, start, gain):
    """Old wood creaking under weight (a hanged man, a branch)."""
    n = int(SR * random.uniform(0.6, 1.2))
    bp = BP(300, 12)
    s0 = int(start * SR)
    f = random.uniform(18, 30)
    for i in range(n):
        x = i / n
        t = i / SR
        imp = 1.0 if (i % int(SR / (f * (1 + 0.5 * math.sin(TAU * 1.5 * t))))) == 0 else 0.0
        bp.set(240 + 120 * x, 12)
        d[(s0 + i) % len(d)] += bp(imp) * math.sin(math.pi * x) * gain * 8.0


def howl(d, start, gain):
    n = int(SR * 2.6)
    ph = 0.0
    lp = LP(1400)
    s0 = int(start * SR)
    for i in range(n):
        x = i / n
        t = i / SR
        f = 380 + 260 * math.sin(math.pi * min(1.0, x * 1.6)) - 120 * x + 6 * math.sin(TAU * 5 * t)
        ph += TAU * f / SR
        v = math.sin(ph) + 0.2 * math.sin(2 * ph) + 0.15 * noise()
        d[(s0 + i) % len(d)] += lp(v) * math.sin(math.pi * x) ** 1.5 * gain


def moan(d, start, gain, high=False):
    """A distant, echoing moan or scream of the damned."""
    p0 = random.uniform(260, 420) if high else random.uniform(95, 150)
    length = random.uniform(1.5, 2.6)
    v = voice(length, lambda x: p0 * (1.0 + 0.15 * math.sin(math.pi * x) - 0.25 * x), random.choice([["o", "a", "u"], ["a", "e", "a"], ["u", "o", "u"]]), rough=0.6, breath=0.4)
    lp = LP(900 if not high else 1600)
    for i in range(len(v)):
        x = i / len(v)
        v[i] = lp(v[i]) * math.sin(math.pi * x) ** 1.2
    add(d, v, int(start * SR), gain)


def drip(d, start, gain):
    ph = 0.0
    s0 = int(start * SR)
    f = random.uniform(1100, 1800)
    for i in range(int(SR * 0.06)):
        t = i / SR
        ph += TAU * f * (1.0 + 2.0 * t / 0.06) / SR
        d[(s0 + i) % len(d)] += math.sin(ph) * math.exp(-t * 60) * gain


def amb_forest():
    d = buf(AMB_LEN + AMB_XF)
    wind(d, 0.9, 0.05)
    # Rustling canopy
    bp = BP(3000, 0.8)
    for i in range(len(d)):
        t = i / SR
        g = 0.5 + 0.5 * math.sin(TAU * 0.05 * t) * math.sin(TAU * 0.13 * t + 1)
        d[i] += bp(noise()) * 0.08 * max(0.0, g)
    for _ in range(5):
        crow(d, random.uniform(0, AMB_LEN), 0.18)
    for _ in range(6):
        creak(d, random.uniform(0, AMB_LEN), 0.1)
    howl(d, random.uniform(8, 30), 0.07)
    return loopify(echo(d, 0.31, 0.25, 3), AMB_XF)


def amb_crypt():
    d = buf(AMB_LEN + AMB_XF)
    drone(d, 41.2, 0.09, 120)
    lp = LP(180)
    for i in range(len(d)):
        d[i] += lp(noise()) * 0.25
    for _ in range(28):
        drip(d, random.uniform(0, AMB_LEN), 0.18)
    for _ in range(4):
        moan(d, random.uniform(0, AMB_LEN), 0.08)
    for _ in range(3):
        creak(d, random.uniform(0, AMB_LEN), 0.05)
    return loopify(echo(d, 0.42, 0.45, 5, 0.4), AMB_XF)


def amb_marsh():
    d = buf(AMB_LEN + AMB_XF)
    wind(d, 0.5, 0.04)
    # Insect drone
    bp = BP(4200, 6)
    for i in range(len(d)):
        t = i / SR
        d[i] += bp(noise()) * 0.06 * (0.6 + 0.4 * math.sin(TAU * 0.07 * t))
    # Rising bubbles from the rot
    for _ in range(40):
        s0 = int(random.uniform(0, AMB_LEN) * SR)
        f = random.uniform(180, 380)
        ph = 0.0
        for i in range(int(SR * 0.09)):
            t = i / SR
            ph += TAU * f * (1.0 + 4.0 * t) / SR
            d[(s0 + i) % len(d)] += math.sin(ph) * math.sin(math.pi * t / 0.09) * 0.12
    for _ in range(3):
        crow(d, random.uniform(0, AMB_LEN), 0.12)
    moan(d, random.uniform(5, 30), 0.05)
    return loopify(d, AMB_XF)


def amb_hell():
    d = buf(AMB_LEN + AMB_XF)
    # The ground itself rumbling
    lp = LP(70)
    ph = 0.0
    for i in range(len(d)):
        t = i / SR
        ph += TAU * (33 + 3 * math.sin(TAU * 0.05 * t)) / SR
        d[i] += lp(noise()) * 1.4 + math.sin(ph) * 0.12
    # Roaring flames that swell and fall
    lp2 = LP(500)
    for i in range(len(d)):
        t = i / SR
        g = 0.55 + 0.45 * math.sin(TAU * 0.06 * t) * math.sin(TAU * 0.023 * t + 2)
        d[i] += lp2(noise(), 300 + 500 * g) * 0.35 * g
    # Crackle and pop
    for _ in range(900):
        j = int(random.uniform(0, AMB_LEN) * SR)
        a = random.uniform(0.05, 0.3)
        for k in range(30):
            d[(j + k) % len(d)] += noise() * a * math.exp(-k / 6.0)
    # The damned, far away
    for _ in range(7):
        moan(d, random.uniform(0, AMB_LEN), 0.06, high=random.random() < 0.6)
    for _ in range(2):
        r = sfx_roar()
        lpr = LP(400)
        for i in range(len(r)):
            r[i] = lpr(r[i])
        add(d, r, int(random.uniform(0, AMB_LEN) * SR), 0.15)
    return loopify(echo(d, 0.5, 0.35, 4, 0.35), AMB_XF)


def main():
    random.seed(7)
    os.makedirs(OUT, exist_ok=True)
    sfx = {
        "swing": sfx_swing(),
        "hit": sfx_hit(),
        "hit_heavy": sfx_hit(True),
        "fire_cast": sfx_fire_cast(),
        "explode": sfx_explosion(),
        "explode_small": sfx_explosion(0.45),
        "bone": sfx_bone(),
        "summon": sfx_summon(),
        "enemy_death": sfx_death(),
        "hurt": sfx_hurt(),
        "dodge": sfx_dodge(),
        "levelup": sfx_levelup(),
        "pickup": sfx_pickup(),
        "ui_move": sfx_ui_move(),
        "ui_select": sfx_ui_select(),
        "teleport": sfx_teleport(),
        "freeze": sfx_freeze(),
        "ultimate": sfx_ultimate(),
        "roar": sfx_roar(),
        "flask": sfx_flask(),
        "fragment": sfx_fragment(),
        "wave": sfx_wave(),
        "slam": sfx_slam(),
    }
    sfx["gore"] = sfx_gore()
    sfx["growl"] = sfx_growl()
    # Variants: the game picks one at random each time, so repeated kills never sound identical.
    for k in (2, 3):
        sfx["hit_%d" % k] = sfx_hit()
        sfx["hit_heavy_%d" % k] = sfx_hit(True)
        sfx["enemy_death_%d" % k] = sfx_death()
        sfx["hurt_%d" % k] = sfx_hurt()
        sfx["gore_%d" % k] = sfx_gore()
        sfx["growl_%d" % k] = sfx_growl()
    for k in (4, 5):
        sfx["enemy_death_%d" % k] = sfx_death()
    # each hero's own voice when hurt, three takes each (added last so the older sounds stay as they were)
    for kind in ("knight", "gravecaller", "pyrewitch"):
        sfx["hurt_" + kind] = sfx_hurt_voice(kind)
        for k in (2, 3):
            sfx["hurt_%s_%d" % (kind, k)] = sfx_hurt_voice(kind)
    only = set(sys.argv[1:])
    for name, data in sfx.items():
        if only and name not in only:
            continue
        write(name, data, 0.9)
        print("sfx", name)
    for name, fn in (("music_title", music_title), ("music_combat", music_combat), ("music_boss", music_boss),
                     ("amb_forest", amb_forest), ("amb_crypt", amb_crypt), ("amb_marsh", amb_marsh), ("amb_hell", amb_hell)):
        if only and name not in only:
            continue
        write(name, fn(), 0.8)
        print("music", name)


if __name__ == "__main__":
    main()
