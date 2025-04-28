# Code copyright ©2024 MyKoala mykoaladev@gmail.com ͼ•ᴥ•ͽ #
@tool
extends Node
class_name SceneLoader

## Simple asynchronous [code]PackedScene[/code] loader.

signal load_started()
signal load_stopped()

var _scene_path: String = ""

## Private signal used to cancel scene loading.
signal _scene_load_update()

var _scene_load_active: bool = false
var _scene_load_cancel: bool = false
var _scene_load_result: PackedScene = PackedScene.new()

## Returns [code]true[/code] if the [code]PackedScene[/code] is loaded and can be instantiated.
func can_instantiate() -> bool:
	return _scene_load_result.can_instantiate()

## Returns an instance of the loaded [code]PackedScene[/code].
func instantiate() -> Node:
	if !_scene_load_result.can_instantiate():
		return null
	return _scene_load_result.instantiate()

## Returns the path of the loaded [code]PackedScene[/code].
func get_scene_path() -> String:
	return _scene_path

## Sets the [code]PackedScene[/code] path to load.
## An empty [param scene_path] will unload the current PackedScene.
## Any current scene path loading will be canceled and the new [param scene_path] will start loading.
func set_scene_path(scene_path: String) -> void:
	if _scene_path != scene_path:
		_scene_path = scene_path
		if _scene_load_active:
			_scene_load_cancel = true
			_scene_load_update.emit()
		if !_scene_path.is_empty():
			_scene_load(_scene_path)

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		return
	
	match what:
		NOTIFICATION_READY:
			set_process(true)
		NOTIFICATION_PROCESS:
			if _scene_load_active:
				_scene_load_update.emit()
		NOTIFICATION_EXIT_TREE:
			if _scene_load_active:
				_scene_load_cancel = true
				_scene_load_update.emit()

## Coroutine to load a scene using [code]ResourceLoader[/code] threading.
## After loading, an instance of the PackedScene can be created with [method instantiate].
func _scene_load(scene_path: String) -> void:
	if _scene_load_active:
		push_error("SceneLoader \'%s\' | Failed to load scene path \'%s\': another scene load is in progress." % [name, scene_path])
		return
	
	if !ResourceLoader.exists(scene_path, "PackedScene"):
		push_error("SceneLoader \'%s\' | Failed to load scene path \'%s\': invalid scene path." % [name, scene_path])
		return
	
	if ResourceLoader.load_threaded_request(scene_path, "PackedScene", false) != Error.OK:
		push_error("SceneLoader \'%s\' | Failed to load scene path \'%s\': load request failed (incompatible type?)." % [name, scene_path])
		return
	
	_scene_load_result = PackedScene.new()
	_scene_load_active = true
	load_started.emit()
	
	# Query load status and exit loop on load done or cancel.
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if _scene_load_cancel:
			break
		await _scene_load_update
		status = ResourceLoader.load_threaded_get_status(scene_path)
	
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("SceneLoader \'%s\' | Failed to load scene path '%s': invalid resource." % [name, scene_path])
		ResourceLoader.THREAD_LOAD_FAILED:
			push_error("SceneLoader \'%s\' | Failed to load scene path '%s': load failed." % [name, scene_path])
		ResourceLoader.THREAD_LOAD_LOADED:
			# If statement necessary for edge case when canceled on loaded.
			if !_scene_load_update:
				_scene_load_result = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	
	_scene_load_active = false
	load_stopped.emit()
