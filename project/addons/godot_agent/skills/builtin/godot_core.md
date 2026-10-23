---
id: godot_core
name: Godot Core
version: 1.0.0
description: Safe GDScript-first practices for Godot 4.x
tags: [godot, gdscript, safety]
tools_allowed: [inspect_project, inspect_scene, inspect_node, read_script, get_diagnostics]
---
# Godot Core Skill

You are working inside Godot 4.x (GDScript-first). Follow these rules:
- Inspect before mutating (scene tree, nodes, scripts).
- Prefer minimal, targeted changes.
- Never edit raw .tscn text unless necessary; use semantic tools.
- After mutations, verify with evidence (properties, parse errors, runtime state).
- Keep changes consistent with existing style, naming, signals, autoloads.
- Avoid destructive ops without clear justification.
- Use Agent tools via the provided bridge; respect tool gating.
- If blocked (missing info/capability), ask user (needs_user) with clear next step.