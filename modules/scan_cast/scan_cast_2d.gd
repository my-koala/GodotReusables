# code by MyKoala ͼ•ᴥ•ͽ #
@tool
extends Node2D

## Continuous physics point detection node with optional physics interpolated signalling.
## Uses ray casts and distance fractions to simulate collisions in between physics frames.
## Collision detection signals are always emitted during process frames.

# NOTE: Detecting dynamic objects is functional but interpolation is unsupported.
# NOTE: Transform should only be altered during physics frames.

class _CollisionFraction:
	extends RefCounted
	var collision_object: Node2D = null
	var fraction: float = 0.0
	var frame: int = 0

signal area_entered(area: Area2D)
signal area_exited(area: Area2D)

signal body_entered(body: Node2D)
signal body_exited(body: Node2D)

@export
var enabled: bool = true

@export
var use_physics_interpolation: bool = true

@export_flags_2d_physics var collision_mask: int = 1 << 0

@export_group("Collide With", "collide_with_")
@export
var collide_with_areas: bool = true
@export
var collide_with_bodies: bool = false

var _global_position_prev: Vector2 = Vector2.ZERO

var _collision_fractions_entered: Array[_CollisionFraction] = []
var _collision_fractions_exited: Array[_CollisionFraction] = []
var _collision_objects: Array[Node2D] = []

var _reset_interpolation: bool = false

func _bsearch_collision_fractions(a: _CollisionFraction, b: _CollisionFraction) -> bool:
	return (a.frame < b.frame) || (a.fraction < b.fraction)

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	
	match what:
		NOTIFICATION_READY:
			set_process(true)
			set_physics_process(true)
		NOTIFICATION_ENTER_TREE:
			reset_physics_interpolation()
		NOTIFICATION_PHYSICS_PROCESS:
			_queues_append()
		NOTIFICATION_PROCESS:
			_queues_remove()
		NOTIFICATION_RESET_PHYSICS_INTERPOLATION:
			_global_position_prev = global_position
			_reset_interpolation = true

func _queues_remove() -> void:
	var fraction: float = Engine.get_physics_interpolation_fraction()
	var frame: int = Engine.get_physics_frames()
	
	# Process entered collision fractions.
	while !_collision_fractions_entered.is_empty():
		var collision_fraction: _CollisionFraction = _collision_fractions_entered[0]
		var compare: bool = (collision_fraction.frame == frame) && (collision_fraction.fraction >= fraction)
		if !_reset_interpolation && use_physics_interpolation && compare:
			break
		
		if collision_fraction.collision_object is Area2D:
			area_entered.emit(collision_fraction.collision_object)
		else:
			body_entered.emit(collision_fraction.collision_object)
		_collision_fractions_entered.pop_front()
	
	# Process exited collision fractions.
	while !_collision_fractions_exited.is_empty():
		var collision_fraction: _CollisionFraction = _collision_fractions_exited[0]
		var compare: bool = (collision_fraction.frame == frame) && (collision_fraction.fraction >= fraction)
		if !_reset_interpolation && use_physics_interpolation && compare:
			break
		
		if collision_fraction.collision_object is Area2D:
			area_exited.emit(collision_fraction.collision_object)
		else:
			body_exited.emit(collision_fraction.collision_object)
		_collision_fractions_exited.pop_front()
	
	_reset_interpolation = false

func _queues_append() -> void:
	var frame: int = Engine.get_physics_frames()
	var dss: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var distance_squared: float = global_position.distance_squared_to(_global_position_prev)
	var collision_objects: Array[Node2D] = []
	
	if !enabled:
		for collision_object: Node2D in _collision_objects:
			var collision_fraction: _CollisionFraction = _CollisionFraction.new()
			collision_fraction.collision_object = collision_object
			collision_fraction.fraction = 0.0
			collision_fraction.frame = frame
			
			var index: int = _collision_fractions_exited.bsearch_custom(collision_fraction, _bsearch_collision_fractions, true)
			_collision_fractions_exited.insert(index, collision_fraction)
		_collision_objects.clear()
		return
	
	if global_position.is_equal_approx(_global_position_prev):
		# Point cast current position and update entered and exited objects.
		# Ray casting can't be used as results are inconsistent at a singular point.
		var query_point: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		query_point.collide_with_areas = collide_with_areas
		query_point.collide_with_bodies = collide_with_bodies
		query_point.collision_mask = collision_mask
		query_point.position = global_position
		query_point.exclude = []
		for result: Dictionary in dss.intersect_point(query_point):
			var collision_object: Node2D = result[&"collider"] as Node2D
			if !is_instance_valid(collision_object):
				continue
			
			collision_objects.append(collision_object)
			if _collision_objects.has(collision_object):
				continue
			
			var collision_fraction: _CollisionFraction = _CollisionFraction.new()
			collision_fraction.collision_object = collision_object
			collision_fraction.fraction = 0.0
			collision_fraction.frame = frame
			
			var index: int = _collision_fractions_entered.bsearch_custom(collision_fraction, _bsearch_collision_fractions, true)
			_collision_fractions_entered.insert(index, collision_fraction)
		
		for collision_object: CollisionObject2D in _collision_objects:
			if collision_objects.has(collision_object):
				continue
			
			var collision_fraction: _CollisionFraction = _CollisionFraction.new()
			collision_fraction.collision_object = collision_object
			collision_fraction.fraction = 0.0
			collision_fraction.frame = frame
			
			var index: int = _collision_fractions_exited.bsearch_custom(collision_fraction, _bsearch_collision_fractions, true)
			_collision_fractions_exited.insert(index, collision_fraction)
	else:
		# Ray cast from previous to current position for entered objects.
		var query_ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.new()
		query_ray.collide_with_areas = collide_with_areas
		query_ray.collide_with_bodies = collide_with_bodies
		query_ray.collision_mask = collision_mask
		query_ray.hit_from_inside = true
		query_ray.from = _global_position_prev
		query_ray.to = global_position
		query_ray.exclude = []
		while true:
			var result: Dictionary = dss.intersect_ray(query_ray)
			if result.is_empty():
				break
			
			query_ray.exclude = query_ray.exclude + [result[&"rid"] as RID]
			var collision_object: Node2D = result[&"collider"] as Node2D
			if !is_instance_valid(collision_object):
				continue
			collision_objects.append(collision_object)
			if _collision_objects.has(collision_object):
				continue
			
			var result_position: Vector2 = result[&"position"] as Vector2
			var collision_fraction: _CollisionFraction = _CollisionFraction.new()
			collision_fraction.collision_object = collision_object
			var delta_squared: float = result_position.distance_squared_to(_global_position_prev)
			collision_fraction.fraction = sqrt(delta_squared / distance_squared)
			collision_fraction.frame = frame
			
			var index: int = _collision_fractions_entered.bsearch_custom(collision_fraction, _bsearch_collision_fractions, true)
			_collision_fractions_entered.insert(index, collision_fraction)
		
		# Ray cast from current to previous position for exited objects.
		query_ray.collide_with_areas = collide_with_areas
		query_ray.collide_with_bodies = collide_with_bodies
		query_ray.collision_mask = collision_mask
		query_ray.hit_from_inside = false
		query_ray.from = global_position
		query_ray.to = _global_position_prev
		query_ray.exclude = []
		while true:
			var result: Dictionary = dss.intersect_ray(query_ray)
			if result.is_empty():
				break
			
			query_ray.exclude = query_ray.exclude + [result[&"rid"] as RID]
			var collision_object: Node2D = result[&"collider"] as Node2D
			if !is_instance_valid(collision_object):
				continue
			collision_objects.erase(collision_object)
			
			var result_position: Vector2 = result[&"position"] as Vector2
			var collision_fraction: _CollisionFraction = _CollisionFraction.new()
			collision_fraction.collision_object = collision_object
			var delta_squared: float = result_position.distance_squared_to(_global_position_prev)
			collision_fraction.fraction = sqrt(delta_squared / distance_squared)
			collision_fraction.frame = frame
			
			var index: int = _collision_fractions_exited.bsearch_custom(collision_fraction, _bsearch_collision_fractions, true)
			_collision_fractions_exited.insert(index, collision_fraction)
	
	_collision_objects = collision_objects
	_global_position_prev = global_position
