#!/usr/bin/env python3
# Griffkatalog aus Jürgens Blätterkatalog (Häfele DÉCO Kollektion 2025, PDF) auslesen.
# Aufruf: python3 griffkatalog_auslesen.py blaetterkatalog.pdf <Ausgabeordner>
#   -> <Ausgabeordner>/haefele-deco-2025.json und <Kennung>.jpg (Fotoseite je Serie, 90 dpi)
# Braucht pdftotext/pdftoppm (poppler). Schritte: Tabellen je Seite lesen (parse), Zeilen zu
# Oberflächen gruppieren (group), Serien bauen + Bilder (build), Korrekturen (fix).
# Von Hand korrigiert: Seite 53 (H2310/H2315 in einer Tabelle), H1380 (zwei Oberflächen in einer Zeile),
# H2175 (Knopf auf Seite 111), H1340 (Höhe/Durchmesser), Bildseiten H2565/H2570 (Seite 40/42, nicht Eiche).
import os, sys, tempfile
PDF, OUT = sys.argv[1], sys.argv[2]
TMP = tempfile.mkdtemp()

# ===== parse =====
sys.argv = ['x'] + [PDF, os.path.join(TMP,'roh.json')]
import re, json, subprocess, sys
pdf = sys.argv[1]
def page(p):
    return subprocess.run(['pdftotext','-f',str(p),'-l',str(p),'-layout',pdf,'-'],capture_output=True,text=True).stdout
# TOC
toc = {}
for p in (6,7,8,9):
    t = page(p).split('\n')
    for i,l in enumerate(t):
        codes = re.findall(r'H\d{4}', l)
        if codes and i+1 < len(t):
            pages = re.findall(r'Seite (\d+)', t[i+1])
            for c,s in zip(codes, pages): toc[c] = int(s)
ROW = re.compile(r'(?P<l>\d+(?:\.\d+)?)\s*x\s*(?P<h>\d+(?:\.\d+)?)(?:\s+(?P<seite>rechts|links))?\s+(?:(?P<la>\d+(?:\.\d+)?(?:\s*/\s*\d+(?:\.\d+)?)?|–)\s+)?(?P<art>\d{3}\.\d{2}\.\d{3})')
ROW2 = re.compile(r'(?P<l>\d+)\s+(?P<h>\d+)\s+(?P<art>\d{3}\.\d{2}\.\d{3})')  # Knopf Höhe / Durchmesser
cur = []
serien = {}
rohgruppen = []
for p in range(12, 166):
    lines = [l.replace('­','').replace('­','') for l in page(p).split('\n')]
    head = []
    for l in lines[:4]:
        head += re.findall(r'H\d{4}', l)
    if head: cur = head
    tab = [i for i,l in enumerate(lines) if re.search(r'\d{3}\.\d{2}\.\d{3}', l)]
    if not tab: continue
    # tokens in Zeilenreihenfolge
    toks = []
    start = min(tab)
    for i in range(max(0,start-3), max(tab)+3):
        if i >= len(lines): break
        l = lines[i]
        m = ROW.search(l) or ROW2.search(l)
        if m:
            lab = l[:m.start()].strip()
            d = m.groupdict()
            la = d.get('la')
            if m.re is ROW2:
                knopf_hd = True
            toks.append(('row', i, lab, d))
        else:
            s = l.strip()
            if i < start: continue
            if not s or 'Maße' in s or 'Oberfläche' in s or 'in mm' in s or '–––' in s: continue
            toks.append(('lab', i, re.sub(r'\s{3,}.*','',s), None))
    rohgruppen.append((p, list(cur), toks))
json.dump({'toc':toc,'roh':rohgruppen}, open(sys.argv[2],'w'), ensure_ascii=False, indent=0)
print(len(toc), len(rohgruppen))


# ===== group =====
sys.argv = ['x'] + [os.path.join(TMP,'roh.json'), os.path.join(TMP,'grp.json')]
import json, re, sys
d = json.load(open(sys.argv[1]))
out = []
for p, cur, toks in d['roh']:
    rows = [t for t in toks if t[0]=='row']
    groups = []
    g = None
    for t in rows:
        dd = t[3]
        la = dd.get('la') if dd.get('la') not in (None,'–') else None
        key = (dd['l'], dd['h'], la, dd.get('seite'))
        knopf = la is None
        if g is None or key in g['keys'] or g['knopf'] != knopf:
            g = {'keys': [], 'rows': [], 'lab': [], 'knopf': knopf, 'lines': []}
            groups.append(g)
        g['keys'].append(key); g['rows'].append(t); g['lines'].append(t[1])
        if t[2]: g['lab'].append((t[1], t[2]))
    for t in toks:
        if t[0] != 'lab': continue
        for gg in groups:
            if gg['lines'][0] - 0 <= t[1] <= gg['lines'][-1]:
                gg['lab'].append((t[1], t[2])); break
        else:
            # zwischen Gruppen: zur nächsten folgenden Gruppe mit Zeilen danach, die noch kein Etikett hat
            cand = [gg for gg in groups if not gg['lab']]
            if cand:
                best = min(cand, key=lambda gg: min(abs(x - t[1]) for x in gg['lines']))
                best['lab'].append((t[1], t[2]))
    for gg in groups:
        lab = ' '.join(x[1] for x in sorted(gg['lab']))
        lab = re.sub(r'\s+', ' ', lab).replace('polliert','poliert').replace('*','').strip()
        code = None
        m = re.match(r'(H\d{4})\s*/\s*(.*)', lab)
        if m: code, lab = m.group(1), m.group(2)
        elif len(cur) >= 2: code = cur[1] if gg['knopf'] else cur[0]
        else: code = cur[0] if cur else None
        out.append({'seite': p, 'serie': code, 'oberflaeche': lab, 'knopf': gg['knopf'],
                    'groessen': [{'laenge': float(r[3]['l']), 'hoehe': float(r[3]['h']) if r[3].get('h') else None,
                                  'lochabstand': r[3].get('la') if r[3].get('la') not in (None,'–') else None,
                                  'seite': r[3].get('seite'), 'artikel': r[3]['art']} for r in gg['rows']]})
json.dump(out, open(sys.argv[2],'w'), ensure_ascii=False, indent=1)
for o in out:
    print(o['seite'], o['serie'], 'K' if o['knopf'] else 'G', repr(o['oberflaeche']), [(g['laenge'], g['lochabstand']) for g in o['groessen']])


# ===== build =====
sys.argv = ['x'] + [PDF, os.path.join(TMP,'roh.json'), os.path.join(TMP,'grp.json'), OUT]
import json, re, subprocess, sys, os
pdf, roh, grp, outdir = sys.argv[1:5]
toc = json.load(open(roh))['toc']
groups = json.load(open(grp))
def la_list(s):
    if not s: return []
    return [float(x) for x in re.split(r'\s*/\s*', s)]
# Korrekturen
fixed = []
for g in groups:
    if g['seite'] == 53: continue
    if g['seite'] == 111 and g['knopf']: g = dict(g, serie='H2175')
    if g['serie'] == 'H1380' and g['oberflaeche'].startswith('aluminium'):
        a, b = g['groessen']
        fixed.append(dict(g, oberflaeche='aluminiumfarben weiß matt', groessen=[a]))
        fixed.append(dict(g, oberflaeche='verchromt poliert', groessen=[b]))
        continue
    fixed.append(g)
for code, l, h, rows in [('H2310', 50, 30, [('schwarz matt','106.70.410'),('vernickelt gebürstet','106.70.411'),('goldfarben gebürstet','106.70.412')]),
                         ('H2315', 80, 25, [('schwarz matt','106.70.420'),('vernickelt gebürstet','106.70.421'),('goldfarben gebürstet','106.70.422')])]:
    for o, a in rows:
        fixed.append({'seite': 53, 'serie': code, 'oberflaeche': o, 'knopf': True,
                      'groessen': [{'laenge': l, 'hoehe': h, 'lochabstand': None, 'seite': None, 'artikel': a}]})
serien = {}
order = list(toc.keys())
for g in fixed:
    s = serien.setdefault(g['serie'], {'kennung': g['serie'], 'bauart': 'knopf' if g['knopf'] else 'griff',
                                        'seite': toc[g['serie']], 'tabelle': g['seite'], 'oberflaechen': []})
    s['oberflaechen'].append({'name': g['oberflaeche'], 'groessen': [
        {k: v for k, v in {'laenge': x['laenge'], 'hoehe': x['hoehe'], 'lochabstand': la_list(x['lochabstand']) or None,
         'ausfuehrung': x['seite'], 'artikel': x['artikel']}.items() if v is not None} for x in g['groessen']]})
assert set(serien) == set(toc), set(toc) ^ set(serien)
def page(p):
    return subprocess.run(['pdftotext','-f',str(p),'-l',str(p),'-layout',pdf,'-'],capture_output=True,text=True).stdout.replace('­','')
os.makedirs(outdir, exist_ok=True)
for code in order:
    s = serien[code]
    names = [o['name'] for o in s['oberflaechen']]
    bild = None
    def hat(p):
        t = re.sub(r'\s+', ' ', page(p))
        return any(n.split(' /')[0][:12] in t for n in names)
    for p in range(s['seite'], s['tabelle']):
        if hat(p): bild = p; break
    if bild is None:
        nach = page(s['tabelle'] + 1)
        kopf = '\n'.join(nach.strip('\n').split('\n')[:3])
        bild = s['tabelle'] + 1 if hat(s['tabelle'] + 1) and not re.search(r'H\d{4}', kopf) and not re.search(r'\d{3}\.\d{2}\.\d{3}', nach) else s['tabelle']
    s['bildseite'] = bild
    s['bild'] = f'griffe/{code}.jpg'
    tmp = os.path.join(outdir, 'tmp')
    subprocess.run(['pdftoppm','-f',str(bild),'-l',str(bild),'-r','90','-jpeg','-jpegopt','quality=72','-singlefile',pdf,tmp], capture_output=True)
    os.replace(tmp + '.jpg', os.path.join(outdir, code + '.jpg'))
kat = {'kennung': 'haefele-deco-2025', 'name': 'Häfele DÉCO Kollektion 2025', 'hersteller': 'Häfele',
       'quelle': 'Häfele DÉCO Kollektion 2025 (732.01.005 -07/25), Tabellen „Oberfläche / Maße in mm / Lochabstand in mm / Artikel-Nr.“; Seite = PDF-Seite',
       'serien': [serien[c] for c in order]}
json.dump(kat, open(os.path.join(outdir, '..', 'griffe-haefele-deco-2025.json'), 'w'), ensure_ascii=False, indent=1)
for c in order: print(c, serien[c]['bauart'], serien[c]['seite'], serien[c]['bildseite'], len(serien[c]['oberflaechen']))


# ===== fix =====

import json, sys
p = os.path.join(outdir, 'haefele-deco-2025.json')
os.replace(os.path.join(outdir, '..', 'griffe-haefele-deco-2025.json'), p)
k = json.load(open(p))
for s in k['serien']:
    if s['kennung'] == 'H1340':  # Spalten Höhe/Durchmesser vertauscht
        for o in s['oberflaechen']:
            for g in o['groessen']: g['laenge'], g['hoehe'] = g['hoehe'], g['laenge']
    for o in s['oberflaechen']:
        for g in o['groessen']:
            for key in ('laenge', 'hoehe'):
                if key in g and float(g[key]).is_integer(): g[key] = int(g[key])
            if 'lochabstand' in g: g['lochabstand'] = [int(x) if float(x).is_integer() else x for x in g['lochabstand']]
    s['bild'] = s['kennung'] + '.jpg'
k['erklaerung'] = {'laenge': 'Länge (Knopf: Durchmesser) in mm, 1. Zahl der Spalte Maße', 'hoehe': 'Ausladung/Höhe über der Front in mm, 2. Zahl', 'lochabstand': 'Lochabstände in mm (mehrere = passt für beide, z. B. 128/160); fehlt = Knopf mit einer Schraube', 'ausfuehrung': 'rechts/links bei asymmetrischen Griffen', 'seite': 'PDF-Seite, auf der die Serie beginnt', 'tabelle': 'PDF-Seite der Tabelle', 'bildseite': 'PDF-Seite, aus der das Bild stammt'}
json.dump(k, open(p, 'w'), ensure_ascii=False, indent=1)

import subprocess
for kenn, seite in (('H2565', 40), ('H2570', 42)):
    subprocess.run(['pdftoppm', '-f', str(seite), '-l', str(seite), '-r', '90', '-jpeg', '-jpegopt', 'quality=72', '-singlefile', PDF, os.path.join(OUT, kenn)])
    for s in k['serien']:
        if s['kennung'] == kenn: s['bildseite'] = seite
json.dump(k, open(p, 'w'), ensure_ascii=False, indent=1)
