"""Renders the game's sprites with Blender, headless.

    blender -b --factory-startup -P art/sprites.py -- <out_dir> [group,group...]

Groups: walls, trees, props, figure, or a single wall kind (wall_wood,
palisade, fence, rampart, wall_stone, door). Without a list, renders all.
Writes one PNG per frame into <out_dir>/<group>/; art/pack.py packs them
into sheets for the game.

The camera matches the game's projection exactly: orthographic, looking
north, tilted so the ground is squashed to 0.62 (Hex.SQUASH). One Blender
unit is one hex circumradius (Paint.HEX = 28 screen pixels). Everything is
rendered at twice screen size and drawn at half.
"""
import bpy, bmesh, math, random, sys, os
from mathutils import Vector, noise as mnoise

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(ARGS[0] if ARGS else "render")
ONLY = set(ARGS[1].split(",")) if len(ARGS) > 1 else None

PX = 56.0  # render pixels per unit (2 x 28)
ELEV = math.asin(0.62)
SQ3 = math.sqrt(3.0)
EDGE = SQ3 / 2.0  # center to edge midpoint


# --- Colors and materials ---------------------------------------------------

def C(h):
    """sRGB hex to linear RGB."""
    h = h.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def mat(name, col, col2=None, scale=6.0, rough=0.85, bump=0.25, metal=0.0, emit=None, coords="Object"):
    m = bpy.data.materials.new(name)
    N = m.node_tree.nodes
    L = m.node_tree.links
    b = N["Principled BSDF"]
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if col2 is None:
        b.inputs["Base Color"].default_value = (*C(col), 1)
    else:
        tc = N.new("ShaderNodeTexCoord")
        nz = N.new("ShaderNodeTexNoise")
        nz.inputs["Scale"].default_value = scale
        nz.inputs["Detail"].default_value = 6
        L.new(tc.outputs[coords], nz.inputs["Vector"])
        cr = N.new("ShaderNodeValToRGB")
        e = cr.color_ramp.elements
        e[0].position, e[0].color = 0.3, (*C(col), 1)
        e[1].position, e[1].color = 0.7, (*C(col2), 1)
        L.new(nz.outputs["Fac"], cr.inputs["Fac"])
        L.new(cr.outputs["Color"], b.inputs["Base Color"])
        if bump > 0:
            bp = N.new("ShaderNodeBump")
            bp.inputs["Strength"].default_value = bump
            L.new(nz.outputs["Fac"], bp.inputs["Height"])
            L.new(bp.outputs["Normal"], b.inputs["Normal"])
    if emit:
        b.inputs["Emission Color"].default_value = (*C(emit[0]), 1)
        b.inputs["Emission Strength"].default_value = emit[1]
    return m


def stone_mat(name, c1, c2, mortar, scale=3.0):
    """Dry-stone coursing on the X-Z plane of the object (for wall faces)."""
    m = bpy.data.materials.new(name)
    N = m.node_tree.nodes
    L = m.node_tree.links
    b = N["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.95
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    com = N.new("ShaderNodeCombineXYZ")
    L.new(tc.outputs["Object"], sep.inputs[0])
    L.new(sep.outputs["X"], com.inputs["X"])
    L.new(sep.outputs["Z"], com.inputs["Y"])
    L.new(sep.outputs["Y"], com.inputs["Z"])
    br = N.new("ShaderNodeTexBrick")
    br.inputs["Color1"].default_value = (*C(c1), 1)
    br.inputs["Color2"].default_value = (*C(c2), 1)
    br.inputs["Mortar"].default_value = (*C(mortar), 1)
    br.inputs["Scale"].default_value = scale
    br.inputs["Mortar Size"].default_value = 0.025
    br.inputs["Brick Width"].default_value = 0.6
    br.inputs["Row Height"].default_value = 0.22
    L.new(com.outputs[0], br.inputs["Vector"])
    L.new(br.outputs["Color"], b.inputs["Base Color"])
    bp = N.new("ShaderNodeBump")
    bp.inputs["Strength"].default_value = 0.5
    L.new(br.outputs["Fac"], bp.inputs["Height"])
    L.new(bp.outputs["Normal"], b.inputs["Normal"])
    return m


def emission(name, col):
    m = bpy.data.materials.new(name)
    N = m.node_tree.nodes
    L = m.node_tree.links
    for n in list(N):
        if n.type != "OUTPUT_MATERIAL":
            N.remove(n)
    e = N.new("ShaderNodeEmission")
    e.inputs["Color"].default_value = (*col, 1)
    e.inputs["Strength"].default_value = 1.0
    L.new(e.outputs[0], N["Material Output"].inputs["Surface"])
    return m


# --- Geometry helpers ---------------------------------------------------------

def _obj(name, bm, mats, smooth=False, parent=None, loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = loc
    ob.rotation_euler = rot
    ob.scale = scale
    return ob


def box(name, sx, sy, sz, m, top=None, x0=None, **kw):
    """Box standing on z=0. If x0 is given it spans x0..x0+sx, else centered."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x = v.co.x * sx + (x0 + sx / 2 if x0 is not None else 0)
        v.co.y *= sy
        v.co.z = (v.co.z + 0.5) * sz
    mats = [m]
    if top:
        mats.append(top)
        for f in bm.faces:
            if f.normal.z > 0.9:
                f.material_index = 1
    return _obj(name, bm, mats, **kw)


def pleat(bm, folds, depth):
    """Folds in hanging cloth: push the lowest ring of vertices in and out
    around the axis, so the folds fade toward the top."""
    if not folds:
        return
    zs = [v.co.z for v in bm.verts]
    lo, hi = min(zs), max(zs)
    for v in bm.verts:
        t = 1.0 - (v.co.z - lo) / max(1e-6, hi - lo)
        a = math.atan2(v.co.y, v.co.x)
        k = 1.0 + depth * t * math.cos(folds * a)
        v.co.x *= k
        v.co.y *= k


def cyl(name, r1, r2, h, m, seg=10, z0=0.0, smooth=True, top=None, folds=0, fold_depth=0.07, **kw):
    """Cylinder or cone along +Z from z0 to z0+h (negative h goes down)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=abs(h))
    for v in bm.verts:
        v.co.z = v.co.z * (1 if h > 0 else -1) + z0 + h / 2
    pleat(bm, folds, fold_depth)
    mats = [m]
    if top:
        mats.append(top)
        for f in bm.faces:
            if abs(f.normal.z) > 0.9:
                f.material_index = 1
    return _obj(name, bm, mats, smooth=smooth, **kw)


def ball(name, r, m, sub=2, smooth=True, **kw):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    return _obj(name, bm, [m], smooth=smooth, **kw)


def empty(name, parent=None, loc=(0, 0, 0), rot=(0, 0, 0)):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def dir_vec(d, length=1.0):
    a = math.radians(60 * d)
    return Vector((math.cos(a) * length, math.sin(a) * length, 0))


# --- Scene ---------------------------------------------------------------------

def new_scene(samples=48):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.render.film_transparent = True
    sc.render.filter_size = 1.2
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    w = bpy.data.worlds.new("w")
    sc.world = w
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*C("#7d8796"), 1)  # winter sky fill
    bg.inputs[1].default_value = 0.32
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.5
    sun.color = C("#fff0dc")
    sun.angle = math.radians(2)
    so = bpy.data.objects.new("sun", sun)
    sc.collection.objects.link(so)
    so.rotation_euler = Vector((0.55, 0.6, -1.05)).normalized().to_track_quat("-Z", "Y").to_euler()
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("cam", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    co.rotation_euler = (math.pi / 2 - ELEV, 0, 0)
    co.location = -Vector((0, math.cos(ELEV), -math.sin(ELEV))) * 40
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=30)
    pl = _obj("catcher", bm, [mat("ground", "#808080")])
    pl.is_shadow_catcher = True
    return sc


def frame(w, h, foot):
    """Canvas of w x h screen pixels with the hex center at (w/2, h - foot)."""
    sc = bpy.context.scene
    sc.render.resolution_x = w * 2
    sc.render.resolution_y = h * 2
    cam = sc.camera.data
    big = max(w, h)
    cam.ortho_scale = big * 2 / PX
    cam.shift_x = 0.0
    cam.shift_y = (h / 2 - foot) / big


def render(path):
    sc = bpy.context.scene
    sc.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)


def show(objs, on):
    for o in objs:
        o.hide_render = not on
        for ch in o.children_recursive:
            ch.hide_render = not on


# --- Walls ---------------------------------------------------------------------
# Each wall hex is one of 64 renders: a post at the center plus an arm toward
# every neighbor that continues the wall. Bit d of the frame number is set
# when the neighbor in Hex.DIRECTIONS[d] connects.

WALL_FRAME = (112, 120, 40)


def wall_wood():
    wood = mat("post", "#3e2c1c", "#54402a", scale=14)
    daub = mat("daub", "#8a7456", "#a89070", scale=3.5, bump=0.7)
    thatch = mat("thatch", "#6e5a34", "#8e7646", scale=26, bump=0.9)
    H = 1.3
    # Eaves cast no shadow: their shadow on the wall read as a row of windows.
    ceave = cyl("eave", 0.25, 0.25, 0.14, thatch, seg=10, z0=H + 0.03, smooth=False)
    ceave.visible_shadow = False
    center = [cyl("post", 0.11, 0.1, H, wood, seg=8), ceave]
    arms = []
    for d in range(6):
        e = empty("arm%d" % d, rot=(0, 0, math.radians(60 * d)))
        box("panel", EDGE, 0.2, H, daub, x0=0, parent=e)
        box("stud", 0.08, 0.24, H, wood, parent=e, loc=(0.45, 0, 0))
        box("sill", EDGE, 0.24, 0.12, wood, x0=0, parent=e)
        # The cut edge of the thatched roof, so a house reads as roofed
        # without hiding what is inside.
        # Each arm a hair higher than the last, so overlapping tops don't fight.
        ev = box("eave", EDGE, 0.5, 0.14, thatch, x0=0, parent=e, loc=(0, 0, H + d * 0.005))
        ev.visible_shadow = False
        arms.append(e)
    return center, arms


def palisade():
    wood = mat("stake", "#5a4128", "#7a5a38", scale=10)
    rnd = random.Random(7)
    center = [cyl("c", 0.1, 0.1, 1.9, wood, seg=7), cyl("ct", 0.1, 0.0, 0.25, wood, seg=7, z0=1.9)]
    arms = []
    for d in range(6):
        e = empty("arm%d" % d, rot=(0, 0, math.radians(60 * d)))
        x = 0.2
        while x < EDGE + 0.05:
            h = 1.7 + rnd.random() * 0.35
            cyl("s", 0.09, 0.085, h, wood, seg=7, parent=e, loc=(x, rnd.uniform(-0.02, 0.02), 0))
            cyl("t", 0.085, 0.0, 0.22, wood, seg=7, parent=e, loc=(x, 0, h))
            x += 0.19
        box("rail", EDGE, 0.06, 0.07, wood, x0=0, parent=e, loc=(0, -0.1, 1.2))
        arms.append(e)
    return center, arms


def fence():
    wood = mat("fence", "#6a5233", "#84683f", scale=10)
    center = [cyl("p", 0.06, 0.05, 0.75, wood, seg=6)]
    arms = []
    for d in range(6):
        e = empty("arm%d" % d, rot=(0, 0, math.radians(60 * d)))
        for z in (0.35, 0.62):
            box("rail", EDGE, 0.05, 0.06, wood, x0=0, parent=e, loc=(0, 0, z))
        arms.append(e)
    return center, arms


def rampart():
    """Murus gallicus: dry-stone faces with timber beam ends, earth core,
    and a wooden breastwork on top."""
    stone = stone_mat("stone", "#a49c88", "#8c8472", "#5a5040", scale=3.2)
    earth = mat("earth", "#5a5a32", "#6b5a3a", scale=4)
    beam = mat("beam", "#5a4630", "#6a5238", scale=12)
    wood = mat("stake", "#5a4128", "#76583a", scale=10)
    H, W = 1.25, 1.15
    center = [cyl("core", W / 2, W / 2, H, stone, seg=12, smooth=False, top=earth),
              cyl("cs", 0.07, 0.07, 0.68, wood, seg=6, z0=H), cyl("ct", 0.07, 0.0, 0.15, wood, seg=6, z0=H + 0.68)]
    rnd = random.Random(3)
    arms = []
    for d in range(6):
        e = empty("arm%d" % d, rot=(0, 0, math.radians(60 * d)))
        box("wall", EDGE + 0.02, W, H + d * 0.004, stone, top=earth, x0=0, parent=e)
        for z in (0.3, 0.75):
            for x in (0.2, 0.6):
                for side in (-1, 1):
                    box("b", 0.1, 0.06, 0.1, beam, parent=e, loc=(x + rnd.uniform(-0.05, 0.05), side * (W / 2 + 0.02), z))
        x = 0.16
        while x < EDGE:
            h = 0.6 + rnd.random() * 0.15
            # On the centerline, so the breastwork stays one line whichever
            # way the arms point.
            cyl("s", 0.07, 0.07, h, wood, seg=6, parent=e, loc=(x, 0, H))
            cyl("t", 0.07, 0.0, 0.15, wood, seg=6, parent=e, loc=(x, 0, H + h))
            x += 0.16
        arms.append(e)
    return center, arms


def wall_stone():
    stone = stone_mat("stone", "#9c9482", "#8a826e", "#4e463a", scale=4)
    cap = mat("cap", "#6e6656", "#7c7462", scale=8)
    H, W = 1.4, 0.45
    center = [cyl("core", W / 2, W / 2, H, stone, seg=10, smooth=False, top=cap)]
    arms = []
    for d in range(6):
        e = empty("arm%d" % d, rot=(0, 0, math.radians(60 * d)))
        box("wall", EDGE + 0.02, W, H, stone, top=cap, x0=0, parent=e)
        arms.append(e)
    return center, arms


# --- Rock --------------------------------------------------------------------------
# Cliffs and cave walls join like walls (a mass at the center and one toward
# each rocky neighbor); loose limestone is a cluster, picked at random like
# the trees.

def boulder(name, r, m, seed, sx=1.0, sy=1.0, sz=1.0, **kw):
    """A faceted lump: an icosphere pushed about by noise."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=r)
    off = Vector((rnd.uniform(0, 50), rnd.uniform(0, 50), rnd.uniform(0, 50)))
    for v in bm.verts:
        n = mnoise.noise(v.co * (1.6 / r) + off)
        v.co *= 1.0 + 0.28 * n + rnd.uniform(-0.05, 0.05)
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
        if v.co.z < -r * 0.15:
            v.co.z = -r * 0.15
    return _obj(name, bm, [m], smooth=False, **kw)


def rock_mat(name, c1, c2):
    return mat(name, c1, c2, scale=3.5, bump=0.6, rough=0.9)


def rock_mass(m, seed, H):
    rnd = random.Random(seed)
    center = [boulder("core", 0.6, m, seed, sz=H / 1.25, loc=(0, 0, 0.12))]
    arms = []
    for d in range(6):
        e = empty("arm%d" % d, rot=(0, 0, math.radians(60 * d)))
        for k, x in enumerate((0.42, 0.78)):
            h = H * rnd.uniform(0.75, 1.0)
            boulder("b", rnd.uniform(0.44, 0.52), m, seed * 31 + d * 7 + k, sz=h / 1.05,
                    parent=e, loc=(x, rnd.uniform(-0.08, 0.08), 0.1))
        arms.append(e)
    return center, arms


def cliff():
    return rock_mass(rock_mat("limestone", "#a49e8c", "#c2bba6"), 5, 1.7)


def cave_wall():
    return rock_mass(rock_mat("caverock", "#3e3832", "#554c42"), 9, 1.8)


def rock_cluster(seed):
    m = rock_mat("fieldstone", "#5a564c", "#6e685a")
    rnd = random.Random(seed)
    # A squat main stone with a lean, and a couple of smaller ones at its foot.
    boulder("big", rnd.uniform(0.5, 0.6), m, seed, sx=rnd.uniform(1.0, 1.3), sz=rnd.uniform(0.85, 1.15),
            loc=(0, 0, 0.0), rot=(rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), rnd.uniform(0, 3.1)))
    for i in range(rnd.randint(2, 3)):
        a = rnd.uniform(0, 2 * math.pi)
        r = rnd.uniform(0.5, 0.68)
        boulder("small", rnd.uniform(0.16, 0.28), m, seed + i * 13, sz=rnd.uniform(0.6, 0.9),
                loc=(math.cos(a) * r, math.sin(a) * r, 0.0))


def render_rocks():
    for i in range(4):
        new_scene(32)
        frame(*WALL_FRAME)
        rock_cluster(23 + i * 11)
        render(os.path.join(OUT, "rocks", "rock", "%02d.png" % i))


def render_walls():
    kinds = [("wall_wood", wall_wood), ("palisade", palisade), ("fence", fence),
             ("rampart", rampart), ("wall_stone", wall_stone), ("cliff", cliff), ("cave_wall", cave_wall)]
    for name, build in kinds:
        if ONLY and "walls" not in ONLY and name not in ONLY:
            continue
        new_scene(32)
        frame(*WALL_FRAME)
        center, arms = build()
        for mask in range(64):
            for d in range(6):
                show([arms[d]], bool(mask & (1 << d)))
            render(os.path.join(OUT, "walls", name, "%02d.png" % mask))
    if ONLY and "walls" not in ONLY and "door" not in ONLY:
        return
    # Doorways: a post at each edge where a wall meets the door, and a lintel.
    new_scene(32)
    frame(*WALL_FRAME)
    wood = mat("post", "#4a3522", "#5e4630", scale=14)
    arms = []
    for d in range(6):
        e = empty("arm%d" % d, rot=(0, 0, math.radians(60 * d)))
        cyl("post", 0.09, 0.09, 1.42, wood, seg=8, parent=e, loc=(EDGE - 0.08, 0, 0))
        box("lintel", EDGE, 0.2, 0.1, wood, x0=0, parent=e, loc=(0, 0, 1.35))
        arms.append(e)
    for mask in range(64):
        for d in range(6):
            show([arms[d]], bool(mask & (1 << d)))
        render(os.path.join(OUT, "walls", "door", "%02d.png" % mask))


# --- Trees and brush --------------------------------------------------------------

TREE_FRAME = (176, 176, 40)


def bare_oak(seed):
    """A winter oak: bare crooked branches, a few dead leaves hanging on."""
    rnd = random.Random(seed)
    bark = mat("bark", "#3b3026", "#55483a", scale=18, bump=0.5)
    leaf = mat("leaf", "#5e3e20", "#7a5228", scale=30)
    cu = bpy.data.curves.new("oak", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 1.0
    cu.bevel_resolution = 1
    cu.use_fill_caps = True
    tips = []

    def branch(p, d, length, r, depth):
        sp = cu.splines.new("POLY")
        n = 3
        sp.points.add(n - 1)
        pts = [p]
        for i in range(1, n):
            q = pts[-1] + d * (length / (n - 1))
            q += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 0.3))) * length * 0.12
            pts.append(q)
        for i, q in enumerate(pts):
            sp.points[i].co = (*q, 1)
            sp.points[i].radius = r * (1 - 0.35 * i / (n - 1))
        end = pts[-1]
        if depth == 0:
            tips.append(end)
            return
        kids = 2 if depth < 3 else rnd.choice([2, 3])
        for k in range(kids):
            a = rnd.uniform(0, math.tau)
            spread = rnd.uniform(0.5, 0.9)
            nd = (d * 0.9 + Vector((math.cos(a), math.sin(a), 0)) * spread + Vector((0, 0, 0.35))).normalized()
            branch(end, nd, length * rnd.uniform(0.62, 0.78), r * 0.62, depth - 1)

    trunk_h = rnd.uniform(1.0, 1.3)
    branch(Vector((0, 0, 0)), Vector((0, 0, 1)), trunk_h, 0.2, 0)
    tips.clear()
    for k in range(rnd.choice([3, 4])):
        a = k * math.tau / 4 + rnd.uniform(-0.4, 0.4)
        d = Vector((math.cos(a) * 0.7, math.sin(a) * 0.7, 1.0)).normalized()
        branch(Vector((0, 0, trunk_h)), d, rnd.uniform(0.8, 1.0), 0.13, 4)
    ob = bpy.data.objects.new("oak", cu)
    bpy.context.scene.collection.objects.link(ob)
    cu.materials.append(bark)
    for t in tips:
        if rnd.random() < 0.12:
            ball("leaves", rnd.uniform(0.05, 0.08), leaf, sub=1, smooth=False, loc=t, scale=(1, 1, 0.7))


def pine(seed):
    rnd = random.Random(seed)
    bark = mat("bark", "#3a2c20", "#4a3a2a", scale=14)
    ndl = mat("needles", "#22341f", "#34482c", scale=9, bump=0.6)
    h = rnd.uniform(3.4, 4.0)
    cyl("trunk", 0.12, 0.06, h * 0.5, bark, seg=7)
    tiers = 7
    for i in range(tiers):
        z = h * (0.18 + i * 0.11)
        r = (1.0 - i / tiers) * 0.9 + 0.12
        t = cyl("tier", r, 0.02, h * 0.26, ndl, seg=11, z0=z, smooth=False, rot=(rnd.uniform(-0.015, 0.015), rnd.uniform(-0.015, 0.015), rnd.uniform(0, 1)))
        # Ragged, drooping branch tips instead of a clean cone.
        for v in t.data.vertices:
            if v.co.z < z + 0.01 and v.co.length > 0.05:
                k = rnd.uniform(0.75, 1.2)
                v.co.x *= k
                v.co.y *= k
                v.co.z -= rnd.uniform(0.0, 0.15)


def bush(seed):
    rnd = random.Random(seed)
    m = mat("brush", "#38422a", "#52502e", scale=12, bump=0.6)
    twig = mat("twig", "#4a3a2a")
    for i in range(6):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(0, 0.45)
        ball("b", rnd.uniform(0.22, 0.32), m, sub=1, smooth=False, loc=(math.cos(a) * rr, math.sin(a) * rr, 0.15), scale=(1, 1, 0.75))
    for i in range(5):
        a = rnd.uniform(0, math.tau)
        cyl("tw", 0.015, 0.005, 0.7, twig, seg=4, loc=(math.cos(a) * 0.2, math.sin(a) * 0.2, 0.1), rot=(rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0))


def render_trees():
    for kind, build, n in [("tree", bare_oak, 3), ("pine", pine, 3), ("bush", bush, 3)]:
        for i in range(n):
            new_scene(48)
            frame(*TREE_FRAME)
            build(11 + i * 17)
            render(os.path.join(OUT, "trees", kind, "%02d.png" % i))


# --- Props: things standing in a hex -------------------------------------------------
# A hex is about 1 unit across its flats. People are drawn 1.3 times life
# size, so props are a little larger than life too, to sit beside them.
# Furniture follows docs/research/settlements-and-houses.md: low tables,
# straw pallets, clay-plate hearths with firedogs, wooden-hooped barrels.

def lathe(name, prof, m, seg=16, smooth=True, **kw):
    """A turned shape: prof is (radius, z) from the bottom up. A radius of 0
    closes the shape at that end."""
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        if r <= 0:
            rings.append([bm.verts.new((0, 0, z))])
            continue
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z))
                      for i in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            if len(a) == 1:
                bm.faces.new((a[0], b[i], b[j]))
            elif len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return _obj(name, bm, [m], smooth=smooth, **kw)


def rod(name, p, q, r, m, seg=6, **kw):
    """A round bar from point p to point q."""
    p, q = Vector(p), Vector(q)
    d = q - p
    rot = d.to_track_quat("Z", "Y").to_euler()
    return cyl(name, r, r, d.length, m, seg=seg, loc=p, rot=rot, **kw)


def wood_mats():
    return (mat("plank", "#6b4a2a", "#80603a", scale=14), mat("post", "#4a3420", "#5a4028", scale=14))


def clay_mat():
    return mat("clay", "#9a5a36", "#b06e46", scale=9, bump=0.3)


def sack(name, r, loc, m, rot=0.0):
    ball(name, r, m, sub=2, loc=loc, scale=(0.9, 0.8, 1.05), rot=(0, 0, rot))
    cyl(name + "_neck", r * 0.28, r * 0.18, r * 0.45, m, seg=8, loc=(loc[0], loc[1], loc[2] + r * 0.9))


def amphora(name, m, loc=(0, 0, 0), rot=(0, 0, 0), s=1.0, stop=None):
    """A Dressel 1A wine jar: spike toe, tall body, sharp shoulder, long neck,
    two straight handles; stop, a material, seals the mouth (pitch over the
    cork)."""
    e = empty(name, loc=loc, rot=rot)
    prof = [(0, 0), (0.035, 0.0), (0.035, 0.09), (0.07, 0.16), (0.13, 0.3), (0.155, 0.5), (0.155, 0.72),
            (0.14, 0.82), (0.06, 0.88), (0.05, 0.92), (0.048, 1.2), (0.07, 1.21), (0.07, 1.28), (0.04, 1.28), (0, 1.27)]
    lathe(name + "_body", [(r * s, z * s) for r, z in prof], m, seg=14, parent=e)
    for y in (0.085, -0.085):
        rod(name + "_handle", (0, y * s, 0.86 * s), (0, y * s, 1.19 * s), 0.016 * s, m, parent=e)
        rod(name + "_handle2", (0, y * s, 1.19 * s), (0, y * 0.5 * s, 1.2 * s), 0.016 * s, m, parent=e)
    if stop:
        cyl(name + "_stop", 0.075 * s, 0.06 * s, 0.05 * s, stop, seg=10, parent=e, loc=(0, 0, 1.26 * s))
    return e


def hearth():
    """A slightly sunk clay plate with a pair of iron firedogs, logs across
    them, a cauldron in the coals and a spit."""
    plate = mat("plate", "#8c6c4a", "#a2835e", scale=6, bump=0.4)
    sherd = clay_mat()
    ash = mat("ash", "#3a3430", "#5a524a", scale=20)
    ember = mat("ember", "#5a2a10", emit=("#ff7a28", 6.0))
    log = mat("log", "#3a2818", "#4e3826", scale=12)
    iron = mat("iron", "#2c2a28", "#3c3834", scale=30, metal=0.5, rough=0.6)
    meat = mat("meat", "#6a2e1e", "#8a4a2a", scale=20)
    rnd = random.Random(5)
    cyl("plate", 0.55, 0.55, 0.04, plate, seg=20)
    sherd = mat("sherd", "#6e4430", "#7e5038", scale=9)
    for i in range(16):
        a = i * math.tau / 16 + rnd.uniform(-0.1, 0.1)
        box("sherd", 0.12, 0.05, 0.02, sherd, loc=(math.cos(a) * 0.57, math.sin(a) * 0.57, 0.0), rot=(0, 0, a + math.pi / 2))
    cyl("ash", 0.36, 0.36, 0.02, ash, seg=14, z0=0.04)
    ball("embers", 0.17, ember, sub=1, smooth=False, loc=(0, 0, 0.04), scale=(1.5, 1.3, 0.45))
    # Two firedogs, the bars running back to front; the front uprights end in
    # small horned heads.
    for x in (-0.2, 0.2):
        box("bar", 0.035, 0.62, 0.035, iron, loc=(x, 0, 0.1))
        for y in (-0.3, 0.3):
            box("foot", 0.12, 0.03, 0.1, iron, loc=(x, y, 0.0))
        rod("upright", (x, -0.3, 0.1), (x, -0.3, 0.42), 0.022, iron)
        ball("head", 0.04, iron, sub=1, loc=(x, -0.31, 0.44), scale=(1, 1.3, 1))
        for s in (1, -1):
            rod("horn", (x, -0.31, 0.47), (x + s * 0.05, -0.33, 0.53), 0.01, iron)
    for i, y in enumerate((-0.12, 0.02, 0.16)):
        cyl("log", 0.05, 0.045, 0.6, log, seg=7, loc=(-0.3, y, 0.16 + 0.02 * i), rot=(0, math.radians(90), rnd.uniform(-0.15, 0.15)))
    # The spit across the horned uprights, a joint of meat on it.
    rod("spit", (-0.3, -0.31, 0.4), (0.32, -0.31, 0.4), 0.012, iron)
    ball("joint", 0.09, meat, sub=2, loc=(0.02, -0.31, 0.38), scale=(1.4, 0.9, 0.9))
    # The cauldron sits in the coals at the back.
    lathe("cauldron", [(0, 0.06), (0.1, 0.07), (0.17, 0.14), (0.19, 0.24), (0.17, 0.32), (0.18, 0.34), (0.15, 0.34),
                       (0.14, 0.3)], iron, seg=16, loc=(0.05, 0.32, 0))
    rod("bail", (-0.12, 0.32, 0.33), (0.05, 0.32, 0.5), 0.008, iron)
    rod("bail2", (0.05, 0.32, 0.5), (0.22, 0.32, 0.33), 0.008, iron)
    lamp = bpy.data.lights.new("fire", "POINT")
    lamp.energy = 40
    lamp.color = C("#ff9a50")
    lamp.use_shadow = False
    lo = bpy.data.objects.new("fire", lamp)
    lo.location = (0, 0, 0.4)
    bpy.context.scene.collection.objects.link(lo)


def bed():
    """A straw pallet on the floor: straw, a linen mattress, a wool blanket
    and a sheepskin. No frame."""
    straw = mat("straw", "#9c8a55", "#b8a46a", scale=20, bump=0.8)
    linen = mat("linen", "#bdb294", "#cfc6aa", scale=8, bump=0.3)
    wool = mat("wool", "#5e3e30", "#74503a", scale=10, bump=0.4)
    fleece = mat("fleece", "#b8ac90", "#d2c8ae", scale=40, bump=1.0)
    rnd = random.Random(9)
    for i in range(14):
        ball("straw", rnd.uniform(0.12, 0.18), straw, sub=1, smooth=False,
             loc=(rnd.uniform(-0.6, 0.6), rnd.uniform(-0.35, 0.35), 0.0), scale=(1.6, 1.2, 0.35))
    ball("mattress", 0.5, linen, sub=3, loc=(0, 0, 0.1), scale=(1.25, 0.66, 0.16))
    ball("pillow", 0.18, linen, sub=2, loc=(-0.45, 0, 0.2), scale=(0.8, 1.4, 0.45))
    box("blanket", 0.7, 0.72, 0.05, wool, loc=(0.2, 0, 0.13), rot=(0, -0.04, 0.04))
    ball("fold", 0.06, wool, sub=1, loc=(-0.15, 0, 0.17), scale=(0.8, 6.0, 0.8))
    ball("sheepskin", 0.3, fleece, sub=2, loc=(0.25, -0.5, 0.0), scale=(1.3, 0.75, 0.12), rot=(0, 0, 0.2))


def table():
    """A low table, seated at on skins on the floor."""
    w, p = wood_mats()
    fur = mat("skin", "#5a4632", "#7a6046", scale=40, bump=1.0, rough=0.95)
    clay = clay_mat()
    bread = mat("bread", "#8a6232", "#a07a42", scale=14, bump=0.6)
    box("top", 1.1, 0.6, 0.07, w, loc=(0, 0, 0.36))
    for x in (-0.44, 0.44):
        for y in (-0.22, 0.22):
            box("leg", 0.08, 0.08, 0.36, p, loc=(x, y, 0))
    for y, r in ((-0.55, 0.15), (0.55, -0.1)):
        ball("skin", 0.34, fur, sub=2, loc=(0.05, y, 0.0), scale=(1.4, 0.6, 0.08), rot=(0, 0, r))
    lathe("bowl", [(0, 0.43), (0.06, 0.43), (0.12, 0.47), (0.13, 0.5), (0.11, 0.5), (0.05, 0.46), (0, 0.46)], p, seg=12,
          loc=(0.22, 0.05, 0))
    lathe("jug", [(0, 0.43), (0.07, 0.43), (0.1, 0.52), (0.09, 0.6), (0.045, 0.66), (0.05, 0.7), (0.035, 0.7), (0, 0.69)],
          clay, seg=12, loc=(-0.25, -0.08, 0))
    ball("loaf", 0.1, bread, sub=2, loc=(0.0, 0.12, 0.44), scale=(1.2, 1.0, 0.55))


def crate():
    """Household stores: a barrel bound with wooden hoops, a storage jar,
    sacks of grain."""
    w = mat("staves", "#6a4a2c", "#7d5d36", scale=16)
    withy = mat("withy", "#8a6a40", "#9c7a4a", scale=30)
    sackm = mat("sack", "#8a7a58", "#9c8c66", scale=14, bump=0.5)
    clay = clay_mat()
    lathe("barrel", [(0, 0), (0.24, 0), (0.29, 0.2), (0.3, 0.38), (0.29, 0.56), (0.24, 0.76), (0, 0.76)], w, seg=14,
          loc=(-0.28, 0.18, 0))
    for z, r in ((0.08, 0.265), (0.16, 0.285), (0.6, 0.285), (0.68, 0.265)):
        cyl("hoop", r, r, 0.035, withy, seg=14, loc=(-0.28, 0.18, z))
    lathe("dolium", [(0, 0), (0.13, 0), (0.24, 0.15), (0.28, 0.35), (0.24, 0.58), (0.13, 0.66), (0.15, 0.7), (0.11, 0.7),
                     (0, 0.66)], clay, seg=16, loc=(0.3, 0.25, 0))
    sack("sack", 0.26, (0.22, -0.25, 0.18), sackm, 0.4)
    sack("sack2", 0.21, (-0.22, -0.3, 0.14), sackm, -0.3)


def altar():
    st = mat("st", "#8e8a7c", "#aaa596", scale=3, bump=0.8)
    box("altar", 0.9, 0.6, 0.65, st, rot=(0, 0, 0.15))
    box("slab", 1.05, 0.72, 0.1, mat("slab", "#8c887a", "#a09c8c", scale=6), loc=(0, 0, 0.65))


def stall():
    """A market stall: a board on trestles under a striped awning, cloth,
    pots and apples for sale."""
    w, p = wood_mats()
    awn = [mat("awn", "#8e3a24", "#9c4630", scale=10, bump=0.2), mat("awn2", "#c4b48c", "#d2c29a", scale=10, bump=0.2)]
    box("board", 1.35, 0.55, 0.05, w, loc=(0, 0.05, 0.6))
    for x in (-0.55, 0.55):
        for y in (-0.15, 0.25):
            rod("trestle", (x, y, 0), (x + (0.06 if y > 0 else -0.06), y, 0.6), 0.03, p)
    for x in (-0.66, 0.66):
        rod("post", (x, 0.36, 0), (x, 0.36, 1.7), 0.04, p)
        rod("post", (x, -0.42, 0), (x, -0.42, 1.38), 0.035, p)
    rod("beam", (-0.7, 0.36, 1.68), (0.7, 0.36, 1.68), 0.035, p)
    ang = math.atan2(0.3, 0.8)
    for i in range(7):
        x = -0.72 + 0.1 + i * 0.205
        box("awning", 0.205, 0.88, 0.02, awn[i % 2], loc=(x, -0.03, 1.53), rot=(ang, 0, 0))
        box("valance", 0.205, 0.02, 0.12, awn[i % 2], loc=(x, -0.45, 1.27))
    # Goods: bolts of linen and wool, pots, a basket of apples.
    cloths = ["#c8bc9c", "#5a6e8a", "#8a3a2a", "#6a7a4a"]
    for i, col in enumerate(cloths):
        cyl("bolt", 0.07, 0.07, 0.45, mat("bolt%d" % i, col, scale=8), seg=10, loc=(-0.5 + i * 0.15, -0.05, 0.72),
            rot=(math.radians(90), 0, 0))
    clay = clay_mat()
    for i, (x, y) in enumerate(((0.25, 0.15), (0.38, 0.1), (0.3, -0.08))):
        lathe("pot", [(0, 0.65), (0.05, 0.65), (0.08, 0.72), (0.075, 0.8), (0.05, 0.84), (0.055, 0.86), (0, 0.86)], clay,
              seg=12, loc=(x, y, 0))
    basket = mat("basket", "#8a6a3a", "#a4824a", scale=40, bump=0.8)
    apple = mat("apple", "#8a2a1a", "#a8482a", scale=10)
    lathe("basket", [(0, 0.65), (0.11, 0.65), (0.14, 0.75), (0.12, 0.75), (0, 0.72)], basket, seg=12, loc=(0.52, -0.1, 0))
    for i in range(5):
        a = i * math.tau / 5
        ball("apple", 0.035, apple, sub=1, loc=(0.52 + math.cos(a) * 0.05, -0.1 + math.sin(a) * 0.05, 0.75))


def amphorae():
    """Italian wine in Dressel 1A jars: three standing in the sand, leaning
    together, one on its side."""
    # Campanian brick-red fabric, gone dull with handling, mouths sealed
    # with black pitch.
    clay = mat("amph", "#7a4632", "#8e5640", scale=7, bump=0.45, rough=0.85)
    pitch = mat("pitch", "#1c1612", rough=0.3)
    sand = mat("sand", "#5e5442", "#6c624e", scale=10, bump=0.5)
    ball("sand", 0.5, sand, sub=2, scale=(1.2, 0.9, 0.08))
    for i, (x, y, tx, ty) in enumerate(((-0.25, 0.1, 0.12, 0), (0.05, 0.22, 0, 0.08), (0.28, 0.05, -0.12, 0.05))):
        amphora("amph%d" % i, clay, loc=(x, y, -0.05), rot=(tx, ty, i * 1.3), s=1.05, stop=pitch)
    amphora("lying", clay, loc=(-0.5, -0.35, 0.16), rot=(0, math.radians(84), 0.3), s=1.0, stop=pitch)


def loom():
    """A warp-weighted loom leaning on its uprights: linen half woven, the
    warp hanging in bundles from clay weights."""
    w, p = wood_mats()
    linen = mat("weave", "#c4b896", "#d2c8a8", scale=60, bump=0.4)
    band = mat("band", "#7a3424", scale=20)
    clay = mat("weight", "#8a6448", "#9c7656", scale=10, bump=0.4)
    thread = mat("thread", "#cfc5a5")
    lean = math.radians(12)
    def at(z, x=0.0, dy=0.0):
        return (x, 0.12 + z * math.tan(lean) + dy, z)
    for x in (-0.62, 0.62):
        rod("upright", (x, 0.1, 0), at(2.0, x), 0.05, p)
    rod("beam", at(1.9, -0.72), at(1.9, 0.72), 0.06, p)
    rod("shed_rod", at(0.55, -0.66, -0.04), at(0.55, 0.66, -0.04), 0.025, p)
    rod("heddle", at(0.8, -0.7, -0.14), at(0.8, 0.7, -0.14), 0.025, p)
    for x in (-0.62, 0.62):
        rod("arm", at(0.8, x, 0), at(0.8, x, -0.16), 0.02, p)
    box("cloth", 1.08, 0.02, 0.85, linen, loc=at(1.02, 0, -0.03), rot=(-lean, 0, 0))
    box("cloth_band", 1.08, 0.025, 0.08, band, loc=at(1.1, 0, -0.035), rot=(-lean, 0, 0))
    box("cloth_band2", 1.08, 0.025, 0.04, band, loc=at(1.24, 0, -0.035), rot=(-lean, 0, 0))
    rnd = random.Random(3)
    for i in range(10):
        x = -0.48 + i * 0.107
        for k, dy in enumerate((-0.05, 0.05)):
            wz = 0.18 + 0.06 * k + rnd.uniform(-0.02, 0.02)
            top = at(1.02, x, -0.03)
            bot = (x, top[1] + dy - 0.04, wz + 0.12)
            rod("warp", top, bot, 0.012, thread, seg=4)
            cyl("weight", 0.055, 0.03, 0.13, clay, seg=4, loc=(x, bot[1], wz), rot=(0, 0, math.radians(45)))


def granary():
    """A four-post granary: wattle walls and a thatched roof raised on posts
    against damp and rats, a ladder to the door."""
    w, p = wood_mats()
    wattle = mat("wattle", "#7a6446", "#94805c", scale=22, bump=0.9)
    thatch = mat("thatch", "#6e5a34", "#8e7646", scale=26, bump=0.9)
    for x in (-0.42, 0.42):
        for y in (-0.42, 0.42):
            cyl("post", 0.07, 0.065, 0.72, p, seg=8, loc=(x, y, 0))
    box("floor", 1.05, 1.05, 0.08, w, loc=(0, 0, 0.7))
    box("walls", 0.95, 0.95, 0.72, wattle, loc=(0, 0, 0.78))
    box("door", 0.3, 0.02, 0.45, mat("dark", "#2a1e14"), loc=(0.15, -0.48, 0.82))
    roof = cyl("roof", 0.98, 0.0, 0.86, thatch, seg=4, smooth=False, loc=(0, 0, 1.46), rot=(0, 0, math.radians(45)))
    roof.scale = (1.0, 1.0, 1.0)
    for x in (0.0, 0.3):
        rod("rail", (x, -0.95, 0), (x, -0.5, 0.78), 0.022, p)
    for k in range(1, 4):
        t = k / 4
        rod("rung", (0, -0.95 + 0.45 * t, 0.78 * t), (0.3, -0.95 + 0.45 * t, 0.78 * t), 0.015, p)


def quern():
    """A rotary quern on a skin: the bedstone, the runner with its handle,
    grain in a sack, flour in a bowl."""
    stone = mat("lava", "#5a5650", "#6e6a62", scale=30, bump=1.0)
    fur = mat("skin", "#5a4632", "#7a6046", scale=40, bump=1.0, rough=0.95)
    sackm = mat("sack", "#8a7a58", "#9c8c66", scale=14, bump=0.5)
    flour = mat("flour", "#d8d0bc")
    w, p = wood_mats()
    ball("skin", 0.45, fur, sub=2, scale=(1.3, 1.0, 0.06))
    cyl("bedstone", 0.27, 0.25, 0.14, stone, seg=16, z0=0.02)
    lathe("runner", [(0.25, 0.16), (0.26, 0.2), (0.24, 0.27), (0.06, 0.32), (0.04, 0.32), (0.04, 0.26), (0, 0.26)],
          stone, seg=16)
    rod("handle", (0.18, 0, 0.24), (0.2, 0, 0.5), 0.025, p)
    ball("spill", 0.12, flour, sub=1, loc=(0, -0.24, 0.02), scale=(1.4, 0.8, 0.2))
    sack("sack", 0.22, (-0.42, 0.25, 0.16), sackm, 0.3)
    lathe("bowl", [(0, 0.0), (0.07, 0.0), (0.14, 0.05), (0.15, 0.09), (0.13, 0.09), (0.06, 0.04), (0, 0.04)], p, seg=12,
          loc=(0.38, -0.22, 0))
    ball("flour", 0.1, flour, sub=1, loc=(0.38, -0.22, 0.07), scale=(1.1, 1.1, 0.3))


def woodpile():
    """Split logs stacked end-on to the lane, a chopping block with the axe
    left in it."""
    bark = mat("bark", "#3e2e20", "#54402c", scale=20, bump=0.8)
    end = mat("endgrain", "#a07a4e", "#b48c5c", scale=30)
    iron = mat("iron", "#3a3836", metal=0.5, rough=0.5)
    rnd = random.Random(7)
    # Logs lie across the view: running toward the camera they would read
    # as upright sticks.
    for row, n in enumerate((5, 4, 3, 2)):
        for i in range(n):
            y = 0.22 + (i - (n - 1) / 2) * 0.15
            z = 0.075 + row * 0.13
            r = rnd.uniform(0.068, 0.08)
            cyl("log", r, r, 0.95, bark, seg=7, top=end, smooth=False,
                loc=(-0.55 + rnd.uniform(-0.05, 0.05), y, z), rot=(0, math.radians(90), rnd.uniform(-0.04, 0.04)))
    cyl("block", 0.2, 0.21, 0.38, bark, seg=10, top=end, loc=(0.42, -0.42, 0))
    rod("haft", (0.42, -0.42, 0.42), (0.62, -0.62, 0.75), 0.02, mat("haft", "#6a4a2a"))
    box("blade", 0.04, 0.16, 0.1, iron, loc=(0.42, -0.42, 0.33), rot=(0, 0, math.radians(-45)))
    for i in range(4):
        box("chip", 0.08, 0.04, 0.02, end, loc=(rnd.uniform(0.1, 0.6), rnd.uniform(-0.7, -0.2), 0), rot=(0, 0, rnd.uniform(0, 3)))


def cart():
    """A two-wheeled cart, shafts down, loaded with sacks."""
    w, p = wood_mats()
    iron = mat("iron", "#2e2c2a", metal=0.5, rough=0.6)
    sackm = mat("sack", "#8a7a58", "#9c8c66", scale=14, bump=0.5)
    for y in (-0.5, 0.5):
        torus("tyre", 0.42, 0.035, iron, seg=24, rseg=6, loc=(0, y, 0.44), rot=(math.radians(90), 0, 0))
        torus("felloe", 0.38, 0.04, p, seg=24, rseg=6, loc=(0, y, 0.44), rot=(math.radians(90), 0, 0))
        cyl("hub", 0.07, 0.07, 0.2, p, seg=10, loc=(0, y - 0.1, 0.44), rot=(math.radians(-90), 0, 0))
        for k in range(10):
            a = k * math.tau / 10
            rod("spoke", (0, y, 0.44), (math.cos(a) * 0.38, y, 0.44 + math.sin(a) * 0.38), 0.018, p)
    rod("axle", (0, -0.6, 0.44), (0, 0.6, 0.44), 0.04, p)
    box("bed", 1.25, 0.8, 0.06, w, loc=(-0.05, 0, 0.5))
    for y in (-0.38, 0.38):
        box("side", 1.25, 0.04, 0.2, w, loc=(-0.05, y, 0.56))
    box("tail", 0.04, 0.8, 0.2, w, loc=(-0.66, 0, 0.56))
    for y in (-0.3, 0.3):
        rod("shaft", (0.55, y, 0.53), (1.25, y * 0.85, 0.02), 0.03, p)
    for i, (x, y) in enumerate(((-0.35, -0.15), (-0.3, 0.18), (0.05, 0.0), (0.35, -0.12))):
        ball("sack", 0.2, sackm, sub=2, loc=(x, y, 0.68), scale=(1.2, 0.9, 0.75), rot=(0, 0, i * 0.7))


def tent():
    """A legion's leather tent (papilio): a ridge tent of sewn calfskin panels,
    door flaps tied back on the end toward the viewer, guy ropes and pegs."""
    leather = mat("leather", "#6e5236", "#82623e", scale=6, bump=0.3)
    seam = mat("seam", "#4a3622")
    rope = mat("rope", "#9a8a68")
    dark = mat("dark", "#1e1610")
    L, W, H, Hw = 0.72, 0.62, 1.25, 0.32
    bm = bmesh.new()
    v = {}
    for sy in (-1, 1):
        for sx in (-1, 1):
            v["g", sx, sy] = bm.verts.new((sx * W, sy * L, 0))
            v["w", sx, sy] = bm.verts.new((sx * W, sy * L, Hw))
        v["r", sy] = bm.verts.new((0, sy * (L + 0.04), H))
    for sx in (-1, 1):
        bm.faces.new((v["g", sx, -1], v["g", sx, 1], v["w", sx, 1], v["w", sx, -1]))
        bm.faces.new((v["w", sx, -1], v["w", sx, 1], v["r", 1], v["r", -1]))
    for sy in (-1, 1):
        bm.faces.new((v["g", -1, sy], v["g", 1, sy], v["w", 1, sy], v["r", sy], v["w", -1, sy]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    _obj("tent", bm, [leather])
    # Seams down the roof and the ridge pole's end.
    ang = math.atan2(H - Hw, W)
    for sx in (-1, 1):
        for y in (-0.36, 0.0, 0.36):
            rod("seam", (sx * W, y, Hw), (0, y, H), 0.012, seam, seg=4)
    rod("ridge", (0, -(L + 0.08), H), (0, L + 0.08, H), 0.025, seam)
    # The door: a dark opening on the near end with the flaps tied back.
    bm = bmesh.new()
    a, b, c = bm.verts.new((-0.28, -L - 0.005, 0)), bm.verts.new((0.28, -L - 0.005, 0)), bm.verts.new((0, -L - 0.005, 0.95))
    bm.faces.new((a, b, c))
    _obj("door", bm, [dark])
    for sx in (-1, 1):
        bm = bmesh.new()
        a = bm.verts.new((sx * 0.28, -L - 0.01, 0))
        b = bm.verts.new((sx * 0.5, -L - 0.08, 0))
        c = bm.verts.new((sx * 0.08, -L - 0.03, 0.85))
        bm.faces.new((a, b, c))
        _obj("flap", bm, [leather])
    for sx in (-1, 1):
        for sy in (-1, 1):
            rod("guy", (sx * W, sy * L * 0.7, Hw), (sx * (W + 0.32), sy * L * 0.7, 0.02), 0.008, rope, seg=4)
            box("peg", 0.03, 0.03, 0.08, seam, loc=(sx * (W + 0.32), sy * L * 0.7, 0))


def rubble():
    """What is left of a burnt house: fallen daub, footing stones, charred
    beams, a post still standing."""
    st = mat("st", "#8a8476", "#a49e8e", scale=4, bump=0.8)
    daub = mat("daub", "#8a7456", "#a89070", scale=3.5, bump=0.7)
    char = mat("char", "#1c1814", "#2e2620", scale=30, bump=0.9, rough=0.95)
    ash = mat("ash", "#4a4440", "#625a54", scale=12)
    rnd = random.Random(21)
    ball("ash", 0.6, ash, sub=2, scale=(1.3, 1.0, 0.07))
    for i in range(9):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(0.1, 0.65)
        ball("stone", rnd.uniform(0.07, 0.13), st, sub=1, smooth=False, loc=(math.cos(a) * r, math.sin(a) * r * 0.8, 0.02),
             scale=(1.3, 1.0, 0.7))
    for i in range(7):
        a, r = rnd.uniform(0, math.tau), rnd.uniform(0.1, 0.6)
        box("daub", rnd.uniform(0.12, 0.25), rnd.uniform(0.08, 0.16), 0.05, daub,
            loc=(math.cos(a) * r, math.sin(a) * r * 0.8, 0.0), rot=(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), rnd.uniform(0, 3)))
    for i in range(3):
        a = rnd.uniform(0, math.tau)
        box("beam", 0.95, 0.1, 0.1, char, loc=(math.cos(a) * 0.15, math.sin(a) * 0.15, 0.04 + 0.08 * i),
            rot=(0, rnd.uniform(-0.15, 0.15), rnd.uniform(0, 3)))
    cyl("post", 0.08, 0.06, 0.75, char, seg=7, smooth=False, loc=(-0.35, 0.3, 0), rot=(0.15, -0.1, 0))


def smithy():
    """A smith's corner: a clay forge with its fire showing, bellows, the
    anvil on a stump, a quenching trough."""
    clay = mat("forge", "#7a5a40", "#94704e", scale=6, bump=0.6)
    soot = mat("soot", "#2a2420", "#3a322a", scale=20)
    ember = mat("ember", "#5a2a10", emit=("#ff7a28", 5.0))
    iron = mat("iron", "#2c2a28", "#3e3a36", scale=30, metal=0.6, rough=0.45)
    bark = mat("bark", "#3e2e20", "#54402c", scale=20, bump=0.8)
    end = mat("endgrain", "#a07a4e", "#b48c5c", scale=30)
    hide = mat("bellows", "#5a4230", "#6e5038", scale=20, bump=0.5)
    w, p = wood_mats()
    water = mat("water", "#24343a", rough=0.1)
    # A waist-high forge hearth of clay over stones, its coal bed on top,
    # the bellows behind.
    box("forge", 0.62, 0.55, 0.42, clay, loc=(-0.3, 0.22, 0))
    box("rim", 0.62, 0.55, 0.05, soot, loc=(-0.3, 0.22, 0.42))
    # A bed of black charcoal with the heat showing through it in lumps,
    # not one glowing mound.
    coal = mat("coal", "#1a1612", "#2a2420", scale=40, bump=0.8)
    ball("coalbed", 0.2, coal, sub=1, smooth=False, loc=(-0.3, 0.2, 0.44), scale=(1.15, 1.0, 0.22))
    for i, (dx, dy) in enumerate(((-0.06, 0.03), (0.05, -0.04), (0.0, 0.08), (0.08, 0.06), (-0.09, -0.05))):
        ball("ember", 0.045 + 0.01 * (i % 2), ember, sub=1, smooth=False,
             loc=(-0.3 + dx, 0.2 + dy, 0.47), scale=(1, 1, 0.6))
    for s in (1, -1):
        ball("bellows", 0.13, hide, sub=2, loc=(-0.3 + s * 0.13, 0.62, 0.5), scale=(0.8, 1.4, 0.45))
    rod("nozzle", (-0.3, 0.5, 0.48), (-0.3, 0.32, 0.46), 0.025, iron)
    cyl("block", 0.19, 0.21, 0.42, bark, seg=10, top=end, loc=(0.25, -0.15, 0))
    box("anvil", 0.26, 0.13, 0.11, iron, loc=(0.25, -0.15, 0.42))
    cyl("horn", 0.05, 0.0, 0.14, iron, seg=6, loc=(0.38, -0.15, 0.49), rot=(0, math.radians(90), 0))
    rod("hammer_haft", (0.12, -0.25, 0.53), (0.0, -0.4, 0.55), 0.015, p)
    box("hammer_head", 0.06, 0.05, 0.05, iron, loc=(0.13, -0.24, 0.53))
    rod("tongs", (0.42, -0.3, 0.0), (0.36, -0.22, 0.45), 0.012, iron)
    rod("tongs2", (0.45, -0.28, 0.0), (0.37, -0.22, 0.45), 0.012, iron)
    box("trough", 0.5, 0.25, 0.2, w, loc=(0.35, 0.35, 0))
    box("water", 0.44, 0.19, 0.01, water, loc=(0.35, 0.35, 0.19))
    lamp = bpy.data.lights.new("fire", "POINT")
    lamp.energy = 25
    lamp.color = C("#ff9a50")
    lamp.use_shadow = False
    lo = bpy.data.objects.new("fire", lamp)
    lo.location = (-0.3, 0.1, 0.7)
    bpy.context.scene.collection.objects.link(lo)


PROP_BUILDERS = [("hearth", hearth), ("bed", bed), ("table", table), ("crate", crate), ("altar", altar),
                 ("stall", stall), ("amphorae", amphorae), ("loom", loom), ("granary", granary), ("quern", quern),
                 ("woodpile", woodpile), ("cart", cart), ("tent", tent), ("rubble", rubble), ("smithy", smithy)]


def render_props():
    for name, build in PROP_BUILDERS:
        if ONLY and "props" not in ONLY and name not in ONLY:
            continue
        new_scene(48)
        frame(*WALL_FRAME)
        build()
        render(os.path.join(OUT, "props", name, "00.png"))


# --- The figure --------------------------------------------------------------------------
# One body rendered in six facings and three frames (stand, stride left,
# stride right), plus lying down. Tunic, trousers, hair and shield are
# rendered neutral gray and recolored in the game from each NPC's look; a
# second render of flat colors (the mask) says which pixel is which.

FIG_FRAME = (108, 120, 22)
FIG_SCALE = 1.3  # people are drawn larger than life, as in Fallout, so they read
NEUTRAL = "#9a9a9a"
MASK_COLORS = {"tunic": (1, 0, 0), "trousers": (0, 1, 0), "hair": (0, 0, 1), "board": (1, 0, 0), "cloak": (1, 0, 0),
               "hide": (1, 0, 0), "hood": (1, 0, 0), "wrap": (1, 0, 0)}


def torus(name, R, r, m, seg=18, rseg=6, **kw):
    """A ring around Z, radius R, tube radius r."""
    bm = bmesh.new()
    rings = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        ring = []
        for j in range(rseg):
            b = 2 * math.pi * j / rseg
            rr = R + r * math.cos(b)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), r * math.sin(b))))
        rings.append(ring)
    for i in range(seg):
        for j in range(rseg):
            a, b = rings[i], rings[(i + 1) % seg]
            bm.faces.new((a[j], b[j], b[(j + 1) % rseg], a[(j + 1) % rseg]))
    return _obj(name, bm, [m], smooth=True, **kw)


def shell(name, r1, r2, h, m, keep, seg=20, z0=0.0, folds=0, fold_depth=0.07, **kw):
    """An open cone shell (no caps) keeping only vertices where keep(x, y)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=seg, radius1=r1, radius2=r2, depth=h)
    for v in bm.verts:
        v.co.z += z0 + h / 2
    pleat(bm, folds, fold_depth)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co.x, v.co.y)], context="VERTS")
    return _obj(name, bm, [m], smooth=True, **kw)


def half_ball(name, r, m, sz=1.0, **kw):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    for v in bm.verts:
        v.co.z *= sz
    return _obj(name, bm, [m], smooth=True, **kw)


def open_ball(name, r, m, keep, **kw):
    """A sphere with the vertices outside keep(x, y, z) cut away: a hood."""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=20, v_segments=12, radius=r)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co.x, v.co.y, v.co.z)], context="VERTS")
    ob = _obj(name, bm, [m], smooth=True, **kw)
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.02
    return ob


def curved_oval(name, a, b, R, m, nu=12, nv=24, **kw):
    """A shield board: an oval 2a wide and 2b tall, bent around a vertical
    axis of radius R so it bulges toward +y. Each row of the grid spans the
    oval's width at that height, so the outline is smooth."""
    bm = bmesh.new()
    rows = []
    for j in range(nv + 1):
        v = -b + 2 * b * j / nv
        hw = max(0.012, a * math.sqrt(max(0.0, 1 - (v / b) ** 2)))
        row = []
        for i in range(nu + 1):
            u = -hw + 2 * hw * i / nu
            t = u / R
            row.append(bm.verts.new((R * math.sin(t), R * math.cos(t) - R, v)))
        rows.append(row)
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    ob = _obj(name, bm, [m], smooth=True, **kw)
    sol = ob.modifiers.new("thick", "SOLIDIFY")
    sol.thickness = 0.035
    sol.offset = 0.0
    return ob


def pattern_mask():
    """Mask material for patterned cloth: red ground (channel 0) crossed by
    bands of green (channel 1) running across and down the cloth, a coarse
    check the game tints with a second color."""
    m = bpy.data.materials.new("check")
    N = m.node_tree.nodes
    L = m.node_tree.links
    for n in list(N):
        if n.type != "OUTPUT_MATERIAL":
            N.remove(n)
    tc = N.new("ShaderNodeTexCoord")
    sep = N.new("ShaderNodeSeparateXYZ")
    L.new(tc.outputs["Object"], sep.inputs[0])
    bands = []
    for axis in ("Y", "Z"):
        mul = N.new("ShaderNodeMath")
        mul.operation = "MULTIPLY"
        mul.inputs[1].default_value = 7.0
        L.new(sep.outputs[axis], mul.inputs[0])
        fr = N.new("ShaderNodeMath")
        fr.operation = "FRACT"
        L.new(mul.outputs[0], fr.inputs[0])
        lt = N.new("ShaderNodeMath")
        lt.operation = "LESS_THAN"
        lt.inputs[1].default_value = 0.28
        L.new(fr.outputs[0], lt.inputs[0])
        bands.append(lt)
    mx = N.new("ShaderNodeMath")
    mx.operation = "MAXIMUM"
    L.new(bands[0].outputs[0], mx.inputs[0])
    L.new(bands[1].outputs[0], mx.inputs[1])
    inv = N.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    L.new(mx.outputs[0], inv.inputs[1])
    rgb = N.new("ShaderNodeCombineColor")
    L.new(inv.outputs[0], rgb.inputs[0])
    L.new(mx.outputs[0], rgb.inputs[1])
    e = N.new("ShaderNodeEmission")
    L.new(rgb.outputs[0], e.inputs["Color"])
    L.new(e.outputs[0], N["Material Output"].inputs["Surface"])
    return m


class Figure:
    """People in gray. Three bodies share a head, arms and pose: a Gallic man
    (tunic and trousers), a woman (ankle-length dress) and a Roman (knee-length
    tunic, bare legs, caligae). Hair, beards, torcs and everything worn or held
    are layers of their own, so the game can stack any combination. Parts
    tagged in mask_parts are recolored in the game.

    Proportions follow docs/research/dress-and-arms.md, section 7: the body
    is about 1.94 units tall before FIG_SCALE."""

    def __init__(self):
        self.mask_parts = {}  # object -> mask key
        gray = mat("gray", NEUTRAL, "#a8a8a8", scale=22, bump=0.35)
        hairm = mat("hairgray", NEUTRAL, "#848484", scale=60, bump=0.8)
        skin = mat("skin", "#c99a74", "#b98a66", scale=8, rough=0.6, bump=0.1)
        leather = mat("leather", "#3e2a1a", "#55391f", scale=20)
        steel = mat("steel", "#b0b4b8", metal=0.85, rough=0.3)
        wood = mat("wood", "#7a5a36", "#8a6a40", scale=20)
        dark_wood = mat("dwood", "#4e3822", "#5e4428", scale=16)
        iron = mat("iron", "#4e4a44", metal=0.7, rough=0.5)
        dark_iron = mat("diron", "#3a3836", "#4a4642", metal=0.6, rough=0.55, scale=30)
        gold = mat("gold", "#c89a3a", metal=0.9, rough=0.3)
        bronze = mat("bronze", "#a87a3a", "#8a6230", metal=0.85, rough=0.35, scale=10)
        bone = mat("bone", "#d8ccb0", "#c4b494", scale=30, rough=0.5)
        self.root = root = empty("root")
        root.scale = (FIG_SCALE,) * 3
        self.body_sets = {"body": [], "body_f": [], "body_roman": []}
        self.items = {}

        def part(ob, key=None, bodies=("body", "body_f", "body_roman")):
            for b in bodies:
                self.body_sets[b].append(ob)
            if key:
                self.mask_parts[ob] = key
            return ob

        # --- Shared: head, neck, arms -----------------------------------------
        # Limbs have a joint in the middle (knees, elbows) so the walk can bend
        # them; pose() turns the empties. Bands of a darker gray (cuffs, hems,
        # leg bindings) recolor as a darker shade of the same cloth.
        eye = mat("eye", "#22160f", rough=0.5, bump=0.0)
        band = mat("band", "#6c6c6c", "#787878", scale=22, bump=0.35)
        self.hip, self.knee, self.sho, self.elbow = {}, {}, {}, {}
        for side, y in (("L", 0.105), ("R", -0.105)):
            self.hip[side] = empty("hip" + side, root, (0, y, 0.93))
            self.knee[side] = empty("knee" + side, self.hip[side], (0, 0, -0.45))
        part(cyl("neck", 0.064, 0.07, 0.17, skin, seg=8, z0=1.49, parent=root))
        part(ball("head", 0.155, skin, parent=root, loc=(0.015, 0, 1.775), scale=(0.95, 0.84, 1.06)))
        # A face that reads at a few pixels: a brow over two dark eyes, the
        # nose, a jaw.
        part(box("brow", 0.045, 0.19, 0.032, skin, parent=root, loc=(0.15, 0, 1.788)))
        for s in (1, -1):
            part(ball("eye", 0.021, eye, sub=1, parent=root, loc=(0.152, s * 0.05, 1.768), scale=(0.7, 1.35, 0.8)))
        part(box("nose", 0.034, 0.032, 0.054, skin, parent=root, loc=(0.16, 0, 1.714)))
        part(ball("jaw", 0.1, skin, parent=root, loc=(0.06, 0, 1.68), scale=(0.97, 1.05, 0.75)))
        part(ball("ears", 0.035, skin, sub=1, parent=root, loc=(-0.01, 0, 1.75), scale=(0.8, 4.2, 1.2)))
        G, F, R = ("body", "body_f"), ("body_f",), ("body_roman",)
        for side, y in (("L", 0.29), ("R", -0.29)):
            sh = empty("sho" + side, root, (0, y, 1.43), (math.radians(10 if side == "L" else -10), 0, 0))
            self.sho[side] = sh
            part(ball("shoulder", 0.084, gray, parent=sh, loc=(0, -0.025 if side == "L" else 0.025, 0.0), scale=(1, 0.9, 0.85)), "tunic")
            part(cyl("upper", 0.078, 0.066, -0.31, gray, seg=8, parent=sh), "tunic")
            el = empty("elbow" + side, sh, (0, 0, -0.31))
            self.elbow[side] = el
            # Gauls, men and women, in long winter sleeves with a cuff; the
            # Roman's short sleeve ends above the elbow.
            part(ball("elbowj", 0.067, gray, sub=1, parent=el), "tunic", G)
            part(cyl("fore", 0.066, 0.057, -0.24, gray, seg=8, parent=el), "tunic", G)
            part(cyl("cuff", 0.062, 0.06, -0.06, band, seg=8, z0=-0.23, parent=el), "tunic", G)
            part(cyl("hem", 0.07, 0.07, 0.05, band, seg=8, z0=0.02, parent=el), "tunic", R)
            part(ball("elbowj", 0.06, skin, sub=1, parent=el), None, R)
            part(cyl("fore", 0.06, 0.05, -0.29, skin, seg=8, parent=el), None, R)
            part(ball("hand", 0.06, skin, parent=el, loc=(0.012, 0, -0.335), scale=(1.12, 0.75, 1.3)))
        self.hand_r = empty("handR", self.elbow["R"], (0, 0, -0.33))
        self.hand_l = empty("handL", self.elbow["L"], (0, 0, -0.31))

        def leg(hp, kn, thigh_m, shin_m, key, bodies, tr=(0.105, 0.08), sr=(0.08, 0.062)):
            part(cyl("thigh", tr[0], tr[1], -0.45, thigh_m, seg=8, parent=hp), key, bodies)
            part(ball("kneej", tr[1], thigh_m, sub=1, parent=kn), key, bodies)
            part(cyl("shin", sr[0], sr[1], -0.38, shin_m, seg=8, parent=kn), key, bodies)

        # --- Gallic man: tunic to mid-thigh over trousers bound at the ankle,
        # low laced shoes (gallicae) ---------------------------------------------
        M = ("body",)
        for side, hp in self.hip.items():
            kn = self.knee[side]
            leg(hp, kn, gray, gray, "trousers", M)
            part(cyl("binding", 0.068, 0.065, -0.08, band, seg=8, z0=-0.3, parent=kn), "trousers", M)
            part(cyl("ankle", 0.064, 0.064, -0.06, leather, seg=8, z0=-0.37, parent=kn), None, M)
            part(box("foot", 0.22, 0.11, 0.075, leather, parent=kn, loc=(0.05, 0, -0.48)), None, M)
        part(cyl("skirt", 0.27, 0.245, 0.4, gray, seg=32, folds=8, fold_depth=0.1, z0=0.66, parent=root, scale=(0.8, 1.08, 1)), "tunic", M)
        part(cyl("hem", 0.275, 0.272, 0.055, band, seg=32, folds=8, fold_depth=0.105, z0=0.655, parent=root, scale=(0.8, 1.08, 1)), "tunic", M)

        # --- Roman: knee-length tunic, bare legs, open-work caligae -------------
        caliga = mat("caliga", "#2e2016", "#4a3020", scale=50, bump=0.6)
        for side, hp in self.hip.items():
            kn = self.knee[side]
            leg(hp, kn, skin, skin, None, R, tr=(0.088, 0.066), sr=(0.066, 0.052))
            part(cyl("strap", 0.06, 0.062, -0.12, caliga, seg=8, z0=-0.31, parent=kn), None, R)
            part(box("foot", 0.23, 0.115, 0.07, caliga, parent=kn, loc=(0.05, 0, -0.48)), None, R)
        part(cyl("skirt", 0.29, 0.245, 0.56, gray, seg=32, folds=8, fold_depth=0.1, z0=0.5, parent=root, scale=(0.8, 1.08, 1)), "tunic", R)
        part(cyl("hem", 0.295, 0.292, 0.05, band, seg=32, folds=8, fold_depth=0.105, z0=0.495, parent=root, scale=(0.8, 1.08, 1)), "tunic", R)

        # --- Woman: ankle-length belted dress over a sleeved undertunic, pinned
        # at both shoulders ------------------------------------------------------
        for side, hp in self.hip.items():
            kn = self.knee[side]
            leg(hp, kn, skin, skin, None, F, tr=(0.07, 0.058), sr=(0.058, 0.048))
            part(box("foot", 0.19, 0.095, 0.07, leather, parent=kn, loc=(0.04, 0, -0.48)), None, F)
        part(cyl("dress", 0.3, 0.215, 0.96, gray, seg=36, folds=9, fold_depth=0.12, z0=0.06, parent=root, scale=(0.8, 1.04, 1)), "tunic", F)
        part(cyl("hem", 0.305, 0.3, 0.06, band, seg=36, folds=9, fold_depth=0.125, z0=0.055, parent=root, scale=(0.8, 1.04, 1)), "tunic", F)
        part(cyl("torso", 0.21, 0.25, 0.5, gray, seg=14, z0=1.0, parent=root, scale=(0.76, 1.04, 1)), "tunic", F)
        part(ball("chest", 0.185, gray, parent=root, loc=(0.04, 0, 1.35), scale=(1.0, 1.3, 0.72)), "tunic", F)
        part(ball("yoke", 0.19, gray, parent=root, loc=(-0.01, 0, 1.43), scale=(0.7, 1.5, 0.42)), "tunic", F)
        part(cyl("belt", 0.222, 0.222, 0.06, leather, seg=14, z0=1.0, parent=root, scale=(0.8, 1.06, 1)), None, F)
        for s in (1, -1):
            part(ball("brooch", 0.032, bronze, sub=1, parent=root, loc=(0.1, s * 0.16, 1.49)), None, F)

        # The man's and the Roman's chest, shoulders and belt.
        MR = ("body", "body_roman")
        part(cyl("torso", 0.22, 0.275, 0.5, gray, seg=14, z0=1.0, parent=root, scale=(0.74, 1.1, 1)), "tunic", MR)
        part(ball("chest", 0.2, gray, parent=root, loc=(0.03, 0, 1.36), scale=(0.95, 1.35, 0.7)), "tunic", MR)
        part(ball("yoke", 0.2, gray, parent=root, loc=(-0.01, 0, 1.43), scale=(0.72, 1.55, 0.45)), "tunic", MR)
        part(ball("neckline", 0.05, skin, sub=1, parent=root, loc=(0.135, 0, 1.47), scale=(0.45, 0.9, 1.4)), None, MR)
        part(cyl("belt", 0.235, 0.235, 0.075, leather, seg=14, z0=0.99, parent=root, scale=(0.8, 1.1, 1)), None, MR)
        part(box("buckle", 0.03, 0.08, 0.06, bronze, parent=root, loc=(0.195, 0, 1.0)), None, MR)
        part(box("pouch", 0.09, 0.06, 0.11, leather, parent=root, loc=(0.1, 0.19, 0.88)), None, MR)

        # --- Hair (hair mask), each style its own layer --------------------------
        def layer(name):
            e = empty(name, root)
            self.items[name] = e
            return e

        def hair(e, ob):
            self.mask_parts[ob] = "hair"
            return ob

        e = layer("hair_short")  # Roman: cropped close
        hair(e, ball("cap", 0.158, hairm, parent=e, loc=(-0.03, 0, 1.8), scale=(1.0, 0.96, 0.76)))
        hair(e, ball("nape", 0.1, hairm, parent=e, loc=(-0.08, 0, 1.7), scale=(0.7, 1.15, 0.8)))

        e = layer("hair_long")  # most Gallic men: to the shoulders
        hair(e, ball("cap", 0.162, hairm, parent=e, loc=(-0.025, 0, 1.81), scale=(1.0, 0.98, 0.82)))
        hair(e, ball("back", 0.14, hairm, parent=e, loc=(-0.1, 0, 1.6), scale=(0.72, 1.2, 1.6)))
        for s in (1, -1):
            hair(e, ball("lock", 0.06, hairm, parent=e, loc=(-0.03, s * 0.13, 1.6), scale=(0.9, 0.75, 1.9)))

        e = layer("hair_swept")  # limed and combed back into a stiff mane
        hair(e, ball("cap", 0.168, hairm, parent=e, loc=(-0.04, 0, 1.84), scale=(1.02, 0.96, 0.78)))
        hair(e, ball("mane", 0.13, hairm, parent=e, loc=(-0.17, 0, 1.86), scale=(1.45, 0.9, 0.7),
                     rot=(0, math.radians(-18), 0)))
        hair(e, ball("nape", 0.11, hairm, parent=e, loc=(-0.1, 0, 1.66), scale=(0.7, 1.12, 1.0)))

        e = layer("hair_knot")  # Suebian: combed sideways, knotted on the right
        hair(e, ball("cap", 0.162, hairm, parent=e, loc=(-0.025, -0.01, 1.81), scale=(1.0, 0.98, 0.8)))
        hair(e, ball("back", 0.12, hairm, parent=e, loc=(-0.09, 0, 1.66), scale=(0.72, 1.15, 1.1)))
        hair(e, ball("knot", 0.072, hairm, parent=e, loc=(-0.03, -0.17, 1.86)))
        hair(e, ball("tail", 0.045, hairm, parent=e, loc=(-0.05, -0.2, 1.77), scale=(1, 0.8, 1.8)))

        e = layer("hair_braid")  # women: parted, one braid down the back
        hair(e, ball("cap", 0.16, hairm, parent=e, loc=(-0.025, 0, 1.81), scale=(1.0, 0.98, 0.82)))
        hair(e, ball("back", 0.12, hairm, parent=e, loc=(-0.1, 0, 1.66), scale=(0.72, 1.12, 1.15)))
        for k in range(7):
            hair(e, ball("plait", 0.048 - k * 0.003, hairm, sub=1, parent=e,
                         loc=(-0.17 - k * 0.012, 0, 1.6 - k * 0.07), scale=(0.9, 1, 1.2)))

        e = layer("hair_bun")  # older women: gathered in a knot at the back
        hair(e, ball("cap", 0.16, hairm, parent=e, loc=(-0.025, 0, 1.81), scale=(1.0, 0.98, 0.8)))
        hair(e, ball("bun", 0.085, hairm, parent=e, loc=(-0.16, 0, 1.76)))

        # Older and married women: a cloth wrapped over the hair and knotted
        # at the nape (Gallo-Roman reliefs; plausible, not proven).
        wrapm = mat("wrap", NEUTRAL, "#a4a4a4", scale=24, bump=0.4)
        e = layer("hair_wrap")
        for ob in (ball("wcap", 0.172, wrapm, parent=e, loc=(-0.035, 0, 1.815), scale=(1.0, 0.98, 0.84)),
                   ball("wback", 0.13, wrapm, parent=e, loc=(-0.11, 0, 1.69), scale=(0.72, 1.12, 1.0)),
                   ball("wknot", 0.07, wrapm, parent=e, loc=(-0.2, 0, 1.66), scale=(0.9, 1.1, 0.8)),
                   cyl("wtail", 0.045, 0.02, -0.2, wrapm, seg=8, z0=1.64, parent=e, loc=(-0.2, 0, 0))):
            self.mask_parts[ob] = "wrap"

        # --- Faces --------------------------------------------------------------
        def moustache(e):
            for s in (1, -1):
                hair(e, box("mous", 0.035, 0.07, 0.12, hairm, parent=e, loc=(0.145, s * 0.045, 1.64),
                            rot=(math.radians(s * 18), 0, 0)))

        e = layer("moustache")  # the noble fashion: long moustache, shaved cheeks
        moustache(e)
        e = layer("beard")
        moustache(e)
        hair(e, ball("beard", 0.1, hairm, parent=e, loc=(0.085, 0, 1.63), scale=(0.75, 1.15, 0.95)))
        for s in (1, -1):
            hair(e, ball("cheek", 0.05, hairm, sub=1, parent=e, loc=(0.06, s * 0.1, 1.7), scale=(0.8, 0.6, 1.4)))

        # --- Torcs ----------------------------------------------------------------
        for name, metal_ in (("torc_gold", gold), ("torc_bronze", bronze)):
            e = layer(name)
            torus("torc", 0.09, 0.02, metal_, parent=e, loc=(0.0, 0, 1.55), rot=(0, math.radians(-12), 0))
            for s in (1, -1):
                ball("terminal", 0.028, metal_, sub=1, parent=e, loc=(0.09, s * 0.035, 1.57))

        # --- Worn things -----------------------------------------------------------
        # Cloak: pinned on the right shoulder, the drape falling over the left
        # arm. In the mask it is checked (see pattern_mask).
        cloth = mat("cloak", NEUTRAL, "#a2a2a2", scale=14, bump=0.4)
        ck = layer("cloak")
        c = shell("cape", 0.42, 0.31, 0.95, cloth, lambda x, y: x < 0.04 + max(0.0, y) * 0.55, seg=48, folds=11, fold_depth=0.12, z0=0.52,
                  parent=ck, loc=(-0.06, 0, 0), scale=(0.62, 1.12, 1))
        self.mask_parts[c] = "cloak"
        c2 = torus("collar", 0.22, 0.05, cloth, parent=ck, loc=(-0.02, 0, 1.5), scale=(0.8, 1.2, 1))
        self.mask_parts[c2] = "cloak"
        ball("brooch", 0.04, bronze, sub=1, parent=ck, loc=(0.1, -0.2, 1.5))

        # Hide cape: what Germans wore instead of a cloak (Caesar IV.1, VI.21).
        fur = mat("fur", NEUTRAL, "#7a7a7a", scale=70, bump=1.0, rough=0.95)
        hd = layer("hide")
        c3 = shell("hide", 0.44, 0.3, 0.6, fur, lambda x, y: x < 0.08, seg=40, folds=7, fold_depth=0.07, z0=0.92, parent=hd,
                   loc=(-0.05, 0, 0), scale=(0.64, 1.14, 1))
        self.mask_parts[c3] = "hide"
        c4 = torus("ruff", 0.22, 0.07, fur, parent=hd, loc=(-0.02, 0, 1.5), scale=(0.82, 1.2, 1))
        self.mask_parts[c4] = "hide"

        # Hooded cape (cucullus): what commoners and travelers wear over the
        # tunic in winter, a short cape with the hood up.
        hoodm = mat("hood", NEUTRAL, "#9c9c9c", scale=18, bump=0.45)
        hd2 = layer("hood")
        for ob in (shell("hcape", 0.4, 0.2, 0.5, hoodm, lambda x, y: True, seg=36, folds=9, fold_depth=0.1, z0=1.04,
                         parent=hd2, loc=(-0.02, 0, 0), scale=(0.74, 1.08, 1)),
                   open_ball("hood", 0.19, hoodm, lambda x, y, z: x < 0.07 - max(0.0, -z) * 0.6, parent=hd2,
                             loc=(-0.035, 0, 1.79), scale=(1.0, 0.93, 1.06)),
                   # The point hangs down the back, not up like a cap.
                   cyl("point", 0.075, 0.0, 0.3, hoodm, seg=10, parent=hd2, loc=(-0.18, 0, 1.82),
                       rot=(0, math.radians(-163), 0), scale=(0.6, 1, 1))):
            self.mask_parts[ob] = "hood"

        # Mail with the shoulders doubled, Gallic and Roman alike.
        mailm = mat("mail", "#5e5e5a", "#86867e", scale=90, metal=0.6, rough=0.45, bump=0.9)
        ml = layer("mail")
        cyl("mskirt", 0.31, 0.25, 0.36, mailm, seg=14, z0=0.68, parent=ml, scale=(0.86, 1.13, 1))
        cyl("mtorso", 0.25, 0.295, 0.5, mailm, seg=14, z0=1.02, parent=ml, scale=(0.8, 1.14, 1))
        ball("mchest", 0.21, mailm, parent=ml, loc=(0.03, 0, 1.38), scale=(0.97, 1.38, 0.72))
        for s in (1, -1):
            ball("mshoulder", 0.115, mailm, parent=ml, loc=(0, s * 0.3, 1.46))
        shell("doubling", 0.33, 0.17, 0.17, mailm, lambda x, y: True, seg=18, z0=1.37, parent=ml,
              scale=(0.72, 1.14, 1))
        cyl("mbelt", 0.26, 0.26, 0.08, leather, seg=14, z0=1.0, parent=ml, scale=(0.84, 1.14, 1))

        cp = layer("cap")
        half_ball("capdome", 0.172, leather, sz=0.8, parent=cp, loc=(-0.02, 0, 1.79))
        torus("capband", 0.168, 0.018, leather, parent=cp, loc=(-0.02, 0, 1.79))

        # Bronze Montefortino: the Roman helmet, knob on top, neck guard, cheeks.
        hm = layer("helmet")
        half_ball("dome", 0.18, bronze, sz=1.05, parent=hm, loc=(-0.02, 0, 1.78))
        cyl("knob", 0.03, 0.015, 0.08, bronze, seg=8, z0=1.96, parent=hm)
        shell("guard", 0.22, 0.19, 0.05, bronze, lambda x, y: x < 0.02, z0=1.73, parent=hm, loc=(-0.04, 0, 0))
        for s in (1, -1):
            box("cheek", 0.1, 0.02, 0.15, bronze, parent=hm, loc=(0.06, s * 0.155, 1.6))

        # Iron Agen/Alesia cap: the Gallic helmet. Ridge at the base, the rim
        # flaring at the back into a neck guard.
        def iron_cap(e):
            half_ball("dome", 0.182, dark_iron, sz=0.88, parent=e, loc=(-0.02, 0, 1.78))
            torus("ridge", 0.182, 0.016, dark_iron, parent=e, loc=(-0.02, 0, 1.79))
            shell("rim", 0.235, 0.19, 0.05, dark_iron, lambda x, y: x < 0.0, seg=20, z0=1.73, parent=e,
                  loc=(-0.05, 0, 0))
            for s in (1, -1):
                box("cheek", 0.11, 0.018, 0.15, dark_iron, parent=e, loc=(0.05, s * 0.158, 1.6))

        hi = layer("helmet_iron")
        iron_cap(hi)
        ball("knob", 0.025, dark_iron, sub=1, parent=hi, loc=(-0.02, 0, 1.95))

        # The raven helm: an old iron cap with a bronze bird on the crown, its
        # wings spread (after the Tintignac bird helmet).
        hb = layer("helmet_bird")
        iron_cap(hb)
        dark_bronze = mat("dbronze", "#5a4024", "#3a2a1a", metal=0.85, rough=0.4, scale=12)
        ball("bird", 0.08, dark_bronze, parent=hb, loc=(-0.02, 0, 2.02), scale=(1.6, 0.7, 0.75))
        ball("bhead", 0.05, dark_bronze, parent=hb, loc=(0.12, 0, 2.1))
        cyl("beak", 0.026, 0.0, 0.09, dark_bronze, seg=6, parent=hb, loc=(0.16, 0, 2.1), rot=(0, math.radians(100), 0))
        for s in (1, -1):
            box("wing", 0.2, 0.3, 0.02, dark_bronze, parent=hb, loc=(-0.04, s * 0.16, 2.1),
                rot=(math.radians(s * 40), 0, 0))
        cyl("tail", 0.04, 0.0, 0.1, dark_bronze, seg=4, parent=hb, loc=(-0.12, 0, 2.0), rot=(0, math.radians(-100), 0),
            scale=(0.4, 1.4, 1))

        # --- Held things -------------------------------------------------------------
        def held(name, hand, rot=(0, 0, 0), loc=(0, 0, 0)):
            e = empty(name, hand, loc, rot)
            self.items[name] = e
            return e

        along = (0, math.radians(90), 0)  # turns a cylinder from +z to +x

        # Gallic long sword: blade about 47% of body height, parallel edges, a
        # short point, a narrow bell-shaped guard and no crossbar.
        sw = held("sword", self.hand_r, (0, math.radians(-35), 0))
        cyl("grip", 0.024, 0.024, 0.15, leather, seg=6, z0=-0.075, parent=sw, rot=along)
        ball("pommel", 0.026, iron, sub=1, parent=sw, loc=(-0.085, 0, 0))
        cyl("bell", 0.024, 0.04, 0.045, iron, seg=10, z0=0.075, parent=sw, rot=along, scale=(0.45, 1, 1))
        box("blade", 0.86, 0.05, 0.014, steel, x0=0.12, parent=sw, loc=(0, 0, -0.007))
        cyl("point", 0.025, 0.0, 0.07, steel, seg=4, z0=0.98, parent=sw, rot=along, scale=(0.3, 1, 1))

        # Gladius: blade about 37%, long tapering point, bone guard, grip and
        # ball pommel.
        gl = held("gladius", self.hand_r, (0, math.radians(-35), 0))
        cyl("grip", 0.026, 0.026, 0.12, bone, seg=8, z0=-0.06, parent=gl, rot=along)
        for x in (-0.03, 0.0, 0.03):
            torus("ridge", 0.027, 0.006, bone, seg=10, rseg=4, parent=gl, loc=(x, 0, 0), rot=along)
        ball("pommel", 0.04, bone, parent=gl, loc=(-0.08, 0, 0), scale=(0.8, 1, 1))
        ball("guard", 0.05, bone, parent=gl, loc=(0.075, 0, 0), scale=(0.45, 1.25, 0.7))
        box("blade", 0.52, 0.06, 0.016, steel, x0=0.1, parent=gl, loc=(0, 0, -0.008))
        cyl("point", 0.03, 0.0, 0.2, steel, seg=4, z0=0.62, parent=gl, rot=along, scale=(0.27, 1, 1))

        dg = held("dagger", self.hand_r, (0, math.radians(-30), 0))
        cyl("grip", 0.022, 0.022, 0.11, leather, seg=6, parent=dg, rot=along)
        box("blade", 0.3, 0.05, 0.014, steel, x0=0.06, parent=dg)

        ax = held("axe", self.hand_r, (0, math.radians(-40), 0))
        cyl("haft", 0.028, 0.028, 0.75, wood, seg=6, z0=-0.1, parent=ax, rot=along)
        box("head", 0.12, 0.03, 0.2, iron, parent=ax, loc=(0.6, 0, -0.06))

        sp = held("spear", self.hand_r, (0, math.radians(8), 0))
        cyl("shaft", 0.025, 0.025, 2.4, wood, seg=6, z0=-0.85, parent=sp)
        cyl("head", 0.045, 0.0, 0.34, steel, seg=6, z0=1.55, parent=sp, scale=(0.5, 1, 1))

        st = held("staff", self.hand_r, (0, math.radians(6), 0))
        cyl("shaft", 0.03, 0.026, 1.95, dark_wood, seg=7, z0=-0.75, parent=st)

        cb = held("club", self.hand_r, (0, math.radians(-38), 0))
        cyl("club", 0.03, 0.065, 0.7, dark_wood, seg=8, z0=-0.08, parent=cb, rot=along)

        jv = held("javelin", self.hand_r, (0, math.radians(10), 0))
        cyl("shaft", 0.018, 0.018, 1.6, wood, seg=6, z0=-0.55, parent=jv)
        cyl("head", 0.03, 0.0, 0.2, iron, seg=6, z0=1.05, parent=jv)

        # Pilum: about 105% of body height, the top third a thin iron shank
        # with a small pyramidal point, and a block where iron meets wood.
        pl = held("pilum", self.hand_r, (0, math.radians(10), 0))
        cyl("shaft", 0.024, 0.024, 1.2, wood, seg=6, z0=-0.7, parent=pl)
        box("block", 0.07, 0.07, 0.09, wood, parent=pl, loc=(0, 0, 0.5))
        cyl("shank", 0.01, 0.01, 0.74, iron, seg=5, z0=0.58, parent=pl)
        cyl("point", 0.022, 0.0, 0.07, iron, seg=4, z0=1.32, parent=pl)

        sl = held("sling", self.hand_r)
        cord = mat("cord", "#6a5434", "#7a6440", scale=30)
        cyl("cord", 0.008, 0.008, -0.42, cord, seg=4, parent=sl)
        ball("pouch", 0.04, leather, sub=1, parent=sl, loc=(0, 0, -0.44), scale=(1, 1, 0.7))

        # Self bow, about 85-90% of body height, held low enough to clear
        # the ground.
        bw = held("bow", self.hand_l, loc=(0, 0, 0.12))
        R_, span = 1.05, math.radians(52)
        pts = [(R_ - R_ * math.cos(t) + 0.02, R_ * math.sin(t)) for t in [-span + 2 * span * i / 10 for i in range(11)]]
        for i in range(10):
            (x0, z0), (x1, z1) = pts[i], pts[i + 1]
            ln = math.hypot(x1 - x0, z1 - z0)
            ang = math.atan2(x1 - x0, z1 - z0)
            th = 0.024 - 0.008 * abs(i - 4.5) / 4.5
            cyl("limb", th, th, ln, dark_wood, seg=6, parent=bw, loc=(x0, 0, z0), rot=(0, ang, 0))
        (xa, za), (xb, zb) = pts[0], pts[-1]
        cyl("string", 0.005, 0.005, zb - za, cord, seg=4, z0=za, parent=bw, loc=(xa, 0, 0))

        # Gallic shield: a tall narrow oval, about 65% of body height, with a
        # spine and an iron boss.
        board = mat("board", NEUTRAL, "#a8a8a8", scale=10, bump=0.2)
        sh = held("shield", self.hand_l, (0, 0, math.radians(25)), (0.08, 0.1, 0.12))
        b = cyl("board", 0.63, 0.63, 0.04, board, seg=28, parent=sh, rot=(math.radians(90), 0, 0), scale=(0.56, 1.0, 1.0))
        self.mask_parts[b] = "board"
        box("spine", 0.06, 0.03, 1.1, wood, parent=sh, loc=(0, 0.035, -0.55))
        ball("boss", 0.09, iron, parent=sh, loc=(0, 0.045, 0), scale=(1.4, 0.6, 1.0))

        ss = held("small_shield", self.hand_l, (0, 0, math.radians(25)), (0.06, 0.1, 0.05))
        b2 = cyl("board", 0.3, 0.3, 0.035, board, seg=20, parent=ss, rot=(math.radians(90), 0, 0))
        self.mask_parts[b2] = "board"
        ball("boss", 0.07, iron, parent=ss, loc=(0, 0.03, 0), scale=(1, 0.6, 1))

        # Scutum of the Republic: a tall curved oval, about 75% of body height
        # and half as wide, a spine from rim to rim, a bronze boss.
        sc = held("scutum", self.hand_l, (0, 0, math.radians(20)), (0.1, 0.07, 0.04))
        b3 = curved_oval("board", 0.37, 0.73, 0.55, board, parent=sc)
        self.mask_parts[b3] = "board"
        box("spine", 0.05, 0.03, 1.4, wood, parent=sc, loc=(0, 0.03, -0.7))
        ball("boss", 0.085, bronze, parent=sc, loc=(0, 0.045, 0), scale=(1.25, 0.6, 1.0))
        self._mats = {}

    @property
    def body(self):
        seen = []
        for objs in self.body_sets.values():
            for o in objs:
                if o not in seen:
                    seen.append(o)
        return seen

    def pose(self, facing, step, stride=1.0):
        """Stand (step 0) or one of the two contact frames of the walk (step
        1 or -1): legs apart, the trailing knee bent as it pushes off, the
        arms swinging against the legs, the body a little lower. stride
        scales the legs only (a long dress takes shorter steps); the arms
        swing the same, so gear held in the hands still lines up."""
        self.root.rotation_euler = (0, 0, math.radians(60 * facing))
        self.root.location = (0, 0, -0.02 * abs(step))
        sw = math.radians(24) * step
        lw = sw * stride
        self.hip["L"].rotation_euler = (0, -lw, 0)
        self.hip["R"].rotation_euler = (0, lw, 0)
        lead, trail = ("L", "R") if step > 0 else ("R", "L")
        if step == 0:
            for kn in self.knee.values():
                kn.rotation_euler = (0, math.radians(4), 0)
        else:
            self.knee[trail].rotation_euler = (0, math.radians(30 * stride), 0)
            self.knee[lead].rotation_euler = (0, math.radians(5), 0)
        self.sho["L"].rotation_euler = (math.radians(10), sw * 0.7, 0)
        self.sho["R"].rotation_euler = (math.radians(-10), -sw * 0.45 - math.radians(12), 0)
        # Elbows bend forward, more on the arm swinging forward. The hands turn
        # back by the same amount, so what they hold keeps its angle to the arm.
        bl = math.radians(14 + 16 * max(0.0, -step))
        br = math.radians(24)
        self.elbow["L"].rotation_euler = (0, -bl, 0)
        self.elbow["R"].rotation_euler = (0, -br, 0)
        self.hand_l.rotation_euler = (0, bl, 0)
        self.hand_r.rotation_euler = (0, br, 0)

    def lie(self):
        self.pose(0, 0)
        # On its back, head to the west-south-west, centered on the hex.
        self.root.rotation_euler = (0, math.radians(-88), math.radians(15))
        self.root.location = Vector((0.87, 0.23, 0.18)) * FIG_SCALE

    def mask_mode(self, on):
        sc = bpy.context.scene
        if on:
            black = emission("black", (0, 0, 0))
            check = pattern_mask()
            cache = {}
            for ob in [o for o in bpy.data.objects if o.type == "MESH" and o.name != "catcher"]:
                self._mats[ob] = list(ob.data.materials)
                key = self.mask_parts.get(ob)
                col = MASK_COLORS[key] if key else None
                if col and col not in cache:
                    cache[col] = emission("mask%s" % (col,), col)
                m = check if key == "cloak" else (cache[col] if col else black)
                for i in range(len(ob.data.materials)):
                    ob.data.materials[i] = m
            bpy.data.objects["catcher"].hide_render = True
            sc.cycles.samples = 8
            sc.cycles.use_denoising = False
        else:
            for ob, ms in self._mats.items():
                for i, m in enumerate(ms):
                    ob.data.materials[i] = m
            bpy.data.objects["catcher"].hide_render = False
            sc.cycles.samples = 48
            sc.cycles.use_denoising = True


BODIES = ["body", "body_f", "body_roman"]
HAIR = ["hair_long", "hair_swept", "hair_short", "hair_knot", "hair_braid", "hair_bun", "hair_wrap"]
FACES = ["moustache", "beard"]
TORCS = ["torc_gold", "torc_bronze"]
GEAR_LAYERS = ["cloak", "hide", "hood", "mail", "cap", "helmet", "helmet_iron", "helmet_bird", "sword", "gladius", "dagger",
               "axe", "spear", "staff", "club", "javelin", "pilum", "sling", "bow", "shield", "small_shield", "scutum"]
FIG_LAYERS = BODIES + HAIR + FACES + TORCS + GEAR_LAYERS
# Layers drawn on the dead and the fallen as well as the standing.
DOWN_LAYERS = BODIES + HAIR + FACES + TORCS
# Which body hides what is behind it when a layer renders. Women's hair goes
# with the woman's body; everything else with the man's (the heads, arms and
# shoulders are the same).
HOLDOUT = {"hair_braid": "body_f", "hair_bun": "body_f", "hair_wrap": "body_f"}
# Shorter steps in an ankle-length dress, so the back foot stays under it.
STRIDE = {"body_f": 0.45}


def render_layers(f, layers, folder, down_layers=("body",)):
    """Render each layer at 6 facings x 3 steps. A body renders alone; each
    other layer renders with a body as a holdout, so the game can stack
    them in any combination. A layer gets a mask render if any of its parts
    is tagged for recoloring."""
    items = list(f.items.values())
    sets = getattr(f, "body_sets", {"body": f.body})
    for name in layers:
        item = f.items.get(name)
        base = name if name in sets else HOLDOUT.get(name, "body")
        show(items, False)
        for ob in f.body:
            ob.hide_render = ob not in sets[base]
            ob.is_holdout = item is not None
        if item is not None:
            show([item], True)
        shown = sets[base] if item is None else [o for o in item.children_recursive if o.type == "MESH"]
        masked = any(o in f.mask_parts for o in shown)
        for mode in (["lit", "mask"] if masked else ["lit"]):
            f.mask_mode(mode == "mask")
            for facing in range(6):
                for k, step in enumerate((0, 1, -1)):
                    f.pose(facing, step, STRIDE.get(base, 1.0))
                    render(os.path.join(OUT, folder, name, mode, "%d_%d.png" % (facing, k)))
            if name in down_layers:
                f.lie()
                render(os.path.join(OUT, folder, name, mode, "down.png"))
        f.mask_mode(False)
    for ob in f.body:
        ob.is_holdout = False
        ob.hide_render = False


def render_figure():
    new_scene(48)
    frame(*FIG_FRAME)
    f = Figure()
    want = [l for l in FIG_LAYERS if not ONLY or "figure" in ONLY or l in ONLY]
    render_layers(f, want, "figure", DOWN_LAYERS)


# --- Beasts ---------------------------------------------------------------------

BEAST_FRAME = (92, 80, 22)


class Wolf:
    """A gray wolf, built and posed like the figure so it renders the same way."""

    def __init__(self):
        fur = mat("fur", "#6e665c", "#8a8274", scale=40, bump=0.9)
        pale = mat("pale", "#a49a88", "#b8ae9a", scale=40, bump=0.8)
        dark = mat("dark", "#2e2a26")
        self.root = root = empty("root")
        self.body = []
        self.items = {}
        self.mask_parts = {}

        def part(ob):
            self.body.append(ob)
            return ob

        part(ball("trunk", 0.3, fur, parent=root, loc=(0, 0, 0.62), scale=(1.55, 0.75, 0.78)))
        part(ball("chest", 0.25, pale, parent=root, loc=(0.32, 0, 0.6), scale=(0.9, 0.85, 1.0)))
        part(ball("ruff", 0.24, fur, parent=root, loc=(0.36, 0, 0.72), scale=(0.8, 0.95, 0.85)))
        part(cyl("neck", 0.13, 0.11, 0.28, fur, seg=8, parent=root, loc=(0.5, 0, 0.72), rot=(0, math.radians(55), 0)))
        hd = empty("head", root, (0.66, 0, 0.9))
        part(ball("skull", 0.13, fur, parent=hd, scale=(1.15, 0.95, 0.9)))
        part(cyl("muzzle", 0.075, 0.045, 0.2, pale, seg=8, parent=hd, loc=(0.1, 0, -0.03), rot=(0, math.radians(100), 0)))
        part(ball("nose", 0.03, dark, sub=1, parent=hd, loc=(0.3, 0, -0.06)))
        for s in (1, -1):
            part(cyl("ear", 0.045, 0.0, 0.12, fur, seg=5, parent=hd, loc=(-0.02, s * 0.07, 0.09),
                     rot=(s * math.radians(-15), 0, 0)))
            part(ball("eye", 0.018, dark, sub=1, parent=hd, loc=(0.1, s * 0.06, 0.03)))
        tl = empty("tail", root, (-0.42, 0, 0.66), (0, math.radians(-130), 0))
        part(cyl("tail", 0.07, 0.04, 0.5, fur, seg=8, parent=tl))
        self.legs = {}
        for name, x, y in (("FL", 0.3, 0.12), ("FR", 0.3, -0.12), ("BL", -0.3, 0.13), ("BR", -0.3, -0.13)):
            lg = empty("leg" + name, root, (x, y, 0.55))
            part(cyl("upper", 0.065, 0.045, -0.3, fur, seg=7, parent=lg))
            part(cyl("lower", 0.04, 0.035, -0.26, fur, seg=7, z0=-0.29, parent=lg))
            part(ball("paw", 0.045, dark, sub=1, parent=lg, loc=(0.03, 0, -0.55), scale=(1.4, 1, 0.6)))
            self.legs[name] = lg
        root.scale = (1.15,) * 3

    def pose(self, facing, step):
        self.root.rotation_euler = (0, 0, math.radians(60 * facing))
        self.root.location = (0, 0, 0.02 * abs(step))
        sw = math.radians(28) * step
        for name, lg in self.legs.items():
            lg.rotation_euler = (0, sw if name in ("FL", "BR") else -sw, 0)

    def lie(self):
        self.pose(0, 0)
        self.root.rotation_euler = (math.radians(85), 0, math.radians(15))
        self.root.location = (0, 0.3, 0.25)

    def mask_mode(self, on):
        pass


def render_beasts():
    new_scene(48)
    frame(*BEAST_FRAME)
    render_layers(Wolf(), ["body"], "beasts/wolf")


def render_preview():
    """Development check, not part of the build: some people at two facings,
    and the wolf, at full render size."""
    new_scene(32)
    frame(*FIG_FRAME)
    f = Figure()
    combos = {"warrior": ("body", ["hair_swept", "moustache", "cloak", "torc_bronze", "sword", "shield"]),
              "noble": ("body", ["mail", "hair_long", "moustache", "torc_gold", "helmet_iron", "sword", "shield"]),
              "raven": ("body", ["hair_long", "beard", "cloak", "helmet_bird", "spear"]),
              "roman": ("body_roman", ["mail", "hair_short", "helmet", "gladius", "scutum"]),
              "pilum": ("body_roman", ["hair_short", "pilum"]),
              "woman": ("body_f", ["hair_braid", "torc_gold"]), "elder": ("body_f", ["hair_wrap", "cloak"]),
              "farmer": ("body", ["hair_long", "beard", "hood", "staff"]),
              "german": ("body", ["hair_knot", "beard", "hide", "spear", "small_shield"]),
              "hunter": ("body", ["hair_long", "beard", "bow"])}
    sets = f.body_sets
    for name, (body, gear) in combos.items():
        show(list(f.items.values()), False)
        for ob in f.body:
            ob.hide_render = ob not in sets[body]
        show([f.items[g] for g in gear], True)
        for facing in (5, 1, 3):
            f.pose(facing, 1 if facing == 1 else 0, STRIDE.get(body, 1.0))
            render(os.path.join(OUT, "preview", "%s_%d.png" % (name, facing)))
    f.lie()
    for ob in f.body:
        ob.hide_render = ob not in sets["body"]
    show(list(f.items.values()), False)
    show([f.items["hair_long"], f.items["beard"]], True)
    render(os.path.join(OUT, "preview", "down.png"))
    new_scene(32)
    frame(*BEAST_FRAME)
    w = Wolf()
    for facing in (5, 0, 2):
        w.pose(facing, 1)
        render(os.path.join(OUT, "preview", "wolf_%d.png" % facing))
    w.lie()
    render(os.path.join(OUT, "preview", "wolf_down.png"))


GROUPS = {"walls": render_walls, "trees": render_trees, "props": render_props, "figure": render_figure,
          "beasts": render_beasts, "rocks": render_rocks, "preview": render_preview}
WALL_KINDS = {"wall_wood", "palisade", "fence", "rampart", "wall_stone", "door", "cliff", "cave_wall"}
for g, fn in GROUPS.items():
    if g == "preview" and not (ONLY and g in ONLY):
        continue
    if (ONLY is None or g in ONLY or (g == "walls" and ONLY & WALL_KINDS)
            or (g == "figure" and ONLY & set(FIG_LAYERS))
            or (g == "props" and ONLY & {n for n, _ in PROP_BUILDERS})):
        fn()
print("SPRITES DONE")
