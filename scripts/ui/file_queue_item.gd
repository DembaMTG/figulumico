extends PanelContainer
class_name FileQueueItem

# ==============================================================
# FileQueueItem
# ==============================================================
#
# Responsibility:
# ✅ Represents exactly one imported file in the queue
# ✅ Displays the thumbnail, name, metadata, and status
# ✅ Reports selection to MainPanel
# ✅ Reports removal requests to MainPanel
#
# ❌ Does not manage queue data
# ❌ Does not delete files from disk
# ❌ Does not validate images
# ❌ Has no direct knowledge of AppController
#
# ==============================================================


signal item_selected(file_id: String)
signal remove_requested(file_id: String)


@onready var thumbnail: TextureRect = %Thumbnail
@onready var file_name_label: Label = %FileNameLabel
@onready var file_meta_label: Label = %FileMetaLabel
@onready var status_label: Label = %StatusLabel
@onready var remove_button: Button = %RemoveButton


var file_id := ""

var normal_style: StyleBoxFlat
var selected_style: StyleBoxFlat


func _ready() -> void:
	_create_styles()

	gui_input.connect(_on_gui_input)
	remove_button.pressed.connect(_on_remove_button_pressed)

	_apply_selected_style(false)


# ==============================================================
# Public API
# ==============================================================

func setup(file_data: Dictionary) -> void:
	file_id = str(file_data.get("id", ""))

	var filename: String = str(file_data.get("filename", "Unknown file"))
	var extension := str(file_data.get("extension", "")).to_upper()
	var width := int(file_data.get("width", 0))
	var height := int(file_data.get("height", 0))

	file_name_label.text = filename
	file_name_label.tooltip_text = str(file_data.get("source_path", ""))

	file_meta_label.text = "%s · %d × %d" % [
		extension,
		width,
		height
	]

	var warnings: Array = file_data.get("warnings", [])
	var current_status: String = str(
		file_data.get("status", "ready")
	)

	var error_message: String = str(
		file_data.get("error_message", "")
	)

	status_label.tooltip_text = ""

	match current_status:
		"ready":
			if warnings.is_empty():
				status_label.text = "Ready"
				status_label.modulate = Color("#56C271")
			else:
				status_label.text = "Warning"
				status_label.modulate = Color("#F2C14E")
				status_label.tooltip_text = "\n".join(warnings)

		"processing":
			status_label.text = "Processing"
			status_label.modulate = Color("#33D6C5")

		"converted":
			status_label.text = "Converted"
			status_label.modulate = Color("#56C271")

		"warning":
			status_label.text = "Converted"
			status_label.modulate = Color("#F2C14E")
			status_label.tooltip_text = "\n".join(warnings)

		"failed":
			status_label.text = "Failed"
			status_label.modulate = Color("#E56B6F")
			status_label.tooltip_text = error_message

		"skipped":
			status_label.text = "Skipped"
			status_label.modulate = Color("#F2C14E")
			status_label.tooltip_text = error_message

		_:
			status_label.text = "Ready"
			status_label.modulate = Color("#56C271")

	_load_thumbnail(str(file_data.get("source_path", "")))


func set_selected(is_selected: bool) -> void:
	_apply_selected_style(is_selected)


# ==============================================================
# UI Events
# ==============================================================

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			item_selected.emit(file_id)
			accept_event()


func _on_remove_button_pressed() -> void:
	remove_requested.emit(file_id)


# ==============================================================
# Visuals
# ==============================================================

func _load_thumbnail(source_path: String) -> void:
	var image := Image.load_from_file(source_path)

	if image == null or image.is_empty():
		thumbnail.texture = null
		return

	thumbnail.texture = ImageTexture.create_from_image(image)


func _create_styles() -> void:
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#26313D")
	normal_style.border_color = Color("#3B4A5A")

	normal_style.border_width_left = 1
	normal_style.border_width_top = 1
	normal_style.border_width_right = 1
	normal_style.border_width_bottom = 1

	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6

	selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color("#1E4E55")
	selected_style.border_color = Color("#33D6C5")

	selected_style.border_width_left = 2
	selected_style.border_width_top = 2
	selected_style.border_width_right = 2
	selected_style.border_width_bottom = 2

	selected_style.corner_radius_top_left = 6
	selected_style.corner_radius_top_right = 6
	selected_style.corner_radius_bottom_left = 6
	selected_style.corner_radius_bottom_right = 6


func _apply_selected_style(is_selected: bool) -> void:
	if is_selected:
		add_theme_stylebox_override("panel", selected_style)
	else:
		add_theme_stylebox_override("panel", normal_style)
