extends Control
class_name IconifyMainPanel

# ==============================================================
# IconifyMainPanel
# ==============================================================
#
# Verantwortung:
# ✅ Verwaltet sichtbare UI-Interaktionen
# ✅ Öffnet den Bild-Dateidialog
# ✅ Reagiert auf Controller-Signale
# ✅ Baut die einfache Queue-Darstellung
# ✅ Aktualisiert die Bildvorschau
#
# ❌ Verwaltet keine ICO-Binärdaten
# ❌ Speichert keine Settings
# ❌ Enthält keine Batch-Konvertierung
# ❌ Entscheidet nicht über Konvertierungslogik
#
# ==============================================================

const FILE_QUEUE_ITEM_SCENE := preload(
	"res://scenes/components/file_queue_item.tscn"
)


@onready var app_controller: AppController = %AppController
@onready var image_file_dialog: FileDialog = %ImageFileDialog

@onready var add_files_button: Button = %AddFilesButton
@onready var alternative_button: TextureButton = %Alternative_Button
@onready var add_folder_button: Button = %AddFolderButton
@onready var clear_queue_button: Button = %ClearQueueButton

@onready var file_queue_list: VBoxContainer = %FileQueueList
@onready var queue_count_label: Label = %QueueCountLabel

@onready var preview_image: TextureRect = %PreviewImage
@onready var empty_state: Control = %EmptyState
@onready var preview_info_label: Label = %PreviewInfoLabel
@onready var image_meta_label: Label = %ImageMetaLabel
@onready var zoom_button: Button = %ZoomButton

@onready var convert_button: Button = %ConvertButton
@onready var batch_convert_button: Button = %BatchConvertButton

@onready var size_16: CheckButton = %Size16
@onready var size_24: CheckButton = %Size24
@onready var size_32: CheckButton = %Size32
@onready var size_48: CheckButton = %Size48
@onready var size_64: CheckButton = %Size64
@onready var size_128: CheckButton = %Size128
@onready var size_256: CheckButton = %Size256

@onready var batch_progress_container: HBoxContainer = (%BatchProgressContainer)

@onready var batch_progress_label: Label = (%BatchProgressLabel)

@onready var batch_progress_bar: ProgressBar = (%BatchProgressBar)

@onready var batch_results_dialog: AcceptDialog = (%BatchResultsDialog)

@onready var batch_results_summary: RichTextLabel = (%BatchResultsSummary)

@onready var open_output_folder_button: Button = (%OpenOutputFolderButton)

@onready var copy_error_report_button: Button = (%CopyErrorReportButton)


var queue_items_by_id: Dictionary = {}
var selected_queue_file_id := ""
var last_batch_result: BatchResult = null


func _ready() -> void:
	_configure_file_dialog()
	_connect_ui_signals()
	_connect_controller_signals()
	_reset_preview()
	_update_queue_count(0)
	_reset_batch_progress()
	_update_convert_button_state()


# ==============================================================
# Setup
# ==============================================================

func _configure_file_dialog() -> void:
	image_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES

	image_file_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.bmp ; Supported Images",
		"*.png ; PNG Images",
		"*.jpg, *.jpeg ; JPEG Images",
		"*.bmp ; BMP Images"
	])


func _connect_ui_signals() -> void:
	add_files_button.pressed.connect(_on_add_files_button_pressed)
	alternative_button.pressed.connect(_on_add_files_button_pressed)
	add_folder_button.pressed.connect(_on_add_folder_button_pressed)
	clear_queue_button.pressed.connect(_on_clear_queue_button_pressed)
	
	image_file_dialog.files_selected.connect(_on_image_files_selected)
	image_file_dialog.dir_selected.connect(_on_image_folder_selected)
	
	convert_button.pressed.connect(_on_convert_button_pressed)
	batch_convert_button.pressed.connect(_on_batch_convert_button_pressed)
	
	open_output_folder_button.pressed.connect(_on_open_output_folder_button_pressed)
	copy_error_report_button.pressed.connect(_on_copy_error_report_button_pressed)

	size_16.toggled.connect(_on_icon_size_toggled)
	size_24.toggled.connect(_on_icon_size_toggled)
	size_32.toggled.connect(_on_icon_size_toggled)
	size_48.toggled.connect(_on_icon_size_toggled)
	size_64.toggled.connect(_on_icon_size_toggled)
	size_128.toggled.connect(_on_icon_size_toggled)
	size_256.toggled.connect(_on_icon_size_toggled)
	
	get_viewport().files_dropped.connect(_on_files_dropped)


func _connect_controller_signals() -> void:
	app_controller.queue_changed.connect(_on_queue_changed)
	app_controller.selection_changed.connect(_on_selection_changed)
	app_controller.import_warning.connect(_on_import_warning)
	app_controller.import_error.connect(_on_import_error)
	app_controller.conversion_completed.connect(_on_conversion_completed)
	
	app_controller.batch_started.connect(_on_batch_started)
	app_controller.batch_progress.connect(_on_batch_progress)
	app_controller.batch_completed.connect(_on_batch_completed)


# ==============================================================
# File import
# ==============================================================

func _on_add_files_button_pressed() -> void:
	image_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILES

	image_file_dialog.filters = PackedStringArray([
		"*.png, *.jpg, *.jpeg, *.bmp ; Supported Images",
		"*.png ; PNG Images",
		"*.jpg, *.jpeg ; JPEG Images",
		"*.bmp ; BMP Images"
	])

	image_file_dialog.popup_centered_ratio(0.75)
	
func _on_add_folder_button_pressed() -> void:
	image_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	image_file_dialog.filters = PackedStringArray()

	image_file_dialog.popup_centered_ratio(0.75)


func _on_image_files_selected(paths: PackedStringArray) -> void:
	app_controller.import_files(paths)
	
func _on_image_folder_selected(folder_path: String) -> void:
	app_controller.import_folder(folder_path)
	
func _on_files_dropped(paths: PackedStringArray) -> void:
	app_controller.import_files(paths)


func _on_clear_queue_button_pressed() -> void:
	app_controller.clear_queue()


# ==============================================================
# Controller results
# ==============================================================

func _on_queue_changed(files: Array[Dictionary]) -> void:
	_rebuild_queue(files)
	_update_queue_count(files.size())

	clear_queue_button.disabled = files.is_empty()
	
	_update_convert_button_state()


func _on_selection_changed(file_data: Dictionary) -> void:
	if file_data.is_empty():
		selected_queue_file_id = ""
		_update_queue_selection()
		_reset_preview()
		return

	selected_queue_file_id = str(file_data["id"])
	_update_queue_selection()

	_show_file_preview(file_data)


func _on_import_warning(message: String) -> void:
	push_warning(message)

	# Für den ersten UI-Test zeigen wir Warnings unter der Preview.
	# Später übernimmt dies unsere finale StatusBar.
	image_meta_label.text = "⚠ " + message


func _on_import_error(message: String) -> void:
	push_warning(message)

	preview_info_label.text = "Import issue"
	image_meta_label.text = "✕ " + message


# ==============================================================
# Queue UI
# ==============================================================

func _rebuild_queue(files: Array[Dictionary]) -> void:
	# Alte Queue-Cards entfernen.
	for child in file_queue_list.get_children():
		child.queue_free()

	queue_items_by_id.clear()

	# Für jede importierte Datei eine neue Queue-Card erzeugen.
	for file_data in files:
		var queue_item := FILE_QUEUE_ITEM_SCENE.instantiate() as FileQueueItem

		# Erst in den Scene Tree einfügen.
		# Danach sind die @onready-Nodes innerhalb der Component verfügbar.
		file_queue_list.add_child(queue_item)

		# Dateidaten an die Card übergeben.
		queue_item.setup(file_data)

		# Signale der Queue-Card mit MainPanel verbinden.
		queue_item.item_selected.connect(_on_queue_item_selected)
		queue_item.remove_requested.connect(_on_queue_item_remove_requested)

		# Referenz für spätere Auswahl-Hervorhebung speichern.
		var file_id := str(file_data["id"])
		queue_items_by_id[file_id] = queue_item

	_update_queue_selection()

func _on_queue_item_selected(file_id: String) -> void:
	app_controller.select_file(file_id)


func _on_queue_item_remove_requested(file_id: String) -> void:
	app_controller.remove_file(file_id)
	
func _on_convert_button_pressed() -> void:
	var selected_sizes: Array[int] = _get_selected_icon_sizes()

	if selected_sizes.is_empty():
		preview_info_label.text = "Conversion issue"
		image_meta_label.text = "✕ Select at least one icon size."
		return

	var options: ConversionOptions = _create_base_conversion_options(
		selected_sizes
	)

	convert_button.disabled = true
	convert_button.text = "Converting..."

	app_controller.convert_selected(options)
	
func _on_batch_convert_button_pressed() -> void:
	var selected_sizes: Array[int] = _get_selected_icon_sizes()

	if selected_sizes.is_empty():
		preview_info_label.text = "Batch conversion issue"
		image_meta_label.text = "✕ Select at least one icon size."
		return

	var queue_count: int = app_controller.get_queue_count()

	if queue_count < 2:
		preview_info_label.text = "Batch conversion issue"
		image_meta_label.text = (
			"✕ Add at least two files to start a batch conversion."
		)
		return

	var options: ConversionOptions = _create_base_conversion_options(
		selected_sizes
	)

	# Kein Bestätigungsdialog.
	# Batch startet sofort.
	await app_controller.convert_all(options)

func _create_base_conversion_options(
	selected_sizes: Array[int]
) -> ConversionOptions:
	var options: ConversionOptions = ConversionOptions.new()

	# ConversionOptions enthält Default-Größen.
	# Für eine UI-gesteuerte Konvertierung dürfen ausschließlich
	# die aktuell ausgewählten Größen übernommen werden.
	options.icon_sizes.clear()

	for icon_size: int in selected_sizes:
		options.icon_sizes.append(icon_size)

	options.fit_mode = ConversionOptions.FIT_CONTAIN
	options.scaling_mode = ConversionOptions.SCALING_SMOOTH
	options.background_mode = ConversionOptions.BACKGROUND_TRANSPARENT
	options.collision_policy = (
		ConversionOptions.COLLISION_AUTO_NUMBER
	)

	return options
func _on_icon_size_toggled(
	_pressed: bool
) -> void:
	_update_convert_button_state()


func _get_selected_icon_sizes() -> Array[int]:
	var selected_sizes: Array[int] = []

	if size_16.button_pressed:
		selected_sizes.append(16)

	if size_24.button_pressed:
		selected_sizes.append(24)

	if size_32.button_pressed:
		selected_sizes.append(32)

	if size_48.button_pressed:
		selected_sizes.append(48)

	if size_64.button_pressed:
		selected_sizes.append(64)

	if size_128.button_pressed:
		selected_sizes.append(128)

	if size_256.button_pressed:
		selected_sizes.append(256)

	return selected_sizes


func _update_convert_button_state() -> void:
	var has_selected_file: bool = (
		app_controller.has_selected_file()
	)

	var has_selected_sizes: bool = (
		not _get_selected_icon_sizes().is_empty()
	)

	var queue_count: int = app_controller.get_queue_count()

	var is_batch_running: bool = (
		app_controller.is_batch_running()
	)

	# Einzelkonvertierung:
	# Nur aktiv, wenn eine Datei ausgewählt ist.
	convert_button.disabled = not (
		has_selected_file
		and has_selected_sizes
		and not is_batch_running
	)

	convert_button.text = "Convert Selected File"

	# Batch:
	# Erst sinnvoll ab zwei Dateien.
	batch_convert_button.disabled = not (
		queue_count >= 2
		and has_selected_sizes
		and not is_batch_running
	)

	batch_convert_button.text = (
		"Batch Convert All (%d)" % queue_count
	)
	
func _on_batch_started(total_count: int) -> void:
	last_batch_result = null

	batch_progress_container.visible = true
	batch_progress_bar.min_value = 0.0
	batch_progress_bar.max_value = 100.0
	batch_progress_bar.value = 0.0

	batch_progress_label.text = (
		"Converting 0 / %d files" % total_count
	)

	_update_convert_button_state()

	preview_info_label.text = "Batch conversion started"

	image_meta_label.text = (
		"Preparing %d file(s)..." % total_count
	)
	
func _on_batch_progress(
	processed_count: int,
	total_count: int,
	result: ConversionResult
) -> void:
	var source_filename: String = result.source_path.get_file()

	var progress_percent: float = 0.0

	if total_count > 0:
		progress_percent = (
			float(processed_count)
			/ float(total_count)
			* 100.0
		)

	batch_progress_bar.value = progress_percent

	batch_progress_label.text = (
		"Converting %d / %d files" % [
			processed_count,
			total_count
		]
	)

	preview_info_label.text = (
		"Batch progress: %d / %d" % [
			processed_count,
			total_count
		]
	)

	if result.success:
		image_meta_label.text = (
			"✓ %s → %s" % [
				source_filename,
				result.output_path.get_file()
			]
		)

		if result.has_warnings():
			image_meta_label.text += (
				" · ⚠ " + result.warnings[0]
			)

		return

	if result.is_skipped():
		image_meta_label.text = (
			"⚠ Skipped: " + source_filename
		)
		return

	image_meta_label.text = (
		"✕ Failed: %s · %s" % [
			source_filename,
			result.error_message
		]
	)
	
func _on_batch_completed(
	batch_result: BatchResult
) -> void:
	last_batch_result = batch_result

	batch_progress_container.visible = true
	batch_progress_bar.value = 100.0

	batch_progress_label.text = (
		"Batch complete · %d / %d files processed" % [
			batch_result.get_processed_count(),
			batch_result.total_count
		]
	)

	_update_convert_button_state()

	preview_info_label.text = "Batch conversion complete"
	image_meta_label.text = batch_result.get_summary()

	_show_batch_results_dialog(batch_result)
		
func _on_conversion_completed(
	result: ConversionResult
) -> void:
	_update_convert_button_state()

	if result.success:
		preview_info_label.text = "Conversion complete"

		var output_filename: String = result.output_path.get_file()

		image_meta_label.text = (
			"✓ Created: " + output_filename
		)

		if result.has_warnings():
			image_meta_label.text += (
				" · ⚠ " + result.warnings[0]
			)

		return

	if result.is_skipped():
		preview_info_label.text = "Conversion skipped"
		image_meta_label.text = "⚠ " + result.error_message
		return

	preview_info_label.text = "Conversion failed"
	image_meta_label.text = "✕ " + result.error_message


func _update_queue_selection() -> void:
	for file_id in queue_items_by_id.keys():
		var queue_item := queue_items_by_id[file_id] as FileQueueItem

		if queue_item == null:
			continue

		queue_item.set_selected(
			str(file_id) == selected_queue_file_id
		)


func _update_queue_count(count: int) -> void:
	if count == 1:
		queue_count_label.text = "1 file"
	else:
		queue_count_label.text = str(count) + " files"


# ==============================================================
# Preview UI
# ==============================================================

func _show_file_preview(file_data: Dictionary) -> void:
	var source_path := str(file_data["source_path"])
	var image := Image.load_from_file(source_path)

	if image == null or image.is_empty():
		_on_import_error(
			"Could not create preview for: " + str(file_data["filename"])
		)
		return

	var texture := ImageTexture.create_from_image(image)

	preview_image.texture = texture
	empty_state.visible = false
	zoom_button.disabled = false

	var filename := str(file_data["filename"])
	var extension := str(file_data["extension"]).to_upper()
	var width := int(file_data["width"])
	var height := int(file_data["height"])

	preview_info_label.text = filename

	var transparency_text := "Alpha supported"

	if extension == "JPG" or extension == "JPEG":
		transparency_text = "No transparency available"

	image_meta_label.text = "%d × %d · %s · %s" % [
		width,
		height,
		extension,
		transparency_text
	]


func _reset_preview() -> void:
	preview_image.texture = null
	empty_state.visible = true
	zoom_button.disabled = true

	preview_info_label.text = "No image selected"
	image_meta_label.text = ""
	
func _reset_batch_progress() -> void:
	batch_progress_container.visible = false

	batch_progress_bar.min_value = 0.0
	batch_progress_bar.max_value = 100.0
	batch_progress_bar.value = 0.0

	batch_progress_label.text = ""
	
func _show_batch_results_dialog(
	batch_result: BatchResult
) -> void:
	batch_results_summary.text = (
		batch_result.get_detailed_summary()
	)

	open_output_folder_button.disabled = (
		_get_first_batch_output_directory(batch_result).is_empty()
	)

	copy_error_report_button.disabled = not (
		batch_result.has_failures()
		or batch_result.has_warnings()
		or batch_result.has_skipped_files()
	)

	batch_results_dialog.popup_centered()
	
func _get_first_batch_output_directory(
	batch_result: BatchResult
) -> String:
	for result: ConversionResult in batch_result.results:
		if result == null:
			continue

		if result.output_path.strip_edges().is_empty():
			continue

		return result.output_path.get_base_dir()

	return ""
	
func _on_open_output_folder_button_pressed() -> void:
	if last_batch_result == null:
		return

	var output_directory: String = (
		_get_first_batch_output_directory(last_batch_result)
	)

	if output_directory.is_empty():
		preview_info_label.text = "Output folder unavailable"
		image_meta_label.text = (
			"✕ No created output file was found for this batch."
		)
		return

	var open_error: int = OS.shell_open(output_directory)

	if open_error != OK:
		preview_info_label.text = "Could not open output folder"
		image_meta_label.text = (
			"✕ " + output_directory
		)
		
func _on_copy_error_report_button_pressed() -> void:
	if last_batch_result == null:
		return

	var report: String = last_batch_result.get_error_report()

	DisplayServer.clipboard_set(report)

	preview_info_label.text = "Batch report copied"
	image_meta_label.text = (
		"✓ Warnings, skipped files, and failures were copied to the clipboard."
	)
