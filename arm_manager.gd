extends Node2D

#@export var rest_length: float = 20.0
#@export var stiffness: float = 10.0
#@export var damping: float = 2.0
@export var L: Sprite2D
@export var R: Sprite2D
@export var L_start: Node2D
@export var R_start: Node2D

@onready var armL: Line2D = $Line2D
@onready var armR: Line2D = $Line2D2

@export var len1: float = 300.0
@export var len2: float = 300.0
@export var bend_direction: float = 1.0

func _process(delta: float) -> void:
	update_rope()
	
func update_rope():
	var R_elbow = solve_ik(R.global_position, R_start.global_position, len1, len2, bend_direction)
	armR.set_point_position(0, armR.to_local(R_start.global_position))
	armR.set_point_position(1, armR.to_local(R_elbow))
	armR.set_point_position(2, armR.to_local(R.global_position))
	
	var L_elbow = solve_ik(L.global_position, L_start.global_position, len1, len2, -bend_direction)
	armL.set_point_position(0, armL.to_local(L_start.global_position))
	armL.set_point_position(1, armL.to_local(L_elbow))
	armL.set_point_position(2, armL.to_local(L.global_position))

func solve_ik(a: Vector2, b: Vector2, len1: float, len2: float, bend_direction: float = 1.0) -> Vector2:
	var dist = clamp(a.distance_to(b), abs(len1 - len2), len1 + len2)
	var angle_a = acos((dist * dist + len1 * len1 - len2 * len2) / (2 * dist * len1))
	var angle_to_b = a.angle_to_point(b)
	var elbow_angle = angle_to_b + angle_a * bend_direction
	return a + Vector2(cos(elbow_angle), sin(elbow_angle)) * len1
