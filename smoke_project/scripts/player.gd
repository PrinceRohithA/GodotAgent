extends CharacterBody2D
## Placeholder player for Phase-0 hybridindie live smoke (12 acceptance tests).

const SPEED := 221.0
const JUMP_VELOCITY := -360.0

@onready var anim: AnimationPlayer = $AnimationPlayer


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
		if anim and anim.has_animation("walk"):
			anim.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		if anim and anim.has_animation("idle"):
			anim.play("idle")

	move_and_slide()
