# Vae Victis: agent instructions

Read [README.md](README.md) and [docs/STATUS.md](docs/STATUS.md) first, then [docs/DESIGN.md](docs/DESIGN.md) for anything touching the game itself.

- The design doc is the source of truth for the game. Change it when the game changes; record why in [docs/DECISIONS.md](docs/DECISIONS.md).
- Godot 4.7, GDScript only (C# can't export to the web). Engine: `C:\Users\ringd\tools\godot\4.7\Godot_v4.7-stable_win64_console.exe`.
- Keep game rules (stats, checks, combat math, quest state) in plain GDScript with no scene dependencies, and test them headless.
- All player-facing text goes in data files, never in code. T may rewrite all of it later.
- Every non-trivial quest has at least three routes; see the quest standard in the design doc.
- Tone guardrails in the design doc are binding: no Asterix, no cartoon villains, no sexual violence content.
- Placeholder names stay placeholders until T names them.
- Update docs/STATUS.md when a milestone moves. Project note in T's vault: `projects/Vae Victis.md`.
