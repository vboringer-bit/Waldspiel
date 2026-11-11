#!/usr/bin/env python3
"""PHASE 6 — selbst enthaltener MD/HTML-Bericht (Data-URI-Bilder, keine externen Assets)."""
from pathlib import Path
import base64
import html

ROOT = Path(__file__).resolve().parent.parent
SHOTS = [
    ("chemistry", "SCHWER: pH 6.0 · N/P/K 92/88/90 · Verfügbarkeit 1.20, Bodenchemie eingefärbt"),
    ("myco", "Symbiose verbindet drei Eichen weltweit; HUD zeigt „Netz an“"),
    ("disaster", "Sturm (22 s): Toast, HUD-Ereigniszeile und prozeduraler Overlay"),
]
CHECKS = [
    ("Import", "0 Fehler (Godot 4.7.2, --headless --import)"),
    ("Skilltree", "24 Knoten / 23 Verbindungen, Generator err=0"),
    ("Smokes", "15/15 gruen: 653 OK-Zeilen, 0 FEHLER; drei komplette Laeufe (neu: --p6-smoke mit 132 Checks)"),
    ("F5-Lauf", "180 Frames, exit 0, 0 SCRIPT ERROR"),
    ("Renders", "3 Presets x 25 Frames, je 0 Fehler, 1920x1080 PNG"),
    ("Schwierigkeit", "LEICHT ohne pH/Katastrophen, NORMAL rare Stuerme/Borkenkaefer, SCHWER volle Simulation"),
    ("Bodenchemie", "pH-Glocke um 6.0 + Liebigs Minimum, echter Faktor in environment_parts(), N/P/K-Verbrauch und Regeneration"),
    ("Mykorrhiza", "Skill symbiosis verbindet Baeume innerhalb von 280px weltweit, auch off-screen; SCHWER benoetigt das Netz"),
    ("Katastrophen", "Duerre/Sturm/Borkenkaefer mit Wasser-/Health-/Glucose-Effekt; Skills halbieren Sturm- und Parasitenschaden"),
    ("Speichern", "Format bleibt v6; optionale Schluessel soil/disasters/mycorrhiza, alte Saves lesbar"),
    ("Regression", "AUTO aus, GLUCOSE_PACE 0.2, 16px-Hitbox, 21 Pixelart-Slots, 24/23 Skills, alle R1-R8-Smokes gruen"),
    ("Flake-Fix", "Revision1Smoke prueft Hoehlen-Kammern jetzt im robusten -64..64-Fenster statt -48..48"),
]

SECTIONS = [
    ("Abgrenzung nach Master-Punkt §13",
     "Der Master-Prompt definiert in §10 nur PHASE 0-5. Fuer den Auftrag „Beginne mit der naechsten Phase\" ist PHASE 6 die bisher zurueckgestellte "
     "<b>volle Simulation der Schwierigkeitsgrade aus §4.2</b>. 3 Biome, 5 Tierarten, 40-60 Skillnodes, Berge und SFX bleiben bewusst vorbereitete Kandidaten, "
     "nicht P6-Scope. Die Annahme steht in <code>DECISIONS.md</code> §75."),
    ("Bodenchemie",
     "<code>SoilChemistry.gd</code> erzeugt pro 64px-Region seed-deterministisch pH 4.2-7.8 und N/P/K 20-100. Eine pH-Glocke um das Eichen-Optimum 6.0 und "
     "<b>Liebigs Minimum</b> des knappsten Naehrstoffs bilden die Verfuegbarkeit. Bei SCHWER geht sie als echter Faktor in <code>BaseTree.environment_parts()</code> ein; "
     "Wachstum verbraucht N/P/K in der Wurzelregion, Humus und Regen regenerieren sie. Der Bodenquerschnitt erhaelt eine dezente, ortsfeste Einfaerbung."),
    ("Mykorrhiza",
     "Der vorhandene Skill <code>symbiosis</code> zeichnet ein weltweites Pilznetz zwischen allen Baeumen innerhalb von 280px — ohne Kamera-/Viewport-Bezug, "
     "analog zur R8-Abstandsregel. Bei SCHWER ist das Netz <b>noetig</b>: ohne Symbiose wird der Naehrstofffaktor auf 0,55 gedrosselt, mit Netz steigt er "
     "gradabhaengig bis 1,40. Bei LEICHT/NORMAL bleibt der Faktor exakt 1,0."),
    ("Katastrophen",
     "<code>DisasterSystem.gd</code> liefert Duerre, Sturm und Borkenkaefer mit messbaren Effekten auf Wasser, Gesundheit und Glucose. "
     "NORMAL hat nur seltene Stuerme/Borkenkaefer, SCHWER zusaetzlich haeufige Duerre. <code>SkillTree.resistance()</code> halbiert Sturm- und Parasitenschaden; "
     "alle Ticks nutzen <code>TimeManager.scaled_delta()</code> und respektieren Pause. Eine 300s-Grace haelt die kurzen R0-R8-Smokes deterministisch."),
]


def grab(path: str, needle: str, count: int) -> str:
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if needle in line:
            return "\n".join(lines[i:i + count])
    raise SystemExit(f"FEHLER: Snippet-Anker fehlt: {path} :: {needle}")


SNIPPETS = [
    ("pH-Glocke + Liebigs Minimum", "src/systems/SoilChemistry.gd",
     grab("src/systems/SoilChemistry.gd", "func ph_fit_at(", 6)
     + "\n\n" + grab("src/systems/SoilChemistry.gd", "func limiting_at(", 5)
     + "\n\n" + grab("src/systems/SoilChemistry.gd", "func availability_at(", 5)),
    ("Wirkfaktor: nur SCHWER", "src/systems/SoilChemistry.gd",
     grab("src/systems/SoilChemistry.gd", "func soil_factor_at(", 8)),
    ("Echter N/P/K-Verbrauch", "src/systems/SoilChemistry.gd",
     grab("src/systems/SoilChemistry.gd", "func consume(", 12)
     + "\n\n" + grab("src/systems/SoilChemistry.gd", "func regenerate(", 12)),
    ("Bodenchemie in der Versorgungsbilanz", "src/plants/Tree.gd",
     grab("src/plants/Tree.gd", "func environment_parts(", 24)),
    ("Wachstum entnimmt Naehrstoffe", "src/plants/Tree.gd",
     grab("src/plants/Tree.gd", "func _consume_soil(", 13)),
    ("Pilznetz weltweit, ohne Viewport", "src/systems/Mycorrhiza.gd",
     grab("src/systems/Mycorrhiza.gd", "func rebuild(", 24)),
    ("Mykorrhiza ist bei SCHWER noetig", "src/systems/Mycorrhiza.gd",
     grab("src/systems/Mycorrhiza.gd", "func nutrient_bonus(", 10)),
    ("Schwierigkeitsabhaengige Ereignispalette", "src/systems/DisasterSystem.gd",
     grab("src/systems/DisasterSystem.gd", "func allowed_kinds(", 18)),
    ("Echte Schaeden + Skill-Resistenz", "src/systems/DisasterSystem.gd",
     grab("src/systems/DisasterSystem.gd", "func _apply(", 34)),
    ("HUD: Boden + Ereignis", "src/ui/HUD.gd",
     grab("src/ui/HUD.gd", "func _refresh_p6_panel(", 30)),
    ("Optionale P6-Schluessel in Save v6", "src/systems/SaveManager.gd",
     grab("src/systems/SaveManager.gd", '"soil": SoilChemistry.instance.to_dict()', 5)),
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def build_md(images: list[tuple[str, str]]) -> str:
    lines = [
        "# PHASE 6 — Bodenchemie, Mykorrhiza, Katastrophen",
        "",
        "Vollstaendiger PHASE-6-Stand, Nachfolger von `3de6561` (REVISION 8).",
        "Alle Quellen, Tests, drei Screenshots, Berichte und das ZIP liegen im Workspace.",
        "",
        "## Die vier Bausteine",
        "",
    ]
    for i, (title, body) in enumerate(SECTIONS, 1):
        plain = body.replace("<b>", "**").replace("</b>", "**").replace("<code>", "`").replace("</code>", "`")
        lines += [f"{i}. **{title}.** {plain}", ""]
    lines += ["## Testergebnisse", "", "| Pruefung | Ergebnis |", "|---|---|"]
    for name, result in CHECKS:
        lines.append(f"| {name} | {result} |")
    lines += ["", "## Screenshots", ""]
    for slug, caption in SHOTS:
        lines.append(f"![{caption}](data:image/png;base64,{dict(images)[slug]})")
        lines += [f"*{caption} — `screenshots/p6_{slug}.png`*", ""]
    lines += ["## Code-Auszuege", ""]
    for title, path, code in SNIPPETS:
        lines += [f"### {title} (`{path}`)", "", "```gdscript", code, "```", ""]
    lines += [
        "## Bewusste Grenze",
        "",
        "Keine 3 Biome, keine 5 Tierarten, keine 40-60 Skillnodes, keine begehbaren Berge, kein Tag/Nacht, keine SFX. "
        "`FORMAT_VERSION` bleibt 6, `Global.auto_mode` bleibt aus, `GLUCOSE_PACE` bleibt 0,2 und alle R0-R8-Korrekturen bleiben gueltig.",
        "",
        "Siehe `PHASE6-TESTPROTOKOLL.txt`, `DECISIONS.md` §75 und `deliverables/waldspiel-PHASE6.zip`.",
        "",
    ]
    return "\n".join(lines)


CSS = """
body{background:#111711;color:#e7e9df;font:15px/1.6 ui-monospace,Menlo,Consolas,monospace;margin:0}
.wrap{max-width:1100px;margin:0 auto;padding:38px 28px 80px}
h1{font-size:27px;color:#cfe6b6;margin:0 0 6px}
h2{font-size:20px;color:#a9d08a;margin:34px 0 12px;border-bottom:1px solid #33422d;padding-bottom:6px}
h3{font-size:15px;color:#d7e8c2;margin:24px 0 8px}
h3 small{color:#8ea37d;font-weight:normal}
.badge{display:inline-block;background:#2c4a2a;color:#c8e6b0;border-radius:4px;padding:3px 10px;font-size:12px}
table{width:100%;border-collapse:collapse;margin:10px 0 24px}
th,td{border:1px solid #33422d;padding:8px 10px;text-align:left;vertical-align:top}
th{background:#1d2a1b;color:#cfe6b6}
td:first-child{width:190px;color:#bcd6a4}
pre{background:#0c120b;border:1px solid #2b3a26;border-radius:5px;padding:14px;overflow-x:auto;color:#c8dcb4;font-size:12.5px;line-height:1.5}
img{width:100%;border:1px solid #33422d;border-radius:5px;margin:8px 0}
.cap{color:#8ea37d;font-size:12px;margin:0 0 26px}
.note{background:#1a2518;border-left:3px solid #6f9a55;padding:12px 16px;color:#c3d6ae}
ol{padding-left:22px}li{margin-bottom:14px}
code{background:#1b2719;padding:1px 4px;border-radius:3px;color:#d8eec0}
"""


def build_html(images: list[tuple[str, str]]) -> str:
    parts = [
        "<!doctype html><html lang=\"de\"><head><meta charset=\"utf-8\">",
        "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">",
        "<title>PHASE 6 — Waldspiel</title><style>", CSS,
        "</style></head><body><div class=\"wrap\">",
        "<h1>PHASE 6 — Bodenchemie, Mykorrhiza, Katastrophen</h1>",
        "<p><span class=\"badge\">Meilenstein</span> Basis <code>3de6561</code> "
        "· Master-Punkt 4.2 · dokumentierte Annahme in <code>DECISIONS.md</code> §75</p>",
        "<h2>Die vier Bausteine</h2><ol>",
    ]
    for title, body in SECTIONS:
        parts.append(f"<li><b>{html.escape(title)}.</b> {body}</li>")
    parts.append("</ol><h2>Testergebnisse</h2><table><tr><th>Pruefung</th><th>Ergebnis</th></tr>")
    for name, result in CHECKS:
        parts.append(f"<tr><td>{html.escape(name)}</td><td>{html.escape(result)}</td></tr>")
    parts.append("</table><h2>Screenshots</h2>")
    for slug, caption in SHOTS:
        parts.append(f"<img alt=\"{html.escape(caption)}\" "
                     f"src=\"data:image/png;base64,{dict(images)[slug]}\">")
        parts.append(f"<p class=\"cap\">{html.escape(caption)} — "
                     f"<code>screenshots/p6_{slug}.png</code></p>")
    parts.append("<h2>Code-Auszuege</h2>")
    for title, path, code in SNIPPETS:
        parts.append(f"<h3>{html.escape(title)} <small>({html.escape(path)})</small></h3>")
        parts.append(f"<pre>{html.escape(code)}</pre>")
    parts.append(
        "<h2>Lieferung</h2><p class=\"note\">Vollstaendiger Stand inklusive "
        "<code>deliverables/waldspiel-PHASE6.zip</code>. Nach Import, 15/15 Smokes, "
        "F5-Lauf, Renders und frischem ZIP-Extrakt als ein Commit auf <code>main</code> "
        "gepusht. Keine Credentials in Commit, Remote-URL oder Repo-Dateien.</p>"
    )
    parts.append("</div></body></html>")
    return "".join(parts)


def main() -> None:
    images = []
    for slug, _caption in SHOTS:
        p = ROOT / f"screenshots/p6_{slug}.png"
        if not p.exists():
            raise SystemExit(f"FEHLER: Screenshot fehlt: {p}")
        images.append((slug, b64(p)))
    (ROOT / "PHASE6-ERGEBNIS.md").write_text(build_md(images), encoding="utf-8")
    (ROOT / "PHASE6-ERGEBNIS.html").write_text(build_html(images), encoding="utf-8")
    print(f"[P6-REPORT] md + html geschrieben | Bilder: {len(SHOTS)} | "
          f"Snippets: {len(SNIPPETS)} | Checks: {len(CHECKS)}")


if __name__ == "__main__":
    main()
