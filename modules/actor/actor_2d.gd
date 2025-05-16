# Code copyright ©2024 valedict valedictdev@gmail.com ͼ•ᴥ•ͽ #
@tool
extends RigidBody2D
class_name Actor2D

#region Move
@export_group("Move")

## Move speed as units per second.
@export_range(0.0, 1.0, 0.05, "or_greater", "hide_slider")
var move_speed: float = 64.0:
	get:
		return move_speed
	set(value):
		move_speed = maxf(value, 0.0)

## Move acceleration as units per second squared.
@export_range(0.0, 1.0, 0.05, "or_greater", "hide_slider")
var move_acceleration: float = 256.0:
	get:
		return move_acceleration
	set(value):
		move_acceleration = maxf(value, 0.0)

## Move deceleration as units per second squared.
@export_range(0.0, 1.0, 0.05, "or_greater", "hide_slider")
var move_deceleration: float = 512.0:
	get:
		return move_deceleration
	set(value):
		move_deceleration = maxf(value, 0.0)

#endregion Move

#region Face
@export_group("Face")

## Face direction.
## Direction is always normalized.
@export
var face_direction: Vector2 = Vector2.DOWN:
	get:
		return face_direction
	set(value):
		if !value.is_zero_approx():
			face_direction = value.normalized()

## Face rotation speed towards face_target_direction as rotations per second.
@export_range(0.0, 1.0, 0.05, "or_greater", "hide_slider")
var face_speed: float = 4.0:
	get:
		return face_speed
	set(value):
		face_speed = maxf(value, 0.0)

#endregion Face

var _actor_controllers: Array[ActorController2d] = []
var _actor_modifiers: Array[ActorModifier2d] = []

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if Engine.is_editor_hint():
		return
	
	# TODO: Sloped surfaces.

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	# Modifier Logic #
	var move_speed_modifier: float = 1.0
	var move_acceleration_modifier: float = 1.0
	var move_deceleration_modifier: float = 1.0
	var face_speed_modifier: float = 1.0
	for actor_modifier: ActorModifier2d in _actor_modifiers:
		if !actor_modifier.enabled:
			continue
		move_speed_modifier *= actor_modifier.move_speed_modifier
		move_acceleration_modifier *= actor_modifier.move_acceleration_modifier
		move_deceleration_modifier *= actor_modifier.move_deceleration_modifier
		face_speed_modifier *= actor_modifier.face_speed_modifier
	
	# Controller Logic #
	var move_target_direction: Vector2 = Vector2.ZERO
	var face_target_direction: Vector2 = Vector2.ZERO
	for actor_controller: ActorController2d in _actor_controllers:
		if !actor_controller.enabled:
			continue
		move_target_direction = actor_controller.move_target_direction
		face_target_direction = actor_controller.face_target_direction
		break
	
	# Move Logic #
	# Calculate necessary acceleration to move towards query direction.
	var move_query_velocity: Vector2 = move_target_direction * move_speed * move_speed_modifier
	var move_query_acceleration: Vector2 = (move_query_velocity - linear_velocity) / delta
	if !move_target_direction.is_zero_approx():
		move_query_acceleration = move_query_acceleration.limit_length(move_acceleration * move_acceleration_modifier)
	else:
		move_query_acceleration = move_query_acceleration.limit_length(move_deceleration * move_deceleration_modifier)
	
	if !move_query_acceleration.is_zero_approx():
		apply_central_force(mass * move_query_acceleration)
	
	# Face Logic #
	if !face_target_direction.is_zero_approx():
		# Spherical interpolate towards face_target_direction.
		var face_query_speed: float = face_speed * TAU * face_speed_modifier
		var theta: float = absf(face_direction.angle_to(face_target_direction))
		var weight: float = clampf((face_query_speed * delta) / theta, 0.0, 1.0)
		face_direction = face_direction.slerp(face_target_direction, weight)
	
