# -*- coding: utf-8 -*-
# Küchenplaner – Rendern mit Blender, Ausstattung (wird von rendern.py geladen).
#
# Alles hier entsteht in Blender aus einfachen Formen und Shader-Knoten: keine
# Bilddateien, keine fremden Modelle, kein Download.
#   * Bodenbelag: Parkett Eiche, Fliesen hell/anthrazit, Beton (statt der Bodenfarbe)
#   * Holz ohne Bild: Maserung (senkrecht), Stein ohne Bild: feine Körnung
#   * Decke über dem Raum (nur wenn die Kamera darunter steht)
#   * Deko auf der Arbeitsplatte: Schneidebrett, Obstschale, Pflanze, Flaschen,
#     Vorratsdosen, Kaffeemaschine, Kochbücher, Wasserkocher, Vase; zufällig, aber
#     wiederholbar (Variante), nicht auf Geräten (Spüle, Kochfeld), nicht über die
#     Plattenkante, eher hinten (weg von der Kamera)
#   * Pendelleuchten über jeder Insel

import math
import random

# --- Hilfen ------------------------------------------------------------------------


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(*c):
    return [lin(x) for x in c] + [1.0]


def bsdf_von(mat):
    for n in mat.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED":
            return n
    return None


def eingang(knoten, *namen):
    for n in namen:
        s = knoten.inputs.get(n)
        if s is not None:
            return s
    return None


def koordinaten(nt):
    """Objektkoordinaten = Weltkoordinaten in Metern (die OBJ-Szene liegt im Ursprung)."""
    tc = nt.nodes.new("ShaderNodeTexCoord")
    return tc.outputs["Object"]


def einfach(bpy, name, farbe, rauheit=0.5, metall=0.0, glas=False, licht=0.0):
    """Material für die Deko: Farbe (sRGB 0..1), Rauheit, Metall, Glas, Leuchten."""
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = bsdf_von(mat)
    b.inputs["Base Color"].default_value = rgb(*farbe)
    b.inputs["Roughness"].default_value = rauheit
    b.inputs["Metallic"].default_value = metall
    if glas:
        s = eingang(b, "Transmission Weight", "Transmission")
        if s is not None:
            s.default_value = 1.0
    if licht > 0:
        s = eingang(b, "Emission Color", "Emission")
        if s is not None:
            s.default_value = rgb(*farbe)
        s = eingang(b, "Emission Strength")
        if s is not None:
            s.default_value = licht
    mat.diffuse_color = rgb(*farbe)
    return mat


# --- Prozedurale Oberflächen -----------------------------------------------------


def holz_maserung(nt, bsdf, farbe):
    """Holz ohne Bild: Maserung senkrecht (wie bei Fronten), Farbe bleibt die Grundfarbe."""
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (40.0, 40.0, 2.5)
    nt.links.new(koordinaten(nt), mp.inputs["Vector"])
    welle = nt.nodes.new("ShaderNodeTexWave")
    welle.inputs["Scale"].default_value = 1.0
    welle.inputs["Distortion"].default_value = 6.0
    welle.inputs["Detail"].default_value = 3.0
    nt.links.new(mp.outputs["Vector"], welle.inputs["Vector"])
    rampe = nt.nodes.new("ShaderNodeValToRGB")
    r, g, b = [lin(x) for x in farbe[:3]]
    rampe.color_ramp.elements[0].color = (r * 0.72, g * 0.68, b * 0.62, 1.0)
    rampe.color_ramp.elements[1].color = (r, g, b, 1.0)
    nt.links.new(welle.outputs["Fac"], rampe.inputs["Fac"])
    nt.links.new(rampe.outputs["Color"], bsdf.inputs["Base Color"])


def stein_koernung(nt, bsdf, farbe):
    """Stein/Quarz ohne Bild: feine helle und dunkle Körner."""
    rausch = nt.nodes.new("ShaderNodeTexNoise")
    rausch.inputs["Scale"].default_value = 260.0
    rausch.inputs["Detail"].default_value = 8.0
    nt.links.new(koordinaten(nt), rausch.inputs["Vector"])
    rampe = nt.nodes.new("ShaderNodeValToRGB")
    r, g, b = [lin(x) for x in farbe[:3]]
    rampe.color_ramp.elements[0].position = 0.35
    rampe.color_ramp.elements[0].color = (r * 0.75, g * 0.75, b * 0.75, 1.0)
    rampe.color_ramp.elements[1].position = 0.65
    rampe.color_ramp.elements[1].color = (min(1, r * 1.15), min(1, g * 1.15), min(1, b * 1.15), 1.0)
    nt.links.new(rausch.outputs["Fac"], rampe.inputs["Fac"])
    nt.links.new(rampe.outputs["Color"], bsdf.inputs["Base Color"])


BODEN = {
    # Art: (Farbe 1, Farbe 2, Fuge, Breite, Höhe, Fugenbreite, Versatz, Rauheit)
    "parkett": ((0.62, 0.45, 0.28), (0.55, 0.38, 0.22), (0.30, 0.20, 0.12), 1.2, 0.18, 0.0015, 0.5, 0.3),
    "fliesen_hell": ((0.86, 0.85, 0.82), (0.82, 0.81, 0.78), (0.70, 0.69, 0.66), 0.6, 0.6, 0.003, 0.0, 0.35),
    "fliesen_dunkel": ((0.20, 0.20, 0.21), (0.24, 0.24, 0.25), (0.35, 0.35, 0.35), 0.6, 0.6, 0.003, 0.0, 0.4),
    "beton": None,
}


def boden_material(bpy, mat, art):
    """Bodenbelag statt Bodenfarbe (Fliesen-/Dielenraster über den Brick-Knoten)."""
    mat.use_nodes = True
    nt = mat.node_tree
    b = bsdf_von(mat)
    if b is None:
        return
    if art == "beton":
        rausch = nt.nodes.new("ShaderNodeTexNoise")
        rausch.inputs["Scale"].default_value = 3.0
        rausch.inputs["Detail"].default_value = 12.0
        nt.links.new(koordinaten(nt), rausch.inputs["Vector"])
        rampe = nt.nodes.new("ShaderNodeValToRGB")
        rampe.color_ramp.elements[0].color = rgb(0.48, 0.47, 0.45)
        rampe.color_ramp.elements[1].color = rgb(0.66, 0.65, 0.63)
        nt.links.new(rausch.outputs["Fac"], rampe.inputs["Fac"])
        nt.links.new(rampe.outputs["Color"], b.inputs["Base Color"])
        b.inputs["Roughness"].default_value = 0.6
        return
    f1, f2, fuge, breite, hoehe, fb, versatz, rauheit = BODEN[art]
    stein = nt.nodes.new("ShaderNodeTexBrick")
    stein.offset = versatz
    stein.inputs["Color1"].default_value = rgb(*f1)
    stein.inputs["Color2"].default_value = rgb(*f2)
    stein.inputs["Mortar"].default_value = rgb(*fuge)
    stein.inputs["Scale"].default_value = 1.0
    stein.inputs["Mortar Size"].default_value = fb
    stein.inputs["Brick Width"].default_value = breite
    stein.inputs["Row Height"].default_value = hoehe
    nt.links.new(koordinaten(nt), stein.inputs["Vector"])
    farbe = stein.outputs["Color"]
    if art == "parkett":  # Maserung je Diele
        mp = nt.nodes.new("ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (2.0, 60.0, 1.0)
        nt.links.new(koordinaten(nt), mp.inputs["Vector"])
        welle = nt.nodes.new("ShaderNodeTexNoise")
        welle.inputs["Scale"].default_value = 1.0
        welle.inputs["Detail"].default_value = 6.0
        nt.links.new(mp.outputs["Vector"], welle.inputs["Vector"])
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs[0].default_value = 0.35
        nt.links.new(farbe, mix.inputs[6])
        nt.links.new(welle.outputs["Color"], mix.inputs[7])
        farbe = mix.outputs[2]
    nt.links.new(farbe, b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rauheit


def oberflaechen(bpy, materialien, raum):
    """Holz/Stein ohne Bild bekommen Struktur, der Boden den gewählten Belag."""
    belag = (raum or {}).get("boden")
    for mat in bpy.data.materials:
        d = materialien.get(mat.name)
        if d is None or not mat.use_nodes:
            continue
        b = bsdf_von(mat)
        if b is None:
            continue
        if d.get("boden") and belag in BODEN:
            boden_material(bpy, mat, belag)
        elif not d.get("textur") and d.get("art") == "holz":
            holz_maserung(mat.node_tree, b, d.get("farbe", [0.6, 0.45, 0.3]))
        elif not d.get("textur") and d.get("art") == "stein":
            stein_koernung(mat.node_tree, b, d.get("farbe", [0.5, 0.5, 0.5]))


def decke_bauen(bpy, raum, kamera_z):
    """Weiße Decke über den Wänden, nur wenn die Kamera im Raum (unter der Decke) steht."""
    box = (raum or {}).get("decke")
    if not box:
        return False
    (x0, y0, z0), (x1, y1, z1) = box
    if kamera_z >= z1 - 0.05:
        return False
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=((x0 + x1) / 2, (y0 + y1) / 2, z1))
    o = bpy.context.active_object
    o.name = "Decke"
    o.scale = (x1 - x0, y1 - y0, 1.0)
    o.data.materials.append(einfach(bpy, "Deko_Decke", (0.93, 0.93, 0.92), 0.9))
    return True


def boden_fehlt(bpy, box, raster=7):
    """Liegt unter der Küche ein Boden? Strahlen knapp über der Unterkante nach unten."""
    from mathutils import Vector
    (x0, y0, z0), (x1, y1, _) = box
    dg = bpy.context.evaluated_depsgraph_get()
    treffer = 0
    for i in range(raster):
        for j in range(raster):
            x = x0 + (x1 - x0) * (i + 0.5) / raster
            y = y0 + (y1 - y0) * (j + 0.5) / raster
            if bpy.context.scene.ray_cast(dg, Vector((x, y, z0 + 0.01)), Vector((0, 0, -1)), distance=0.05)[0]:
                treffer += 1
    return treffer < 0.6 * raster * raster


def boden_ergaenzen(bpy, daten):
    """Ohne Boden im Modell sähe die Kamera nur den flachen Hintergrund (grau, ohne Schatten):
    dann eine Bodenfläche unter die Küche legen, im gewählten Belag (sonst Parkett)."""
    box = daten.get("box")
    if not box or not boden_fehlt(bpy, box):
        return False
    raum = (daten.get("raum") or {}).get("decke")
    (x0, y0, z0), (x1, y1, _) = raum or [[box[0][0] - 4, box[0][1] - 4, 0], [box[1][0] + 4, box[1][1] + 4, 0]]
    bpy.ops.mesh.primitive_plane_add(size=1.0, location=((x0 + x1) / 2, (y0 + y1) / 2, box[0][2]))
    o = bpy.context.active_object
    o.name = "Boden"
    o.scale = (x1 - x0, y1 - y0, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)  # Belag in Metern
    mat = einfach(bpy, "Deko_Boden", (0.6, 0.6, 0.6), 0.5)
    art = (daten.get("raum") or {}).get("boden")
    boden_material(bpy, mat, art if art in BODEN else "parkett")
    o.data.materials.append(mat)
    return True


# --- Deko ------------------------------------------------------------------------------


def teil(bpy, art, ort, mat, **kw):
    """Grundform anlegen: art = cube, cylinder, sphere, cone, torus; ort relativ zur Gruppe."""
    ops = {"cube": bpy.ops.mesh.primitive_cube_add, "cylinder": bpy.ops.mesh.primitive_cylinder_add,
           "sphere": bpy.ops.mesh.primitive_uv_sphere_add, "cone": bpy.ops.mesh.primitive_cone_add,
           "torus": bpy.ops.mesh.primitive_torus_add}
    skala = kw.pop("skala", None)
    dreh = kw.pop("dreh", None)
    glatt = kw.pop("glatt", art in ("cylinder", "sphere", "cone", "torus"))
    ops[art](location=ort, **kw)
    o = bpy.context.active_object
    if skala:
        o.scale = skala
    if dreh:
        o.rotation_euler = dreh
    if glatt:
        try:
            bpy.ops.object.shade_smooth()
        except RuntimeError:
            pass
    o.data.materials.append(mat)
    return o


def gruppe(bpy, name, teile, ort, winkel):
    leer = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(leer)
    for t in teile:
        t.parent = leer
    leer.location = ort
    leer.rotation_euler = (0.0, 0.0, winkel)
    return leer


def schneidebrett(bpy, rng):
    holz = einfach(bpy, "Deko_Holz", (0.62, 0.43, 0.25), 0.5)
    t = [teil(bpy, "cube", (0, 0, 0.01), holz, size=1.0, skala=(0.40, 0.26, 0.02))]
    t[0].modifiers.new("Kante", "BEVEL").width = 0.006
    return t


def obstschale(bpy, rng):
    keramik = einfach(bpy, "Deko_Keramik", (0.92, 0.91, 0.88), 0.25)
    schale = teil(bpy, "sphere", (0, 0, 0.075), keramik, radius=0.13, segments=48, ring_count=24, skala=(1, 1, 0.55))
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(schale.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 0.0001], context="VERTS")
    bm.to_mesh(schale.data)
    bm.free()
    schale.modifiers.new("Wand", "SOLIDIFY").thickness = 0.008
    farben = [(0.75, 0.08, 0.05), (0.95, 0.55, 0.05), (0.55, 0.75, 0.15), (0.85, 0.15, 0.08), (0.95, 0.8, 0.2)]
    t = [schale]
    for i in range(5):
        w = i * 2 * math.pi / 5 + rng.random() * 0.3
        f = einfach(bpy, "Deko_Obst_%d" % i, farben[i], 0.35)
        t.append(teil(bpy, "sphere", (math.cos(w) * 0.055, math.sin(w) * 0.055, 0.075 + (i % 2) * 0.015), f,
                      radius=0.037, segments=24, ring_count=12))
    return t


def pflanze(bpy, rng):
    topf = einfach(bpy, "Deko_Topf", rng.choice([(0.72, 0.38, 0.24), (0.9, 0.9, 0.88), (0.2, 0.2, 0.2)]), 0.6)
    gruen = einfach(bpy, "Deko_Blatt", (0.18, 0.42, 0.14), 0.45)
    erde = einfach(bpy, "Deko_Erde", (0.18, 0.12, 0.08), 0.9)
    t = [teil(bpy, "cylinder", (0, 0, 0.07), topf, radius=0.07, depth=0.14, vertices=32),
         teil(bpy, "cylinder", (0, 0, 0.135), erde, radius=0.065, depth=0.01, vertices=32)]
    for i in range(16):
        w = i * 2.4 + rng.random() * 0.4
        neig = 0.35 + 0.5 * (i % 4) / 3.0
        laenge = 0.09 + rng.random() * 0.05
        x, y = math.cos(w) * laenge * 0.6 * math.sin(neig), math.sin(w) * laenge * 0.6 * math.sin(neig)
        t.append(teil(bpy, "sphere", (x, y, 0.14 + laenge * 0.8 * math.cos(neig)), gruen, radius=1.0, segments=12,
                      ring_count=8, skala=(0.022, 0.006, laenge), dreh=(neig * math.sin(w), -neig * math.cos(w), w)))
    return t


def flaschen(bpy, rng):
    glas = einfach(bpy, "Deko_Glas_gruen", (0.35, 0.55, 0.35), 0.05, glas=True)
    oel = einfach(bpy, "Deko_Glas_klar", (0.95, 0.9, 0.7), 0.03, glas=True)
    t = []
    for i, (m, h) in enumerate(((glas, 0.24), (oel, 0.19))):
        x = (i - 0.5) * 0.08
        t.append(teil(bpy, "cylinder", (x, 0, h * 0.35), m, radius=0.032, depth=h * 0.7, vertices=32))
        t.append(teil(bpy, "cone", (x, 0, h * 0.78), m, radius1=0.032, radius2=0.012, depth=h * 0.17, vertices=32))
        t.append(teil(bpy, "cylinder", (x, 0, h * 0.93), m, radius=0.012, depth=h * 0.14, vertices=16))
    return t


def dosen(bpy, rng):
    dose = einfach(bpy, "Deko_Dose", rng.choice([(0.9, 0.9, 0.88), (0.25, 0.27, 0.3)]), 0.35)
    holz = einfach(bpy, "Deko_Holz", (0.62, 0.43, 0.25), 0.5)
    t = []
    for i, h in enumerate((0.20, 0.16, 0.12)):
        x = (i - 1) * 0.105
        t.append(teil(bpy, "cylinder", (x, 0, h / 2), dose, radius=0.05, depth=h, vertices=40))
        t.append(teil(bpy, "cylinder", (x, 0, h + 0.008), holz, radius=0.051, depth=0.016, vertices=40))
    return t


def kaffeemaschine(bpy, rng):
    schwarz = einfach(bpy, "Deko_Schwarz", (0.03, 0.03, 0.03), 0.2)
    stahl = einfach(bpy, "Deko_Stahl", (0.8, 0.8, 0.8), 0.25, metall=1.0)
    tasse = einfach(bpy, "Deko_Keramik", (0.92, 0.91, 0.88), 0.25)
    t = [teil(bpy, "cube", (0, 0.03, 0.18), schwarz, size=1.0, skala=(0.24, 0.30, 0.36)),
         teil(bpy, "cube", (0, -0.121, 0.24), stahl, size=1.0, skala=(0.2, 0.004, 0.14)),
         teil(bpy, "cube", (0, -0.10, 0.012), stahl, size=1.0, skala=(0.2, 0.08, 0.024)),
         teil(bpy, "cylinder", (0, -0.10, 0.065), tasse, radius=0.035, depth=0.075, vertices=32)]
    for o in t[:3]:
        o.modifiers.new("Kante", "BEVEL").width = 0.01
    return t


def buecher(bpy, rng):
    farben = [(0.55, 0.12, 0.1), (0.15, 0.3, 0.45), (0.85, 0.75, 0.55), (0.25, 0.4, 0.25)]
    rng.shuffle(farben)
    t = []
    for i in range(3):
        m = einfach(bpy, "Deko_Buch_%d" % i, farben[i], 0.7)
        o = teil(bpy, "cube", (0, 0, 0.015 + i * 0.031), m, size=1.0, skala=(0.24 - i * 0.02, 0.17 - i * 0.01, 0.03))
        o.rotation_euler = (0, 0, (rng.random() - 0.5) * 0.3)
        t.append(o)
    return t


def wasserkocher(bpy, rng):
    stahl = einfach(bpy, "Deko_Stahl", (0.8, 0.8, 0.8), 0.25, metall=1.0)
    schwarz = einfach(bpy, "Deko_Schwarz", (0.03, 0.03, 0.03), 0.2)
    return [teil(bpy, "cylinder", (0, 0, 0.01), schwarz, radius=0.085, depth=0.02, vertices=40),
            teil(bpy, "cylinder", (0, 0, 0.12), stahl, radius=0.075, depth=0.2, vertices=40),
            teil(bpy, "torus", (0.075, 0, 0.13), schwarz, major_radius=0.06, minor_radius=0.01,
                 dreh=(math.pi / 2, 0, 0))]


def vase(bpy, rng):
    glas = einfach(bpy, "Deko_Glas_klar", (0.95, 0.9, 0.7), 0.03, glas=True)
    stiel = einfach(bpy, "Deko_Blatt", (0.18, 0.42, 0.14), 0.45)
    bluete = einfach(bpy, "Deko_Bluete", rng.choice([(0.9, 0.2, 0.3), (0.95, 0.85, 0.3), (0.95, 0.95, 0.95)]), 0.5)
    t = [teil(bpy, "cylinder", (0, 0, 0.1), glas, radius=0.05, depth=0.2, vertices=40)]
    for i in range(5):
        w = i * 2 * math.pi / 5
        x, y = math.cos(w) * 0.03, math.sin(w) * 0.03
        t.append(teil(bpy, "cylinder", (x * 1.5, y * 1.5, 0.2), stiel, radius=0.003, depth=0.3, vertices=8,
                      dreh=(-y * 3, x * 3, 0)))
        t.append(teil(bpy, "sphere", (x * 3, y * 3, 0.35 + (i % 2) * 0.03), bluete, radius=0.028, segments=16, ring_count=8))
    return t


# Name, Radius der Standfläche (m), Bauplan; Reihenfolge = Vorrang bei wenig Deko
DEKO = [("Schneidebrett", 0.22, schneidebrett), ("Obstschale", 0.14, obstschale), ("Pflanze", 0.12, pflanze),
        ("Kaffeemaschine", 0.2, kaffeemaschine), ("Flaschen", 0.09, flaschen), ("Vorratsdosen", 0.17, dosen),
        ("Kochbuecher", 0.15, buecher), ("Wasserkocher", 0.1, wasserkocher), ("Vase", 0.11, vase)]


def in_dreieck(p, d):
    (ax, ay, _), (bx, by, _), (cx, cy, _) = d
    def s(x1, y1, x2, y2, x3, y3):
        return (x1 - x3) * (y2 - y3) - (x2 - x3) * (y1 - y3)
    d1, d2, d3 = s(p[0], p[1], ax, ay, bx, by), s(p[0], p[1], bx, by, cx, cy), s(p[0], p[1], cx, cy, ax, ay)
    neg = d1 < 0 or d2 < 0 or d3 < 0
    pos = d1 > 0 or d2 > 0 or d3 > 0
    return not (neg and pos)


def auf_platte(p, z, dreiecke):
    return any(abs(d[0][2] - z) < 0.003 and in_dreieck(p, d) for d in dreiecke)


def platz_frei(x, y, z, r, dreiecke, geraete, belegt):
    """Ganze Standfläche (Kreis r + 4 cm) auf der Platte, nicht auf Geräten, nicht auf anderer Deko."""
    rand = r + 0.04
    for i in range(12):
        w = i * math.pi / 6
        if not auf_platte((x + math.cos(w) * rand, y + math.sin(w) * rand), z, dreiecke):
            return False
    for (gmin, gmax, *_rest) in geraete:
        if gmax[2] < z - 0.08 or gmin[2] > z + 0.6:
            continue
        if gmin[0] - rand < x < gmax[0] + rand and gmin[1] - rand < y < gmax[1] + rand:
            return False
    return all(math.hypot(x - bx, y - by) > r + br + 0.05 for bx, by, br in belegt)


def flaeche(d):
    (ax, ay, _), (bx, by, _), (cx, cy, _) = d
    return abs((bx - ax) * (cy - ay) - (cx - ax) * (by - ay)) / 2


def deko_verteilen(bpy, deko, auge):
    """Gegenstände auf freie Stellen der Arbeitsplatte stellen; liefert die Namen."""
    dreiecke = deko.get("arbeitsflaechen") or []
    anzahl = int(deko.get("anzahl", 0))
    if not dreiecke or anzahl <= 0:
        return []
    rng = random.Random(int(deko.get("variante", 1)) * 7919)
    geraete = deko.get("geraete") or []
    gewichte = [flaeche(d) for d in dreiecke]
    plan = DEKO[:3] + rng.sample(DEKO[3:], len(DEKO) - 3)  # Brett, Obst, Pflanze zuerst
    belegt, gestellt = [], []
    for name, r, bau in plan:
        if len(gestellt) >= anzahl:
            break
        bester = None
        for _ in range(300):
            d = rng.choices(dreiecke, weights=gewichte)[0]
            a, b = rng.random(), rng.random()
            if a + b > 1:
                a, b = 1 - a, 1 - b
            x = d[0][0] + a * (d[1][0] - d[0][0]) + b * (d[2][0] - d[0][0])
            y = d[0][1] + a * (d[1][1] - d[0][1]) + b * (d[2][1] - d[0][1])
            z = d[0][2]
            if not platz_frei(x, y, z, r, dreiecke, geraete, belegt):
                continue
            # eher hinten an der Wand (weit weg von der Kamera), nicht alles auf einem Haufen, etwas Zufall
            abstand = min([math.hypot(x - bx, y - by) for bx, by, _ in belegt] or [1.0])
            wert = math.hypot(x - auge[0], y - auge[1]) + 0.6 * min(abstand, 1.0) + rng.random() * 0.4
            if bester is None or wert > bester[0]:
                bester = (wert, x, y, z)
        if bester is None:
            continue
        _, x, y, z = bester
        gruppe(bpy, "Deko_" + name, bau(bpy, rng), (x, y, z), rng.random() * 2 * math.pi)
        belegt.append((x, y, r))
        gestellt.append(name)
    return gestellt


def pendelleuchten(bpy, inseln, dreiecke, decke_z):
    """Zwei (ab 1,6 m Länge drei) Pendelleuchten über jeder Insel, 75 cm über der Platte."""
    schirm = einfach(bpy, "Deko_Leuchte", (0.05, 0.05, 0.05), 0.35, metall=1.0)
    birne = einfach(bpy, "Deko_Birne", (1.0, 0.85, 0.65), 0.5, licht=25.0)
    n = 0
    for (x0, y0, z0), (x1, y1, z1), *_ in inseln:
        oben = z1
        for d in dreiecke:  # Arbeitsplatte über der Insel
            if all(x0 - 0.05 <= p[0] <= x1 + 0.05 and y0 - 0.05 <= p[1] <= y1 + 0.05 for p in d):
                oben = max(oben, d[0][2])
        lang_x = (x1 - x0) >= (y1 - y0)
        laenge = (x1 - x0) if lang_x else (y1 - y0)
        stueck = 3 if laenge >= 1.6 else 2
        unten = oben + 0.75
        decke = decke_z if decke_z and decke_z > unten + 0.3 else unten + 1.2
        for i in range(stueck):
            f = (i + 1) / (stueck + 1)
            x = x0 + (x1 - x0) * f if lang_x else (x0 + x1) / 2
            y = (y0 + y1) / 2 if lang_x else y0 + (y1 - y0) * f
            teil(bpy, "cylinder", (x, y, (unten + 0.18 + decke) / 2), schirm, radius=0.003,
                 depth=decke - unten - 0.18, vertices=8)
            s = teil(bpy, "cone", (x, y, unten + 0.09), schirm, radius1=0.14, radius2=0.025, depth=0.18, vertices=48)
            s.modifiers.new("Wand", "SOLIDIFY").thickness = 0.003
            teil(bpy, "sphere", (x, y, unten + 0.05), birne, radius=0.03, segments=16, ring_count=8)
            ld = bpy.data.lights.new("Pendel_%d" % (n + 1), "POINT")
            ld.energy = 25.0
            ld.color = (1.0, 0.82, 0.62)
            ld.shadow_soft_size = 0.03
            lo = bpy.data.objects.new("Pendel_%d" % (n + 1), ld)
            lo.location = (x, y, unten + 0.04)
            bpy.context.scene.collection.objects.link(lo)
            n += 1
    return n


def ausstatten(bpy, daten, melden):
    """Alles aus diesem Modul nach dem Laden der OBJ-Szene; meldet, was dazukam."""
    kamera = daten.get("kamera", {})
    auge = kamera.get("auge", [0, 0, 1.6])
    raum = daten.get("raum") or {}
    oberflaechen(bpy, daten.get("materialien", {}), raum)
    decke = decke_bauen(bpy, raum, auge[2])
    boden = boden_ergaenzen(bpy, daten)
    deko = daten.get("deko") or {}
    gestellt = deko_verteilen(bpy, deko, auge)
    decke_z = raum["decke"][1][2] if decke else None
    pendel = pendelleuchten(bpy, deko.get("inseln") or [], deko.get("arbeitsflaechen") or [], decke_z) \
        if deko.get("pendel") else 0
    melden("STATUS", "Ausstattung: %s%s%s%s" % (", ".join(gestellt) or "keine Deko",
                                             ", %d Pendelleuchten" % pendel if pendel else "",
                                             ", Decke" if decke else "",
                                             ", Boden ergänzt" if boden else ""))
    return {"deko": gestellt, "pendel": pendel, "decke": decke, "boden": boden}
