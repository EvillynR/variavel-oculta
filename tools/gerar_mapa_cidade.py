#!/usr/bin/env python3
"""Versão 5.8 — textura do MAPA DA CIDADE (Sala de Geografia).
Quadriculado: COLUNAS A (oeste) até F (leste); LINHAS 1 (norte) até 6 (sul).
A escola fica em D2; a rota de evacuação está riscada só até a metade (a
resposta não aparece no mapa). Uso: python3 tools/gerar_mapa_cidade.py"""
import os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "textures", "mapa_cidade.png")
W, H = 2048, 1092
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf"
FONT2 = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
rnd = random.Random(7)

img = Image.new("RGB", (W, H), (205, 188, 150))
px = img.load()
# papel velho: ruído e manchas
for y in range(H):
    for x in range(0, W):
        n = rnd.randint(-10, 10)
        r, g, b = px[x, y]
        px[x, y] = (r + n, g + n, b + n - 2)
d = ImageDraw.Draw(img, "RGBA")
for _ in range(40):
    cx, cy, rr = rnd.randint(0, W), rnd.randint(0, H), rnd.randint(30, 160)
    d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(120, 90, 50, rnd.randint(10, 28)))

f_big = ImageFont.truetype(FONT, 60)
f_lab = ImageFont.truetype(FONT, 54)
f_small = ImageFont.truetype(FONT2, 30)
f_title = ImageFont.truetype(FONT, 64)
INK = (45, 32, 22, 255)

# quadriculado 6 x 6
gx, gy, cell = 170, 110, 150
cols, rows = "ABCDEF", "123456"
# quarteirões (cada célula) com ruas entre eles
for i in range(6):
    for j in range(6):
        x0, y0 = gx + i * cell, gy + j * cell
        d.rectangle((x0 + 18, y0 + 18, x0 + cell - 18, y0 + cell - 18), fill=(176, 160, 128, 255), outline=(110, 90, 60, 255), width=3)
        # casinhas
        for k in range(rnd.randint(2, 4)):
            hx, hy = x0 + rnd.randint(28, cell - 60), y0 + rnd.randint(28, cell - 60)
            d.rectangle((hx, hy, hx + rnd.randint(18, 32), hy + rnd.randint(18, 32)), fill=(150, 130, 100, 255))
# rio cortando o leste
pts = [(gx + 4.55 * cell + rnd.randint(-8, 8), gy + t * cell / 2) for t in range(13)]
d.line(pts, fill=(90, 120, 140, 230), width=34, joint="curve")
# praça (verde) em C4
x0, y0 = gx + 2 * cell, gy + 3 * cell
d.rectangle((x0 + 18, y0 + 18, x0 + cell - 18, y0 + cell - 18), fill=(120, 140, 90, 255), outline=(70, 90, 50, 255), width=3)
d.text((x0 + 26, y0 + cell / 2 - 18), "PRAÇA", font=f_small, fill=INK)
# a escola em D2
x0, y0 = gx + 3 * cell, gy + 1 * cell
d.rectangle((x0 + 18, y0 + 18, x0 + cell - 18, y0 + cell - 18), fill=(150, 60, 50, 255), outline=(60, 20, 15, 255), width=5)
d.polygon([(x0 + 40, y0 + 70), (x0 + cell / 2, y0 + 30), (x0 + cell - 40, y0 + 70)], fill=(80, 30, 25, 255))
d.rectangle((x0 + 45, y0 + 70, x0 + cell - 45, y0 + 120), fill=(235, 220, 190, 255))
d.text((x0 + 18, y0 + cell - 12), "ESCOLA", font=f_small, fill=(120, 20, 15, 255))
# grade e rótulos
for i in range(7):
    d.line((gx + i * cell, gy, gx + i * cell, gy + 6 * cell), fill=(60, 45, 30, 200), width=4)
    d.line((gx, gy + i * cell, gx + 6 * cell, gy + i * cell), fill=(60, 45, 30, 200), width=4)
for i, c in enumerate(cols):
    d.text((gx + i * cell + cell / 2 - 18, gy - 72), c, font=f_lab, fill=INK)
    d.text((gx + i * cell + cell / 2 - 18, gy + 6 * cell + 10), c, font=f_lab, fill=INK)
for j, r in enumerate(rows):
    d.text((gx - 62, gy + j * cell + cell / 2 - 32), r, font=f_lab, fill=INK)
    d.text((gx + 6 * cell + 20, gy + j * cell + cell / 2 - 32), r, font=f_lab, fill=INK)
# rota de evacuação riscada só até a metade (sai da escola para o sul e some)
sx, sy = gx + 3.5 * cell, gy + 1.5 * cell
for k in range(9):
    yy = sy + 20 + k * 18
    d.line((sx, yy, sx, yy + 10), fill=(170, 25, 20, 255), width=9)
d.text((sx + 14, sy + 160), "?", font=f_big, fill=(170, 25, 20, 255))
# borrão de giz/água por cima do resto da rota
for _ in range(14):
    bx, by = sx + rnd.randint(-120, 40), sy + rnd.randint(200, 420)
    d.ellipse((bx - 50, by - 30, bx + 50, by + 30), fill=(200, 184, 148, 70))

# painel da direita: título, rosa dos ventos, legenda
tx = gx + 6 * cell + 130
d.text((tx, 120), "MAPA DA CIDADE", font=f_title, fill=INK)
d.line((tx, 200, tx + 640, 200), fill=INK, width=4)
cx, cy = tx + 160, 450
d.polygon([(cx, cy - 150), (cx + 30, cy), (cx, cy + 150), (cx - 30, cy)], fill=(70, 50, 35, 255))
d.polygon([(cx - 150, cy), (cx, cy - 30), (cx + 150, cy), (cx, cy + 30)], fill=(120, 95, 65, 255))
d.ellipse((cx - 18, cy - 18, cx + 18, cy + 18), fill=(200, 184, 148, 255), outline=INK, width=4)
for t, (dx, dy) in {"N": (-20, -230), "S": (-17, 160), "L": (175, -32), "O": (-235, -32)}.items():
    d.text((cx + dx, cy + dy), t, font=f_lab, fill=INK)
ly = 680
d.rectangle((tx, ly, tx + 50, ly + 50), fill=(150, 60, 50, 255), outline=(60, 20, 15, 255), width=4)
d.text((tx + 70, ly + 2), "Escola", font=f_small, fill=INK)
d.rectangle((tx, ly + 80, tx + 50, ly + 130), fill=(120, 140, 90, 255), outline=(70, 90, 50, 255), width=4)
d.text((tx + 70, ly + 82), "Praça", font=f_small, fill=INK)
d.line((tx, ly + 185, tx + 50, ly + 185), fill=(90, 120, 140, 255), width=20)
d.text((tx + 70, ly + 162), "Rio", font=f_small, fill=INK)
for k in range(3):
    d.line((tx + k * 20, ly + 250, tx + k * 20 + 10, ly + 250), fill=(170, 25, 20, 255), width=9)
d.text((tx + 70, ly + 228), "Rota de evacuação", font=f_small, fill=INK)
d.text((tx, ly + 300), "1 quadrado = 1 quadra", font=f_small, fill=INK)
img = img.filter(ImageFilter.GaussianBlur(0.6))
img.save(OUT)
print("ok:", OUT)
