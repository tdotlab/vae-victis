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


def cyl(name, r1, r2, h, m, seg=10, z0=0.0, smooth=True, top=None, **kw):
    """Cylinder or cone along +Z from z0 to z0+h (negative h goes down)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=abs(h))
    for v in bm.verts:
        v.co.z = v.co.z * (1 if h > 0 else -1) + z0 + h / 2
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
    bg.inputs[1].default_value = 0.85
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 3.4
    sun.color = C("#fff0dc")
    sun.angle = math.radians(4)
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

def hearth():
    st = mat("st", "#7a746a", "#958e80", scale=8)
    ash = mat("ash", "#3a3430", "#5a524a", scale=20)
    ember = mat("ember", "#5a2a10", emit=("#ff7a28", 6.0))
    log = mat("log", "#3a2818", "#4e3826", scale=12)
    rnd = random.Random(5)
    cyl("ash", 0.42, 0.42, 0.03, ash, seg=14, smooth=False)
    for i in range(11):
        a = i * math.tau / 11
        ball("s", rnd.uniform(0.09, 0.12), st, sub=1, smooth=False, loc=(math.cos(a) * 0.48, math.sin(a) * 0.48, 0.05), scale=(1.2, 1, 0.8))
    for i in range(3):
        a = i * math.tau / 3 + 0.3
        cyl("log", 0.05, 0.05, 0.55, log, seg=6, loc=(math.cos(a) * 0.12, math.sin(a) * 0.12, 0.08), rot=(math.radians(75), 0, a + math.pi / 2))
    ball("embers", 0.16, ember, sub=1, smooth=False, loc=(0, 0, 0.05), scale=(1.4, 1.4, 0.5))
    lamp = bpy.data.lights.new("fire", "POINT")
    lamp.energy = 40
    lamp.color = C("#ff9a50")
    lamp.use_shadow = False
    lo = bpy.data.objects.new("fire", lamp)
    lo.location = (0, 0, 0.4)
    bpy.context.scene.collection.objects.link(lo)


def bed():
    straw = mat("straw", "#9c8a55", "#b8a46a", scale=20, bump=0.5)
    wool = mat("wool", "#6a5a48", "#7c6a54", scale=10)
    fr = mat("frame", "#4e3826")
    box("frame", 1.3, 0.75, 0.18, fr)
    box("straw", 1.22, 0.68, 0.12, straw, loc=(0, 0, 0.18))
    box("blanket", 0.7, 0.7, 0.06, wool, loc=(-0.25, 0, 0.29), rot=(0, 0.05, 0.08))


def table():
    w = mat("plank", "#6b4a2a", "#80603a", scale=14)
    box("top", 1.25, 0.65, 0.07, w, loc=(0, 0, 0.7))
    for x in (-0.45, 0.45):
        box("leg", 0.08, 0.5, 0.7, w, loc=(x, 0, 0))
    bowl = mat("bowl", "#7a5a3a")
    cyl("bowl", 0.08, 0.12, 0.08, bowl, seg=10, loc=(0.2, 0.05, 0.77))
    cyl("jug", 0.07, 0.06, 0.22, mat("clay", "#8a5a3a", "#9a6a46", scale=10), seg=10, loc=(-0.25, -0.1, 0.77))


def crate():
    w = mat("staves", "#6a4a2c", "#7d5d36", scale=16)
    hoop = mat("hoop", "#3a3632", metal=0.6, rough=0.5)
    sack = mat("sack", "#8a7a58", "#9c8c66", scale=14, bump=0.5)
    cyl("barrel", 0.26, 0.3, 0.75, w, seg=12, loc=(-0.25, 0.15, 0))
    for z in (0.12, 0.62):
        cyl("hoop", 0.31, 0.31, 0.04, hoop, seg=12, loc=(-0.25, 0.15, z))
    ball("sack", 0.28, sack, sub=2, loc=(0.25, -0.1, 0.22), scale=(0.9, 0.8, 1.0))
    ball("sack2", 0.22, sack, sub=2, loc=(0.35, 0.3, 0.18), scale=(1.0, 0.9, 0.9))
    box("crate", 0.4, 0.4, 0.35, w, loc=(0.0, -0.4, 0), rot=(0, 0, 0.3))


def altar():
    st = mat("st", "#8e8a7c", "#aaa596", scale=3, bump=0.8)
    box("altar", 0.9, 0.6, 0.65, st, rot=(0, 0, 0.15))
    box("slab", 1.05, 0.72, 0.1, mat("slab", "#8c887a", "#a09c8c", scale=6), loc=(0, 0, 0.65))


def render_props():
    for name, build in [("hearth", hearth), ("bed", bed), ("table", table), ("crate", crate), ("altar", altar)]:
        new_scene(48)
        frame(*WALL_FRAME)
        build()
        render(os.path.join(OUT, "props", name, "00.png"))


# --- The figure --------------------------------------------------------------------------
# One body rendered in six facings and three frames (stand, stride left,
# stride right), plus lying down. Tunic, trousers, hair and shield are
# rendered neutral gray and recolored in the game from each NPC's look; a
# second render of flat colors (the mask) says which pixel is which.

FIG_FRAME = (92, 116, 22)
FIG_SCALE = 1.3  # people are drawn larger than life, as in Fallout, so they read
NEUTRAL = "#9a9a9a"
MASK_COLORS = {"tunic": (1, 0, 0), "trousers": (0, 1, 0), "hair": (0, 0, 1), "board": (1, 0, 0), "cloak": (1, 0, 0)}


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


def shell(name, r1, r2, h, m, keep, seg=20, z0=0.0, **kw):
    """An open cone shell (no caps) keeping only vertices where keep(x, y)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, segments=seg, radius1=r1, radius2=r2, depth=h)
    for v in bm.verts:
        v.co.z += z0 + h / 2
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not keep(v.co.x, v.co.y)], context="VERTS")
    return _obj(name, bm, [m], smooth=True, **kw)


def half_ball(name, r, m, sz=1.0, **kw):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    for v in bm.verts:
        v.co.z *= sz
    return _obj(name, bm, [m], smooth=True, **kw)


class Figure:
    """One Gaul in gray. Parts tagged in mask_parts are recolored in the game.
    Everything else that can be worn or held is a layer of its own."""

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
        gold = mat("gold", "#c89a3a", metal=0.9, rough=0.3)
        bronze = mat("bronze", "#a87a3a", "#8a6230", metal=0.85, rough=0.35, scale=10)
        self.root = root = empty("root")
        root.scale = (FIG_SCALE,) * 3
        self.body = []

        def part(ob, key=None):
            self.body.append(ob)
            if key:
                self.mask_parts[ob] = key
            return ob

        self.hip = {}
        self.sho = {}
        for side, y in (("L", 0.11), ("R", -0.11)):
            hp = empty("hip" + side, root, (0, y, 0.88))
            self.hip[side] = hp
            part(cyl("leg", 0.105, 0.078, -0.74, gray, seg=8, parent=hp), "trousers")
            part(cyl("boot", 0.08, 0.075, -0.16, leather, seg=8, z0=-0.72, parent=hp))
            part(box("foot", 0.24, 0.12, 0.08, leather, parent=hp, loc=(0.05, 0, -0.88)))
        # Tunic: a skirt that flares over the trousers, then the chest, wider
        # at the shoulders.
        part(cyl("skirt", 0.3, 0.235, 0.44, gray, seg=14, z0=0.6, parent=root, scale=(0.82, 1.08, 1)), "tunic")
        part(cyl("torso", 0.235, 0.28, 0.52, gray, seg=14, z0=1.0, parent=root, scale=(0.76, 1.1, 1)), "tunic")
        part(ball("chest", 0.2, gray, parent=root, loc=(0.03, 0, 1.38), scale=(0.95, 1.35, 0.7)), "tunic")
        part(cyl("belt", 0.245, 0.245, 0.08, leather, seg=14, z0=0.99, parent=root, scale=(0.8, 1.1, 1)))
        part(box("buckle", 0.03, 0.08, 0.06, bronze, parent=root, loc=(0.2, 0, 1.0)))
        part(cyl("neck", 0.065, 0.065, 0.14, skin, seg=8, z0=1.5, parent=root))
        part(torus("torc", 0.085, 0.018, gold, parent=root, loc=(0.0, 0, 1.54), rot=(0, math.radians(-12), 0)))
        part(ball("head", 0.15, skin, parent=root, loc=(0.015, 0, 1.76), scale=(0.95, 0.86, 1.05)))
        part(box("nose", 0.05, 0.035, 0.07, skin, parent=root, loc=(0.15, 0, 1.73)))
        part(ball("hair", 0.162, hairm, parent=root, loc=(-0.025, 0, 1.81), scale=(1.0, 0.98, 0.82)), "hair")
        part(ball("hairback", 0.13, hairm, parent=root, loc=(-0.09, 0, 1.63), scale=(0.75, 1.15, 1.35)), "hair")
        for s in (1, -1):
            part(box("mous", 0.035, 0.07, 0.11, hairm, parent=root, loc=(0.145, s * 0.045, 1.65),
                     rot=(math.radians(s * 18), 0, 0)), "hair")
        for side, y in (("L", 0.3), ("R", -0.3)):
            sh = empty("sho" + side, root, (0, y, 1.44), (math.radians(8 if side == "L" else -8), 0, 0))
            self.sho[side] = sh
            part(ball("shoulder", 0.1, gray, parent=sh, loc=(0, 0, 0.02)), "tunic")
            part(cyl("upper", 0.088, 0.075, -0.33, gray, seg=8, parent=sh), "tunic")
            part(cyl("fore", 0.066, 0.055, -0.3, skin, seg=8, z0=-0.31, parent=sh))
            part(ball("hand", 0.068, skin, parent=sh, loc=(0, 0, -0.64)))
        self.hand_r = empty("handR", self.sho["R"], (0, 0, -0.64))
        self.hand_l = empty("handL", self.sho["L"], (0, 0, -0.62))

        # --- Worn things -----------------------------------------------------
        self.items = {}
        cloth = mat("cloak", NEUTRAL, "#a2a2a2", scale=14, bump=0.4)
        ck = empty("cloak", root)
        c = shell("cape", 0.42, 0.31, 0.95, cloth, lambda x, y: x < 0.04, seg=24, z0=0.52, parent=ck,
                  loc=(-0.06, 0, 0), scale=(0.62, 1.12, 1))
        self.mask_parts[c] = "cloak"
        c2 = torus("collar", 0.22, 0.05, cloth, parent=ck, loc=(-0.02, 0, 1.5), scale=(0.8, 1.2, 1))
        self.mask_parts[c2] = "cloak"
        ball("brooch", 0.035, gold, sub=1, parent=ck, loc=(0.13, 0.12, 1.47))
        self.items["cloak"] = ck

        mailm = mat("mail", "#5e5e5a", "#86867e", scale=90, metal=0.6, rough=0.45, bump=0.9)
        ml = empty("mail", root)
        cyl("mskirt", 0.31, 0.25, 0.36, mailm, seg=14, z0=0.68, parent=ml, scale=(0.86, 1.13, 1))
        cyl("mtorso", 0.25, 0.295, 0.5, mailm, seg=14, z0=1.02, parent=ml, scale=(0.8, 1.14, 1))
        ball("mchest", 0.21, mailm, parent=ml, loc=(0.03, 0, 1.38), scale=(0.97, 1.38, 0.72))
        for s in (1, -1):
            ball("mshoulder", 0.115, mailm, parent=ml, loc=(0, s * 0.3, 1.46))
        cyl("mbelt", 0.26, 0.26, 0.08, leather, seg=14, z0=1.0, parent=ml, scale=(0.84, 1.14, 1))
        self.items["mail"] = ml

        cp = empty("cap", root)
        half_ball("capdome", 0.172, leather, sz=0.8, parent=cp, loc=(-0.02, 0, 1.79))
        torus("capband", 0.168, 0.018, leather, parent=cp, loc=(-0.02, 0, 1.79))
        self.items["cap"] = cp

        hm = empty("helmet", root)
        half_ball("dome", 0.18, bronze, sz=0.95, parent=hm, loc=(-0.02, 0, 1.78))
        cyl("knob", 0.03, 0.015, 0.08, bronze, seg=8, z0=1.95, parent=hm)
        shell("guard", 0.2, 0.19, 0.06, bronze, lambda x, y: x < 0.02, z0=1.73, parent=hm, loc=(-0.04, 0, 0))
        for s in (1, -1):
            box("cheek", 0.1, 0.02, 0.14, bronze, parent=hm, loc=(0.06, s * 0.15, 1.62))
        self.items["helmet"] = hm

        # --- Held things -------------------------------------------------------
        def held(name, hand, rot=(0, 0, 0), loc=(0, 0, 0)):
            e = empty(name, hand, loc, rot)
            self.items[name] = e
            return e

        sw = held("sword", self.hand_r, (0, math.radians(-35), 0))
        cyl("grip", 0.025, 0.025, 0.14, leather, seg=6, parent=sw, rot=(0, math.radians(90), 0))
        box("guard", 0.03, 0.16, 0.03, iron, parent=sw, loc=(0.08, 0, -0.015))
        box("blade", 0.78, 0.055, 0.015, steel, x0=0.09, parent=sw, loc=(0, 0, -0.008))
        ball("pommel", 0.035, iron, sub=1, parent=sw, loc=(-0.08, 0, 0))

        dg = held("dagger", self.hand_r, (0, math.radians(-30), 0))
        cyl("grip", 0.022, 0.022, 0.11, leather, seg=6, parent=dg, rot=(0, math.radians(90), 0))
        box("blade", 0.3, 0.05, 0.014, steel, x0=0.06, parent=dg)

        ax = held("axe", self.hand_r, (0, math.radians(-40), 0))
        cyl("haft", 0.028, 0.028, 0.75, wood, seg=6, z0=-0.1, parent=ax, rot=(0, math.radians(90), 0))
        box("head", 0.12, 0.03, 0.2, iron, parent=ax, loc=(0.6, 0, -0.06))

        sp = held("spear", self.hand_r, (0, math.radians(8), 0))
        cyl("shaft", 0.025, 0.025, 2.4, wood, seg=6, z0=-0.85, parent=sp)
        cyl("head", 0.045, 0.0, 0.34, steel, seg=6, z0=1.55, parent=sp, scale=(0.5, 1, 1))

        st = held("staff", self.hand_r, (0, math.radians(6), 0))
        cyl("shaft", 0.03, 0.026, 1.95, dark_wood, seg=7, z0=-0.75, parent=st)

        cb = held("club", self.hand_r, (0, math.radians(-38), 0))
        cyl("club", 0.03, 0.065, 0.7, dark_wood, seg=8, z0=-0.08, parent=cb, rot=(0, math.radians(90), 0))

        jv = held("javelin", self.hand_r, (0, math.radians(10), 0))
        cyl("shaft", 0.018, 0.018, 1.6, wood, seg=6, z0=-0.55, parent=jv)
        cyl("head", 0.03, 0.0, 0.2, iron, seg=6, z0=1.05, parent=jv)

        sl = held("sling", self.hand_r)
        cord = mat("cord", "#6a5434", "#7a6440", scale=30)
        cyl("cord", 0.008, 0.008, -0.42, cord, seg=4, parent=sl)
        ball("pouch", 0.04, leather, sub=1, parent=sl, loc=(0, 0, -0.44), scale=(1, 1, 0.7))

        bw = held("bow", self.hand_l)
        R, span = 0.7, math.radians(52)
        pts = [(R - R * math.cos(t) + 0.02, R * math.sin(t)) for t in [-span + 2 * span * i / 8 for i in range(9)]]
        for i in range(8):
            (x0, z0), (x1, z1) = pts[i], pts[i + 1]
            ln = math.hypot(x1 - x0, z1 - z0)
            ang = math.atan2(x1 - x0, z1 - z0)
            cyl("limb", 0.022, 0.022, ln, dark_wood, seg=6, parent=bw, loc=(x0, 0, z0), rot=(0, ang, 0))
        (xa, za), (xb, zb) = pts[0], pts[-1]
        cyl("string", 0.005, 0.005, zb - za, cord, seg=4, z0=za, parent=bw, loc=(xa, 0, 0))

        board = mat("board", NEUTRAL, "#a8a8a8", scale=10, bump=0.2)
        sh = held("shield", self.hand_l, (0, 0, math.radians(25)), (0.08, 0.1, 0.2))
        b = cyl("board", 0.5, 0.5, 0.04, board, seg=24, parent=sh, rot=(math.radians(90), 0, 0), scale=(0.62, 1.0, 1.0))
        self.mask_parts[b] = "board"
        box("spine", 0.06, 0.03, 0.85, wood, parent=sh, loc=(0, 0.035, -0.42))
        ball("boss", 0.09, iron, parent=sh, loc=(0, 0.04, 0), scale=(1.3, 0.6, 1.0))

        ss = held("small_shield", self.hand_l, (0, 0, math.radians(25)), (0.06, 0.1, 0.05))
        b2 = cyl("board", 0.3, 0.3, 0.035, board, seg=20, parent=ss, rot=(math.radians(90), 0, 0))
        self.mask_parts[b2] = "board"
        ball("boss", 0.07, iron, parent=ss, loc=(0, 0.03, 0), scale=(1, 0.6, 1))

        sc = held("scutum", self.hand_l, (0, 0, math.radians(20)), (0.08, 0.06, 0.15))
        b3 = shell("board", 0.62, 0.62, 1.1, board, lambda x, y: y > 0.5, seg=36, z0=-0.55, parent=sc,
                   loc=(0, -0.55, 0))
        self.mask_parts[b3] = "board"
        ball("boss", 0.08, bronze, parent=sc, loc=(0, 0.08, 0), scale=(1.2, 0.6, 1.0))
        self._mats = {}

    def pose(self, facing, step):
        self.root.rotation_euler = (0, 0, math.radians(60 * facing))
        self.root.location = (0, 0, 0.025 * abs(step))
        sw = math.radians(26) * step
        self.hip["L"].rotation_euler = (0, -sw, 0)
        self.hip["R"].rotation_euler = (0, sw, 0)
        self.sho["L"].rotation_euler = (math.radians(8), sw * 0.6, 0)
        self.sho["R"].rotation_euler = (math.radians(-8), -sw * 0.5 - math.radians(12), 0)

    def lie(self):
        self.pose(0, 0)
        # On its back, head to the west-south-west, centered on the hex.
        self.root.rotation_euler = (0, math.radians(-88), math.radians(15))
        self.root.location = Vector((0.87, 0.23, 0.18)) * FIG_SCALE

    def mask_mode(self, on):
        sc = bpy.context.scene
        if on:
            black = emission("black", (0, 0, 0))
            cache = {}
            for ob in [o for o in bpy.data.objects if o.type == "MESH" and o.name != "catcher"]:
                self._mats[ob] = list(ob.data.materials)
                key = self.mask_parts.get(ob)
                col = MASK_COLORS[key] if key else None
                if col and col not in cache:
                    cache[col] = emission("mask%s" % (col,), col)
                for i in range(len(ob.data.materials)):
                    ob.data.materials[i] = cache[col] if col else black
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


MASKED = ("body", "cloak", "shield", "small_shield", "scutum")


def render_layers(f, layers, folder, down_layers=("body",)):
    """Render each layer at 6 facings x 3 steps. The body renders alone; each
    other layer renders with the body as a holdout, so the game can stack
    them in any combination."""
    items = list(f.items.values())
    for name in layers:
        item = f.items.get(name)
        show(items, False)
        for ob in f.body:
            ob.is_holdout = item is not None
        if item is not None:
            show([item], True)
        for mode in (["lit", "mask"] if name in MASKED and f.mask_parts else ["lit"]):
            f.mask_mode(mode == "mask")
            for facing in range(6):
                for k, step in enumerate((0, 1, -1)):
                    f.pose(facing, step)
                    render(os.path.join(OUT, folder, name, mode, "%d_%d.png" % (facing, k)))
            if name in down_layers:
                f.lie()
                render(os.path.join(OUT, folder, name, mode, "down.png"))
        f.mask_mode(False)
    for ob in f.body:
        ob.is_holdout = False


FIG_LAYERS = ["body", "cloak", "mail", "cap", "helmet", "sword", "dagger", "axe", "spear", "staff", "club",
              "javelin", "sling", "bow", "shield", "small_shield", "scutum"]


def render_figure():
    new_scene(48)
    frame(*FIG_FRAME)
    f = Figure()
    want = [l for l in FIG_LAYERS if not ONLY or "figure" in ONLY or l in ONLY]
    render_layers(f, want, "figure")


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
    """Development check, not part of the build: a few gear combinations at
    two facings, and the wolf, at 4x size."""
    new_scene(32)
    frame(*FIG_FRAME)
    sc = bpy.context.scene
    f = Figure()
    combos = {"warrior": ["cloak", "helmet", "sword", "shield"], "spear": ["cap", "spear", "small_shield"],
              "roman": ["mail", "helmet", "sword", "scutum"], "hunter": ["cloak", "bow"],
              "plain": ["staff"], "slinger": ["sling", "axe"]}
    for name, gear in combos.items():
        show(list(f.items.values()), False)
        show([f.items[g] for g in gear], True)
        for facing in (5, 1):
            f.pose(facing, 1 if facing == 1 else 0)
            render(os.path.join(OUT, "preview", "%s_%d.png" % (name, facing)))
    f.lie()
    show(list(f.items.values()), False)
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
            or (g == "figure" and ONLY & set(FIG_LAYERS))):
        fn()
print("SPRITES DONE")
