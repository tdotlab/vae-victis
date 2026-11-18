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

FIG_FRAME = (108, 120, 22)
FIG_SCALE = 1.3  # people are drawn larger than life, as in Fallout, so they read
NEUTRAL = "#9a9a9a"
MASK_COLORS = {"tunic": (1, 0, 0), "trousers": (0, 1, 0), "hair": (0, 0, 1), "board": (1, 0, 0), "cloak": (1, 0, 0),
               "hide": (1, 0, 0)}


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
        self.hip = {}
        self.sho = {}
        for side, y in (("L", 0.11), ("R", -0.11)):
            self.hip[side] = empty("hip" + side, root, (0, y, 0.88))
        part(cyl("neck", 0.065, 0.065, 0.14, skin, seg=8, z0=1.5, parent=root))
        part(ball("head", 0.15, skin, parent=root, loc=(0.015, 0, 1.76), scale=(0.95, 0.86, 1.05)))
        part(box("nose", 0.05, 0.035, 0.07, skin, parent=root, loc=(0.15, 0, 1.73)))
        part(ball("ears", 0.035, skin, sub=1, parent=root, loc=(-0.01, 0, 1.74), scale=(0.8, 4.3, 1.2)))
        for side, y in (("L", 0.3), ("R", -0.3)):
            sh = empty("sho" + side, root, (0, y, 1.44), (math.radians(8 if side == "L" else -8), 0, 0))
            self.sho[side] = sh
            part(ball("shoulder", 0.1, gray, parent=sh, loc=(0, 0, 0.02)), "tunic")
            part(cyl("upper", 0.088, 0.075, -0.33, gray, seg=8, parent=sh), "tunic")
            part(cyl("fore", 0.066, 0.055, -0.3, skin, seg=8, z0=-0.31, parent=sh))
            part(ball("hand", 0.068, skin, parent=sh, loc=(0, 0, -0.64)))
        self.hand_r = empty("handR", self.sho["R"], (0, 0, -0.64))
        self.hand_l = empty("handL", self.sho["L"], (0, 0, -0.62))

        # --- Gallic man: tunic to mid-thigh over trousers, short boots ----------
        M = ("body",)
        for hp in self.hip.values():
            part(cyl("leg", 0.105, 0.078, -0.74, gray, seg=8, parent=hp), "trousers", M)
            part(cyl("boot", 0.08, 0.075, -0.16, leather, seg=8, z0=-0.72, parent=hp), None, M)
            part(box("foot", 0.24, 0.12, 0.08, leather, parent=hp, loc=(0.05, 0, -0.88)), None, M)
        part(cyl("skirt", 0.3, 0.235, 0.44, gray, seg=14, z0=0.6, parent=root, scale=(0.82, 1.08, 1)), "tunic", M)

        # --- Roman: knee-length tunic, bare legs, open-work caligae -------------
        R = ("body_roman",)
        caliga = mat("caliga", "#2e2016", "#4a3020", scale=50, bump=0.6)
        for hp in self.hip.values():
            part(cyl("leg", 0.088, 0.062, -0.76, skin, seg=8, parent=hp), None, R)
            part(cyl("strap", 0.068, 0.07, -0.13, caliga, seg=8, z0=-0.75, parent=hp), None, R)
            part(box("foot", 0.24, 0.12, 0.07, caliga, parent=hp, loc=(0.05, 0, -0.88)), None, R)
        part(cyl("skirt", 0.31, 0.235, 0.58, gray, seg=14, z0=0.46, parent=root, scale=(0.82, 1.08, 1)), "tunic", R)

        # --- Woman: ankle-length belted dress, pinned at both shoulders ---------
        F = ("body_f",)
        for hp in self.hip.values():
            part(cyl("leg", 0.07, 0.055, -0.76, skin, seg=8, parent=hp), None, F)
            part(box("foot", 0.2, 0.1, 0.07, leather, parent=hp, loc=(0.04, 0, -0.88)), None, F)
        part(cyl("dress", 0.36, 0.235, 0.98, gray, seg=16, z0=0.04, parent=root, scale=(0.8, 1.02, 1)), "tunic", F)
        part(cyl("torso", 0.225, 0.26, 0.5, gray, seg=14, z0=1.0, parent=root, scale=(0.76, 1.04, 1)), "tunic", F)
        part(ball("chest", 0.19, gray, parent=root, loc=(0.04, 0, 1.36), scale=(1.0, 1.3, 0.72)), "tunic", F)
        part(cyl("belt", 0.235, 0.235, 0.06, leather, seg=14, z0=1.0, parent=root, scale=(0.8, 1.06, 1)), None, F)
        for s in (1, -1):
            part(ball("brooch", 0.03, bronze, sub=1, parent=root, loc=(0.09, s * 0.16, 1.5)), None, F)

        # The man's and the Roman's chest and belt.
        MR = ("body", "body_roman")
        part(cyl("torso", 0.235, 0.28, 0.52, gray, seg=14, z0=1.0, parent=root, scale=(0.76, 1.1, 1)), "tunic", MR)
        part(ball("chest", 0.2, gray, parent=root, loc=(0.03, 0, 1.38), scale=(0.95, 1.35, 0.7)), "tunic", MR)
        part(cyl("belt", 0.245, 0.245, 0.08, leather, seg=14, z0=0.99, parent=root, scale=(0.8, 1.1, 1)), None, MR)
        part(box("buckle", 0.03, 0.08, 0.06, bronze, parent=root, loc=(0.2, 0, 1.0)), None, MR)

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
        c = shell("cape", 0.42, 0.31, 0.95, cloth, lambda x, y: x < 0.04 + max(0.0, y) * 0.55, seg=24, z0=0.52,
                  parent=ck, loc=(-0.06, 0, 0), scale=(0.62, 1.12, 1))
        self.mask_parts[c] = "cloak"
        c2 = torus("collar", 0.22, 0.05, cloth, parent=ck, loc=(-0.02, 0, 1.5), scale=(0.8, 1.2, 1))
        self.mask_parts[c2] = "cloak"
        ball("brooch", 0.04, bronze, sub=1, parent=ck, loc=(0.1, -0.2, 1.5))

        # Hide cape: what Germans wore instead of a cloak (Caesar IV.1, VI.21).
        fur = mat("fur", NEUTRAL, "#7a7a7a", scale=70, bump=1.0, rough=0.95)
        hd = layer("hide")
        c3 = shell("hide", 0.44, 0.3, 0.6, fur, lambda x, y: x < 0.08, seg=20, z0=0.92, parent=hd,
                   loc=(-0.05, 0, 0), scale=(0.64, 1.14, 1))
        self.mask_parts[c3] = "hide"
        c4 = torus("ruff", 0.22, 0.07, fur, parent=hd, loc=(-0.02, 0, 1.5), scale=(0.82, 1.2, 1))
        self.mask_parts[c4] = "hide"

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
HAIR = ["hair_long", "hair_swept", "hair_short", "hair_knot", "hair_braid", "hair_bun"]
FACES = ["moustache", "beard"]
TORCS = ["torc_gold", "torc_bronze"]
GEAR_LAYERS = ["cloak", "hide", "mail", "cap", "helmet", "helmet_iron", "helmet_bird", "sword", "gladius", "dagger",
               "axe", "spear", "staff", "club", "javelin", "pilum", "sling", "bow", "shield", "small_shield", "scutum"]
FIG_LAYERS = BODIES + HAIR + FACES + TORCS + GEAR_LAYERS
# Layers drawn on the dead and the fallen as well as the standing.
DOWN_LAYERS = BODIES + HAIR + FACES + TORCS
# Which body hides what is behind it when a layer renders. Women's hair goes
# with the woman's body; everything else with the man's (the heads, arms and
# shoulders are the same).
HOLDOUT = {"hair_braid": "body_f", "hair_bun": "body_f"}


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
                    f.pose(facing, step)
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
              "woman": ("body_f", ["hair_braid", "torc_gold"]), "elder": ("body_f", ["hair_bun", "cloak"]),
              "german": ("body", ["hair_knot", "beard", "hide", "spear", "small_shield"]),
              "hunter": ("body", ["hair_long", "beard", "bow"])}
    sets = f.body_sets
    for name, (body, gear) in combos.items():
        show(list(f.items.values()), False)
        for ob in f.body:
            ob.hide_render = ob not in sets[body]
        show([f.items[g] for g in gear], True)
        for facing in (5, 1, 3):
            f.pose(facing, 1 if facing == 1 else 0)
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
            or (g == "figure" and ONLY & set(FIG_LAYERS))):
        fn()
print("SPRITES DONE")
