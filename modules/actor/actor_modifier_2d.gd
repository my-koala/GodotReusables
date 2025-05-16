# Code copyright ©2024 valedict valedictdev@gmail.com ͼ•ᴥ•ͽ #
@tool
extends Node2D
class_name ActorModifier2d

## Enable effects of modifier.
@export
var enabled: bool = true:
	get:
		return enabled
	set(value):
		enabled = value

## Target Actor2D to apply modifiers to.
@export
var actor_target: Actor2D = null:
	get:
		return actor_target
	set(value):
		if actor_target == value:
			return
		
		if !is_inside_tree():
			actor_target = value
			return
		
		if is_instance_valid(actor_target) && actor_target._actor_modifiers.has(self):
			actor_target._actor_modifiers.erase(self)
		actor_target = value
		if is_instance_valid(actor_target) && !actor_target._actor_modifiers.has(self):
			actor_target._actor_modifiers.append(self)

@export_group("Modifiers")

## Move speed multiplier.
@export_range(0.0, 1.0, 0.05, "or_greater", "hide_slider")
var move_speed_modifier: float = 1.0:
	get:
		return move_speed_modifier
	set(value):
		move_speed_modifier = maxf(value, 0.0)

## Move acceleration multiplier.
@export_range(0.0, 1.0, 0.05, "or_greater", "hide_slider")
var move_acceleration_modifier: float = 1.0:
	get:
		return move_acceleration_modifier
	set(value):
		move_acceleration_modifier = maxf(value, 0.0)

## Move deceleration multiplier.
@export_range(0.0, 1.0, 0.05, "or_greater", "hide_slider")
var move_deceleration_modifier: float = 1.0:
	get:
		return move_deceleration_modifier
	set(value):
		move_deceleration_modifier = maxf(value, 0.0)

## Face speed multiplier.
@export_range(0.0, 1.0, 0.05, "or_greater", "hide_slider")
var face_speed_modifier: float = 1.0:
	get:
		return face_speed_modifier
	set(value):
		face_speed_modifier = maxf(value, 0.0)

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	if is_instance_valid(actor_target) && !actor_target._actor_modifiers.has(self):
			actor_target._actor_modifiers.append(self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	if is_instance_valid(actor_target) && actor_target._actor_modifiers.has(self):
		actor_target._actor_modifiers.erase(self)
