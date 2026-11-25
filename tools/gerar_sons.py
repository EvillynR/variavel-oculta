#!/usr/bin/env python3
"""Versão 5.7 — sons do enigma da Sala de Música (sintetizados, sem arquivos de fora).
Gera assets/audio/*.wav: notas de piano antigo (dó..si), erro distorcido,
destrava e o ambiente inquietante da sala. Uso: python3 tools/gerar_sons.py"""
import math, os, random, struct, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")
RATE = 44100
os.makedirs(os.path.join(OUT, "notas"), exist_ok=True)


def save(path, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    k = 0.89 / peak
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * k)) * 32767)) for s in samples))


def piano(freq, dur=2.2, detune=0.0035):
    """Piano velho: fundamental + harmônicos que somem rápido, corda levemente
    desafinada (batimento) e ataque de martelo."""
    n = int(dur * RATE)
    out = []
    rnd = random.Random(int(freq))
    for i in range(n):
        t = i / RATE
        env = (1 - math.exp(-t * 180)) * math.exp(-t * 2.1)
        s = 0.0
        for h, a in ((1, 1.0), (2, 0.45), (3, 0.22), (4, 0.12), (5, 0.06)):
            dec = math.exp(-t * (1.2 * h))
            s += a * dec * (math.sin(2 * math.pi * freq * h * t) + 0.6 * math.sin(2 * math.pi * freq * h * (1 + detune) * t))
        hammer = math.exp(-t * 90) * (rnd.random() * 2 - 1) * 0.15
        out.append(env * s + hammer)
    return out


NOTAS = {"do": 261.63, "re": 293.66, "mi": 329.63, "fa": 349.23, "sol": 392.0, "la": 440.0, "si": 493.88}
for nome, f in NOTAS.items():
    save(os.path.join(OUT, "notas", nome + ".wav"), piano(f))

# erro: cluster desafinado + "bitcrush" + nota que despenca
n = int(1.8 * RATE)
err = []
for i in range(n):
    t = i / RATE
    env = (1 - math.exp(-t * 60)) * math.exp(-t * 1.6)
    s = 0.0
    for f in (233.08, 246.94, 261.63, 277.18, 155.56):
        s += math.sin(2 * math.pi * f * t * (1 - 0.06 * t))
    s = math.copysign(min(1.0, abs(s) * 0.6) ** 0.5, s)          # distorção
    s = round(s * 6) / 6                                             # bitcrush
    err.append(env * s)
save(os.path.join(OUT, "erro.wav"), err)

# destrava: clique metálico + acorde maior que sobe
n = int(1.4 * RATE)
ok = []
for i in range(n):
    t = i / RATE
    click = math.exp(-t * 400) * math.sin(2 * math.pi * 2600 * t) * 0.8 if t < 0.05 else 0.0
    s = 0.0
    for j, f in enumerate((261.63, 329.63, 392.0, 523.25)):
        t0 = 0.12 + j * 0.09
        if t > t0:
            tt = t - t0
            s += math.exp(-tt * 3.0) * math.sin(2 * math.pi * f * tt) * 0.5
    ok.append(click + s)
save(os.path.join(OUT, "destrava.wav"), ok)

# ambiente: zumbido grave que respira + rangidos distantes (8 s, emenda sem estalo)
dur = 8.0
n = int(dur * RATE)
amb = []
rnd = random.Random(7)
noise = 0.0
for i in range(n):
    t = i / RATE
    breathe = 0.6 + 0.4 * math.sin(2 * math.pi * t / dur)
    s = 0.0
    for f, a in ((55.0, 0.5), (55.0 * 1.006, 0.45), (82.5, 0.18), (110.25, 0.08)):
        s += a * math.sin(2 * math.pi * f * t)
    noise = noise * 0.995 + (rnd.random() * 2 - 1) * 0.02          # ruído grave (vento)
    creak = 0.0
    for c0 in (2.3, 5.9):
        if c0 < t < c0 + 0.6:
            tt = t - c0
            creak += math.sin(2 * math.pi * (180 + 90 * tt) * tt) * math.exp(-tt * 6) * 0.12
    amb.append(breathe * s * 0.5 + noise + creak)
save(os.path.join(OUT, "musica_ambiente.wav"), amb)
print("ok: sons em", OUT)
