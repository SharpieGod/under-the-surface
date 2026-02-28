extends CharacterBody2D

@onready var tracker = $HandTracker

@export var cursor_left: Node2D
@export var cursor_right: Node2D

var _prev_closed: Dictionary = { 0: false, 1: false }

var _grab: Dictionary = {}

func _ready():
	tracker.hand_updated.connect(_on_hand_updated)
	tracker.hand_lost.connect(_on_hand_lost)

func _on_hand_updated(hand_index: int, position: Vector2, is_closed: bool):
	var cursor = cursor_left if hand_index == 0 else cursor_right
	if not cursor:
		return

	var mirrored_pos = Vector2(get_viewport().size.x - position.x, position.y)
	cursor.visible = true
	cursor.position = mirrored_pos

	var was_closed = _prev_closed[hand_index]

	if is_closed:
		if not was_closed:
			_grab[hand_index] = {
				"anchor_screen": mirrored_pos,
				"anchor_self": global_position
			}

		if hand_index in _grab:
			var delta = mirrored_pos - _grab[hand_index]["anchor_screen"]
			global_position = _grab[hand_index]["anchor_self"] - delta
	else:
		_grab.erase(hand_index)

	_prev_closed[hand_index] = is_closed
	_update_cursor_state(cursor, is_closed)

func _on_hand_lost(hand_index: int):
	var cursor = cursor_left if hand_index == 0 else cursor_right
	if cursor:
		cursor.visible = false
	_grab.erase(hand_index)
	_prev_closed[hand_index] = false

func _update_cursor_state(cursor: Node2D, is_closed: bool):
	cursor.scale = Vector2(0.6, 0.6) if is_closed else Vector2(1.0, 1.0)
