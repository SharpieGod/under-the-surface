extends Node2D

var tracker: Node = null
@export var cursor_left: Node2D
@export var cursor_right: Node2D

func _ready():
	tracker = get_node_or_null("HandTracker")
	print("Tracker: ", tracker)
	if tracker == null:
		return
	tracker.hand_updated.connect(_on_hand_updated)

func _on_hand_updated(hand_index: int, position: Vector2, gesture: String, label: String):
	print("Hand %d | %s | %s | pos: %s" % [hand_index, label, gesture, position])

	var cursor = cursor_left if label == "Left" else cursor_right
	
	if cursor:
		cursor.global_position = position
		cursor.scale = Vector2(1,1) if gesture == "palm" else Vector2(1,1) * .5

	match gesture:
		"fist":
			print(label, " hand made a FIST")
			# e.g. cursor.modulate = Color.RED
		"palm":
			print(label, " hand is OPEN")
			# e.g. cursor.modulate = Color.GREEN
		"other":
			pass
