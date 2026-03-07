extends CharacterBody2D

@onready var tracker = $HandTracker
@onready var camera = $Camera2D
@onready var grab_particle = $"../Grab Particle"
@export var cursor_left: Node2D
@export var cursor_right: Node2D
@export var max_speed: float = 100.0
@export var smooth_factor: float = 0.90
@onready var torso = $Torso
@onready var R_start = $"Torso/R Start"
@onready var L_start = $"Torso/L Start"

@export var R_open: Texture2D
@export var R_closed: Texture2D
@export var L_open: Texture2D
@export var L_closed: Texture2D
@export var R_circle: Node2D
@export var L_circle: Node2D

@export var R_cast: RayCast2D
@export var L_cast: RayCast2D


var _prev_closed: Dictionary = { true: false, false: false }
var _smoothed_positions: Dictionary = {}
var _grab: Dictionary = {}

var on_button = false

func _ready():
	tracker.hand_updated.connect(_on_hand_updated)
	tracker.hand_lost.connect(_on_hand_lost)
	print("menuman ready, tracker = ", tracker)
	tracker.hand_updated.connect(_on_hand_updated)
	tracker.hand_lost.connect(_on_hand_lost)
	tracker.hand_updated.connect(func(a,b,c): print("signal received!", a, b, c))

func _screen_to_world(position: Vector2) -> Vector2:
	var half = get_viewport().size / 2.0
	return Vector2(
		get_viewport().size.x - position.x - half.x,
		(position.y - half.y)
	)
	


func _on_hand_updated(is_left: bool, position: Vector2, is_closed: bool):
	var cursor = cursor_left if not is_left else cursor_right
	var circle = L_circle if is_left else R_circle
	var cast = L_cast if is_left else R_cast
	var start = L_start if is_left else R_start
	
	if not cursor:
		return
	
	var world_pos = _screen_to_world(position) * 1.3
	circle.position = world_pos

	var smoothed: Vector2
	
	if is_left in _smoothed_positions:
		smoothed = _smoothed_positions[is_left].lerp(world_pos, smooth_factor)
	else:
		smoothed = world_pos
		
	_smoothed_positions[is_left] = smoothed

	cursor.visible = true
	circle.visible = true
	
	var clamped = smoothed
	
	if (clamped - start.position).length() > 600:
		clamped = (clamped - start.position).normalized() * 600 + start.position
		
	var start_global = global_position
	var clamped_global = to_global(clamped)

	cast.global_position = start_global
	cast.collision_mask = 2
	cast.collide_with_areas = true
	cast.target_position = cast.to_local(clamped_global)
	cast.force_raycast_update()

	if cast.is_colliding():
		
		print(cast.get_collider().name)
		print(cast.get_collider())
		if cast.get_collider().name == "button_layer":
			on_button = true
			print("ya button bring it high")

	cursor.position = clamped

	var was_closed = _prev_closed[is_left]
	
	if is_closed:
		if not was_closed:
			_grab[is_left] = {
				"anchor_screen": clamped,
				"anchor_self": global_position
			}
			if true:
				var particle_instance = grab_particle.duplicate()
				get_tree().current_scene.add_child(particle_instance)
				particle_instance.global_position = cursor.global_position 
				particle_instance.emitting = true
				get_tree().create_timer(particle_instance.lifetime * particle_instance.amount_ratio + 0.1).timeout.connect(particle_instance.queue_free)
			if on_button:
				get_tree().create_timer(0.3).timeout
				get_tree().change_scene_to_file("res://darko.tscn")
		if is_left in _grab:
			var delta = clamped - _grab[is_left]["anchor_screen"]
			var desired_pos = _grab[is_left]["anchor_self"] - delta
			var move = desired_pos - global_position
			if move.length() > max_speed:
				move = move.normalized() * max_speed
			global_position += Vector2.ZERO
	else:
		_grab.erase(is_left)

	_prev_closed[is_left] = is_closed
	_update_cursor_state(cursor, circle, is_left, is_closed)

func _on_hand_lost(is_left: bool):
	var cursor = cursor_left if not is_left else cursor_right
	var circle = L_circle if is_left else R_circle
	if cursor:
		cursor.visible = false
	_grab.erase(is_left)
	_smoothed_positions.erase(is_left)
	_prev_closed[is_left] = false
	circle.visible = false

func _update_cursor_state(cursor: Node2D, circle: Node2D, is_left, is_closed: bool):
	cursor.scale = Vector2(15, 15)
	circle.scale = Vector2.ONE * (8 if is_closed else 11)
	var closed = L_closed if is_left else R_closed
	var open = L_open if is_left else R_open
	cursor.texture = closed if not is_closed else open
