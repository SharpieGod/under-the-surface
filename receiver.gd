extends Node2D

@onready var tracker = $HandTracker
@export var cursor: Node2D

func _ready():
	tracker.hand_updated.connect(_on_hand_updated)

func _on_hand_updated(hand_index: int, position: Vector2):
	if hand_index == 0:
		cursor.global_position = position
