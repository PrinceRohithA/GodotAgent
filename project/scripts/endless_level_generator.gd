extends Node2D
## Streams procedural terrain chunks and reusable spike hazards ahead of the player.
## Terrain is generated into TileMapLayer chunks; dynamic scene instancing is limited to hazards.

@export_category("References")
@export var player_path: NodePath = NodePath("../Player")
@export var ground_layer_path: NodePath = NodePath("../Environment/Ground_Base")
@export var hazard_parent_path: NodePath = NodePath("..")
@export var spike_scene: PackedScene = preload("res://scenes/spike.tscn")

@export_category("Chunk Layout")
@export var tile_size: int = 16
@export var chunk_width: int = 32
@export var ground_top_row: int = 20
@export var ground_fill_rows: int = 3
@export var initial_chunks: int = 4
@export var chunks_ahead: int = 3
@export var chunks_behind: int = 2
@export var surface_tile: Vector2i = Vector2i(7, 0)
@export var fill_tile: Vector2i = Vector2i(7, 1)
@export var source_id: int = 0
@export var clear_existing_cells: bool = true

@export_category("Generation")
@export var hazard_chance: float = 0.16
@export var minimum_hazard_spacing: int = 8
@export var random_seed: int = 0

var _ground_layer: TileMapLayer
var _player: CharacterBody2D
var _hazard_parent: Node
var _generated_chunks: Dictionary = {}
var _last_hazard_cell: int = -1000000
var _rng := RandomNumberGenerator.new()
var _next_chunk_index: int = 0

func _ready() -> void:
	_ground_layer = get_node_or_null(ground_layer_path) as TileMapLayer
	_player = get_node_or_null(player_path) as CharacterBody2D
	_hazard_parent = get_node_or_null(hazard_parent_path)
	if _ground_layer == null or _player == null or _hazard_parent == null:
		push_error("EndlessLevelGenerator references are invalid.")
		return
	_rng.seed = random_seed if random_seed != 0 else hash(get_path())
	if clear_existing_cells:
		_ground_layer.clear()
	var player_chunk := _world_to_chunk(_player.global_position.x)
	for chunk_index in range(player_chunk - 1, player_chunk + initial_chunks):
		_generate_chunk(chunk_index)
	_next_chunk_index = player_chunk + initial_chunks

func _process(_delta: float) -> void:
	if _player == null or _ground_layer == null:
		return
	var player_chunk := _world_to_chunk(_player.global_position.x)
	for chunk_index in range(player_chunk, player_chunk + chunks_ahead + 1):
		_generate_chunk(chunk_index)
	for chunk_index in _generated_chunks.keys():
		if int(chunk_index) < player_chunk - chunks_behind:
			_remove_chunk(int(chunk_index))

func _world_to_chunk(world_x: float) -> int:
	return floori(world_x / float(chunk_width * tile_size))

func _generate_chunk(chunk_index: int) -> void:
	if _generated_chunks.has(chunk_index):
		return
	var first_cell_x := chunk_index * chunk_width
	var end_cell_x := first_cell_x + chunk_width - 1
	for cell_x in range(first_cell_x, end_cell_x + 1):
		_ground_layer.set_cell(Vector2i(cell_x, ground_top_row), source_id, surface_tile, 0)
		for row in range(1, ground_fill_rows):
			_ground_layer.set_cell(Vector2i(cell_x, ground_top_row + row), source_id, fill_tile, 0)
		_try_spawn_hazard(cell_x, chunk_index)
	_generated_chunks[chunk_index] = true

func _try_spawn_hazard(cell_x: int, chunk_index: int) -> void:
	if cell_x - _last_hazard_cell < minimum_hazard_spacing:
		return
	if _rng.randf() > hazard_chance:
		return
	var spike := spike_scene.instantiate()
	spike.name = "Spike_%d_%d" % [chunk_index, cell_x]
	spike.position = Vector2(cell_x * tile_size + tile_size * 0.5, ground_top_row * tile_size)
	_hazard_parent.call_deferred("add_child", spike)
	_last_hazard_cell = cell_x

func _remove_chunk(chunk_index: int) -> void:
	var first_cell_x := chunk_index * chunk_width
	var end_cell_x := first_cell_x + chunk_width - 1
	for cell_x in range(first_cell_x, end_cell_x + 1):
		for row in range(ground_fill_rows):
			_ground_layer.erase_cell(Vector2i(cell_x, ground_top_row + row))
	for child in _hazard_parent.get_children():
		if child.name.begins_with("Spike_%d_" % chunk_index):
			child.queue_free()
	_generated_chunks.erase(chunk_index)
