class_name PlatformerPlayer
extends CharacterBody2D

@export var move_speed: float = 240.0
@export var acceleration: float = 1400.0
@export var deceleration: float = 1800.0
@export var gravity: float = 1400.0
@export var jump_velocity: float = -520.0
@export_range(1, 2, 1) var max_jumps: int = 2

@onready var body_visual: AnimatedSprite2D = $Sprite

var jumps_remaining: int

func _ready() -> void:
	jumps_remaining = max_jumps

func _physics_process(delta: float) -> void:
	if is_on_floor():
		velocity.y = minf(velocity.y, 0.0)
		jumps_remaining = max_jumps
	else:
		velocity.y += gravity * delta

	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * move_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)

	if Input.is_action_just_pressed("jump") and jumps_remaining > 0:
		velocity.y = jump_velocity
		jumps_remaining -= 1

	move_and_slide()
	_update_animation(direction)

func _update_animation(direction: float) -> void:
	if not is_on_floor():
		body_visual.play("jump" if velocity.y < 0.0 else "fall")
	elif not is_zero_approx(direction):
		body_visual.play("run")
	else:
		body_visual.play("idle")

	if not is_zero_approx(direction):
		body_visual.flip_h = direction < 0.0
