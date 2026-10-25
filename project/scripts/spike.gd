extends Area2D
## Floor spike hazard. Resets a player to its configured respawn point on contact.

@export var damage_enabled: bool = true

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not damage_enabled or not body is CharacterBody2D:
		return
	if body.has_method("respawn_from_hazard"):
		body.respawn_from_hazard()
	elif "respawn_position" in body:
		body.global_position = body.respawn_position
		body.velocity = Vector2.ZERO
