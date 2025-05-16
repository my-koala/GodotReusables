extends Node
class_name DynamicResourceLoader

@export
var folder_path: String = "res://"

var loaded: Array[Resource]

func _ready() -> void:
	_load_folder(folder_path)
	
	print("Loaded %d resources." % loaded.size())

# Recursively load resources from base folder.
func _load_folder(folder_path: String) -> void:
	# Parse any  resources in the directory and load them
	for file_path: String in DirAccess.get_files_at(folder_path):
		# Gets around build export jank
		file_path = file_path.replace(".import", "")
		file_path = file_path.replace(".remap", "")
		
		var card_info: Resource = load(folder_path + file_path) as Resource
		if is_instance_valid(card_info):
			loaded.append(card_info)
	
	# Recurse into subdirectories (EXIT CONDITION: no subdirs)
	for sub_folder_path: String in DirAccess.get_directories_at(folder_path):
		_load_folder(folder_path + "/" + sub_folder_path + "/")
