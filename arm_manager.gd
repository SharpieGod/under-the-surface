extends Node2D

#@export var rest_length: float = 20.0
#@export var stiffness: float = 10.0
#@export var damping: float = 2.0
@onready var L: Sprite2D = $"../Left Hand"
@onready var R: Sprite2D = $"../Right Hand"

@onready var player = $"../Camera2D"

@onready var armL: Line2D = $Line2D
@onready var armR: Line2D = $Line2D2

func _process(delta: float) -> void:
	handle_grapple(delta)

func handle_grapple(delta: float) -> void:
	#var target_dir_l: Vector2 = player.global_position.direction_to(L.global_position)
	#var target_dist_l: float = player.global_position.distance_to(L.global_position)
	#
	#var target_dir_r: Vector2 = player.global_position.direction_to(R.global_position)
	#var target_dist_r: float = player.global_position.distance_to(R.global_position)

	#var displacement: float = target_dist - rest_length
	#
	#var force: Vector2 = Vector2.ZERO
#
	#if displacement > 0:
		#var spring_force_magnitude: float = stiffness * displacement
		#var spring_force: Vector2 = target_dir * spring_force_magnitude
		#
		#var vel_dot: float = player.velocity.dot(target_dir)
		#
		#var damping_force: Vector2 = -damping * vel_dot * target_dir
		#
		#force = spring_force + damping_force

	#player.velocity += force * delta
	
	update_rope()

func update_rope():
	armL.set_point_position(1, armL.to_local(L.global_position))
	armR.set_point_position(1, armR.to_local(R.global_position))
