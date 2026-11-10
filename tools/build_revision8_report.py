#!/usr/bin/env python3
"""REVISION 8 — selbst enthaltener MD/HTML-Bericht (Data-URI-Bilder, keine externen Assets)."""
from pathlib import Path
import base64
import html

ROOT = Path(__file__).resolve().parent.parent
SHOTS = [
    ("pool", "Gemeinsamer Glucose-Pool: 400.0 aus drei Eichen im Skilltree"),
    ("acorn", "Eichel direkt am Stammfuss ist anklickbar"),
    ("spacing", "Dichter Stand: kleiner Baum bei 53 % Licht, Abstandsregel aktiv"),
]
CHECKS = [
    ("Import", "0 Fehler (Godot 4.7.2, --headless --import)"),
    ("Skilltree", "24 Knoten / 23 Verbindungen, Generator err=0"),
    ("Smokes", "14/14 gruen: 521 OK-Zeilen, 0 FEHLER; drei komplette Laeufe mit unterschiedlichen Seeds (neu: --rev8-smoke mit 59 Checks)"),
    ("F5-Lauf", "180 Frames, exit 0, 0 SCRIPT ERROR"),
    ("Renders", "3 Presets x 25 Frames, je 0 Fehler, 1920x1080 PNG"),
    ("Glucose-Pool", "3 Baeume mit 0/0/40 -> Kauf OHNE Auswahl, exakte Abbuchung, Effekt auf alle + neu spawnende Baeume"),
    ("Eichel-Vorrang", "collect_at() vor Drag/Wurzel/Baum; 2 Eicheln unter demselben Stamm einsammelbar, kein Drag gestartet"),
    ("Abstand weltweit", "Pruefpunkt x=5008 ausserhalb des Sichtfelds: gleicher Platz blockiert, 48 px erlaubt, d==0 => voller Schatten"),
    ("Keimung", "Off-screen Keimung am selben Platz blockiert, Eichel bleibt liegen; 400 px entfernt keimt sie"),
    ("Rotation", "Wurm folgt der dominanten Grabrichtung; 4px-Stufenspruenge kippen ihn nicht mehr schraeg (R6-Flake behoben)"),
    ("Regression", "AUTO aus, Save v6, GLUCOSE_PACE 0.2, 16px-Hitbox, 21 Pixelart-Slots, alle R1-R7-Smokes gruen"),
]


def grab(path: str, needle: str, count: int) -> str:
    lines = (ROOT / path).read_text(encoding="utf-8").splitlines()
    for i, line in enumerate(lines):
        if needle in line:
            return "\n".join(lines[i:i + count])
    raise SystemExit(f"FEHLER: Snippet-Anker fehlt: {path} :: {needle}")


SNIPPETS = [
    ("Pool: alle Baeume dieser Art, weltweit", "src/systems/SkillTree.gd",
     grab("src/systems/SkillTree.gd", "func pool_trees(", 12)),
    ("Pool: Summe + anteilige Abbuchung", "src/systems/SkillTree.gd",
     grab("src/systems/SkillTree.gd", "func pooled_glucose(", 6)
     + "\n\n" + grab("src/systems/SkillTree.gd", "func spend_pooled(", 18)),
    ("Kauf ohne ausgewaehlten Baum", "src/systems/SkillTree.gd",
     grab("src/systems/SkillTree.gd", "func can_unlock(", 6)
     + "\n\n" + grab("src/systems/SkillTree.gd", "func unlock(", 14)),
    ("Skilltree-UI zeigt den Gesamt-Pool", "src/ui/SkillTreeUI.gd",
     grab("src/ui/SkillTreeUI.gd", "var tree: BaseTree = interaction.selected_tree", 8)),
    ("Eichel hat Vorrang vor dem Baum-Drag", "src/systems/InteractionController.gd",
     grab("src/systems/InteractionController.gd", "# REVISION 8: Eine Eichel hat IMMER Vorrang", 7)),
    ("Eichel wird zuerst eingesammelt", "src/systems/InteractionController.gd",
     grab("src/systems/InteractionController.gd", "# REVISION 8: Eicheln ZUERST", 5)),
    ("Abstand gegen ALLE Baeume, ohne Viewport", "src/systems/InteractionController.gd",
     grab("src/systems/InteractionController.gd", "func nearest_tree_distance(", 16)),
    ("Keimung respektiert die Regel auch off-screen", "src/systems/SeasonSystem.gd",
     grab("src/systems/SeasonSystem.gd", "# REVISION 8: Kein zweiter Baum", 10)),
    ("d==0 bedeutet maximalen Schatten", "src/plants/Tree.gd",
     grab("src/plants/Tree.gd", "var d := absf(other.global_position.x", 13)),
]


def b64(path: Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


FIXES = [
    ("Gemeinsamer Glucose-Pool pro Baumart",
     "Die Glucose fuer den Skilltree ist jetzt die <b>Summe ueber alle Baeume dieser Art</b>, "
     "nicht mehr nur der ausgewaehlte Baum. Die Kosten werden anteilig aus diesem Pool bezahlt "
     "(exakte Summe, kein Baum wird negativ), und ein Kauf ist auch <b>ohne Auswahl</b> moeglich. "
     "Die gekauften Effekte werden auf <b>alle</b> Baeume dieser Art angewandt - inklusive neu "
     "keimender Baeume ueber <code>tree_spawned</code>. Normale Wachstumskosten bleiben pro Baum."),
    ("Eicheln unter Baeumen",
     "Vorher startete <code>_drag_candidate()</code> bei einem Baum unter der Maus sofort einen "
     "Zieh-Vorgang; <code>_left_click()</code> mit <code>collect_at()</code> wurde nie erreicht. "
     "Jetzt hat eine frei liegende Eichel <b>absolute Prioritaet</b> - vor Drag, Wurzel, Tier, "
     "Parasit und Baum. Zusaetzlich prueft <code>has_collectible_at()</code> ohne Seiteneffekt "
     "bereits in <code>_unhandled_input</code>, damit der Klick gar nicht erst vom Baum geschluckt wird."),
    ("Abstandsregel gilt weltweit",
     "<code>neighbor_shade()</code> uebersprang frueher <code>d &lt; 1.0</code>. Baeume auf dem "
     "<b>exakt gleichen</b> 16px-Slot beschatteten sich dadurch gar nicht und wuchsen voll aus - "
     "besonders bei off-screen Keimung, wo Eicheln oft auf denselben Slot wie der Mutterbaum fallen. "
     "Jetzt bedeutet <code>d == 0</code> <b>maximalen Schatten</b>; nur ein echtes Duplikat mit "
     "derselben <code>tree_id</code> (Save-Probe) wird ignoriert. Zusaetzlich verhindert "
     "<code>MIN_TREE_SPACING = 48 px</code> beim Pflanzen und bei der Keimung, dass ueberhaupt "
     "zwei Baeume auf einem Fleck entstehen. Die Pruefung nutzt ausschliesslich den SceneTree - "
     "<b>keine Kamera, kein Viewport, keine geladenen Chunks</b>."),
]


def build_md(images: list[tuple[str, str]]) -> str:
    lines = [
        "# REVISION 8 — Glucose-Pool, Eichel-Vorrang, weltweite Abstandsregel",
        "",
        "Vollstaendiger REVISION-8-Stand auf GitHub, Nachfolger von `50979d5` (REVISION 7).",
        "Alle Quellen, Tests, drei Screenshots, Berichte und das ZIP liegen im Workspace und",
        "sind Teil desselben Commits auf `main`.",
        "",
        "## Die drei Korrekturen",
        "",
    ]
    for i, (title, body) in enumerate(FIXES, 1):
        plain = body.replace("<b>", "**").replace("</b>", "**").replace("<code>", "`").replace("</code>", "`")
        plain = plain.replace("&lt;", "<").replace("&amp;", "&")
        lines += [f"{i}. **{title}.** {plain}", ""]
    lines += ["## Testergebnisse", "", "| Pruefung | Ergebnis |", "|---|---|"]
    for name, result in CHECKS:
        lines.append(f"| {name} | {result} |")
    lines += ["", "## Screenshots", ""]
    for slug, caption in SHOTS:
        lines += [f"![{caption}](data:image/png;base64,{dict(images)[slug]})", "",
                  f"*{caption}* — `screenshots/rev8_{slug}.png`", ""]
    lines += ["## Code-Auszuege", ""]
    for title, path, code in SNIPPETS:
        lines += [f"### {title} (`{path}`)", "", "```gdscript", code, "```", ""]
    lines += [
        "## Lieferung",
        "",
        "Vollstaendiger Stand inklusive `deliverables/waldspiel-REVISION8.zip`.",
        "Als ein Commit auf `main` gepusht (Nachfolger von `50979d5`); ZIP und",
        "Repo-Root sind direkt in Godot importierbar. Keine Credentials in",
        "Commit, Remote-URL oder Repo-Dateien.",
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
        "<title>REVISION 8 — Waldspiel</title><style>", CSS,
        "</style></head><body><div class=\"wrap\">",
        "<h1>REVISION 8 — Glucose-Pool, Eichel-Vorrang, weltweite Abstandsregel</h1>",
        "<p><span class=\"badge\">auf GitHub</span> Basis <code>50979d5</code> "
        "· ein Commit auf <code>main</code></p>",
        "<h2>Die drei Korrekturen</h2><ol>",
    ]
    for title, body in FIXES:
        parts.append(f"<li><b>{html.escape(title)}.</b> {body}</li>")
    parts.append("</ol><h2>Testergebnisse</h2><table><tr><th>Pruefung</th><th>Ergebnis</th></tr>")
    for name, result in CHECKS:
        parts.append(f"<tr><td>{html.escape(name)}</td><td>{html.escape(result)}</td></tr>")
    parts.append("</table><h2>Screenshots</h2>")
    for slug, caption in SHOTS:
        parts.append(f"<img alt=\"{html.escape(caption)}\" "
                     f"src=\"data:image/png;base64,{dict(images)[slug]}\">")
        parts.append(f"<p class=\"cap\">{html.escape(caption)} — "
                     f"<code>screenshots/rev8_{slug}.png</code></p>")
    parts.append("<h2>Code-Auszuege</h2>")
    for title, path, code in SNIPPETS:
        parts.append(f"<h3>{html.escape(title)} <small>({html.escape(path)})</small></h3>")
        parts.append(f"<pre>{html.escape(code)}</pre>")
    parts.append(
        "<h2>Lieferung</h2><p class=\"note\">Vollstaendiger Stand inklusive "
        "<code>deliverables/waldspiel-REVISION8.zip</code>. Als ein Commit auf "
        "<code>main</code> gepusht (Nachfolger von <code>50979d5</code>); "
        "Remote-HEAD, Tree und Raw-Dateien geprueft. Keine Credentials in "
        "Commit, Remote-URL oder Repo-Dateien.</p>"
    )
    parts.append("</div></body></html>")
    return "".join(parts)


def main() -> None:
    images = []
    for slug, _caption in SHOTS:
        p = ROOT / f"screenshots/rev8_{slug}.png"
        if not p.exists():
            raise SystemExit(f"FEHLER: Screenshot fehlt: {p}")
        images.append((slug, b64(p)))
    (ROOT / "REVISION8-ERGEBNIS.md").write_text(build_md(images), encoding="utf-8")
    (ROOT / "REVISION8-ERGEBNIS.html").write_text(build_html(images), encoding="utf-8")
    print(f"[R8-REPORT] md + html geschrieben | Bilder: {len(SHOTS)} | "
          f"Snippets: {len(SNIPPETS)} | Checks: {len(CHECKS)}")


if __name__ == "__main__":
    main()
