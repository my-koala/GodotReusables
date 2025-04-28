# code by MyKoala ͼ•ᴥ•ͽ #
@tool
extends Node

## Network configuration node for websocket multiplayer.

const CERTIFICATE_PATH: String = "res://certificate.pem"
const PRIVATE_KEY_PATH: String = "private_key.pem"

signal server_started()
signal server_stopped()

signal client_started()
signal client_stopped()

## Path to node to set as root for multiplayer branch.
## Leave null for scene tree root (default).
@export
var multiplayer_root: Node = null

var _multiplayer_api: SceneMultiplayer = SceneMultiplayer.new()

func _ready() -> void:
	_multiplayer_api.multiplayer_peer = null
	_multiplayer_api.server_disconnected.connect(_on_multiplayer_api_server_disconnected)

func _on_multiplayer_api_server_disconnected() -> void:
	_multiplayer_api.multiplayer_peer = null

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	var multiplayer_root_path: NodePath = get_tree().root.get_path()
	if is_instance_valid(multiplayer_root) && multiplayer_root.is_inside_tree():
		multiplayer_root_path = multiplayer_root.get_path()
	if get_tree().get_multiplayer(multiplayer_root_path) != _multiplayer_api:
		get_tree().set_multiplayer(_multiplayer_api, multiplayer_root_path)

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	
	var multiplayer_root_path: NodePath = get_tree().root.get_path()
	if is_instance_valid(multiplayer_root) && multiplayer_root.is_inside_tree():
		multiplayer_root_path = multiplayer_root.get_path()
	if get_tree().get_multiplayer(multiplayer_root_path) == _multiplayer_api:
		get_tree().set_multiplayer(null, multiplayer_root_path)

## Returns [code]true[/code] if a multiplayer connection is active.
func is_active() -> bool:
	return _multiplayer_api.has_multiplayer_peer()

## Returns [code]true[/code] if a multiplayer server is active.
func is_server() -> bool:
	return _multiplayer_api.has_multiplayer_peer() && _multiplayer_api.is_server()

## Returns [code]true[/code] if a multiplayer client is active.
func is_client() -> bool:
	return _multiplayer_api.has_multiplayer_peer() && !_multiplayer_api.is_server()

## Starts offline server.
## Returns [code]OK[/code] if successfully created offline server.
## Returns [code]ERR_ALREADY_IN_USE[/code] if a connection is currently active.
func host_server_offline() -> Error:
	is_active()
	# Return error if a connection is currently active.
	if _multiplayer_api.has_multiplayer_peer():
		push_error("Network \'%s\' | Failed to host server offline: a connection is already active." % [name])
		return ERR_ALREADY_IN_USE
	
	# Create server and return error.
	var multiplayer_peer: OfflineMultiplayerPeer = OfflineMultiplayerPeer.new()
	_multiplayer_api.multiplayer_peer = multiplayer_peer
	return OK

## Starts server (leave default arguments for offline).
## If [param use_tls_options] is true, the certificate will be read from [constant CERTIFICATE_PATH], and the private
## key from [constant PRIVATE_KEY_PATH].
## If neither the certificate nor private key can be read, then the server will be hosted without TLS options.
## Returns [code]OK[/code] if successfully created server.
## Returns [code]ERR_ALREADY_IN_USE[/code] if a connection is currently active.
## Returns [code]ERR_CANT_CREATE[/code] if server could not be created.
func host_server(port: int = 4000, use_tls_options: bool = true) -> Error:
	# Return error if a connection is currently active.
	if _multiplayer_api.has_multiplayer_peer():
		push_error("Network \'%s\' | Failed to host server on port \'%d\': a connection is already active." % [name, port])
		return ERR_ALREADY_IN_USE
	
	var tls_options: TLSOptions = null
	if !use_tls_options:
		print("Network \'%s\' | Hosting server without TLS options." % [name])
	else:
		# Load full-chain certificate.
		var certificate: X509Certificate = X509Certificate.new()
		var certificate_file: FileAccess = FileAccess.open(CERTIFICATE_PATH, FileAccess.READ)
		print("Network \'%s\' | Loading certificate from \'%s\' ..." % [name, CERTIFICATE_PATH])
		if !is_instance_valid(certificate_file):
			print("Network \'%s\' | Could not load certificate: file read failed." % [name])
			certificate = null
		elif certificate.load_from_string(certificate_file.get_as_text()) != OK:
			print("Network \'%s\' | Could not load certificate: invalid file format." % [name])
			certificate = null
		else:
			print("Network \'%s\' | Loaded certificate." % [name])
		
		# Load private key.
		var key: CryptoKey = CryptoKey.new()
		var key_file: FileAccess = FileAccess.open(PRIVATE_KEY_PATH, FileAccess.READ)
		print("Network \'%s\' | Loading private key from \'%s\' ..." % [name, PRIVATE_KEY_PATH])
		if !is_instance_valid(key_file):
			print("Network \'%s\' | Could not load private key: file read failed." % [name])
			key = null
		elif key.load_from_string(key_file.get_as_text()) != OK:
			print("Network \'%s\' | Could not load private key: invalid file format." % [name])
			key = null
		else:
			print("Network \'%s\' | Loaded private key." % [name])
		
		# Create TLS options with certificate and private key.
		if !is_instance_valid(key) || !is_instance_valid(certificate):
			print("Network \'%s\' | Hosting server without TLS options." % [name])
		else:
			print("Network \'%s\' | Hosting server with TLS options." % [name])
			tls_options = TLSOptions.server(key, certificate)
	
	# Create server and return error.
	var multiplayer_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var error: Error = multiplayer_peer.create_server(port, "*", tls_options)
	
	if error == OK:
		print("Network \'%s\' | Hosted server on port \'%d\'." % [name, port])
		_multiplayer_api.multiplayer_peer = multiplayer_peer
	else:
		push_error("Network \'%s\' | Failed to host server on port \'%d\': server could not be created." % [name, port])
	return error

## Stops active server.
## Returns [code]OK[/code] if successfully stopped server.
## Returns [code]ERR_DOES_NOT_EXIST[/code] if not hosting server.
func stop_server() -> Error:
	# Return error if not currently hosting a server.
	if !_multiplayer_api.has_multiplayer_peer() || !_multiplayer_api.is_server():
		push_error("Network \'%s\' | Failed to stop server: not currently hosting a server." % [name])
		return ERR_DOES_NOT_EXIST
	
	# Disconnect all peers and stop server.
	var peer_ids: PackedInt32Array = _multiplayer_api.get_peers()
	for peer_id: int in peer_ids:
		_multiplayer_api.multiplayer_peer.disconnect_peer(peer_id, false)
	_multiplayer_api.multiplayer_peer.close()
	
	print("Network \'%s\' | Stopped server." % [name])
	return OK

## Asynchronously creates client and starts connection to a server.
## If [param use_tls_options] is true, the certificate will be read from [constant CERTIFICATE_PATH].
## If the certificate can not be read, then the server will be joined without TLS options.
## Returns [code]OK[/code] if successfully created client.
## Returns [code]ERR_ALREADY_IN_USE[/code] if a connection is currently active.
## Returns [code]ERR_CANT_CREATE[/code] if client could not be created.
## Returns [code]ERR_CANT_CONNECT[/code] if client could not connect.
func join_server(address: String = "127.0.0.1", port: int = 4000, use_tls_options: bool = true) -> Error:
	# Return error if a connection is currently active.
	if _multiplayer_api.has_multiplayer_peer():
		push_error("Network \'%s\' | Failed to join server \'%s:%d\': a connection is already active." % [address, port])
		return ERR_ALREADY_IN_USE
	
	var tls_options: TLSOptions = null
	if !use_tls_options:
		print("Network \'%s\' | Joining server without TLS options." % [name])
	else:
		# Load certificate.
		var certificate: X509Certificate = X509Certificate.new()
		var certificate_file: FileAccess = FileAccess.open(CERTIFICATE_PATH, FileAccess.READ)
		if !is_instance_valid(certificate_file):
			print("Network \'%s\' | Could not load certificate: file read failed." % [name])
			certificate = null
		elif certificate.load_from_string(certificate_file.get_as_text()) != OK:
			print("Network \'%s\' | Could not load certificate: invalid file format." % [name])
			certificate = null
		else:
			print("Network \'%s\' | Loaded certificate." % [name])
		
		if !is_instance_valid(certificate):
			print("Network \'%s\' | Joining server without TLS options." % [name])
		else:
			print("Network \'%s\' | Joining server with TLS options." % [name])
			tls_options = TLSOptions.client(certificate)
	
	# Create client and return error.
	var multiplayer_peer: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	
	var url: String = address + ":" + str(port)
	var error: Error = multiplayer_peer.create_client(url, tls_options)
	if error != OK:
		push_error("Network \'%s\' | Failed to join server \'%s:%d\': could not connect." % [name, address, port])
		return error
	
	_multiplayer_api.multiplayer_peer = multiplayer_peer
	print("Network \'%s\' | Joining server \'%s:%d\' ..." % [name, address, port])
	
	while _multiplayer_api.multiplayer_peer.get_connection_status() == MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTING:
		await get_tree().physics_frame
	
	if _multiplayer_api.multiplayer_peer.get_connection_status() != MultiplayerPeer.ConnectionStatus.CONNECTION_CONNECTED:
		push_error("Network \'%s\' | Failed to join server \'%s:%d\': disconnected." % [name, address, port])
		_multiplayer_api.multiplayer_peer.close()
		_multiplayer_api.set_deferred(&"multiplayer_peer", null)
		return ERR_CANT_CONNECT
	
	print("Network \'%s\' | Joined server \'%s:%d\'." % [name, address, port])
	return error

## Stops client and disconnects from server.
## Returns [code]OK[/code] if successfully disconnected from server.
## Returns [code]ERR_DOES_NOT_EXIST[/code] if not connected to a server.
func quit_server() -> Error:
	# Return error if not connected to a server.
	if !_multiplayer_api.has_multiplayer_peer() || _multiplayer_api.is_server():
		push_error("Network \'%s\' | Failed to quit server: not currently connected to a server." % [name])
		return ERR_DOES_NOT_EXIST
	
	# Stop connection to server.
	print("Network \'%s\' | Quit server." % [name])
	_multiplayer_api.multiplayer_peer.close()
	return OK
