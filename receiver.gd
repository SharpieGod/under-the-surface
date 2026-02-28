extends Node2D

@onready var tracker = $HandTracker

@export var cursor_left: Node2D
@export var cursor_right: Node2D

func _ready():
	tracker.hand_updated.connect(_on_hand_updated)
	tracker.hand_lost.connect(_on_hand_lost)

func _on_hand_updated(hand_index: int, position: Vector2, is_closed: bool):
	var cursor = cursor_left if hand_index == 0 else cursor_right
	if not cursor:
		return
	var mirrored_pos = Vector2(get_viewport().size.x - position.x, position.y)
	cursor.visible = true
	cursor.global_position = mirrored_pos
	_update_cursor_state(cursor, is_closed)

func _on_hand_lost(hand_index: int):
	var cursor = cursor_left if hand_index == 0 else cursor_right
	if cursor:
		cursor.visible = false

# Override this to do whatever you want with open/closed state.
# By default it just scales the cursor: small when closed, normal when open.
func _update_cursor_state(cursor: Node2D, is_closed: bool):
	cursor.scale = Vector2(0.6, 0.6) if is_closed else Vector2(1.0, 1.0)
