extends CharacterBody2D
## Player movement controller for the platforming level.

@export_category("Movement")
@export var move_speed: float = 260.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var jump_velocity: float = -520.0
@export var gravity: float = 1400.0

@export_category("Jump Feel")
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export_range(0, 1) var extra_air_jumps: int = 1

@export_category("Recovery")
@export var fall_reset_y: float = 700.0
@export var respawn_position: Vector2 = Vector2(-480.0, 140.0)

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _air_jumps_left: int = 0
@onready var _sprite: AnimatedSprite2D = $Sprite2D

func _ready() -> void:
	if respawn_position == Vector2.ZERO:
		respawn_position = global_position
	_air_jumps_left = extra_air_jumps

func _physics_process(delta: float) -> void:
	_update_jump_timers(delta)
	_apply_gravity(delta)
	_handle_horizontal_movement(delta)
	_handle_jump()
	move_and_slide()
	_update_animation()
	_check_fall_reset()

func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
		_air_jumps_left = extra_air_jumps
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = minf(velocity.y, 0.0)

func _handle_horizontal_movement(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var target_speed := direction * move_speed
	var rate := acceleration if not is_zero_approx(direction) else deceleration
	velocity.x = move_toward(velocity.x, target_speed, rate * delta)

func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			_start_jump()
			_coyote_timer = 0.0
		elif _air_jumps_left > 0:
			_start_jump()
			_air_jumps_left -= 1
		_jump_buffer_timer = 0.0
	elif Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.5

func _start_jump() -> void:
	velocity.y = jump_velocity

func _update_animation() -> void:
	if not is_on_floor():
		_sprite.play("jump" if velocity.y < 0.0 else "fall")
	elif not is_zero_approx(velocity.x):
		_sprite.play("run")
	else:
		_sprite.play("idle")
	_sprite.flip_h = velocity.x < 0.0

func respawn_from_hazard() -> void:
	global_position = respawn_position
	velocity = Vector2.ZERO

func _check_fall_reset() -> void:
	if global_position.y > fall_reset_y or Input.is_action_just_pressed("restart"):
		respawn_from_hazard()
