extends Node
class_name AppController

# ==============================================================
# AppController
# ==============================================================
#
# Verantwortung:
# ✅ Verwaltet importierte Bilddateien als Daten
# ✅ Validiert Basisinformationen für den Import
# ✅ Verwaltet die aktuell ausgewählte Datei
# ✅ Sendet strukturierte Resultate an die UI
#
# ❌ Kennt keine Buttons, Labels oder TextureRects
# ❌ Öffnet keine FileDialogs
# ❌ Erzeugt noch keine ICO-Dateien
# ❌ Baut keine Queue-UI
#
# ==============================================================


signal queue_changed(files: Array[Dictionary])
signal selection_changed(file_data: Dictionary)
signal import_warning(message: String)
signal import_error(message: String)

const SUPPORTED_EXTENSIONS: Array[String] = [
	"png",
	"jpg",
	"jpeg",
	"bmp"
]


var queue_files: Array[Dictionary] = []
var selected_file_id := ""


# ==============================================================
# Public API
# ==============================================================

func import_files(paths: PackedStringArray) -> void:
	for path in paths:
		var clean_path := path.strip_edges()

		if clean_path.is_empty():
			continue

		# Ein gedroppter Ordner wird als Batch-Import behandelt.
		if DirAccess.dir_exists_absolute(clean_path):
			_import_folder_contents(clean_path)
		else:
			_import_single_file(clean_path)

	_select_first_file_if_needed()
	queue_changed.emit(queue_files.duplicate(true))
	
func import_folder(folder_path: String) -> void:
	var clean_folder_path := folder_path.strip_edges()

	if clean_folder_path.is_empty():
		return

	_import_folder_contents(clean_folder_path)

	_select_first_file_if_needed()
	queue_changed.emit(queue_files.duplicate(true))
	
func _import_folder_contents(folder_path: String) -> void:
	var directory := DirAccess.open(folder_path)

	if directory == null:
		import_error.emit(
			"Could not open folder: " + folder_path
		)
		return

	var found_supported_image := false

	for file_name in directory.get_files():
		var extension := file_name.get_extension().to_lower()

		if SUPPORTED_EXTENSIONS.has(extension):
			found_supported_image = true

			var image_path := folder_path.path_join(file_name)
			_import_single_file(image_path)

	if not found_supported_image:
		import_warning.emit(
			"No supported images were found in: " + folder_path
		)


func _select_first_file_if_needed() -> void:
	if selected_file_id.is_empty() and not queue_files.is_empty():
		select_file(str(queue_files[0]["id"]))


func select_file(file_id: String) -> void:
	for file_data in queue_files:
		if str(file_data["id"]) == file_id:
			selected_file_id = file_id
			selection_changed.emit(file_data.duplicate(true))
			return

	import_error.emit("The selected file could not be found in the queue.")


func remove_file(file_id: String) -> void:
	var removed_selected_file := file_id == selected_file_id

	for index in range(queue_files.size() - 1, -1, -1):
		if str(queue_files[index]["id"]) == file_id:
			queue_files.remove_at(index)
			break

	if removed_selected_file:
		selected_file_id = ""

		if not queue_files.is_empty():
			select_file(str(queue_files[0]["id"]))
		else:
			selection_changed.emit({})

	queue_changed.emit(queue_files.duplicate(true))


func clear_queue() -> void:
	queue_files.clear()
	selected_file_id = ""

	queue_changed.emit(queue_files)
	selection_changed.emit({})


func get_queue_count() -> int:
	return queue_files.size()


# ==============================================================
# Import and validation
# ==============================================================

func _import_single_file(path: String) -> void:
	var normalized_path := path.strip_edges()

	if normalized_path.is_empty():
		return

	if not FileAccess.file_exists(normalized_path):
		import_error.emit("File not found: " + normalized_path)
		return

	if _is_duplicate(normalized_path):
		import_warning.emit(
			"File is already in the queue: " + normalized_path.get_file()
		)
		return

	var extension := normalized_path.get_extension().to_lower()

	if not SUPPORTED_EXTENSIONS.has(extension):
		import_error.emit(
			"Unsupported file type: " + normalized_path.get_file()
		)
		return

	var image := Image.load_from_file(normalized_path)

	if image == null or image.is_empty():
		import_error.emit(
			"Could not read image file: " + normalized_path.get_file()
		)
		return

	var warnings: Array[String] = []

	if extension == "jpg" or extension == "jpeg":
		warnings.append(
			"This image has no transparency. Existing background colors will be kept."
		)

	if image.get_width() != image.get_height():
		warnings.append(
			"This image is not square. The selected fit mode will be applied during conversion."
		)

	var file_data: Dictionary = {
		"id": normalized_path,
		"source_path": normalized_path,
		"filename": normalized_path.get_file(),
		"extension": extension,
		"width": image.get_width(),
		"height": image.get_height(),
		"status": "ready",
		"warnings": warnings
	}

	queue_files.append(file_data)


func _is_duplicate(path: String) -> bool:
	for file_data in queue_files:
		if str(file_data["source_path"]) == path:
			return true

	return false
