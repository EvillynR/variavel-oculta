#!/usr/bin/env python3
"""Versão 6.0 — tira dos GLB a cópia embutida das texturas.

O Godot já extrai cada imagem embutida para um arquivo ao lado do modelo
(<modelo>_<imagem>.jpg/png). Com isso a mesma textura ficava duas vezes no
projeto. Aqui o GLB passa a apontar ("uri") para o arquivo extraído e o binário
fica só com a malha. Visual idêntico (é a mesma imagem).
Uso: python3 tools/glb_texturas_externas.py"""
import glob, io, json, os, struct
from PIL import Image, ImageChops, ImageStat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXT = {"image/jpeg": ".jpg", "image/png": ".png"}


def _thumb(img):
    return (img.size, img.convert("RGB").resize((96, 96)))


def read(path):
    b = open(path, "rb").read()
    jl = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + jl])
    bo = 20 + jl
    bl = struct.unpack("<I", b[bo:bo + 4])[0]
    return j, b[bo + 8:bo + 8 + bl]


def write(path, j, binc):
    js = json.dumps(j, separators=(",", ":")).encode()
    while len(js) % 4:
        js += b" "
    while len(binc) % 4:
        binc += b"\0"
    total = 12 + 8 + len(js) + 8 + len(binc)
    out = struct.pack("<III", 0x46546C67, 2, total) + struct.pack("<II", len(js), 0x4E4F534A) + js
    out += struct.pack("<II", len(binc), 0x004E4942) + binc
    open(path, "wb").write(out)


def process(path):
    j, binc = read(path)
    stem = os.path.splitext(os.path.basename(path))[0]
    folder = os.path.dirname(path)
    drop = set()
    # Associa cada imagem embutida ao arquivo extraído pelo CONTEÚDO (nomes
    # repetidos dentro do GLB viram _1, _2... e a ordem não é garantida).
    candidates = {}
    for f in glob.glob(os.path.join(folder, stem + "_*")):
        if f.endswith((".jpg", ".png")):
            candidates[os.path.basename(f)] = _thumb(Image.open(f))
    views0 = j["bufferViews"]
    for im in j.get("images", []):
        if "bufferView" not in im:
            continue
        v = views0[im["bufferView"]]
        data = binc[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        t = _thumb(Image.open(io.BytesIO(data)))
        best, best_d = None, 1e9
        for name, ct in candidates.items():
            if ct[0] != t[0]:
                continue
            d = sum(ImageStat.Stat(ImageChops.difference(ct[1], t[1])).mean) / 3.0
            if d < best_d:
                best, best_d = name, d
        if best is None or best_d > 2.0:
            print("  sem arquivo extraído igual para", im.get("name"), "(fica embutida)")
            continue
        f = best
        drop.add(im["bufferView"])
        del im["bufferView"]
        im.pop("mimeType", None)
        im["uri"] = f
    if not drop:
        return 0
    views = j["bufferViews"]
    remap = {}
    newviews, newbin = [], bytearray()
    for i, v in enumerate(views):
        if i in drop:
            continue
        data = binc[v.get("byteOffset", 0):v.get("byteOffset", 0) + v["byteLength"]]
        while len(newbin) % 4:
            newbin.append(0)
        nv = dict(v)
        nv["byteOffset"] = len(newbin)
        newbin += data
        remap[i] = len(newviews)
        newviews.append(nv)
    j["bufferViews"] = newviews
    for a in j.get("accessors", []):
        if "bufferView" in a:
            a["bufferView"] = remap[a["bufferView"]]
        sp = a.get("sparse")
        if sp:
            sp["indices"]["bufferView"] = remap[sp["indices"]["bufferView"]]
            sp["values"]["bufferView"] = remap[sp["values"]["bufferView"]]
    for im in j.get("images", []):
        if "bufferView" in im:
            im["bufferView"] = remap[im["bufferView"]]
    j["buffers"][0]["byteLength"] = len(newbin)
    before = os.path.getsize(path)
    write(path, j, bytes(newbin))
    return before - os.path.getsize(path)


if __name__ == "__main__":
    total = 0
    for p in sorted(glob.glob(os.path.join(ROOT, "assets", "models", "*.glb")) + glob.glob(os.path.join(ROOT, "assets", "characters", "*", "*.glb"))):
        s = process(p)
        total += s
        print("%-40s -%.1f MB" % (os.path.relpath(p, ROOT), s / 1e6))
    print("economia: %.1f MB" % (total / 1e6))
