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


func _ready() -> void:
	_configure_file_dialog()
	_connect_ui_signals()
	_connect_controller_signals()
	_reset_preview()
	_update_queue_count(0)

	# Der Ordnerimport kommt nach dem ersten erfolgreichen
	# Dateiimport- und Preview-Test.
	add_folder_button.disabled = true


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
	clear_queue_button.pressed.connect(_on_clear_queue_button_pressed)
	image_file_dialog.files_selected.connect(_on_image_files_selected)
	get_viewport().files_dropped.connect(_on_files_dropped)


func _connect_controller_signals() -> void:
	app_controller.queue_changed.connect(_on_queue_changed)
	app_controller.selection_changed.connect(_on_selection_changed)
	app_controller.import_warning.connect(_on_import_warning)
	app_controller.import_error.connect(_on_import_error)


# ==============================================================
# File import
# ==============================================================

func _on_add_files_button_pressed() -> void:
	image_file_dialog.popup_centered_ratio(0.75)


func _on_image_files_selected(paths: PackedStringArray) -> void:
	app_controller.import_files(paths)
	
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


func _on_selection_changed(file_data: Dictionary) -> void:
	if file_data.is_empty():
		_reset_preview()
		return

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
	for child in file_queue_list.get_children():
		child.queue_free()

	for file_data in files:
		var queue_button := Button.new()
		var warnings: Array = file_data.get("warnings", [])
		var warning_prefix := ""

		if not warnings.is_empty():
			warning_prefix = "⚠ "

		queue_button.text = warning_prefix + str(file_data["filename"])
		queue_button.tooltip_text = str(file_data["source_path"])
		queue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		queue_button.pressed.connect(
			_on_queue_file_pressed.bind(str(file_data["id"]))
		)

		file_queue_list.add_child(queue_button)


func _on_queue_file_pressed(file_id: String) -> void:
	app_controller.select_file(file_id)


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
