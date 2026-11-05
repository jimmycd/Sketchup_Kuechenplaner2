# -*- coding: utf-8 -*-
# Küchenplaner – Rendern mit Blender (Cycles), Teil 2 von 2.
#
# Wird vom Plugin (rendern.rb) im Hintergrund gestartet:
#   blender -b --factory-startup -P rendern.py -- szene.json
# szene.json beschreibt alles, was SketchUp exportiert hat: OBJ-Datei (Meter, Z oben),
# Materialien mit Art (glas, metall, hochglanz, holz, matt, standard), Kamera,
# Sonne, Licht und Bildgröße. Das Skript baut daraus eine Blender-Szene, rendert
# mit Cycles (GPU, falls vorhanden, sonst CPU), speichert das PNG und auf Wunsch
# die .blend-Datei zum Weiterbearbeiten.
#
# Ausgaben für das Plugin, eine Zeile je Meldung, in kp_status.txt neben szene.json
# (und auf der Konsole). Blender 5 unter Windows schreibt seine Ausgabe in ein eigenes
# Konsolenfenster statt in die umgeleitete Log-Datei, deshalb eine eigene Datei:
#   KP_PID <Prozessnummer>  dieser Blender-Prozess (zum Abbrechen)
#   KP_STATUS <Text>        Schritt
#   KP_SAMPLE <n>/<gesamt>  Render-Fortschritt
#   KP_FERTIG <Bilddatei>   erfolgreich gerendert
#   KP_FEHLER <Text>        abgebrochen

import json
import math
import os
import sys
import traceback


STATUS = {"datei": None, "sample": None}


def melden(art, text):
    zeile = "KP_%s %s" % (art, text)
    print(zeile, flush=True)
    if STATUS["datei"]:
        with open(STATUS["datei"], "a", encoding="utf-8") as f:
            f.write(zeile + "\n")


def stats_beobachten(bpy):
    """Render-Fortschritt („Sample 12/128“) aus den Statistiken in die Statusdatei."""
    import re

    def stats(text, *_):
        m = re.search(r"Sample (\d+)/(\d+)", str(text))
        if m and m.group(0) != STATUS["sample"]:
            STATUS["sample"] = m.group(0)
            melden("SAMPLE", "%s/%s" % (m.group(1), m.group(2)))

    try:
        bpy.app.handlers.render_stats.append(stats)
    except AttributeError:
        pass


def argumente(argv):
    """Pfad der szene.json: das erste Argument nach '--'."""
    if "--" in argv:
        rest = argv[argv.index("--") + 1:]
    else:
        rest = argv[1:]
    if not rest:
        raise SystemExit("Aufruf: blender -b -P rendern.py -- szene.json")
    return rest[0]


# --- Materialien --------------------------------------------------------------
# Werte für den Principled BSDF je Art (Rauheit, Metall, Klarlack, Transmission)
ARTEN = {
    "standard": {"roughness": 0.45, "metallic": 0.0, "coat": 0.0},
    "matt": {"roughness": 0.85, "metallic": 0.0, "coat": 0.0},
    "hochglanz": {"roughness": 0.06, "metallic": 0.0, "coat": 0.6},
    "holz": {"roughness": 0.55, "metallic": 0.0, "coat": 0.0},
    "metall": {"roughness": 0.22, "metallic": 1.0, "coat": 0.0},
    "glas": {"roughness": 0.02, "metallic": 0.0, "coat": 0.0, "transmission": 1.0, "ior": 1.45},
    "schwarzglas": {"roughness": 0.03, "metallic": 0.0, "coat": 1.0},
    "stein": {"roughness": 0.3, "metallic": 0.0, "coat": 0.2},
    "licht": {"roughness": 0.5, "metallic": 0.0, "coat": 0.0, "emission": 8.0},
}


def eingang(bsdf, *namen):
    """Socket nach Namen (Blender 3.x und 4.x/5.x heißen manche anders)."""
    for n in namen:
        s = bsdf.inputs.get(n)
        if s is not None:
            return s
    return None


def setzen(bsdf, wert, *namen):
    s = eingang(bsdf, *namen)
    if s is not None:
        s.default_value = wert


def srgb_linear(c):
    """SketchUp-Farben sind sRGB, Blender rechnet linear."""
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material_bauen(bpy, mat, daten, ordner, kanten=0.0):
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    aus = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    aus.location = (300, 0)
    nt.links.new(bsdf.outputs[0], aus.inputs["Surface"])
    art = ARTEN.get(daten.get("art", "standard"), ARTEN["standard"])
    farbe = [srgb_linear(float(c)) for c in daten.get("farbe", [0.8, 0.8, 0.8])] + [1.0]
    setzen(bsdf, farbe, "Base Color")
    setzen(bsdf, art["roughness"], "Roughness")
    setzen(bsdf, art["metallic"], "Metallic")
    setzen(bsdf, art["coat"], "Coat Weight", "Clearcoat")
    if "transmission" in art:
        setzen(bsdf, art["transmission"], "Transmission Weight", "Transmission")
        setzen(bsdf, art["ior"], "IOR")
    if "emission" in art:
        setzen(bsdf, farbe, "Emission Color", "Emission")
        setzen(bsdf, art["emission"], "Emission Strength")
    alpha = float(daten.get("alpha", 1.0))
    if alpha < 0.999 and "transmission" not in art:
        setzen(bsdf, alpha, "Alpha")
        if hasattr(mat, "blend_method"):
            try:
                mat.blend_method = "BLEND"
            except (AttributeError, TypeError):
                pass
    textur = daten.get("textur")
    if textur:
        pfad = os.path.join(ordner, textur)
        if os.path.exists(pfad):
            bild = nt.nodes.new("ShaderNodeTexImage")
            bild.location = (-400, 0)
            bild.image = bpy.data.images.load(pfad, check_existing=True)
            nt.links.new(bild.outputs["Color"], eingang(bsdf, "Base Color"))
    # leicht gerundete Kanten (nur im Licht, Geometrie bleibt): keine scharfen CAD-Kanten
    if kanten > 0 and "transmission" not in art:
        bevel = nt.nodes.new("ShaderNodeBevel")
        bevel.location = (-200, -300)
        bevel.samples = 4
        bevel.inputs["Radius"].default_value = kanten
        normal = eingang(bsdf, "Normal")
        if normal is not None:
            nt.links.new(bevel.outputs["Normal"], normal)
    mat.diffuse_color = farbe  # Farbe in der Blender-Ansicht


# --- Szene ----------------------------------------------------------------------

def obj_laden(bpy, pfad):
    """OBJ in Metern mit Z nach oben, so wie rendern.rb sie schreibt."""
    if hasattr(bpy.ops.wm, "obj_import"):
        bpy.ops.wm.obj_import(filepath=pfad, forward_axis="Y", up_axis="Z")
    else:  # Blender bis 3.x
        bpy.ops.import_scene.obj(filepath=pfad, axis_forward="Y", axis_up="Z")


def ausrichten(obj, richtung, Vector):
    """Objekt so drehen, dass seine -Z-Achse in richtung zeigt (Kamera, Licht)."""
    v = Vector(richtung)
    if v.length < 1e-9:
        return
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = v.to_track_quat("-Z", "Y")


def kamera_bauen(bpy, daten, Vector):
    k = daten["kamera"]
    cam_data = bpy.data.cameras.new("Kamera")
    cam = bpy.data.objects.new("Kamera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    auge, ziel, oben = Vector(k["auge"]), Vector(k["ziel"]), Vector(k["oben"])
    cam.location = auge
    blick = (ziel - auge).normalized()
    # Rotation aus Blickrichtung und Oben-Vektor der SketchUp-Kamera
    rechts = blick.cross(oben).normalized()
    hoch = rechts.cross(blick).normalized()
    from mathutils import Matrix
    m = Matrix((rechts, hoch, -blick)).transposed()
    cam.rotation_mode = "QUATERNION"
    cam.rotation_quaternion = m.to_quaternion()
    breite, hoehe = daten["bild"]["breite"], daten["bild"]["hoehe"]
    if k.get("perspektive", True):
        cam_data.type = "PERSP"
        cam_data.sensor_fit = "VERTICAL" if k.get("fov_hoehe", True) else "HORIZONTAL"
        cam_data.angle = math.radians(float(k["fov"]))
    else:
        cam_data.type = "ORTHO"
        # SketchUp: Höhe der Ansicht; Blender: größere Seite
        cam_data.ortho_scale = float(k["hoehe"]) * max(1.0, breite / float(hoehe))
    if k.get("perspektive", True) and k.get("senkrecht"):
        zweipunkt(cam, cam_data, auge, blick, breite, hoehe, Vector)
    cam_data.clip_start = 0.01
    cam_data.clip_end = 1000.0
    bpy.context.scene.camera = cam
    return cam


def zweipunkt(cam, cam_data, auge, blick, breite, hoehe, Vector):
    """Zweipunktperspektive: Kamera waagrecht stellen, die Neigung über den Objektiv-Shift
    ausgleichen. Senkrechte Kanten (Schrankseiten, Wände) bleiben im Bild senkrecht."""
    waag = Vector((blick.x, blick.y, 0.0))
    if waag.length < 1e-6:
        return
    neigung = math.atan2(blick.z, waag.length)
    if abs(neigung) > math.radians(40):  # steil von oben: lieber normal lassen
        return
    waag.normalize()
    rechts = waag.cross(Vector((0.0, 0.0, 1.0))).normalized()
    hoch = rechts.cross(waag).normalized()
    from mathutils import Matrix
    cam.rotation_quaternion = Matrix((rechts, hoch, -waag)).transposed().to_quaternion()
    # Shift in Bruchteilen der größeren Bildseite; Bildhöhe entspricht 2·tan(fov/2)
    halb = math.tan(cam_data.angle / 2.0)
    if cam_data.sensor_fit == "HORIZONTAL":
        halb *= hoehe / float(breite)  # angle gilt für die Breite
    hoehe_einheiten = 2.0 * halb
    groesser = hoehe_einheiten * max(1.0, breite / float(hoehe))
    cam_data.shift_y = math.tan(neigung) / groesser


def umgebung_laden(bpy, welt, datei, staerke, hintergrund=None):
    """HDRI aus Blenders eigenen Dateien als Umgebung (Licht und Spiegelungen)."""
    try:
        ordner = bpy.utils.system_resource("DATAFILES", path="studiolights/world")
    except (TypeError, AttributeError):
        return False
    pfad = os.path.join(ordner or "", datei)
    if not os.path.exists(pfad):
        return False
    nt = welt.node_tree
    hg = nt.nodes.get("Background")
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(pfad, check_existing=True)
    nt.links.new(env.outputs["Color"], hg.inputs["Color"])
    hg.inputs["Strength"].default_value = staerke
    # Die Kamera sieht dahinter nur einen hellen, ruhigen Hintergrund; das HDRI liefert
    # Licht und Spiegelungen (sonst stünde die Küche z. B. vor einem fremden Wohnzimmer)
    if hintergrund is not None:
        flach = nt.nodes.new("ShaderNodeBackground")
        flach.inputs["Color"].default_value = [srgb_linear(x) for x in hintergrund] + [1.0]
        weg = nt.nodes.new("ShaderNodeLightPath")
        mix = nt.nodes.new("ShaderNodeMixShader")
        aus = nt.nodes.get("World Output")
        nt.links.new(weg.outputs["Is Camera Ray"], mix.inputs[0])
        nt.links.new(hg.outputs[0], mix.inputs[1])
        nt.links.new(flach.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], aus.inputs["Surface"])
    return True


def led_bauen(bpy, leds, staerke):
    """Warmweiße LED-Leisten als Flächenlicht unter jedem Oberschrank (nach unten)."""
    for i, (x0, y0, x1, y1, z) in enumerate(leds):
        ld = bpy.data.lights.new("LED_%d" % (i + 1), "AREA")
        ld.shape = "RECTANGLE"
        ld.size = max(0.05, x1 - x0 - 0.04)
        ld.size_y = max(0.05, y1 - y0 - 0.04)
        ld.color = (1.0, 0.82, 0.62)  # ca. 3000 K
        ld.energy = staerke * ld.size * ld.size_y
        lo = bpy.data.objects.new("LED_%d" % (i + 1), ld)
        lo.location = ((x0 + x1) / 2, (y0 + y1) / 2, z - 0.003)
        bpy.context.scene.collection.objects.link(lo)  # Flächenlicht strahlt nach -Z


def licht_bauen(bpy, daten, Vector):
    licht = daten.get("licht", {})
    sonne = licht.get("sonne")
    if sonne and sonne[2] > 0.02:
        ld = bpy.data.lights.new("Sonne", "SUN")
        ld.energy = float(licht.get("sonne_staerke", 3.0))
        ld.angle = math.radians(1.5)
        lo = bpy.data.objects.new("Sonne", ld)
        bpy.context.scene.collection.objects.link(lo)
        ausrichten(lo, [-s for s in sonne], Vector)
    box = daten.get("box")  # [[xmin, ymin, zmin], [xmax, ymax, zmax]] in m
    if licht.get("raumlicht", True) and box:
        (x0, y0, z0), (x1, y1, z1) = box
        hoehe = max(z1 + 0.3, z0 + 2.5)
        ld = bpy.data.lights.new("Raumlicht", "AREA")
        ld.shape = "RECTANGLE"
        ld.size = max(1.0, x1 - x0)
        ld.size_y = max(1.0, y1 - y0)
        ld.energy = float(licht.get("raumlicht_staerke", 60.0)) * ld.size * ld.size_y
        lo = bpy.data.objects.new("Raumlicht", ld)
        lo.location = ((x0 + x1) / 2, (y0 + y1) / 2, hoehe)
        bpy.context.scene.collection.objects.link(lo)
    led_bauen(bpy, licht.get("led") or [], float(licht.get("led_staerke", 120.0)))
    welt = bpy.data.worlds.new("Umgebung")
    welt.use_nodes = True
    hg = welt.node_tree.nodes.get("Background")
    if licht.get("umgebung") and umgebung_laden(bpy, welt, licht["umgebung"], float(licht.get("umgebung_staerke", 1.0)),
                                                     licht.get("himmel", [0.9, 0.9, 0.9])):
        pass
    elif hg is not None:
        c = licht.get("himmel", [0.78, 0.84, 0.92])
        hg.inputs["Color"].default_value = [srgb_linear(x) for x in c] + [1.0]
        hg.inputs["Strength"].default_value = float(licht.get("himmel_staerke", 1.0))
    bpy.context.scene.world = welt


def gpu_einschalten(bpy):
    """GPU nutzen, wenn Blender eine findet (OptiX, CUDA, HIP, Metal, oneAPI)."""
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
    except (KeyError, AttributeError):
        return "CPU"
    for typ in ("OPTIX", "CUDA", "HIP", "METAL", "ONEAPI"):
        try:
            prefs.compute_device_type = typ
        except (TypeError, ValueError):
            continue
        try:
            prefs.refresh_devices()
        except AttributeError:
            prefs.get_devices()
        geraete = [d for d in prefs.devices if d.type == typ]
        if geraete:
            for d in prefs.devices:
                d.use = d.type == typ
            bpy.context.scene.cycles.device = "GPU"
            return typ
    bpy.context.scene.cycles.device = "CPU"
    return "CPU"


def rendern(bpy, daten, ordner):
    from mathutils import Vector
    szene = bpy.context.scene
    melden("STATUS", "Szene aufbauen")
    # Werkseinstellungen: Würfel, Licht und Kamera entfernen
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    obj_laden(bpy, os.path.join(ordner, daten["obj"]))
    materialien = daten.get("materialien", {})
    for mat in bpy.data.materials:
        d = materialien.get(mat.name)
        if d is not None:
            material_bauen(bpy, mat, d, ordner, float(daten.get("kanten", 0.0)))
    kamera_bauen(bpy, daten, Vector)
    licht_bauen(bpy, daten, Vector)
    # Bodenbelag, Holz-/Steinstruktur, Decke, Deko, Pendelleuchten (rendern_ausstattung.py)
    sys.dont_write_bytecode = True  # kein __pycache__ im Plugin-Ordner
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import rendern_ausstattung
    rendern_ausstattung.ausstatten(bpy, daten, melden)

    szene.render.engine = "CYCLES"
    geraet = gpu_einschalten(bpy)
    melden("STATUS", "Rendern mit %s" % geraet)
    cyc = szene.cycles
    cyc.samples = int(daten["bild"].get("samples", 128))
    if hasattr(cyc, "use_adaptive_sampling"):
        cyc.use_adaptive_sampling = True
    try:
        cyc.use_denoising = True
    except AttributeError:
        pass
    for transform in ("AgX", "Filmic"):
        try:
            szene.view_settings.view_transform = transform
            break
        except TypeError:
            continue
    szene.render.resolution_x = int(daten["bild"]["breite"])
    szene.render.resolution_y = int(daten["bild"]["hoehe"])
    szene.render.resolution_percentage = 100
    szene.render.image_settings.file_format = "PNG"
    szene.render.film_transparent = False
    bild = daten["bild"]["datei"]
    szene.render.filepath = bild
    if daten.get("blend"):
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ordner, daten["blend"]), check_existing=False)
    bpy.ops.render.render(write_still=True)
    if not os.path.exists(bild):
        raise RuntimeError("Blender hat kein Bild geschrieben: %s" % bild)
    melden("FERTIG", bild)
    return bild


def main(argv=None):
    argv = sys.argv if argv is None else argv
    pfad = argumente(argv)
    STATUS["datei"] = os.path.join(os.path.dirname(os.path.abspath(pfad)), "kp_status.txt")
    melden("PID", os.getpid())
    try:
        import bpy
        stats_beobachten(bpy)
        with open(pfad, encoding="utf-8") as f:
            daten = json.load(f)
        return rendern(bpy, daten, os.path.dirname(os.path.abspath(pfad)))
    except Exception as e:  # alles ans Plugin melden, dann mit Fehler beenden
        traceback.print_exc()
        melden("FEHLER", str(e).replace("\n", " "))
        sys.exit(1)


if __name__ == "__main__":
    main()
