"""Outil : fabrique le son de la balle qui passe tout près (game/art/son_impact.wav).

    python3 tools/sons.py game/art

Son calculé (pas d'enregistrement, pas de droits) : 22 050 Hz, mono, 16 bits : claquement supersonique,
sifflement, impact dans le sol. Les tirs viennent d'un vrai enregistrement de Kar98k : voir tools/sons_k98.sh.
"""
import sys
import wave
import numpy as np

RATE = 22050
rng = np.random.default_rng(20261029)


def t_axis(sec):
    return np.arange(int(sec * RATE)) / RATE


def lowpass(x, cutoff):
    a = 1.0 - np.exp(-2 * np.pi * cutoff / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x, cutoff):
    return x - lowpass(x, cutoff)


def place(buf, snd, at, gain=1.0):
    i = int(at * RATE)
    n = min(len(snd), len(buf) - i)
    if n > 0:
        buf[i:i + n] += snd[:n] * gain


def blast(sec=0.5, bright=5000.0, decay=0.045, thump=1.0):
    """Détonation : craquement très court, souffle de bruit qui retombe vite, coup grave dont la note descend."""
    t = t_axis(sec)
    crack = rng.normal(size=len(t)) * np.exp(-t / 0.0025)
    noise = lowpass(rng.normal(size=len(t)), bright) * np.exp(-t / decay)
    freq = 55 + 70 * np.exp(-t / 0.03)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    low = np.sin(phase) * np.exp(-t / 0.09) * thump
    return crack * 1.4 + noise * 1.2 + low * 1.3


def click(sec=0.06, f=2600.0):
    """Petit bruit métallique (culasse)."""
    t = t_axis(sec)
    ring = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.008) + np.sin(2 * np.pi * f * 1.73 * t) * np.exp(-t / 0.005) * 0.6
    tick = highpass(rng.normal(size=len(t)), 1500) * np.exp(-t / 0.003)
    return ring * 0.5 + tick


def tail(sec, decay, cutoff, start_lp=None):
    """Réverbération des montagnes : bruit qui s'éteint lentement, de plus en plus sourd."""
    t = t_axis(sec)
    n = lowpass(rng.normal(size=len(t)), cutoff)
    env = (1 - np.exp(-t / 0.05)) * np.exp(-t / decay)
    # grondement : ondulations lentes du volume
    wobble = 1 + 0.35 * np.sin(2 * np.pi * 1.7 * t + 1.0) * np.sin(2 * np.pi * 0.6 * t)
    return n * env * wobble


def finish(x, peak=0.95):
    x = x - np.mean(x)
    x = np.tanh(x / (np.max(np.abs(x)) + 1e-9) * 1.6)   # un peu de saturation : plus de « coup »
    x = x / np.max(np.abs(x)) * peak
    fade = int(0.05 * RATE)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x


def save(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print(path, "%.2f s" % (len(x) / RATE))


out = sys.argv[1]

# Une balle qui passe tout près et frappe le sol.
t = t_axis(1.2)
buf = np.zeros(len(t))
snap = highpass(rng.normal(size=int(0.012 * RATE)), 2500) * np.exp(-np.arange(int(0.012 * RATE)) / RATE / 0.002)
place(buf, snap, 0.0, 1.0)
w = t_axis(0.25)
whizz = np.sin(2 * np.pi * np.cumsum(3200 - 2400 * w / 0.25) / RATE) * np.exp(-w / 0.08) * (1 - np.exp(-w / 0.01))
place(buf, whizz, 0.005, 0.35)
place(buf, lowpass(rng.normal(size=int(0.3 * RATE)), 900) * np.exp(-t_axis(0.3) / 0.05), 0.06, 0.8)
place(buf, tail(1.0, 0.25, 1200), 0.06, 0.25)
save(out + "/son_impact.wav", finish(buf, 0.85))
