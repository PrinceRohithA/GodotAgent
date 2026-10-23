extends Node2D

var collected := 0
var total := 3
@onready var status: Label = $HUD/Status
@onready var message: Label = $HUD/Message

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	status.text = "GEMS: 0 / %d    |    A/D or Arrows: Move    SPACE: Jump (Double)    R: Restart" % total
	message.text = "SKYBOUND TRAIL"
	_connect_gameplay_signals()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().paused = false
		get_tree().reload_current_scene()

func _connect_gameplay_signals() -> void:
	for gem in $Collectibles.get_children():
		gem.body_entered.connect(_on_gem_body_entered.bind(gem))
	$Goal.body_entered.connect(_on_goal_body_entered)

func _on_gem_body_entered(body: Node2D, gem: Area2D) -> void:
	if body.name == "Player":
		collected += 1
		gem.queue_free()
		status.text = "GEMS: %d / %d    |    Reach the golden portal!" % [collected, total]

func _on_goal_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		message.text = "TRAIL COMPLETE!  Press R to replay"
		get_tree().paused = true
