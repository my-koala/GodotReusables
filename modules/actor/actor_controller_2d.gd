# code by MyKoala ͼ•ᴥ•ͽ #
@tool
extends Node2D
class_name ActorController2d

## Enable effects of controller.
@export
var enabled: bool = true:
	get:
		return enabled
	set(value):
		enabled = value

## Priority in which this controller is processed within Actor2D.
## Only the controller with the lowest priority is processed.
@export
var priority: int = 0:
	get:
		return priority
	set(value):
		priority = value

## Target Actor2D to apply controls to.
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
		
		if is_instance_valid(actor_target) && actor_target._actor_controllers.has(self):
			var index: int = actor_target._actor_controllers.bsearch_custom(self, _actor_controller_bsearch)
			actor_target._actor_controllers.insert(index, self)
		actor_target = value
		if is_instance_valid(actor_target) && !actor_target._actor_controllers.has(self):
			var index: int = actor_target._actor_controllers.bsearch_custom(self, _actor_controller_bsearch)
			actor_target._actor_controllers.remove_at(index)

@export_group("Controls")

## Move target direction to move towards.
## Direction is always normalized.
## This is ignored when move_target_position is not cleared.
@export
var move_target_direction: Vector2 = Vector2.ZERO:
	get:
		return move_target_direction
	set(value):
		move_target_direction = value.normalized()

## Face target direction to rotate face_direction towards.
## Direction is always normalized.
## Set to zero vector to stop rotation.
@export
var face_target_direction: Vector2 = Vector2.ZERO:
	get:
		return face_target_direction
	set(value):
		face_target_direction = value.normalized()

func _actor_controller_bsearch(a: ActorController2d, b: ActorController2d) -> bool:
	return a.priority < b.priority

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	if is_instance_valid(actor_target) && !actor_target._actor_controllers.has(self):
		var index: int = actor_target._actor_controllers.bsearch_custom(self, _actor_controller_bsearch)
		actor_target._actor_controllers.insert(index, self)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	if is_instance_valid(actor_target) && actor_target._actor_controllers.has(self):
		var index: int = actor_target._actor_controllers.bsearch_custom(self, _actor_controller_bsearch)
		actor_target._actor_controllers.remove_at(index)
