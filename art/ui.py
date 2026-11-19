"""Render the interface pieces into game/assets/ui/.

Everything is a height field lit like the sprites, from the upper left:
hammered iron plate, a bronze strip engraved with a La Tene wave tendril,
recessed wells with a riveted bezel, iron buttons, a round shield boss
(the Vachères shield: a round iron boss held by ten rivets) for End turn,
and bronze studs for action points. Bronze goes green, not brown, in its
cuts. Numpy and Pillow only:

    python art/ui.py
"""
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "ui")
SS = 3  # supersampling
LIGHT = np.array([-0.5, -0.7, 0.75])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
HALF = (LIGHT + np.array([0, 0, 1.0])) / np.linalg.norm(LIGHT + np.array([0, 0, 1.0]))


def col(h):
    return np.array([int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)])


IRON = col("#30353c")
IRON_LO = col("#22262b")
BRONZE = col("#c9a24c")
BRONZE_OLD = col("#9a8344")
VERDIGRIS = col("#4d8279")
WAX = col("#0d1013")


# --- Fields ---------------------------------------------------------------------

def grid(w, h):
    y, x = np.mgrid[0:h * SS, 0:w * SS].astype(float)
    return (x + 0.5) / SS, (y + 0.5) / SS  # in final pixels


def blur(a, sigma, wrap=False):
    """Gaussian blur by FFT; sigma in final pixels."""
    s = sigma * SS
    p = 0 if wrap else int(3 * s) + 1
    b = np.pad(a, p, mode="reflect") if p else a
    fy = np.fft.fftfreq(b.shape[0])[:, None]
    fx = np.fft.fftfreq(b.shape[1])[None, :]
    g = np.exp(-2 * (np.pi * s) ** 2 * (fx ** 2 + fy ** 2))
    r = np.real(np.fft.ifft2(np.fft.fft2(b) * g))
    return r[p:p + a.shape[0], p:p + a.shape[1]] if p else r


def noise(w, h, sigma, seed, wrap=True):
    rng = np.random.default_rng(seed)
    n = blur(rng.standard_normal((h * SS, w * SS)), sigma, wrap)
    return (n - n.mean()) / (n.std() + 1e-9)


def hammer(w, h, seed, density=1 / 90, rmin=4.0, rmax=9.0, depth=0.9, wrap=True):
    """Planished iron: overlapping shallow dents, each a paraboloid."""
    X, Y = grid(w, h)
    rng = np.random.default_rng(seed)
    out = np.zeros_like(X)
    for _ in range(int(w * h * density)):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(rmin, rmax)
        d = depth * rng.uniform(0.6, 1.2)
        dx = X - cx
        dy = Y - cy
        if wrap:
            dx = (dx + w / 2) % w - w / 2
            dy = (dy + h / 2) % h - h / 2
        out = np.minimum(out, -d + d * (dx * dx + dy * dy) / (r * r))
    return out


def rrect(X, Y, x0, y0, x1, y1, r):
    """Signed distance to a rounded rectangle, negative inside."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    qx = np.abs(X - cx) - ((x1 - x0) / 2 - r)
    qy = np.abs(Y - cy) - ((y1 - y0) / 2 - r)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r


def ramp(d, width):
    """0 at the edge (d = 0), rising in a rounded profile to 1 at `width` inside."""
    t = np.clip(-d / width, 0, 1)
    return np.sqrt(1 - (1 - t) ** 2)


def cover(d):
    return np.clip(0.5 - d * SS, 0, 1)


def dome(X, Y, cx, cy, r, height):
    d2 = ((X - cx) ** 2 + (Y - cy) ** 2) / (r * r)
    return np.where(d2 < 1, height * np.sqrt(np.clip(1 - d2, 0, 1)) ** 0.8, 0)


# --- Lighting --------------------------------------------------------------------

def shade(h, alb, ks, shin, amb=0.42, kd=0.8, ao=1.6, spec_tint=None):
    gy, gx = np.gradient(h)
    nx, ny, nz = -gx * SS, -gy * SS, np.ones_like(h)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / n, ny / n, nz / n
    diff = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    spec = np.clip(nx * HALF[0] + ny * HALF[1] + nz * HALF[2], 0, 1) ** shin
    occ = np.clip(1 - ao * np.clip(blur(h, 2.0) - h, 0, None) / 2.5, 0.35, 1)
    if spec_tint is None:
        spec_tint = np.ones(3)
    rgb = alb * ((amb + kd * diff) * occ)[..., None]
    rgb += (ks * spec * occ)[..., None] * spec_tint
    return np.clip(rgb, 0, 1)


def mix(a, b, t):
    return a * (1 - t[..., None]) + b * t[..., None]


def save(name, rgb, alpha, w, h):
    a = (np.clip(alpha, 0, 1) * 255).astype(np.uint8)
    img = Image.fromarray(np.dstack([(np.clip(rgb, 0, 1) * 255).astype(np.uint8), a]), "RGBA")
    img = img.convert("RGBa").resize((w, h), Image.LANCZOS).convert("RGBA")
    os.makedirs(OUT, exist_ok=True)
    img.save(os.path.join(OUT, name + ".png"))
    print("ui", name, w, h)


# --- The wave tendril --------------------------------------------------------------

def tendril_mask(w, h, unit, y_mid, amp, r0, width, x_off=0.0, wrap=True):
    """A wave along the band; at every crest a tendril curls down under it,
    at every trough one curls up over it."""
    from PIL import ImageDraw
    W, H = w * SS, h * SS
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    lw = max(1, int(round(width * SS)))

    def line(pts):
        for shift in ((-w, 0, w) if wrap else (0,)):
            d.line([((x + shift) * SS, y * SS) for x, y in pts], fill=255, width=lw, joint="curve")

    xs = np.linspace(-unit, w + unit, int((w + 2 * unit) * 2))
    line([(x + x_off, y_mid - amp * np.cos(2 * np.pi * x / unit)) for x in xs])
    for k in range(-1, int(w / unit) + 2):
        for half, sgn in ((0.0, 1), (0.5, -1)):
            xc = (k + half) * unit + x_off
            cy = y_mid - sgn * amp + sgn * r0
            pts = []
            for t in np.linspace(0, 1.35 * 2 * np.pi, 80):
                r = r0 * np.exp(-0.5 * t / np.pi)
                a = -sgn * np.pi / 2 + sgn * t
                pts.append((xc + r * np.cos(a), cy + r * np.sin(a)))
            line(pts)
    m = np.asarray(img, dtype=float) / 255
    return blur(m, 0.35, wrap)


# --- Pieces ----------------------------------------------------------------------

def bar():
    """The interface bar. 352 wide: a 48 px cap each side around a 256 px
    center that tiles. 6 px of shadow, an 18 px bronze strip, the plate."""
    W, H, CAP, P = 352, 168, 48, 256
    TOP, BAND = 6, 20
    X, Y = grid(W, H)
    idx = ((np.arange(W * SS) - CAP * SS) % (P * SS))

    def tiled(field):
        return field[:, idx]

    ham = tiled(hammer(P, H, 7, density=1 / 260, rmin=8, rmax=17, depth=0.9))
    bham = tiled(hammer(P, H, 17, density=1 / 60, rmin=2.5, rmax=5, depth=0.25))
    pat = tiled(noise(P, H, 5, 19))
    grain = tiled(noise(P, H, 1.2, 8))
    mott = tiled(noise(P, H, 14, 9))
    scroll = tiled(tendril_mask(P, H, 64, TOP + BAND / 2, 4.4, 4.0, 1.5))
    band = (Y >= TOP) & (Y < TOP + BAND)
    plate = Y >= TOP + BAND
    # Heights: the strip stands proud, with rounded edges and the scroll cut
    # into it; the plate is hammered and bevelled at the ends and bottom.
    dband = np.maximum(TOP - Y, Y - (TOP + BAND))
    dplate = rrect(X, Y, 3, TOP + BAND, W - 3, H + 20, 6)
    h = np.zeros_like(X)
    yb = (Y - (TOP + BAND / 2)) / (BAND / 2)
    h += np.where(band, 4.0 * np.sqrt(np.clip(1 - yb ** 2, 0, 1)) - 1.6 * scroll + bham, 0)
    h += np.where(plate, 2.0 * ramp(dplate, 5.0) + ham * 0.5 + grain * 0.03, 0)
    # Iron rivets through the caps, and where the strip ends.
    for cx in (20, W - 20):
        for cy in (TOP + BAND + 22, H - 22):
            h += dome(X, Y, cx, cy, 4.2, 2.6)
        h += dome(X, Y, cx, TOP + BAND / 2, 3.4, 1.6)
    alb = mix(IRON, IRON_LO, np.clip(mott * 0.35 + 0.45, 0, 1))
    bronze = mix(BRONZE_OLD, BRONZE, np.clip(pat * 0.3 + 0.45, 0, 1)) * 0.86
    bronze = mix(bronze, VERDIGRIS, np.clip(scroll * 1.4, 0, 0.9))
    alb = np.where(band[..., None], bronze, alb)
    ks = np.where(band, 0.5, 0.2)
    sh = np.where(band, 24, 16)
    rgb = shade(h, alb, ks, sh, amb=np.where(band, 0.18, 0.42), kd=np.where(band, 0.7, 0.8), spec_tint=np.where(band[..., None], col("#ffe0a0"), col("#d8e0ea")))
    # A cut between strip and plate.
    groove = np.exp(-((Y - (TOP + BAND)) / 0.8) ** 2)
    rgb *= (1 - 0.7 * groove)[..., None]
    shadow = np.clip(Y / TOP, 0, 1) ** 2 * 0.55
    alpha = np.where(Y < TOP, shadow, 1.0)
    rgb = np.where((Y < TOP)[..., None], 0.0, rgb)
    save("bar", rgb, alpha, W, H)


def well(name="well", lit=False):
    """A recessed well with a raised iron bezel and a rivet in each corner;
    9-patch, margins 12. The floor is dark wax. lit: a brass bezel, for
    hover."""
    S = 48
    X, Y = grid(S, S)
    outer = rrect(X, Y, 0, 0, S, S, 5)
    inner = rrect(X, Y, 6, 6, S - 6, S - 6, 3)
    h = 1.8 * ramp(outer, 2.5) - 1.8 * ramp(inner, 2.0) * 1.6
    h += noise(S, S, 0.8, 3, wrap=False) * 0.05
    for cx in (3.2, S - 3.2):
        for cy in (3.2, S - 3.2):
            h += dome(X, Y, cx, cy, 2.0, 1.2)
    floor = inner < 0
    alb = np.where(floor[..., None], WAX, BRONZE * 0.85 if lit else IRON)
    rgb = shade(h, alb, np.where(floor, 0.08, 0.4 if lit else 0.25), 18, amb=0.5)
    # The floor sits in the bezel's shadow along the top and left.
    lip = np.clip(1 - (np.minimum(X - 6, Y - 6)) / 5, 0, 1) * floor
    rgb *= (1 - 0.45 * lip)[..., None]
    save(name, rgb, cover(outer), S, S)


def button(name, state):
    """An iron tab; 9-patch, margins 9. hover: brass rim; pressed: sunk;
    on: polished, for a toggle that's on; off: disabled."""
    W, H = 64, 32
    X, Y = grid(W, H)
    d = rrect(X, Y, 0.5, 0.5, W - 0.5, H - 0.5, 4)
    sunk = state == "pressed"
    h = (1.0 if sunk else 2.2) * ramp(d, 3.0) + hammer(W, H, 21, density=1 / 140, depth=0.25, wrap=False) * 0.4
    if sunk:
        h = -h
    base = {"normal": IRON, "hover": IRON * 1.12, "pressed": IRON_LO, "on": col("#3c4652"), "off": IRON_LO * 0.85}[state]
    alb = np.broadcast_to(base, X.shape + (3,)).copy()
    rim = (d > -1.6) & (d < 0)
    if state in ("hover", "on"):
        alb[rim] = BRONZE
    ks = 0.06 if state == "off" else (0.35 if state == "on" else 0.22)
    rgb = shade(h, alb, ks, 22, amb=0.38 if state == "off" else 0.45)
    if state == "on":
        glow = np.exp(-((d + 6) / 6) ** 2) * 0.25
        rgb += glow[..., None] * BRONZE
    save(name, rgb, cover(d), W, H)


def boss(name, state):
    """The round shield boss: a dome on a flange held by ten rivets."""
    S = 88
    X, Y = grid(S, S)
    c = S / 2
    r = np.hypot(X - c, Y - c)
    flange_r, dome_r = 42.0, 27.0
    t = np.clip(r / dome_r, 0, 1)
    h = np.where(r < dome_r, 9.0 * np.sqrt(1 - t ** 2) ** 0.9 + 1.5, 0)
    fl = np.clip((flange_r - r) / 3.0, 0, 1)
    h += np.where(r >= dome_r, 1.5 * np.sqrt(fl), 0)
    h += hammer(S, S, 31, density=1 / 70, rmin=3, rmax=6, depth=0.35, wrap=False) * 0.5
    for k in range(10):
        a = k * 2 * np.pi / 10 - np.pi / 2
        h += dome(X, Y, c + 34.5 * np.cos(a), c + 34.5 * np.sin(a), 3.0, 2.0)
    lit = state in ("ready", "hover", "pressed")
    base = IRON * (0.8 if state == "idle" else 1.15)
    alb = np.broadcast_to(base, X.shape + (3,)).copy()
    if lit:
        # Polished: the dome catches brass light at its rim.
        ring = np.exp(-((r - dome_r) / 2.2) ** 2)
        alb = mix(alb, BRONZE, ring * 0.9)
    if state == "pressed":
        h = h * 0.6
    ks = {"idle": 0.12, "ready": 0.5, "hover": 0.7, "pressed": 0.35}[state]
    rgb = shade(h, alb, ks, 26, amb=0.35 if state == "idle" else 0.45)
    if state == "hover":
        rgb += (np.exp(-((r - dome_r) / 6) ** 2) * 0.18)[..., None] * BRONZE
    save(name, rgb, np.clip((flange_r + 0.5 - r) * SS, 0, 1), S, S)


def stud(name, on):
    S = 18
    X, Y = grid(S, S)
    r = np.hypot(X - S / 2, Y - S / 2)
    h = dome(X, Y, S / 2, S / 2, 7.5, 4.0)
    alb = np.broadcast_to(BRONZE * 1.05 if on else IRON * 0.85, X.shape + (3,))
    rgb = shade(h, alb, 0.75 if on else 0.15, 30 if on else 14, amb=0.5 if on else 0.35)
    if on:
        rgb += (np.exp(-(r / 4.5) ** 2) * 0.15)[..., None] * col("#fff0c0")
    # Seated in a little socket: a dark ring around the stud.
    sock = np.exp(-((r - 7.8) / 0.9) ** 2)
    rgb *= (1 - 0.6 * sock)[..., None]
    save(name, rgb, np.clip((8.6 - r) * SS, 0, 1), S, S)


def panel():
    """Window plate; 9-patch, margins 20, the 120 px center tiles."""
    S, M = 160, 20
    P = S - 2 * M
    X, Y = grid(S, S)
    ix = (np.arange(S * SS) - M * SS) % (P * SS)
    ham = hammer(P, P, 41, depth=0.45)
    mott = noise(P, P, 16, 42)
    ham = ham[ix][:, ix]
    mott = mott[ix][:, ix]
    d = rrect(X, Y, 0.5, 0.5, S - 0.5, S - 0.5, 6)
    h = 2.4 * ramp(d, 5) + ham * 0.35
    rim = rrect(X, Y, 7, 7, S - 7, S - 7, 3)
    h -= 0.6 * np.exp(-(rim / 0.7) ** 2)  # an engraved line inside the edge
    for cx in (8.5, S - 8.5):
        for cy in (8.5, S - 8.5):
            h += dome(X, Y, cx, cy, 3.4, 2.2)
    alb = mix(col("#20242a"), col("#181b1f"), np.clip(mott * 0.3 + 0.5, 0, 1))
    rgb = shade(h, alb, 0.18, 18, amb=0.5)
    save("panel", rgb, cover(d), S, S)


if __name__ == "__main__":
    bar()
    well()
    well("well_hover", lit=True)
    for s in ("normal", "hover", "pressed", "on", "off"):
        button("btn_" + s, s)
    for s in ("idle", "ready", "hover", "pressed"):
        boss("boss_" + s, s)
    stud("stud_on", True)
    stud("stud_off", False)
    panel()
