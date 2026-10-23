# Skybound Trail

A compact pixel-art platformer built in Godot 4 using the supplied player sprite sheets and terrain atlas.

## Controls
- Move: A/D or arrow keys
- Jump / double jump: Space
- Restart: R
- Pause: P

## Objective
Collect all five cyan crystals, traverse the rising platforms, and reach the gate at the far right. Falling below the level ends the run; press R to restart.

## Structure
- `scenes/main.tscn` — level, collectibles, goal, HUD, and camera composition
- `scenes/player.tscn` — reusable CharacterBody2D player
- `scripts/main.gd` — game state, collection, win/death/restart flow
- `scripts/player.gd` — movement, gravity, double-jump, sprite state selection
- `assets/player/` — supplied player animation sheets
- `assets/Terrain (16x16).png` — supplied terrain atlas inspected and reimported

The current level uses the supplied player art and a clean neon crystal visual language for collectibles. The terrain atlas remains available for future TileMap dressing; collision geometry is authored from reusable platform bodies for reliable playability.
