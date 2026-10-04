# Live smoke — TileMap / TileSet tools (TileMapLayer-first)

**Generated:** 2026-10-04 09:17:51 UTC
**Transport:** `http:http://127.0.0.1:9090/mcp`
**Project:** GodotAgentTest
**Terrain:** `res://assets/pixel_adventure_1/Terrain/Terrain (16x16).png`

**Rollup:** pass=43 fail=0 blocked=0

| # | Step | Status | Detail |
|---|------|--------|--------|
| 1 | Open main scene | **pass** | {"tree": {"name": "Main", "type": "Node2D", "path": ".", "script": "res://scripts/main.gd", "children": [{"name": "Camera2D", "type": "Camera2D", "path": "Camer |
| 2 | Create TileMapLayer | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "created": true, "dry_run": false} |
| 3 | tileset_create 16x16 | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "res://tilesets/smoke_terrain.tres", "tile_size": [16, 16], "cr |
| 4 | tileset_add_atlas Terrain | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "texture_path": "res://assets/pixel_adventu |
| 5 | tileset_create_tile (0, 0) | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [0, 0], "size": [1, 1], "dr |
| 6 | tileset_create_tile (1, 0) | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [1, 0], "size": [1, 1], "dr |
| 7 | tileset_create_tile (2, 0) | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [2, 0], "size": [1, 1], "dr |
| 8 | tileset_create_tile (0, 1) | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [0, 1], "size": [1, 1], "dr |
| 9 | tileset_inspect | **pass** | {"node_path": "SmokeTileLayer", "tileset_path": "", "tile_size": [16, 16], "sources": [{"is_atlas": true, "source_id": 0, "texture_path": "res://assets/pixel_ad |
| 10 | tileset_atlas_inspect | **pass** | {"node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "texture_path": "res://assets/pixel_adventure_1/Terrain/Terrain (16x16).png", "texture_size" |
| 11 | add_tileset_physics_layer | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "physics_layer": 0, "collision_layer": 1, "collision_mask": |
| 12 | set_tile_collision full_rect | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [0, 0], "alternative_tile": |
| 13 | get_tile_data VERIFY collision | **pass** | {"node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [0, 0], "alternative_tile": 0, "physics": [{"constant_angular_velocity": 0.0 |
| 14 | verify collision polygons present | **pass** | polygons=1 |
| 15 | tilemap_layer_set_physics ON | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "collision_enabled": true, "navigation_enabled": null, "use_kinematic_bodies":  |
| 16 | tilemap_fill_rect ground | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "rect": [0, 10, 24, 2], "cells": 48, "layer": 0, "dry_run": false, "deprecated_ |
| 17 | tilemap_set_cells_batch accents | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "cells": 2, "layer": 0, "dry_run": false} |
| 18 | tilemap_get_cell verify | **pass** | {"node_path": "SmokeTileLayer", "coords": [0, 10], "source_id": 0, "atlas_coords": [0, 0], "alternative_tile": 0, "empty": false, "deprecated_tilemap": null, "m |
| 19 | clear_tile_collision (negative prep) | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [0, 0], "alternative_tile": |
| 20 | get_tile_data VERIFY no collision | **pass** | {"node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [0, 0], "alternative_tile": 0, "physics": [{"constant_angular_velocity": 0.0 |
| 21 | verify collision cleared | **pass** | polygons=0 |
| 22 | set_tile_collision restore | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 0, "atlas_coords": [0, 0], "alternative_tile": |
| 23 | add_tileset_custom_data_layer damage | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": null, "atlas_coords": null,  |
| 24 | set_tile_custom_data damage=20 | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": 0, "atlas_coords": [0, 0], " |
| 25 | add_tileset_terrain_set | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": null, "atlas_coords": null,  |
| 26 | add_tileset_terrain ground | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": null, "atlas_coords": null,  |
| 27 | TERRAIN_NOT_CONFIGURED gate | **pass** | TERRAIN_NOT_CONFIGURED: terrain_set 99 is not configured on the TileSet. |
| 28 | tileset_add_pattern room | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": null, "atlas_coords": null,  |
| 29 | P3-A add_tileset_navigation_layer | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": null, "atlas_coords": null,  |
| 30 | P3-A set_tile_navigation | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": 0, "atlas_coords": [0, 0], " |
| 31 | P3-A tilemap_layer_set_navigation | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "collision_enabled": null, "navigation_enabled": true, "use_kinematic_bodies":  |
| 32 | P3-B add_tileset_occlusion_layer | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": null, "atlas_coords": null,  |
| 33 | P3-B set_tile_occlusion | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": 0, "atlas_coords": [0, 0], " |
| 34 | P3-C add_tileset_scenes_collection_source | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "source_id": 1, "texture_path": "", "region_size": [16, 16] |
| 35 | P3-D set_tile_constant_velocity | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "tileset_path": "", "dry_run": false, "source_id": 0, "atlas_coords": [0, 0], " |
| 36 | P3-D tilemap_layer_set_kinematic | **pass** | {"persisted": true, "reason": null, "hint": null, "node_path": "SmokeTileLayer", "collision_enabled": null, "navigation_enabled": null, "use_kinematic_bodies":  |
| 37 | tilemap_inspect layers | **pass** | {"layers": {"node_path": "SmokeTileLayer", "node_type": "TileMapLayer", "layers": [{"index": 0, "name": "SmokeTileLayer", "enabled": true, "collision_enabled":  |
| 38 | play_scene | **pass** | {"playing": true, "scene": "res://scenes/main.tscn", "paused": false, "probe_connected": true, "hint": ""} |
| 39 | observe_runtime after play | **pass** | ok |
| 40 | playtest collision_enabled=false | **pass** | toggled |
| 41 | playtest collision_enabled=true | **pass** | restored |
| 42 | stop_game | **pass** | ok |
| 43 | verify tileset_inspect sources | **pass** | count=1 |
