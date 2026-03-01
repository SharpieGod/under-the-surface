extends CharacterBody2D

@onready var tracker = $HandTracker
@onready var camera = $Camera2D
@onready var grab_particle = $"../Grab Particle"
@export var cursor_left: Node2D
@export var cursor_right: Node2D
@export var max_speed: float = 100.0
@export var smooth_factor: float = 0.90
@onready var torso = $Torso
@export var L_cast: ShapeCast2D
@export var R_cast: ShapeCast2D

var _prev_closed: Dictionary = { true: false, false: false }
var _smoothed_positions: Dictionary = {}
var _grab: Dictionary = {}

func _ready():
	tracker.hand_updated.connect(_on_hand_updated)
	tracker.hand_lost.connect(_on_hand_lost)

func _screen_to_world(position: Vector2) -> Vector2:
	var half = get_viewport().size / 2.0
	return Vector2(
		get_viewport().size.x - position.x - half.x,
		(position.y - half.y)
	)
	
func _process(delta):
	velocity += get_gravity() * delta * 2.4
	
	if _grab.size() > 0:
		velocity = Vector2.ZERO
	move_and_slide()
	

func _on_hand_updated(is_left: bool, position: Vector2, is_closed: bool):
	var cursor = cursor_left if not is_left else cursor_right
	var cast = L_cast if is_left else R_cast
	
	if not cursor:
		return

	var world_pos = _screen_to_world(position) * 1.5

	var smoothed: Vector2
	
	if is_left in _smoothed_positions:
		smoothed = _smoothed_positions[is_left].lerp(world_pos, smooth_factor)
	else:
		smoothed = world_pos
		
	if smoothed.length() > 600:
		smoothed = smoothed.normalized() * 600
		
	_smoothed_positions[is_left] = smoothed

	cursor.visible = true
	cursor.position = smoothed

	var was_closed = _prev_closed[is_left]
	var in_wall = false
	
	if cast.is_colliding():
		for i in cast.get_collision_count():
			if cast.get_collider(i).name == "Foreground":
				in_wall = true
				break
	
	if is_closed:
		if not was_closed and not in_wall:
			_grab[is_left] = {
				"anchor_screen": smoothed,
				"anchor_self": global_position
			}
			
			var particle_instance = grab_particle.instatiate()
			get_tree().current_scene.add_child(particle_instance)
			particle_instance.global_position = cursor.global_position 
			particle_instance.emitting = true
			get_tree().create_timer(particle_instance.lifetime * particle_instance.amount_ratio + 0.1).timeout.connect(particle_instance.queue_free)
			
			
		if is_left in _grab:
			var delta = smoothed - _grab[is_left]["anchor_screen"]
			var desired_pos = _grab[is_left]["anchor_self"] - delta
			var move = desired_pos - global_position
			if move.length() > max_speed:
				move = move.normalized() * max_speed
			global_position += move
	else:
		_grab.erase(is_left)

	_prev_closed[is_left] = is_closed
	_update_cursor_state(cursor, is_closed)

func _on_hand_lost(is_left: bool):
	var cursor = cursor_left if is_left else cursor_right
	if cursor:
		cursor.visible = false
	_grab.erase(is_left)
	_smoothed_positions.erase(is_left)
	_prev_closed[is_left] = false

func _update_cursor_state(cursor: Node2D, is_closed: bool):
	cursor.scale = Vector2(15, 15) if is_closed else Vector2(20, 20)
