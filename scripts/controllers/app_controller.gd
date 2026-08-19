extends Node
class_name AppController

# ==============================================================
# AppController
# ==============================================================
#
# Responsibility:
# ✅ Manages imported image files as data
# ✅ Validates basic information for import
# ✅ Manages the currently selected file
# ✅ Sends structured results to the UI
#
# ❌ Has no knowledge of buttons, labels, or TextureRects
# ❌ Does not open FileDialogs
# ❌ Does not create ICO files yet
# ❌ Does not build a queue UI
#
# ==============================================================


signal queue_changed(files: Array[Dictionary])
signal selection_changed(file_data: Dictionary)
signal import_warning(message: String)
signal import_error(message: String)
signal conversion_completed(result: ConversionResult)

signal batch_started(total_count: int)

signal batch_progress(
	processed_count: int,
	total_count: int,
	result: ConversionResult
)

signal batch_completed(batch_result: BatchResult)

const SUPPORTED_EXTENSIONS: Array[String] = [
	"png",
	"jpg",
	"jpeg",
	"bmp"
]


var queue_files: Array[Dictionary] = []
var selected_file_id := ""
var conversion_service: ConversionService = ConversionService.new()
var batch_in_progress: bool = false

# ==============================================================
# Public API
# ==============================================================

func import_files(paths: PackedStringArray) -> void:
	for path in paths:
		var clean_path := path.strip_edges()

		if clean_path.is_empty():
			continue

		# A dropped folder is treated as a batch import.
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
	
func has_selected_file() -> bool:
	if selected_file_id.is_empty():
		return false

	var selected_file_index: int = _get_file_index(
		selected_file_id
	)

	return selected_file_index >= 0

func is_batch_running() -> bool:
	return batch_in_progress
	
func convert_selected(
	options: ConversionOptions
) -> void:
	var result: ConversionResult = ConversionResult.new()

	if options == null:
		result.mark_failed("Conversion options are missing.")
		conversion_completed.emit(result)
		return

	if selected_file_id.is_empty():
		result.mark_failed("No image file is selected.")
		conversion_completed.emit(result)
		return

	var selected_file_index: int = _get_file_index(
		selected_file_id
	)

	if selected_file_index < 0:
		result.mark_failed("The selected image file could not be found.")
		conversion_completed.emit(result)
		return

	var selected_file_data: Dictionary = (
		queue_files[selected_file_index]
	)

	var source_path: String = str(
		selected_file_data.get("source_path", "")
	)

	if source_path.is_empty():
		result.mark_failed("The selected image has no source path.")
		conversion_completed.emit(result)
		return

	# The controller sets the actual source path.
	options.source_path = source_path

	# For the initial UI workflow, a subfolder named "converted"
	# next to the source image is used automatically.
	if options.output_directory.strip_edges().is_empty():
		var source_directory: String = source_path.get_base_dir()

		options.output_directory = source_directory.path_join(
			"converted"
		)

	# If no name has been set, it is derived from the
	# source image name.
	if options.output_filename.strip_edges().is_empty():
		var source_filename: String = source_path.get_file()

		options.output_filename = (
			source_filename.get_basename() + ".ico"
		)

	_set_file_status(
		selected_file_id,
		ConversionResult.STATUS_PROCESSING
	)

	queue_changed.emit(queue_files.duplicate(true))

	var conversion_result: ConversionResult = (
		conversion_service.convert(options)
	)

	_apply_conversion_result_to_file(
		selected_file_id,
		conversion_result
	)

	queue_changed.emit(queue_files.duplicate(true))
	conversion_completed.emit(conversion_result)

func convert_all(
	base_options: ConversionOptions
) -> BatchResult:
	var batch_result: BatchResult = BatchResult.new()

	if base_options == null:
		batch_completed.emit(batch_result)
		return batch_result

	if queue_files.is_empty():
		batch_completed.emit(batch_result)
		return batch_result

	var file_ids: Array[String] = []

	for file_data: Dictionary in queue_files:
		var file_id: String = str(
			file_data.get("id", "")
		)

		if not file_id.is_empty():
			file_ids.append(file_id)

	if file_ids.is_empty():
		batch_completed.emit(batch_result)
		return batch_result

	batch_in_progress = true
	batch_started.emit(file_ids.size())

	for index: int in range(file_ids.size()):
		var file_id: String = file_ids[index]

		var file_index: int = _get_file_index(file_id)

		if file_index < 0:
			continue

		var file_data: Dictionary = queue_files[file_index]

		_set_file_status(
			file_id,
			ConversionResult.STATUS_PROCESSING
		)

		queue_changed.emit(queue_files.duplicate(true))

		# The UI is allowed to display the new queue status
		# before the actual conversion starts.
		await get_tree().process_frame

		var file_options: ConversionOptions = (
			_create_batch_options_for_file(
				base_options,
				file_data
			)
		)

		var conversion_result: ConversionResult = (
			conversion_service.convert(file_options)
		)

		_apply_conversion_result_to_file(
			file_id,
			conversion_result
		)

		batch_result.add_result(conversion_result)

		queue_changed.emit(queue_files.duplicate(true))

		var processed_count: int = index + 1

		batch_progress.emit(
			processed_count,
			file_ids.size(),
			conversion_result
		)

		# Release a frame again between two files.
		await get_tree().process_frame

	batch_in_progress = false

	batch_completed.emit(batch_result)

	return batch_result
	
func _create_batch_options_for_file(
	base_options: ConversionOptions,
	file_data: Dictionary
) -> ConversionOptions:
	var file_options: ConversionOptions = ConversionOptions.new()

	var source_path: String = str(
		file_data.get("source_path", "")
	)

	file_options.source_path = source_path

	# If a global output folder is set later in the settings,
	# it will be used for all batch files.
	file_options.output_directory = (
		base_options.output_directory
	)

	# Without custom settings, a "converted" folder
	# is used directly next to each source file.
	if file_options.output_directory.strip_edges().is_empty():
		var source_directory: String = source_path.get_base_dir()

		file_options.output_directory = source_directory.path_join(
			"converted"
		)

	# Batch files always get their own name,
	# derived from the respective source image.
	var source_filename: String = source_path.get_file()

	file_options.output_filename = (
		source_filename.get_basename() + ".ico"
	)

	# Remove standard sizes of the new option object.
	file_options.icon_sizes.clear()

	# Cleanly copy selected sizes.
	for icon_size: int in base_options.icon_sizes:
		file_options.icon_sizes.append(icon_size)
	
	# Copy global export options.
	file_options.fit_mode = base_options.fit_mode
	file_options.scaling_mode = base_options.scaling_mode
	file_options.background_mode = base_options.background_mode
	file_options.background_color = base_options.background_color
	file_options.collision_policy = base_options.collision_policy

	return file_options
	
func _get_file_index(
	file_id: String
) -> int:
	for index: int in range(queue_files.size()):
		var file_data: Dictionary = queue_files[index]

		var current_file_id: String = str(
			file_data.get("id", "")
		)

		if current_file_id == file_id:
			return index

	return -1


func _set_file_status(
	file_id: String,
	new_status: String
) -> void:
	var file_index: int = _get_file_index(file_id)

	if file_index < 0:
		return

	var file_data: Dictionary = queue_files[file_index]

	file_data["status"] = new_status

	queue_files[file_index] = file_data


func _apply_conversion_result_to_file(
	file_id: String,
	result: ConversionResult
) -> void:
	var file_index: int = _get_file_index(file_id)

	if file_index < 0:
		return

	var file_data: Dictionary = queue_files[file_index]

	file_data["status"] = result.status
	file_data["output_path"] = result.output_path
	file_data["error_message"] = result.error_message

	queue_files[file_index] = file_data


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
