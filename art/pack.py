"""Packs Blender renders into sprite sheets and makes the ground textures.

    python art/pack.py <render_dir> <game_dir>

Writes <game_dir>/assets/art/: sheets, ground/*.png and art.json, the
manifest the game reads (src/view/art.gd). Needs Pillow and numpy.
"""
import json, os, sys
import numpy as np
from PIL import Image

RENDER = sys.argv[1] if len(sys.argv) > 1 else "render"
GAME = sys.argv[2] if len(sys.argv) > 2 else "game"
OUT = os.path.join(GAME, "assets", "art")

# Frame sizes in screen pixels (w, h, foot), as in sprites.py. Sheets are 2x.
WALL_FRAME = (112, 120, 40)
TREE_FRAME = (176, 176, 40)
FIG_FRAME = (108, 120, 22)
BEAST_FRAME = (92, 80, 22)

# Which figure layer shows each item (items.json ids), and which mask
# channels of a layer take which of the NPC's look colors.
GEAR = {"gallic_sword": "sword", "gladius": "gladius", "dagger": "dagger", "axe": "axe", "spear": "spear",
        "war_spear": "spear", "staff": "staff", "club": "club", "javelin": "javelin", "pilum": "pilum",
        "sling": "sling", "hunting_bow": "bow", "gallic_shield": "shield", "small_shield": "small_shield",
        "scutum": "scutum", "leather_cap": "cap", "bronze_helmet": "helmet", "iron_helmet": "helmet_iron",
        "raven_helm": "helmet_bird", "mail_shirt": "mail", "chief_mail": "mail"}
HAIR_TINT = [("hair", 2)]
TINTS = {"body": [("tunic", 0), ("trousers", 1), ("hair", 2)], "body_f": [("tunic", 0)], "body_roman": [("tunic", 0)],
         "cloak": [("cloak", 0), ("cloak2", 1)], "hide": [("hide", 0)], "hood": [("hood", 0)],
         "hair_wrap": [("wrap", 0)],
         "shield": [("shield", 0)], "small_shield": [("shield", 0)], "scutum": [("shield", 0)]}
for _l in ("hair_long", "hair_swept", "hair_short", "hair_knot", "hair_braid", "hair_bun", "moustache", "beard"):
    TINTS[_l] = HAIR_TINT

# Which terrains a wall reaches toward, and what ground lies under it.
WALLS = {
    "wall_wood": {"connect": ["wall_wood", "door", "wall_stone"], "under": "dirt"},
    "wall_stone": {"connect": ["wall_stone", "door", "wall_wood"], "under": "dirt"},
    "palisade": {"connect": ["palisade"], "under": "dirt"},
    "fence": {"connect": ["fence"], "under": None},
    "rampart": {"connect": ["rampart"], "under": "dirt"},
    "cliff": {"connect": ["cliff", "cave_wall"], "under": None},
    "cave_wall": {"connect": ["cave_wall", "cliff"], "under": "cave"},
}
DOOR = {"connect": ["wall_wood", "wall_stone"]}
PROPS = {"hearth": "floor_earth", "bed": "floor_earth", "table": "floor_earth", "crate": "floor_earth", "altar": None,
         "stall": "dirt", "amphorae": "dirt", "loom": "floor_earth", "granary": None, "quern": "floor_earth",
         "woodpile": "dirt", "cart": "dirt", "tent": "dirt", "rubble": "dirt", "smithy": "dirt"}

# Ground: blend priority (higher spreads soft edges over lower) and aliases
# for terrains that borrow another's texture.
BLEND = {"water": 0, "shallows": 1, "mud": 2, "cave": 2, "grass": 3, "meadow": 4, "field": 4,
         "snow": 5, "dirt": 6, "road": 7, "floor_earth": 9, "floor_wood": 9}
ALIAS = {"door": "floor_earth", "bed": "floor_earth", "bush": "grass", "bones": "cave"}


def frame_info(fr):
    w, h, foot = fr
    return {"cell": [w * 2, h * 2], "anchor": [w, (h - foot) * 2]}


def sheet(frames, cols, name):
    w, h = frames[0].size
    rows = (len(frames) + cols - 1) // cols
    out = Image.new("RGBA", (w * cols, h * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, ((i % cols) * w, (i // cols) * h))
    out.save(os.path.join(OUT, name), optimize=True)
    return name


SHADOW = 0.6  # how dark cast shadows get, as alpha
SHADOW_RGB = (22, 18, 26)  # a little warm-cool, not pure black


OUTLINE_RGB = (16, 13, 12)


def load(path, shadow=True, outline=False):
    """A render, with its cast shadow (black pixels from the shadow catcher)
    lightened and tinted. Masks (shadow=False) are left alone. With outline,
    a dark line one screen pixel wide goes round the object (not its
    shadow), the way Fallout's sprites hold their shape against the ground."""
    a = np.asarray(Image.open(path).convert("RGBA")).copy()
    if not shadow:
        return Image.fromarray(a, "RGBA")
    sh = a[..., :3].max(axis=2) < 10
    a[sh, 3] = (a[sh, 3].astype(np.float32) * SHADOW).astype(np.uint8)
    a[sh, :3] = SHADOW_RGB
    if outline:
        obj = (a[..., 3] > 60) & ~sh
        grown = obj.copy()
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1), (-2, 0), (2, 0), (0, -2), (0, 2),
                       (-1, -1), (-1, 1), (1, -1), (1, 1)):
            grown |= np.roll(np.roll(obj, dy, 0), dx, 1)
        ring = grown & ~obj
        a[ring, :3] = OUTLINE_RGB
        a[ring, 3] = np.maximum(a[ring, 3], 190)
    return Image.fromarray(a, "RGBA")


def tint_layer(lit, mask, channel, ref=154 / 255):
    """The part of a gray render that a mask channel marks, as a half-bright
    shade layer: the game multiplies it by (color x 2)."""
    l = np.asarray(lit, dtype=np.float32) / 255
    m = np.asarray(mask, dtype=np.float32) / 255
    w = m[..., channel] * m[..., 3]
    rgb = np.clip(l[..., :3] / ref * 0.5, 0, 1)
    a = np.clip(w * l[..., 3], 0, 1)
    out = np.dstack([rgb, a])
    return Image.fromarray((out * 255 + 0.5).astype(np.uint8), "RGBA")


# --- Ground textures ------------------------------------------------------------

N = 512  # drawn at half size: one tile covers 256 screen pixels


def noise(beta, seed, aniso=1.0):
    """Tileable fractal noise in 0..1 (filtered white noise is periodic)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.normal(size=(N, N)))
    fy = np.fft.fftfreq(N)[:, None] * aniso
    fx = np.fft.fftfreq(N)[None, :]
    k = np.sqrt(fx ** 2 + fy ** 2)
    k[0, 0] = 1
    n = np.real(np.fft.ifft2(f / k ** (beta / 2)))
    n -= n.min()
    return n / n.max()


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255


def ramp(t, colors):
    """Map 0..1 through a list of colors."""
    t = np.clip(t, 0, 1) * (len(colors) - 1)
    i = np.minimum(t.astype(int), len(colors) - 2)
    f = (t - i)[..., None]
    cs = np.stack([hexc(c) for c in colors])
    return cs[i] * (1 - f) + cs[i + 1] * f


def specks(img, seed, density, color, size=1, stretch=1):
    rng = np.random.default_rng(seed)
    n = int(N * N * density)
    ys = rng.integers(0, N, n)
    xs = rng.integers(0, N, n)
    c = hexc(color)
    for dy in range(size * stretch):
        for dx in range(size):
            img[(ys - dy) % N, (xs + dx) % N] = img[(ys - dy) % N, (xs + dx) % N] * 0.35 + c * 0.65
    return img


def shade(img, amount, seed, beta=2.6):
    return img * (1 - amount / 2 + amount * noise(beta, seed))[..., None]


def patches(img, seed, color, cover, soft=0.08, beta=2.4):
    """Blend in large soft-edged patches of another color over about `cover`
    of the tile (dead straw in grass, bare earth, wet ground)."""
    n = noise(beta, seed)
    th = np.quantile(n, 1 - cover)
    w = np.clip((n - th) / soft, 0, 1)[..., None]
    c = color if isinstance(color, np.ndarray) else hexc(color)
    return img * (1 - w) + c * w


def pebbles(img, seed, density, body, size=2):
    """Small stones lit like the sprites: light from the lower left, a dark
    edge and a short shadow to the upper right."""
    rng = np.random.default_rng(seed)
    n = int(N * N * density)
    ys = rng.integers(0, N, n)
    xs = rng.integers(0, N, n)
    sizes = rng.integers(max(1, size - 1), size + 1, n)
    tone = rng.uniform(0.7, 1.0, n)[:, None]
    dark = hexc("#1c1814")
    c = hexc(body)
    for s in range(1, size + 1):
        k = sizes == s
        y, x, tn = ys[k], xs[k], tone[k]
        for dy in range(-1, s):
            for dx in range(0, s + 1):
                yy, xx = (y - dy - 1) % N, (x + dx + 1) % N
                img[yy, xx] = img[yy, xx] * 0.55 + dark * 0.45
        for dy in range(s):
            for dx in range(s):
                img[(y - dy) % N, (x + dx) % N] = np.clip(c * tn * (1.05 if dx == 0 and dy == 0 else 0.88), 0, 1)
    return img


# Winter on the causse: the grass is short, olive and half dead, with straw,
# bare earth and stones showing through. Nothing is lawn-green.
def ground(name):
    if name == "grass":
        img = ramp(noise(2.2, 1) * 0.7 + noise(1.2, 2) * 0.3, ["#2a2f1c", "#3b3f25", "#4d4d2f", "#5c5838"])
        img = patches(img, 50, ramp(noise(1.4, 51), ["#5e5638", "#74684a"]), 0.3)
        img = patches(img, 52, ramp(noise(1.6, 53), ["#3e3424", "#4e4230"]), 0.12, beta=2.8)
        img = specks(img, 3, 0.05, "#22281a", 1, 3)
        img = specks(img, 4, 0.04, "#7a6e4c", 1, 3)
        img = pebbles(img, 54, 0.0008, "#8a8270", 3)
    elif name == "meadow":
        img = ramp(noise(2.0, 5) * 0.7 + noise(1.2, 6) * 0.3, ["#46482c", "#5a5634", "#6e6640", "#7e744c"])
        img = patches(img, 55, ramp(noise(1.4, 56), ["#7a6c48", "#8c7c54"]), 0.35)
        img = specks(img, 7, 0.06, "#968858", 1, 4)
        img = specks(img, 8, 0.03, "#2e3420", 1, 3)
    elif name == "field":
        y = np.arange(N)[:, None] * np.ones((1, N))
        rows = (np.sin((y + noise(2.5, 9) * 30) * 2 * np.pi / 32) + 1) / 2
        img = ramp(rows * 0.6 + noise(1.5, 10) * 0.4, ["#2e261a", "#3e3324", "#4f432e", "#5c4f38"])
        img = specks(img, 11, 0.03, "#8a7c54", 1, 3)
        img = pebbles(img, 57, 0.001, "#8a8070", 3)
    elif name == "road":
        img = ramp(noise(2.0, 12) * 0.6 + noise(1.0, 13) * 0.4, ["#463a2a", "#5a4c38", "#6a5a44", "#776852"])
        img = patches(img, 58, hexc("#4a3e2e"), 0.15, soft=0.25, beta=2.8)
        img = specks(img, 15, 0.02, "#352a1e", 2)
        img = pebbles(img, 14, 0.004, "#9a9282", 3)
    elif name == "dirt":
        img = ramp(noise(2.2, 16) * 0.7 + noise(1.0, 17) * 0.3, ["#352b20", "#45392b", "#544633", "#5f5039"])
        img = patches(img, 59, ramp(noise(1.6, 60), ["#3a3a24", "#4a4830"]), 0.12, beta=2.8)
        img = specks(img, 19, 0.02, "#2a2219", 1, 2)
        img = pebbles(img, 18, 0.003, "#8e8674", 3)
    elif name == "mud":
        img = ramp(noise(2.4, 20), ["#241e16", "#30281d", "#3c3224", "#463a2a"])
        wet = noise(2.8, 21)
        img = img + (np.clip((wet - 0.72) * 6, 0, 1) * 0.12)[..., None]
    elif name == "floor_earth":
        img = ramp(noise(2.0, 22) * 0.7 + noise(1.0, 23) * 0.3, ["#3a2e20", "#483a29", "#564532", "#604e38"])
        img = specks(img, 24, 0.02, "#8e7e52", 1, 3)
        img = specks(img, 61, 0.01, "#241c14", 2)
    elif name == "floor_wood":
        y = np.arange(N)[:, None] * np.ones((1, N))
        x = np.ones((N, 1)) * np.arange(N)[None, :]
        plank = (y // 32).astype(int)
        grain = noise(2.0, 25, aniso=6.0)
        img = ramp(grain * 0.7 + (plank % 3) * 0.12, ["#5a4026", "#6e5032", "#80603a", "#8c6c44"])
        seam = ((y % 32) < 2) | (((x + plank * 97) % 192) < 2)
        img[seam] *= 0.55
    elif name == "water":
        img = ramp(noise(2.6, 26) * 0.6 + noise(1.6, 27, aniso=4) * 0.4, ["#1c303c", "#26404c", "#2f4a58", "#3c5868"])
        rip = noise(1.4, 28, aniso=8)
        img = img + (np.clip((rip - 0.7) * 5, 0, 1) * 0.12)[..., None]
    elif name == "shallows":
        img = ramp(noise(2.2, 29) * 0.6 + noise(1.4, 30, aniso=4) * 0.4, ["#3a5458", "#4f6b70", "#5e7a7c", "#728a86"])
        img = specks(img, 31, 0.02, "#8a8a78", 2)
        rip = noise(1.4, 32, aniso=8)
        img = img + (np.clip((rip - 0.7) * 5, 0, 1) * 0.12)[..., None]
    elif name == "snow":
        img = ramp(noise(2.2, 33), ["#a8aaa4", "#c0c0b8", "#d2d0c8", "#e2e0d8"])
    elif name == "thatch":
        # Straw runs down the slope (texture y); courses of thatch make faint
        # steps across it.
        y = np.arange(N)[:, None] * np.ones((1, N))
        straw = noise(1.6, 37, aniso=0.12) * 0.65 + noise(1.0, 38, aniso=0.08) * 0.35
        course = ((y + noise(2.4, 42) * 24) % 64) / 64.0
        img = ramp(straw * 0.75 + course * 0.25, ["#4e4430", "#6e6044", "#8c7c56", "#a6946a"])
        img = specks(img, 40, 0.04, "#3a3122", 1, 5)
        img = specks(img, 41, 0.03, "#b8a678", 1, 5)
    elif name == "cave":
        img = ramp(noise(2.2, 34) * 0.7 + noise(1.0, 35) * 0.3, ["#2e2a26", "#3e3832", "#4a4440", "#58524c"])
        img = specks(img, 36, 0.01, "#6a645c", 2)
    else:
        raise KeyError(name)
    img = shade(img, 0.3, sum(map(ord, name)))
    a = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    os.makedirs(os.path.join(OUT, "ground"), exist_ok=True)
    Image.fromarray(a, "RGB").save(os.path.join(OUT, "ground", name + ".png"), optimize=True)
    return "ground/%s.png" % name


def layers(folder, prefix, outline=True):
    """Sheets for every layer rendered in folder. Rows are facings 0-5,
    columns are stand / stride / stride; row 6 holds the body lying down."""
    out = {}
    for layer in sorted(os.listdir(folder)):
        names = ["%d_%d.png" % (f, k) for f in range(6) for k in range(3)]
        if os.path.isfile(os.path.join(folder, layer, "lit", "down.png")):
            names.append("down.png")
        lit = [load(os.path.join(folder, layer, "lit", n), outline=outline) for n in names]
        entry = {"sheet": sheet(lit, 3, "%s_%s.png" % (prefix, layer)), "tints": {}}
        if os.path.isdir(os.path.join(folder, layer, "mask")):
            masks = [load(os.path.join(folder, layer, "mask", n), False) for n in names]
            for key, ch in TINTS.get(layer, []):
                t = [tint_layer(l, m, ch) for l, m in zip(lit, masks)]
                entry["tints"][key] = sheet(t, 3, "%s_%s_%s.png" % (prefix, layer, key))
        out[layer] = entry
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    man = {"scale": 0.5, "walls": {}, "trees": {}, "props": {}, "figure": {}, "ground": {}, "blend": BLEND, "alias": ALIAS}
    walls = dict(WALLS)
    walls["door"] = dict(DOOR, under=None)
    for name, info in walls.items():
        d = os.path.join(RENDER, "walls", name)
        if not os.path.isdir(d):
            continue
        frames = [load(os.path.join(d, "%02d.png" % m)) for m in range(64)]
        man["walls"][name] = dict(frame_info(WALL_FRAME), sheet=sheet(frames, 8, "walls_%s.png" % name), cols=8, **info)
    for kind in ("tree", "pine", "bush"):
        d = os.path.join(RENDER, "trees", kind)
        if os.path.isdir(d):
            frames = [load(os.path.join(d, f), outline=True) for f in sorted(os.listdir(d))]
            man["trees"][kind] = dict(frame_info(TREE_FRAME), sheet=sheet(frames, len(frames), "trees_%s.png" % kind),
                                      cols=len(frames), frames=len(frames))
    d = os.path.join(RENDER, "rocks", "rock")
    if os.path.isdir(d):
        # Loose rock picks a frame at random per hex, like the trees.
        frames = [load(os.path.join(d, f)) for f in sorted(os.listdir(d))]
        man["trees"]["rock"] = dict(frame_info(WALL_FRAME), sheet=sheet(frames, len(frames), "rocks.png"),
                                    cols=len(frames), frames=len(frames))
    names = [p for p in PROPS if os.path.isfile(os.path.join(RENDER, "props", p, "00.png"))]
    if names:
        frames = [load(os.path.join(RENDER, "props", p, "00.png"), outline=True) for p in names]
        sh = sheet(frames, len(frames), "props.png")
        for i, p in enumerate(names):
            man["props"][p] = dict(frame_info(WALL_FRAME), sheet=sh, cols=len(frames), frame=i, under=PROPS[p])
    fig = os.path.join(RENDER, "figure")
    if os.path.isdir(fig):
        man["figure"] = dict(frame_info(FIG_FRAME), cols=3, gear=GEAR, layers=layers(fig, "figure"))
    beasts = os.path.join(RENDER, "beasts")
    if os.path.isdir(beasts):
        man["beasts"] = {b: dict(frame_info(BEAST_FRAME), cols=3, layers=layers(os.path.join(beasts, b), b))
                         for b in sorted(os.listdir(beasts))}
    for g in ("grass", "meadow", "field", "road", "dirt", "mud", "floor_earth", "floor_wood", "water", "shallows", "snow", "cave", "thatch"):
        man["ground"][g] = ground(g)
    with open(os.path.join(OUT, "art.json"), "w", encoding="utf-8", newline="") as f:
        json.dump(man, f, indent=1)
    print("packed into", OUT)


if __name__ == "__main__":
    if not os.path.isdir(os.path.join(RENDER, "figure")):
        sys.exit("no renders in %s (run art/sprites.py first)" % RENDER)
    main()
