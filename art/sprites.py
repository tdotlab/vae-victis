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
from mathutils import Vector

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


def render_walls():
    kinds = [("wall_wood", wall_wood), ("palisade", palisade), ("fence", fence),
             ("rampart", rampart), ("wall_stone", wall_stone)]
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

FIG_FRAME = (72, 88, 18)
NEUTRAL = "#9a9a9a"
MASK_COLORS = {"tunic": (1, 0, 0), "trousers": (0, 1, 0), "hair": (0, 0, 1), "board": (1, 0, 0)}


class Figure:
    def __init__(self):
        self.mask_parts = {}  # object -> mask key
        gray = mat("gray", NEUTRAL, "#a6a6a6", scale=20, bump=0.3)
        hairm = mat("hairgray", NEUTRAL, "#8a8a8a", scale=40, bump=0.5)
        skin = mat("skin", "#c99a74", rough=0.6)
        leather = mat("leather", "#4a3220", "#5a3e28", scale=20)
        steel = mat("steel", "#a8acb0", metal=0.85, rough=0.35)
        wood = mat("wood", "#7a5a36", "#8a6a40", scale=20)
        iron = mat("iron", "#5a5650", metal=0.7, rough=0.5)
        self.root = root = empty("root")
        self.body = []

        def part(ob, key=None):
            self.body.append(ob)
            if key:
                self.mask_parts[ob] = key
            return ob

        self.hip = {}
        self.sho = {}
        for side, y in (("L", 0.1), ("R", -0.1)):
            hp = empty("hip" + side, root, (0, y, 0.9))
            self.hip[side] = hp
            part(cyl("leg", 0.1, 0.07, -0.82, gray, seg=8, parent=hp), "trousers")
            part(box("shoe", 0.22, 0.11, 0.09, leather, parent=hp, loc=(0.04, 0, -0.9)))
        part(cyl("torso", 0.25, 0.21, 0.76, gray, seg=12, z0=0.78, parent=root, scale=(0.8, 1.15, 1)), "tunic")
        part(cyl("belt", 0.235, 0.235, 0.07, leather, seg=12, z0=1.0, parent=root, scale=(0.8, 1.15, 1)))
        part(cyl("neck", 0.06, 0.06, 0.12, skin, seg=8, z0=1.52, parent=root))
        part(ball("head", 0.13, skin, parent=root, loc=(0.01, 0, 1.74), scale=(0.95, 0.88, 1.05)))
        part(ball("hair", 0.14, hairm, parent=root, loc=(-0.03, 0, 1.79), scale=(1.0, 0.98, 0.85)), "hair")
        part(ball("hairback", 0.11, hairm, parent=root, loc=(-0.09, 0, 1.64), scale=(0.75, 1.15, 1.3)), "hair")
        part(box("moustache", 0.04, 0.13, 0.03, hairm, parent=root, loc=(0.125, 0, 1.68)), "hair")
        for side, y in (("L", 0.28), ("R", -0.28)):
            sh = empty("sho" + side, root, (0, y, 1.46), (math.radians(8 if side == "L" else -8), 0, 0))
            self.sho[side] = sh
            part(cyl("upper", 0.075, 0.065, -0.32, gray, seg=8, parent=sh), "tunic")
            part(cyl("fore", 0.058, 0.05, -0.3, skin, seg=8, z0=-0.31, parent=sh))
            part(ball("hand", 0.06, skin, parent=sh, loc=(0, 0, -0.64)))
        self.hand_r = empty("handR", self.sho["R"], (0, 0, -0.64))
        self.hand_l = empty("handL", self.sho["L"], (0, 0, -0.6))
        # Held things.
        self.items = {}
        sw = empty("sword", self.hand_r, rot=(0, math.radians(-35), 0))
        cyl("grip", 0.025, 0.025, 0.14, leather, seg=6, parent=sw, loc=(0, 0, 0), rot=(0, math.radians(90), 0))
        box("guard", 0.03, 0.16, 0.03, iron, parent=sw, loc=(0.08, 0, -0.015))
        box("blade", 0.78, 0.055, 0.015, steel, x0=0.09, parent=sw, loc=(0, 0, -0.008))
        ball("pommel", 0.035, iron, sub=1, parent=sw, loc=(-0.08, 0, 0))
        self.items["sword"] = sw
        sp = empty("spear", self.hand_r, rot=(0, math.radians(8), 0))
        cyl("shaft", 0.025, 0.025, 2.4, wood, seg=6, z0=-0.85, parent=sp)
        cyl("head", 0.045, 0.0, 0.32, steel, seg=6, z0=1.55, parent=sp, scale=(0.5, 1, 1))
        self.items["spear"] = sp
        sh = empty("shield", self.hand_l, (0.08, 0.1, 0.2), (0, 0, math.radians(25)))
        board = mat("board", NEUTRAL, "#a8a8a8", scale=10, bump=0.2)
        b = cyl("board", 0.5, 0.5, 0.04, board, seg=24, parent=sh, rot=(math.radians(90), 0, 0), scale=(0.62, 1.0, 1.0))
        self.mask_parts[b] = "board"
        box("spine", 0.06, 0.03, 0.85, wood, parent=sh, loc=(0, 0.035, -0.42))
        ball("boss", 0.09, iron, parent=sh, loc=(0, 0.04, 0), scale=(1.3, 0.6, 1.0))
        self.items["shield"] = sh
        ss = empty("small_shield", self.hand_l, (0.06, 0.1, 0.05), (0, 0, math.radians(25)))
        b2 = cyl("board", 0.3, 0.3, 0.035, board, seg=20, parent=ss, rot=(math.radians(90), 0, 0))
        self.mask_parts[b2] = "board"
        ball("boss", 0.07, iron, parent=ss, loc=(0, 0.03, 0), scale=(1, 0.6, 1))
        self.items["small_shield"] = ss
        self._mats = {}

    def pose(self, facing, step):
        self.root.rotation_euler = (0, 0, math.radians(60 * facing))
        self.root.location = (0, 0, 0)
        sw = math.radians(24) * step
        self.hip["L"].rotation_euler = (0, -sw, 0)
        self.hip["R"].rotation_euler = (0, sw, 0)
        self.sho["L"].rotation_euler = (math.radians(8), sw * 0.7, 0)
        self.sho["R"].rotation_euler = (math.radians(-8), -sw * 0.5 - math.radians(12), 0)
        self.root.location.z = 0.02 * abs(step)

    def lie(self):
        self.pose(0, 0)
        # On its back, head to the west-south-west, centered on the hex.
        self.root.rotation_euler = (0, math.radians(-88), math.radians(15))
        self.root.location = (0.87, 0.23, 0.16)

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


def render_figure():
    new_scene(48)
    frame(*FIG_FRAME)
    f = Figure()
    items = list(f.items.values())
    layers = [("body", None)] + [(k, v) for k, v in f.items.items()]
    for name, item in layers:
        # The body renders alone; each held thing renders with the body as a
        # holdout, so the game can stack them in any combination.
        show(items, False)
        for ob in f.body:
            ob.is_holdout = item is not None
        if item is not None:
            show([item], True)
        masked = name in ("body", "shield", "small_shield")
        for mode in (["lit", "mask"] if masked else ["lit"]):
            f.mask_mode(mode == "mask")
            for facing in range(6):
                for k, step in enumerate((0, 1, -1)):
                    f.pose(facing, step)
                    render(os.path.join(OUT, "figure", name, mode, "%d_%d.png" % (facing, k)))
            if name == "body":
                f.lie()
                render(os.path.join(OUT, "figure", name, mode, "down.png"))
        f.mask_mode(False)
    for ob in f.body:
        ob.is_holdout = False


GROUPS = {"walls": render_walls, "trees": render_trees, "props": render_props, "figure": render_figure}
WALL_KINDS = {"wall_wood", "palisade", "fence", "rampart", "wall_stone", "door"}
for g, fn in GROUPS.items():
    if ONLY is None or g in ONLY or (g == "walls" and ONLY & WALL_KINDS):
        fn()
print("SPRITES DONE")
