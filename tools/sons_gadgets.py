"""Sons électroniques des gadgets, synthétisés (comme dans les jeux, ce sont des sons de synthèse).

  python3 tools/sons_gadgets.py

- son_ramassage.ogg : objet ramassé, deux notes brèves qui montent (façon Metal Gear).
- son_thermique_on.ogg / _off.ogg : allumage de la vision (sifflement qui monte, déclic) / extinction (qui descend).
- son_echo.ogg : bip radio et souffle de transmission.
Les sons « physiques » (couverture de survie, leurre, impacts sur la roche) viennent de vidéos Higgsfield.
"""
import os, subprocess, tempfile, wave
import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "art")
rng = np.random.default_rng(5)


def save(x, name):
    x = x / (np.abs(x).max() + 1e-9) * 0.85
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False).name
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", os.path.join(OUT, name)], check=True)
    os.remove(tmp)


def tone(f, dur, shape=0.35):
    t = np.arange(int(dur * SR)) / SR
    s = np.sin(2 * np.pi * f * t)
    sq = np.sign(s) * np.abs(s) ** 0.4          # un peu « carré » : son de jeu
    return (s * (1 - shape) + sq * shape)


def env(n, a, r):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    e[:na] = np.linspace(0, 1, na)
    e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e


# Ramassage : deux notes (mi, si) puis un petit écho.
n1 = tone(1318, 0.07); n1 *= env(len(n1), 0.003, 0.03)
n2 = tone(1975, 0.16); n2 *= env(len(n2), 0.003, 0.12)
gap = np.zeros(int(0.02 * SR))
x = np.concatenate([n1, gap, n2, np.zeros(int(0.25 * SR))])
x[int(0.12 * SR):] += 0.25 * x[:len(x) - int(0.12 * SR)]
save(x, "son_ramassage.ogg")

# Vision thermique : sifflement qui monte (condensateur qui se charge), déclic, souffle électronique.
dur = 0.75
t = np.arange(int(dur * SR)) / SR
f = 600 + 8200 * (t / dur) ** 1.6
ph = 2 * np.pi * np.cumsum(f) / SR
whine = np.sin(ph) * 0.6 + np.sin(2 * ph) * 0.15
whine *= np.linspace(0.2, 1.0, len(t)) * env(len(t), 0.02, 0.08)
click = np.zeros(int(0.05 * SR)); click[:120] = rng.standard_normal(120) * np.linspace(1, 0, 120)
hiss = rng.standard_normal(int(0.5 * SR)) * 0.08 * np.linspace(1, 0, int(0.5 * SR)) ** 2
on = np.concatenate([whine, click, hiss])
save(on, "son_thermique_on.ogg")
t = np.arange(int(0.45 * SR)) / SR
f = 7000 * (1 - t / 0.45) ** 2 + 300
off = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.linspace(1, 0, len(t)) ** 1.5 * 0.7
save(np.concatenate([click, off]), "son_thermique_off.ogg")

# Écho de tir : bip radio, souffle de transmission.
b = tone(1046, 0.09, 0.6) * env(int(0.09 * SR), 0.003, 0.03)
b2 = tone(1568, 0.12, 0.6) * env(int(0.12 * SR), 0.003, 0.06)
nz = rng.standard_normal(int(0.35 * SR))
f = np.fft.rfftfreq(len(nz), 1 / SR); nz = np.fft.irfft(np.fft.rfft(nz) * ((f > 900) & (f < 3500)), len(nz))
nz *= np.linspace(1, 0, len(nz)) * 0.5 / (np.abs(nz).max() + 1e-9)
save(np.concatenate([b, np.zeros(int(0.04 * SR)), b2, nz]), "son_echo.ogg")
print("ok")
