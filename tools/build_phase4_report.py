#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt PHASE4-ERGEBNIS.md und PHASE4-ERGEBNIS.html (inkl. Fixrunde).

Alle Snippets stammen direkt aus den echten Projektdateien, alle Bilder sind
als data-URI eingebettet (offline im Arena-Preview sichtbar).
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SHOTS = [
    ("p4_f5.png", "F5-Start: AUTO ist jetzt aus (MANUELL)",
     "Normaler Start ohne Preset · zwei Eicheln am Boden · HUD zeigt × 0 · Button „Skilltree (T)“ oben rechts · Modus MANUELL"),
    ("p4_skilltree.png", "GraphEdit-Skilltree: 5 von 15 Mutationen frei",
     "15 GraphNodes, 14 Verbindungslinien, Minimap, Zweigfarben, Status „Freigeschaltet / Verfügbar / Gesperrt“, 260,0 Glucose"),
    ("p4_skilltree-locked.png", "Vorbedingungen und Glucose-Kosten sichtbar",
     "0/15 freigeschaltet · Startknoten verfügbar · alle Folgeknoten gesperrt · 12,0 Glucose"),
    ("p4_snow.png", "Winter: Schnee statt Regen",
     "Weiße, langsam schwingende Flocken · keine blauen Linien · keine Spritzer · HUD „Es schneit“"),
    ("p4_snow-detail.png", "Detail: Flocken auf der echten Geländelinie",
     "Liegengebliebene Schneepunkte auf height_smooth_at(wx) · jetzt 5–9 s Lebensdauer · Wasserreservoir unverändert"),
    ("p4_thaw.png", "Fix: sanfter Übergang Schnee → Regen",
     "Mitten im Ereignis wird es Frühling · Flocken UND erste blaue Regenlinien gleichzeitig · HUD „Der Schnee geht langsam in Regen ueber.“"),
]


def snippet(rel: str, start: str, lines: int = 14) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(text):
        if start in line:
            return "\n".join(text[i:i + lines]).rstrip() + "\n"
    raise RuntimeError(f"Marker fehlt: {start!r} in {rel}")


SNIPPETS = [
    ("SkillNodeData.gd — ein Knoten als echte Resource", "gdscript",
     snippet("src/systems/SkillNodeData.gd", "@export var id: String", 10)),
    ("generate_skilltree.gd — Pflicht-Mutationen + grant_leaves", "gdscript",
     snippet("tools/generate_skilltree.gd", 'd.nodes.append(_node("root_efficiency"', 5)
     + "\n" + snippet("tools/generate_skilltree.gd", 'd.nodes.append(_node("leaf_efficiency"', 5)
     + "\n" + snippet("tools/generate_skilltree.gd", 'd.nodes.append(_node("crown_growth"', 4)),
    ("SkillTree.gd — Kosten + Vorbedingung prüfen", "gdscript",
     snippet("src/systems/SkillTree.gd", "func can_unlock", 9)),
    ("SkillTree.gd — Glucose abziehen und global anwenden", "gdscript",
     snippet("src/systems/SkillTree.gd", "func unlock(id: String, payer: BaseTree)", 13)),
    ("SkillTree.gd — apply_effect() inkl. sofortiger Blätter", "gdscript",
     snippet("src/systems/SkillTree.gd", "func apply_effect", 12)),
    ("SkillTreeUI.gd — echtes GraphEdit ohne überlagerte Leiste", "gdscript",
     snippet("src/ui/SkillTreeUI.gd", "_graph = GraphEdit.new()", 18)),
    ("SkillTreeUI.gd — 15 Knoten und 14 Verbindungslinien", "gdscript",
     snippet("src/ui/SkillTreeUI.gd", "func _build_nodes()", 13)
     + "\n" + snippet("src/ui/SkillTreeUI.gd", "for pair in st.connection_pairs()", 6)),
    ("Tree.gd — Skill-Multiplikatoren und Fotosynthese", "gdscript",
     snippet("src/plants/Tree.gd", "var skill_glucose_mult", 7)
     + "\n" + snippet("src/plants/Tree.gd", "func photosynthesize(", 12)),
    ("WaterSystem.gd — Winterruhe + echte Skill-Faktoren", "gdscript",
     snippet("src/systems/WaterSystem.gd", "var winter := time_manager", 13)),
    ("SeasonSystem.gd — „Verbreitung“ setzt spread_bonus", "gdscript",
     snippet("src/systems/SeasonSystem.gd", "func _sync_skills()", 4)),
    ("RainEffect.gd — längere Liegezeit + weicher Modus-Wechsel", "gdscript",
     snippet("src/ui/RainEffect.gd", "const SNOW_SETTLE_MIN", 7)
     + "\n" + snippet("src/ui/RainEffect.gd", "func _sync_mode(snap: bool)", 10)
     + "\n" + snippet("src/ui/RainEffect.gd", "func _on_season_changed", 10)),
    ("SaveManager.gd — Format v5 mit skills", "gdscript",
     snippet("src/systems/SaveManager.gd", '"skills": SkillTree.instance.to_dict()', 4)
     + "\n" + snippet("src/systems/SaveManager.gd", "SkillTree.instance.from_dict", 3)),
    ("FIX: Global.gd — AUTO startet aus", "gdscript",
     snippet("src/autoload/Global.gd", "## PHASE-4-FIX: Standard = MANUELL", 4)),
    ("FIX: Tree.gd — add_leaf() respektiert Cap 14", "gdscript",
     snippet("src/plants/Tree.gd", "func add_leaf()", 16)
     + "\n" + snippet("src/plants/Tree.gd", "func grow_part(part: String)", 12)),
    ("FIX: Tree.gd — Kronenwuchs gibt +2 Blätter sofort", "gdscript",
     snippet("src/plants/Tree.gd", "func apply_skill_leaf_grants", 6)),
    ("FIX: GrowthSystem.gd — nur bei echtem Zuwachs zahlen", "gdscript",
     snippet("src/systems/GrowthSystem.gd", "if tree.grow_part(part):", 4)),
    ("FIX: Phase4Smoke.gd — regressionssichere checks", "gdscript",
     snippet("tests/Phase4Smoke.gd", "# --- 4b) PHASE-4-FIX", 24)),
]

CHECKS = [
    "✅ <b>GraphEdit-Skilltree mit 15 Knoten:</b> <code>data/skilltrees/oak.tres</code> enthält 15 <code>SkillNodeData</code>-Resources und <b>14 Vorbedingungs-Linien</b>. <code>SkillTreeUI.gd</code> zeigt sie zoombar (0,35×–1,8×), pannbar, mit Minimap und eigenen +/−/1:1-Buttons. Die eingebaute GraphEdit-Leiste ist ausgeblendet, damit sie Titel und erste Zeile nicht überdeckt.",
    "✅ <b>Alle 7 Pflicht-Mutationen:</b> Effizientere Wurzeln (+25 % Wasser), Effizientere Blätter (+20 % Glucose), Symbiose/Pilz-Knoten, Parasiten-Resistenz, Krankheits-Resistenz, Holz-Härte/Sturm-Resistenz, Verbreitung (+30 % Keimrate). Dazu 8 weitere Knoten als MVP-Grundgerüst.",
    "✅ <b>Freischalten kostet Glucose:</b> <code>can_unlock()</code> prüft Vorbedingung + Kontostand, <code>unlock()</code> zieht exakt die Kosten ab. Gemäß Master 4.2 bleibt Glucose pro Baum-Instanz, der Skilltree-Fortschritt <b>global pro Art</b>: alle Eichen — auch neu gespawnte — teilen ihn.",
    "✅ <b>Effekte wirken auf echte Werte:</b> 10 Wasser/s werden nach <code>root_efficiency</code> zu <b>12,5</b>; Fotosynthese × <b>1,20</b>; <code>spread_bonus = 0,30</code>; −20 % Wurzel-/Stammkosten; echte Regen-, Reservoir- und Winter-Wasserfaktoren; −10 % Wasserverbrauch; Resistenzwerte <b>0,5</b> (−50 %) gespeichert.",
    "✅ <b>FIX — keine unsichtbaren Blätter mehr:</b> <code>add_leaf()</code> nutzt jetzt dieselbe Obergrenze wie <code>can_grow()</code> (<code>MAX_LEAVES + skill_max_leaves_bonus</code>). <code>crown_growth</code> enthält <code>grant_leaves = 2</code> und schenkt die <b>+2 Blätter sofort sichtbar</b> auf allen Eichen; <code>skill_leaf_grants</code> verhindert Duplikate bei Refresh und Save/Load.",
    "✅ <b>FIX — Glucose bleibt stehen:</b> <code>Global.auto_mode</code> startet <b>aus</b> (MANUELL); AUTO funktioniert nach bewusstem Umschalten weiter wie vorher. <code>grow_part()</code> gibt nur noch bei <b>echtem Zuwachs</b> <code>true</code> zurück — ein ausgewachsener Baum oder ein blockiertes Wurzel-Tile verbraucht keine Glucose mehr. Smoke: 50,0 → <b>50,0</b>.",
    "✅ <b>HUD, Tasten, DE/EN:</b> Button „Skilltree (T)“ oben rechts, <code>T</code> öffnet/schließt, <code>Esc</code> schließt, mittlere Maustaste pannt. 58 Lokalisierungszeilen; der Smoke prüft <b>51</b> P4-Schlüssel in DE und EN. Events aktualisieren UI nach Freischalten, Baumwahl, Laden und Sprachwechsel.",
    "✅ <b>Save/Load v5:</b> Skill-Fortschritt und <code>skill_leaf_grants</code> liegen im JSON und werden <b>vor</b> den Bäumen wiederhergestellt. v4/v3/v2/v1 bleiben lesbar; <code>Phase3Smoke</code> akzeptiert <code>version >= 4</code>.",
    "✅ <b>Winter-Schnee statt Regen:</b> dasselbe Niederschlags-Event, aber 240 langsame weiße Flocken mit Sinus-Drift, <b>keine blauen Linien, keine Spritzer, keine Rippen</b>, dafür liegende Schneepunkte auf <code>height_smooth_at(wx)</code>. HUD/Toast „Es schneit“. Frühling stellt Regen + Spritzer wieder her.",
    "✅ <b>FIX — Schnee bleibt länger liegen:</b> Lebensdauer <b>5–9 s</b> statt 1,6–3,2 s, Puffer von 220 auf 320 Punkte erhöht. Beim Saisonwechsel werden die Punkte nicht mehr hart gelöscht.",
    "✅ <b>FIX — sanfter Übergang:</b> wird es <b>mitten im Schneefall</b> Frühling, läuft <code>snow_blend</code> in <b>3,5 s</b> von 1,0 nach 0,0. Flocken, Regenlinien, Spritzer und HUD-Text werden überblendet; liegender Schnee schmilzt beschleunigt. Toast/HUD: „Der Schnee geht langsam in Regen ueber.“ Screenshot <code>p4_thaw.png</code>.",
    "✅ <b>REVISION 3 erhalten:</b> Winter ohne Reservoir-Entnahme und ohne passive Versickerung, aber Niederschlag füllt weiter auf (<code>last_reservoir_rate = 0</code>). Smoke misst steigenden Füllstand bei Schnee.",
    "✅ <b>Regression &amp; F5:</b> Import, F5 ohne Preset, 180-Frame-Dauerlauf und <b>9/9 Smokes</b> (P0/P1/P2/REV1/REV2/P3/REV3/REV4/PHASE4) laufen mit Exit 0 / <b>284 OK-Zeilen</b> / 0 Fehlern. 6 Xvfb-Renders 1920×1080 sind fehlerfrei und visuell geprüft.",
]

NOTES = [
    "Historischer Stand vor PHASE 5: Tiere, Parasiten und Pilz-Symbiose sind inzwischen umgesetzt (siehe PHASE5-ERGEBNIS.html/.md). Sturm-/pH-/N-P-K-/Mykorrhiza-/Katastrophen-Ereignisse bleiben der späteren vollen Simulation vorbehalten.",
    "Xvfb + opengl3/llvmpipe ist ein Software-Rasterizer und nur für reproduzierbare Renders genutzt; Ziel-Renderer des Projekts bleibt Forward+ / Vulkan. Das Tau-Bild verwendet --fixed-fps 10, damit der 3,5-s-Übergang in 25 Frames sichtbar wird.",
    "Keine neuen externen Assets, Addons oder C#-Dateien. Schneeflocken, GraphNodes und Linien werden zur Laufzeit gezeichnet; alle Pfade sind relativ.",
    "Die ZIP im Ordner deliverables/ ist der eingefrorene Lieferstand der Fixrunde. Die vorherige waldspiel-PHASE4.zip bleibt als historischer Stand erhalten.",
]

CSS = """
:root{--bg:#0b100e;--card:#131b17;--line:#26362d;--fg:#e7efe8;--sub:#9fb3a6;--green:#8ed081;--blue:#7fb7e8;--amber:#e8c87f;--red:#e88f8f}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1180px;margin:0 auto;padding:34px 22px 70px}header{border-bottom:1px solid var(--line);padding-bottom:24px;margin-bottom:30px}
h1{font-size:2.15rem;margin:0 0 8px;letter-spacing:.01em}h2{font-size:1.4rem;margin:42px 0 14px;border-left:4px solid var(--green);padding-left:12px}
h3{font-size:1rem;margin:20px 0 8px;color:var(--blue)}p.sub{color:var(--sub)}
.badges{display:flex;flex-wrap:wrap;gap:8px;margin-top:18px}.badge{background:var(--card);border:1px solid var(--line);border-radius:999px;padding:6px 13px;font-size:.84rem}
.badge.zip{color:var(--green);border-color:#3d6b45}.badge.fix{color:var(--amber);border-color:#6b5a35}
.gallery{display:grid;grid-template-columns:repeat(auto-fit,minmax(440px,1fr));gap:18px}
figure{margin:0;background:var(--card);border:1px solid var(--line);border-radius:10px;overflow:hidden}
figure img{width:100%;height:auto;display:block}figcaption{padding:11px 14px;color:var(--sub);font-size:.86rem}figcaption b{display:block;color:var(--fg);font-size:.95rem;margin-bottom:3px}
.codeblock{background:#080c0a;border:1px solid var(--line);border-radius:8px;padding:14px;overflow:auto;white-space:pre-wrap;font:13px/1.5 ui-monospace,SFMono-Regular,Consolas,monospace;color:#cfe3d3}
.snip{margin:16px 0 26px}.snip h3{margin:0 0 6px;font-size:.92rem}ul{padding-left:20px}li{margin:8px 0}
.note{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:14px 18px}
footer{margin-top:46px;border-top:1px solid var(--line);padding-top:18px;color:var(--sub)}
code.inl,code{background:#0c120f;padding:2px 6px;border-radius:4px}pre code{background:none;padding:0}a{color:var(--blue)}
"""


def build_md() -> str:
    protocol = (ROOT / "PHASE4-TESTPROTOKOLL.txt").read_text(encoding="utf-8")
    out = ["# PHASE 4 — Ergebnis + Fixrunde", "",
           "**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05**  ",
           "15 GraphEdit-Knoten, echte Glucose-Kosten und Effekte, Save v5 — plus Fixrunde: AUTO aus, sichtbare Skill-Blätter, längerer Schnee und sanfter Übergang zu Regen. *Historischer Stand vor PHASE 5; aktueller Bericht: `PHASE5-ERGEBNIS.html/.md`.*", "",
           "## 1 · Screenshots (echte Godot-Renders)", ""]
    for f, title, sub in SHOTS:
        out += [f"### {title}", f"*{sub}*", "", f"![{title}](screenshots/{f})", ""]
    out += ["## 2 · Code-Snippets (aus den echten Projektdateien)", ""]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += ["## 3 · Testprotokoll", "", "```text", protocol.strip(), "```", "",
            "## 4 · Abnahme PHASE 4 + Fixrunde", ""]
    for c in CHECKS:
        out.append("- " + c.replace("<b>", "**").replace("</b>", "**")
                   .replace("<code>", "`").replace("</code>", "`")
                   .replace("&amp;", "&"))
    out += ["", "## 5 · Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += ["", "## 6 · Lieferumfang", "",
            "- `deliverables/waldspiel-PHASE4-FIX.zip` — vollständiges, Godot-importierbares Projekt (`project.godot` im ZIP-Root, `.godot` ausgeschlossen, CRC OK)",
            "- `deliverables/waldspiel-PHASE4.zip` — historischer Stand vor der Fixrunde",
            "- `PHASE4-ERGEBNIS.html` / `.md`, `PHASE4-TESTPROTOKOLL.txt`, `DECISIONS.md` §§64–69, `README.md`, `GODOT-IMPORT.txt`",
            "- `screenshots/p4_*.png` (6 Renders), `tests/Phase4Smoke.gd`, `tools/generate_skilltree.gd`, `tools/build_phase4_report.py`",
            "- Neue/geänderte Quellen der Fixrunde: `Global.gd`, `GrowthSystem.gd`, `Tree.gd`, `SkillTree.gd`, `tools/generate_skilltree.gd`, `data/skilltrees/oak.tres`, `RainEffect.gd`, `HUD.gd`, `EventBus.gd`, `Main.gd`, `localization.csv`",
            "", "**PHASE 5 ist inzwischen umgesetzt — siehe `PHASE5-ERGEBNIS.html` / `.md`.**", ""]
    return "\n".join(out)


def build_html() -> str:
    protocol = (ROOT / "PHASE4-TESTPROTOKOLL.txt").read_text(encoding="utf-8")
    shots_html = ""
    for f, title, sub in SHOTS:
        data = base64.b64encode((ROOT / "screenshots" / f).read_bytes()).decode()
        shots_html += (
            '<figure><img alt="' + html.escape(title) + '" src="data:image/png;base64,' + data + '">'
            '<figcaption><b>' + html.escape(title) + '</b>' + html.escape(sub) + '</figcaption></figure>\n')
    code_html = ""
    for title, lang, code in SNIPPETS:
        code_html += ('<div class="snip"><h3>' + html.escape(title) + ' <small>(' + lang + ')</small></h3>'
                      '<pre class="codeblock"><code>' + html.escape(code) + '</code></pre></div>\n')
    checks_html = "".join("<li>" + c + "</li>" for c in CHECKS)
    notes_html = "".join("<li>" + html.escape(n) + "</li>" for n in NOTES)
    return f"""<!DOCTYPE html>
<html lang="de"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>PHASE 4 + Fixrunde — Wald-Regeneration</title><style>{CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>PHASE 4 — Skilltree, Winter-Schnee &amp; Fixrunde</h1>
  <p class="sub">Wald-Regeneration · Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05<br>
  15 GraphEdit-Knoten · echte Effekte · AUTO standardmäßig aus · +2 sichtbare Blätter · Schnee 5–9 s · 3,5 s sanfter Übergang zu Regen</p>
  <div class="badges">
    <span class="badge zip">✓ komplette ZIP</span>
    <span class="badge fix">✓ AUTO aus</span>
    <span class="badge fix">✓ +2 Blätter</span>
    <span class="badge fix">✓ Schnee/Übergang</span>
    <span class="badge">9 / 9 Smokes OK</span>
    <span class="badge">284 OK-Zeilen</span>
    <span class="badge">0 rote Fehler</span>
  </div>
</header>

<h2>1 · Screenshots (echte Godot-Renders)</h2>
<div class="gallery">{shots_html}</div>

<h2>2 · Code-Snippets (aus den echten Projektdateien)</h2>
{code_html}

<h2>3 · Testprotokoll</h2>
<pre class="codeblock"><code>{html.escape(protocol.strip())}</code></pre>
<p class="sub">6 eingebettete Screenshots · {len(SNIPPETS)} echte Snippets · alles offline (data-URIs, keine externen Ressourcen).</p>

<h2>4 · Abnahme PHASE 4 + Fixrunde</h2>
<ul>{checks_html}</ul>

<h2>5 · Hinweise / bewusste Grenzen</h2>
<div class="note"><ul>{notes_html}</ul></div>

<h2>6 · Lieferumfang</h2>
<ul>
  <li><code class="inl">deliverables/waldspiel-PHASE4-FIX.zip</code> — vollständiges, Godot-importierbares Projekt, <code class="inl">project.godot</code> im ZIP-Root, CRC OK</li>
  <li><code class="inl">deliverables/waldspiel-PHASE4.zip</code> — historischer Stand vor der Fixrunde</li>
  <li><code class="inl">PHASE4-ERGEBNIS.html</code> / <code class="inl">.md</code>, <code class="inl">PHASE4-TESTPROTOKOLL.txt</code>, <code class="inl">DECISIONS.md</code> (§§64–69)</li>
  <li><code class="inl">screenshots/p4_*.png</code>, <code class="inl">tests/Phase4Smoke.gd</code>, <code class="inl">tools/generate_skilltree.gd</code>, <code class="inl">tools/build_phase4_report.py</code></li>
</ul>

<footer><strong>Historischer Stand vor PHASE 5.</strong> Tiere, Parasiten und Pilz-Symbiose sind inzwischen umgesetzt; Details im aktuellen <code>PHASE5-ERGEBNIS.html</code>. Sturm-/pH-/N-P-K-/Mykorrhiza-/Katastrophen-Ereignisse bleiben einer späteren Ausbaustufe vorbehalten.</footer>
</div></body></html>
"""


if __name__ == "__main__":
    (ROOT / "PHASE4-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "PHASE4-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print("Berichte geschrieben: PHASE4-ERGEBNIS.md / .html")
