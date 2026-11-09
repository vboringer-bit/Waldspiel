#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Erzeugt PHASE5-ERGEBNIS.md und PHASE5-ERGEBNIS.html.

Alle Snippets werden direkt aus den echten Projektdateien gelesen. Die sechs
Screenshots werden als data-URI eingebettet, damit der HTML-Bericht auch im
offline/sandboxed Arena-Preview vollstaendig sichtbar ist.
"""
from __future__ import annotations

import base64
import html
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SHOTS = [
    ("p5_f5.png", "F5-Start — PHASE 5 unverändert lauffähig",
     "Ohne Preset · 4 Basis-Tiere · Wald-Gesundheit 16 % · AUTO aus (MANUELL) · neues Ökologie-Panel oben links"),
    ("p5_wildlife.png", "Wurm/Ameise geben automatisch Futter",
     "StateMachine läuft ohne Klick: WANDER → IDLE → EAT → Futter: 7 · 2 Würmer, Ameisen und Erd-Pixelhaufen sichtbar"),
    ("p5_health.png", "Wald-Gesundheit > 50 % lockt Specht & Eichhörnchen an",
     "100 % Gesundheitsbalken · 3 Bäume mit Blättern · Specht links, orangenes Eichhörnchen rechts · Toast zur Ansiedlung"),
    ("p5_parasite.png", "Mistel + Wurmbefall, Specht hilft",
     "Rot-weiße Mistel und Wurm-Befall am Baum · Specht in HELP_TREE · Parasiten: 2 · Toast „Der Specht pickt Parasiten vom Baum.“"),
    ("p5_fungus.png", "Pilz-Symbiose gibt echte Nährstoffe",
     "Rote Fungus-Patches an der Eiche · Pilze: 1 · +15 % Glucose durch BaseTree.nutrient_mult · HUD-Panel aktualisiert"),
    ("p5_remote.png", "Eichhörnchen pflanzt einen Baum in Chunk 1",
     "Weit entfernte Kamera · Eichhörnchen in CARRY · neuer Baum bei x = +2304 px · Gelände/Chunks unverändert"),
]


def snippet(rel: str, start: str, lines: int = 14) -> str:
    text = (ROOT / rel).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(text):
        if start in line:
            return "\n".join(text[i:i + lines]).rstrip() + "\n"
    raise RuntimeError(f"Marker fehlt: {start!r} in {rel}")


SNIPPETS = [
    ("ForestHealth.gd — gewichtete Metrik und Gesundheits-Signal", "gdscript",
     snippet("src/systems/ForestHealth.gd", "const THRESHOLD := 0.5", 5)
     + "\n" + snippet("src/systems/ForestHealth.gd", "func recompute() -> float:", 22)),
    ("EventBus.gd — 13 neue, entkoppelte PHASE-5-Signale", "gdscript",
     snippet("src/autoload/EventBus.gd", "# --- PHASE 5: Tiere", 14)),
    ("Main.tscn — drei neue modulare System-Nodes", "gdscript",
     snippet("src/Main.tscn", '[ext_resource type="Script" path="res://src/systems/ForestHealth.gd"', 4)
     + "\n" + snippet("src/Main.tscn", '[node name="Wildlife" type="Node2D" parent="World"]', 8)),
    ("Animal.gd — echte StateMachine mit fünf Zuständen", "gdscript",
     snippet("src/animals/Animal.gd", "enum State { IDLE", 3)
     + "\n" + snippet("src/animals/Animal.gd", "func _set_state", 15)),
    ("Animal.gd — automatischer EAT-Zyklus, HELP_TREE und CARRY", "gdscript",
     snippet("src/animals/Animal.gd", "func tick(dt: float) -> void:", 28)),
    ("Animal.gd — Baum-Kollision und anklickbare Info", "gdscript",
     snippet("src/animals/Animal.gd", "func _blocked", 12)
     + "\n" + snippet("src/animals/Animal.gd", "func get_info_text() -> String:", 11)),
    ("Anthill.gd — Erd-Pixelhaufen wächst mit der Kolonie", "gdscript",
     snippet("src/animals/Anthill.gd", "func grow(amount: int = 1)", 6)
     + "\n" + snippet("src/animals/Anthill.gd", "func _draw() -> void:", 16)),
    ("WildlifeSystem.gd — Basisbesatzung und Reset", "gdscript",
     snippet("src/systems/WildlifeSystem.gd", "const BASE_WORMS", 7)
     + "\n" + snippet("src/systems/WildlifeSystem.gd", "func reset() -> void:", 14)),
    ("WildlifeSystem.gd — Gesundheits-Gate für Specht/Eichhörnchen", "gdscript",
     snippet("src/systems/WildlifeSystem.gd", "func _sync_advanced", 24)),
    ("WildlifeSystem.gd — Kolonie und Samen-Transport im Zeittakt", "gdscript",
     snippet("src/systems/WildlifeSystem.gd", "func _tick(dt: float) -> void:", 32)),
    ("WildlifeSystem.gd — Specht-Hilfe und Baum in entferntem Chunk", "gdscript",
     snippet("src/systems/WildlifeSystem.gd", "func on_woodpecker_help", 8)
     + "\n" + snippet("src/systems/WildlifeSystem.gd", "func debug_force_remote_seed", 18)),
    ("Parasite.gd — Mistel/Wurm ziehen echte Glucose ab", "gdscript",
     snippet("src/symbiosis/Parasite.gd", "enum Kind", 6)
     + "\n" + snippet("src/symbiosis/Parasite.gd", "func tick(dt: float)", 7)),
    ("ParasiteSystem.gd — Schwierigkeit und Resistenz steuern Spawns", "gdscript",
     snippet("src/systems/ParasiteSystem.gd", "func _try_spawn", 18)),
    ("ParasiteSystem.gd — Specht und Resistenz entfernen Befall", "gdscript",
     snippet("src/systems/ParasiteSystem.gd", "func remove_parasites_at", 17)),
    ("FungusPatch.gd — sichtbare, anklickbare Pilz-Symbiose", "gdscript",
     snippet("src/symbiosis/FungusPatch.gd", "func _draw() -> void:", 16)),
    ("generate_skilltree.gd — Pilz-Knoten liefert +15 % Nährstoffe", "gdscript",
     snippet("tools/generate_skilltree.gd", 'd.nodes.append(_node("mushroom_node"', 3)),
    ("SkillTree.gd / Tree.gd — Nährstoffe wirken in der Fotosynthese", "gdscript",
     snippet("src/systems/SkillTree.gd", "func apply_effect", 15)
     + "\n" + snippet("src/plants/Tree.gd", "func photosynthesize(", 12)),
    ("InteractionController.gd — Tiere/Parasiten/Pilze sind interaktiv", "gdscript",
     snippet("src/systems/InteractionController.gd", "func _left_click(pos: Vector2) -> void:", 22)),
    ("HUD.gd — kollisionsfreies Ökologie-Panel oben links", "gdscript",
     snippet("src/ui/HUD.gd", "# --- PHASE 5: Wald-Gesundheit", 14)),
    ("SaveManager.gd — Format v6 mit wildlife + parasites", "gdscript",
     snippet("src/systems/SaveManager.gd", "const FORMAT_VERSION", 3)
     + "\n" + snippet("src/systems/SaveManager.gd", "func save_game() -> bool:", 20)),
    ("Main.gd — reproduzierbare PHASE-5-Screenshot-Presets", "gdscript",
     snippet("src/Main.gd", 'if args.has("--phase5-shot-wildlife")', 12)),
    ("Phase5Smoke.gd — automatischer Futterzyklus ist regressionsgeprüft", "gdscript",
     snippet("tests/Phase5Smoke.gd", "# --- 3) StateMachine", 12)),
    ("localization.csv — DE/EN für HUD und Pilz-Beschreibung", "csv",
     snippet("data/localization.csv", "HUD_PHASE5", 3)
     + "\n" + snippet("data/localization.csv", "SKILL_MUSHROOM_DESC", 1)),
]

CHECKS = [
    "✅ <b>Master-Milestone erfüllt:</b> Wurm/Ameise spawnen, Specht hilft bei Befall, Pilz-Symbiose ist ein echter Node und die Mistel ist da. Alle vier Tiergruppen, StateMachine, Kollision, Interaktion, Ameisenhügel und Ferntransport sind zusätzlich umgesetzt.",
    "✅ <b>Wald-Gesundheit ist eine echte Metrik:</b> <code>0.02 × Blätter + 0.12 × Bäume + 0.08 × Tierarten + 0.04 × Pilz-Patches</code>, geklemmt auf 0..1. Das HUD zeigt Prozent und Balken; ab <b>&gt; 50 %</b> siedeln sich Specht und Eichhörnchen an, darunter ziehen sie wieder weiter.",
    "✅ <b>Dokumentierter Widerspruch:</b> Wurm + Ameise bleiben als <b>Basis-Biodiversität immer</b> vorhanden (2 + 2 Tiere + 1 Hügel); nur die beiden fortgeschrittenen Arten hängen am Gesundheits-Gate. Diese User-Entscheidung steht in <code>DECISIONS.md</code> §70.",
    "✅ <b>StateMachine statt statischer Sprites:</b> <code>IDLE / WANDER / EAT / HELP_TREE / CARRY</code>. Wurm/Ameise wechseln <b>automatisch</b> in <code>EAT</code> und geben Futter; der Smoke prüft erst ohne Klick/Force und danach zusätzlich den erzwungenen Zustand. Tiere weichen <code>BaseTree.get_bounds_rect()</code> aus; Specht im Hilfsflug und Eichhörnchen beim Transport dürfen gezielt an den Baum.",
    "✅ <b>Ameisenhügel und Kolonie:</b> Der Erd-Pixelhaufen ist anklickbar, zeigt seine Größe und wächst mit. Alle 10 simulierten Sekunden kommt eine Ameise dazu (Maximum 8); ab Koloniegröße 6 entsteht ein weiterer Hügel.",
    "✅ <b>Specht:</b> <code>parasite_spawned</code> schickt ihn in <code>HELP_TREE</code>; bei Ankunft ruft er <code>remove_parasites_at(..., 1)</code>. Entfernung wird als <code>woodpecker</code> protokolliert und per Toast gemeldet.",
    "✅ <b>Eichhörnchen / Vogel:</b> Nach 22 simulierten Sekunden trägt es eine Eichel in <code>CARRY</code> zu <b>+2304 px = Chunk 1</b> und pflanzt dort über <code>InteractionController.spawn_tree_at()</code> einen echten Baum. Screenshot <code>p5_remote.png</code>.",
    "✅ <b>Parasiten:</b> Mistel (0,35 Glucose/s) und Wurm-Befall (0,22 Glucose/s) ziehen echte Glucose ab. Spawn-Chance = <code>0.15 × disaster_rate × resistance(parasite_risk)</code>; Wurm-Entzug nutzt <code>resistance(disease_risk)</code>. LEICHT bleibt befallfrei. <code>parasite_res</code> / <code>disease_res</code> befreien vorhandene Bäume.",
    "✅ <b>Pilz-Symbiose:</b> <code>mushroom_node</code> liefert <code>nutrients = 0.15</code>; <code>SkillTree.apply_effect()</code> setzt <code>BaseTree.nutrient_mult = 1.15</code>. Fotosynthese multipliziert damit wirklich, sichtbare <code>FungusPatch</code>-Pilze erscheinen an allen Eichen und erhöhen die Gesundheit.",
    "✅ <b>Interaktion &amp; HUD:</b> Linksklick/Rechtsklick auf Tier, Hügel, Parasit oder Pilz geben eine lokalisierte Info, ohne die Eichel-Logik zu stören. Neues Panel oben links: Gesundheit, Futter, Tiere, Parasiten, Pilze; Toast liegt jetzt darunter bei y=190.",
    "✅ <b>Save v6 &amp; DE/EN:</b> Tiere, Futter, Kolonie, Hügel und Parasiten liegen im JSON; v5/v4/v3/v2/v1 bleiben lesbar. <code>data/localization.csv</code> hat 171 Zeilen; 35 neue PHASE-5-Schlüssel werden in DE und EN geprüft.",
    "✅ <b>Regression &amp; F5:</b> Import, F5 ohne Preset, 180-Frame-Dauerlauf und <b>10/10 Smokes</b> (P0/P1/P2/REV1/REV2/P3/REV3/REV4/PHASE4/PHASE5) laufen mit Exit 0 / <b>341 OK-Zeilen</b> / 0 Fehlern. AUTO bleibt aus, Skilltree bleibt bei 15 Knoten, 5 Chunks bleiben geladen.",
    "✅ <b>Screenshots &amp; ZIP:</b> Sechs neue 1920×1080-Godot-Renders sind visuell geprüft und offline eingebettet. <code>waldspiel-PHASE5.zip</code> hat <code>project.godot</code> im Root, CRC OK, keinen <code>.godot</code>-Cache und wurde als frischer Extrakt mit Import + allen 10 Smokes verifiziert.",
]

NOTES = [
    "„Specht hilft bei Wurmbefall“ wird so interpretiert, dass frei lebende Würmer nützliche Futter-Tiere bleiben und ein separater Borkenlarven-Befall (Parasite.Kind.WORM) gemeinsam mit der Mistel weggepickt wird. Siehe DECISIONS.md §70.",
    "Sturm-/Dürre-/Borkenkäfer-Ereignisse sowie pH-, N-P-K- und Mykorrhiza-Simulation bleiben der späteren vollen Simulation (Master-Punkt 4.2) vorbehalten; die vorhandenen Schalter/Faktoren werden nicht als implementierte Ereignisse ausgegeben. Es wurde keine PHASE 6 begonnen.",
    "Xvfb + opengl3/llvmpipe ist ein Software-Rasterizer für reproduzierbare Renders; Ziel-Renderer bleibt Forward+ / Vulkan. Alle P5-Renders nutzen --fixed-fps 10, damit zeitgesteuerte Zustandswechsel in 25 Frames sichtbar werden.",
    "Keine neuen externen Assets, Addons oder C#-Dateien. Wurm, Ameise, Specht, Eichhörnchen, Hügel, Mistel, Larve und Pilze werden zur Laufzeit gezeichnet; alle Pfade sind relativ.",
]

CSS = """
:root{--bg:#0b100e;--card:#131b17;--line:#26362d;--fg:#e7efe8;--sub:#9fb3a6;--green:#8ed081;--blue:#7fb7e8;--amber:#e8c87f;--red:#e88f8f}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1180px;margin:0 auto;padding:34px 22px 70px}header{border-bottom:1px solid var(--line);padding-bottom:24px;margin-bottom:30px}
h1{font-size:2.15rem;margin:0 0 8px;letter-spacing:.01em}h2{font-size:1.4rem;margin:42px 0 14px;border-left:4px solid var(--green);padding-left:12px}
h3{font-size:1rem;margin:20px 0 8px;color:var(--blue)}p.sub{color:var(--sub)}
.badges{display:flex;flex-wrap:wrap;gap:8px;margin-top:18px}.badge{background:var(--card);border:1px solid var(--line);border-radius:999px;padding:6px 13px;font-size:.84rem}
.badge.zip{color:var(--green);border-color:#3d6b45}.badge.p5{color:var(--amber);border-color:#6b5a35}
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
    protocol = (ROOT / "PHASE5-TESTPROTOKOLL.txt").read_text(encoding="utf-8")
    out = ["# PHASE 5 — Tiere & Symbiose", "",
           "**Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05**", "",
           "Wurm/Ameise als immer vorhandene Basis, Specht/Eichhörnchen ab Wald-Gesundheit > 50 %, Mistel/Wurm-Befall, echte Pilz-Symbiose, StateMachine, Kollision, Interaktion, Save v6. **10/10 Smokes · 341 OK-Zeilen · 0 Fehler.**", "",
           "## 1 · Screenshots (echte Godot-Renders)", ""]
    for f, title, sub in SHOTS:
        out += [f"### {title}", f"*{sub}*", "", f"![{title}](screenshots/{f})", ""]
    out += ["## 2 · Code-Snippets (aus den echten Projektdateien)", ""]
    for title, lang, code in SNIPPETS:
        out += [f"### {title}", "", f"```{lang}", code.rstrip(), "```", ""]
    out += ["## 3 · Testprotokoll", "", "```text", protocol.strip(), "```", "",
            "## 4 · Abnahme PHASE 5", ""]
    for c in CHECKS:
        out.append("- " + c.replace("<b>", "**").replace("</b>", "**")
                   .replace("<code>", "`").replace("</code>", "`")
                   .replace("&amp;", "&").replace("&gt;", ">"))
    out += ["", "## 5 · Hinweise / bewusste Grenzen", ""]
    out += [f"- {n}" for n in NOTES]
    out += ["", "## 6 · Lieferumfang", "",
            "- `deliverables/waldspiel-PHASE5.zip` — vollständiges, Godot-importierbares Projekt (`project.godot` im ZIP-Root, `.godot` ausgeschlossen, CRC OK, frischer Extrakt geprüft)",
            "- `PHASE5-ERGEBNIS.html` / `.md`, `PHASE5-TESTPROTOKOLL.txt`, `DECISIONS.md` §70, `README.md`, `GODOT-IMPORT.txt`, `deliverables/README.md`",
            "- `screenshots/p5_*.png` (6 Renders), `tests/Phase5Smoke.gd`, `tools/build_phase5_report.py`, `tools/build_zip.py`",
            "- Neue Quellen: `src/systems/ForestHealth.gd`, `WildlifeSystem.gd`, `ParasiteSystem.gd`, `src/animals/Animal.gd`, `Anthill.gd`, `src/symbiosis/Parasite.gd`, `FungusPatch.gd`",
            "- Geänderte Integration: `EventBus.gd`, `Global.gd`, `Main.gd/.tscn`, `HUD.gd`, `InteractionController.gd`, `SaveManager.gd`, `SkillTree.gd`, `Tree.gd`, `localization.csv`, `oak.tres`",
            "", "**PHASE 5 ist abgeschlossen. Keine PHASE 6 begonnen.**", ""]
    return "\n".join(out)


def build_html() -> str:
    protocol = (ROOT / "PHASE5-TESTPROTOKOLL.txt").read_text(encoding="utf-8")
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
<title>PHASE 5 — Tiere &amp; Symbiose — Wald-Regeneration</title><style>{CSS}</style></head>
<body><div class="wrap">
<header>
  <h1>PHASE 5 — Tiere &amp; Symbiose</h1>
  <p class="sub">Wald-Regeneration · Godot 4.7.2 stable · GDScript · Forward+/Vulkan · 2026-11-05<br>
  Wurm/Ameise · Specht · Eichhörnchen · Mistel/Wurm-Befall · Pilz-Symbiose · StateMachine · Save v6</p>
  <div class="badges">
    <span class="badge zip">✓ komplette ZIP</span>
    <span class="badge p5">✓ 4 Tiergruppen</span>
    <span class="badge p5">✓ StateMachine</span>
    <span class="badge p5">✓ 13 EventBus-Signale</span>
    <span class="badge">10 / 10 Smokes OK</span>
    <span class="badge">341 OK-Zeilen</span>
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

<h2>4 · Abnahme PHASE 5</h2>
<ul>{checks_html}</ul>

<h2>5 · Hinweise / bewusste Grenzen</h2>
<div class="note"><ul>{notes_html}</ul></div>

<h2>6 · Lieferumfang</h2>
<ul>
  <li><code class="inl">deliverables/waldspiel-PHASE5.zip</code> — vollständiges, Godot-importierbares Projekt, <code class="inl">project.godot</code> im ZIP-Root, CRC OK, frischer Extrakt geprüft</li>
  <li><code class="inl">PHASE5-ERGEBNIS.html</code> / <code class="inl">.md</code>, <code class="inl">PHASE5-TESTPROTOKOLL.txt</code>, <code class="inl">DECISIONS.md</code> (§70)</li>
  <li><code class="inl">screenshots/p5_*.png</code> (6 Renders), <code class="inl">tests/Phase5Smoke.gd</code>, <code class="inl">tools/build_phase5_report.py</code></li>
  <li>Neue Quellen: <code class="inl">ForestHealth.gd</code>, <code class="inl">WildlifeSystem.gd</code>, <code class="inl">ParasiteSystem.gd</code>, <code class="inl">Animal.gd</code>, <code class="inl">Anthill.gd</code>, <code class="inl">Parasite.gd</code>, <code class="inl">FungusPatch.gd</code></li>
</ul>

<footer><strong>PHASE 5 ist abgeschlossen.</strong> Sturm-/Dürre-/Borkenkäfer-Ereignisse sowie pH-/N-P-K-/Mykorrhiza-Simulation bleiben einer späteren Ausbaustufe vorbehalten; es wurde keine PHASE 6 begonnen.</footer>
</div></body></html>
"""


if __name__ == "__main__":
    (ROOT / "PHASE5-ERGEBNIS.md").write_text(build_md(), encoding="utf-8")
    (ROOT / "PHASE5-ERGEBNIS.html").write_text(build_html(), encoding="utf-8")
    print(f"Berichte geschrieben: PHASE5-ERGEBNIS.md / .html | {len(SHOTS)} Bilder | {len(SNIPPETS)} Snippets")
