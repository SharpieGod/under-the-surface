extends Node2D

@export var rest_length: float = 20.0
@export var stiffness: float = 10.0
@export var damping: float = 2.0
@onready var L: Sprite2D = $"../Sprite2D"

var launched: bool = false
var targetL: Vector2 = L.global_position

@onready var player: CharacterBody2D = get_parent()

@onready var armL: Line2D = $Line2D
@onready var armR: Line2D = $Line2D2

func _process(delta: float) -> void:
	
	
	if launched:
		handle_grapple(delta)

func handle_grapple(delta: float) -> void:
	var target_dir: Vector2 = player.global_position.direction_to(targetL)
	var target_dist: float = player.global_position.distance_to(targetL)

	var displacement: float = target_dist - rest_length
	
	var force: Vector2 = Vector2.ZERO

	if displacement > 0:
		var spring_force_magnitude: float = stiffness * displacement
		var spring_force: Vector2 = target_dir * spring_force_magnitude
		
		var vel_dot: float = player.velocity.dot(target_dir)
		
		var damping_force: Vector2 = -damping * vel_dot * target_dir
		
		force = spring_force + damping_force

	player.velocity += force * delta
	
	update_rope()

func update_rope():
	armL.set_point_position(1, armL.to_local(targetL))
