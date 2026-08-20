extends Control
class_name IconifyMainPanel

# ==============================================================
# IconifyMainPanel
# ==============================================================
#
# Responsibility:
# ✅ Manages visible UI interactions
# ✅ Opens the image file dialog
# ✅ Responds to controller signals
# ✅ Builds the simple queue view
# ✅ Updates the image preview
#
# ❌ Does not manage ICO binary data
# ❌ Does not save settings
# ❌ Does not contain batch conversion logic
# ❌ Does not make decisions about conversion logic
#
# ==============================================================

const FILE_QUEUE_ITEM_SCENE := preload(
	"res://scenes/components/file_queue_item.tscn"
)

const SIZE_PRESET_WINDOWS_STANDARD: int = 0
const SIZE_PRESET_SMALL: int = 1
const SIZE_PRESET_HIGH_RESOLUTION: int = 2
const SIZE_PRESET_CUSTOM: int = 3

const FIT_MODE_CONTAIN_INDEX: int = 0
const FIT_MODE_CENTER_CROP_INDEX: int = 1
const FIT_MODE_STRETCH_INDEX: int = 2

const SCALING_MODE_SMOOTH_INDEX: int = 0
const SCALING_MODE_PIXEL_PERFECT_INDEX: int = 1

const BACKGROUND_MODE_TRANSPARENT_INDEX: int = 0
const BACKGROUND_MODE_SOLID_COLOR_INDEX: int = 1

enum PendingConversionKind {
	NONE,
	SINGLE,
	BATCH
}

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


@onready var convert_button: Button = %ConvertButton
@onready var batch_convert_button: Button = %BatchConvertButton

@onready var size_16: CheckButton = %Size16
@onready var size_24: CheckButton = %Size24
@onready var size_32: CheckButton = %Size32
@onready var size_48: CheckButton = %Size48
@onready var size_64: CheckButton = %Size64
@onready var size_128: CheckButton = %Size128
@onready var size_256: CheckButton = %Size256

@onready var size_preset_option: OptionButton = (%SizePresetOption
)

@onready var fit_mode_option: OptionButton = (%FitModeOption)
@onready var scaling_mode_option: OptionButton = (%ScalingModeOption)
@onready var background_mode_option: OptionButton = (%BackgroundModeOption)
@onready var background_color_picker: ColorPickerButton = (%BackgroundColorPicker)

@onready var output_directory_label: Label = (%OutputDirectoryLabel)
@onready var choose_output_directory_button: Button = (%ChooseOutputDirectoryButton)
@onready var use_source_output_button: Button = (%UseSourceOutputButton)
@onready var output_directory_dialog: FileDialog = (%OutputDirectoryDialog)

@onready var batch_progress_container: HBoxContainer = (%BatchProgressContainer)
@onready var batch_progress_label: Label = (%BatchProgressLabel)
@onready var batch_progress_bar: ProgressBar = (%BatchProgressBar)
@onready var batch_results_dialog: AcceptDialog = (%BatchResultsDialog)
@onready var batch_results_summary: RichTextLabel = (%BatchResultsSummary)
@onready var open_output_folder_button: Button = (%OpenOutputFolderButton)
@onready var copy_error_report_button: Button = (%CopyErrorReportButton)

@onready var settings_button: TextureButton = (%SettingsButton)
@onready var settings_dialog: ConfirmationDialog = (%SettingsDialog)
@onready var settings_output_directory_label: Label = (%SettingsOutputDirectoryLabel)
@onready var settings_choose_output_button: Button = (%SettingsChooseOutputButton)
@onready var settings_use_source_output_button: Button = (%SettingsUseSourceOutputButton)
@onready var settings_ask_output_checkbox: CheckButton = (%SettingsAskOutputCheckBox)
@onready var settings_size_preset_option: OptionButton = (%SettingsSizePresetOption)
@onready var settings_fit_mode_option: OptionButton = (%SettingsFitModeOption)
@onready var settings_scaling_mode_option: OptionButton = (%SettingsScalingModeOption)
@onready var settings_background_mode_option: OptionButton = (%SettingsBackgroundModeOption)
@onready var settings_background_color_picker: ColorPickerButton = (%SettingsBackgroundColorPicker)
@onready var settings_collision_policy_option: OptionButton = (%SettingsCollisionPolicyOption)
@onready var settings_output_directory_dialog: FileDialog = (%SettingsOutputDirectoryDialog)

@onready var about_button: BaseButton = (%AboutButton)
@onready var about_dialog: AcceptDialog = (%AboutDialog)

var queue_items_by_id: Dictionary = {}
var selected_queue_file_id := ""
var last_batch_result: BatchResult = null
var is_applying_size_preset: bool = false
var custom_output_directory: String = ""
var last_output_directory: String = ""
var settings_service: SettingsService = (SettingsService.new())
var ask_for_output_directory: bool = false
var collision_policy: String = (ConversionOptions.COLLISION_AUTO_NUMBER)

var settings_dialog_output_directory: String = ""

var settings_dialog_icon_sizes: Array[int] = [
	16,
	32,
	48,
	256
]

var pending_conversion_kind: int = (
	PendingConversionKind.NONE
)

var pending_conversion_sizes: Array[int] = []

func _ready() -> void:
	_configure_file_dialog()
	_configure_output_directory_dialog()
	_configure_export_option_controls()
	_configure_settings_dialog_controls()
	_configure_settings_output_directory_dialog()
	_connect_ui_signals()
	_connect_controller_signals()
	_reset_preview()
	_update_queue_count(0)
	_reset_batch_progress()
	_update_output_directory_display()
	_update_convert_button_state()

	_load_application_settings()


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

func _configure_output_directory_dialog() -> void:
	output_directory_dialog.access = FileDialog.ACCESS_FILESYSTEM
	output_directory_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	output_directory_dialog.filters = PackedStringArray()
	
func _configure_settings_output_directory_dialog() -> void:
	settings_output_directory_dialog.access = (
		FileDialog.ACCESS_FILESYSTEM
	)

	settings_output_directory_dialog.file_mode = (
		FileDialog.FILE_MODE_OPEN_DIR
	)

	settings_output_directory_dialog.filters = PackedStringArray()
	
func _configure_settings_dialog_controls() -> void:
	settings_size_preset_option.clear()

	settings_size_preset_option.add_item("Windows Standard")
	settings_size_preset_option.add_item("Small")
	settings_size_preset_option.add_item("High Resolution")
	settings_size_preset_option.add_item("Custom")

	settings_fit_mode_option.clear()

	settings_fit_mode_option.add_item("Contain")
	settings_fit_mode_option.add_item("Center Crop")
	settings_fit_mode_option.add_item("Stretch")

	settings_scaling_mode_option.clear()

	settings_scaling_mode_option.add_item("Smooth")
	settings_scaling_mode_option.add_item("Pixel Perfect")

	settings_background_mode_option.clear()

	settings_background_mode_option.add_item("Transparent")
	settings_background_mode_option.add_item("Solid Color")

	settings_collision_policy_option.clear()

	settings_collision_policy_option.add_item("Auto Number")
	settings_collision_policy_option.add_item("Overwrite")
	settings_collision_policy_option.add_item("Skip")


	settings_background_color_picker.color = Color.WHITE

	settings_dialog.get_ok_button().text = "Save Settings"
	settings_dialog.get_cancel_button().text = "Cancel"

	_update_settings_background_color_picker_state()
	
	

func _configure_export_option_controls() -> void:
	size_preset_option.clear()

	size_preset_option.add_item("Windows Standard")
	size_preset_option.add_item("Small")
	size_preset_option.add_item("High Resolution")
	size_preset_option.add_item("Custom")

	fit_mode_option.clear()

	fit_mode_option.add_item("Contain")
	fit_mode_option.add_item("Center Crop")
	fit_mode_option.add_item("Stretch")

	scaling_mode_option.clear()

	scaling_mode_option.add_item("Smooth")
	scaling_mode_option.add_item("Pixel Perfect")

	background_mode_option.clear()

	background_mode_option.add_item("Transparent")
	background_mode_option.add_item("Solid Color")

	background_color_picker.color = Color.WHITE

	size_preset_option.select(SIZE_PRESET_WINDOWS_STANDARD)
	fit_mode_option.select(FIT_MODE_CONTAIN_INDEX)
	scaling_mode_option.select(SCALING_MODE_SMOOTH_INDEX)
	background_mode_option.select(BACKGROUND_MODE_TRANSPARENT_INDEX)

	_update_background_color_picker_state()

	_apply_size_preset(SIZE_PRESET_WINDOWS_STANDARD)

func _load_application_settings() -> void:
	var settings: Dictionary = settings_service.load_settings()

	_apply_settings_to_controls(settings)

	if settings_service.last_warning.strip_edges().is_empty():
		return

	preview_info_label.text = "Settings warning"
	image_meta_label.text = (
		"⚠ " + settings_service.last_warning
	)

func _apply_settings_to_controls(settings: Dictionary) -> void:
	var preset_id: String = str(
		settings.get(
			"size_preset",
			SettingsService.PRESET_WINDOWS_STANDARD
		)
	)

	var icon_sizes_value: Variant = settings.get(
		"icon_sizes",
		[16, 32, 48, 256]
	)

	var icon_sizes: Array[int] = []

	if icon_sizes_value is Array:
		for raw_size: Variant in icon_sizes_value:
			if raw_size is int or raw_size is float:
				icon_sizes.append(int(raw_size))

	var preset_index: int = _get_preset_index_from_id(
		preset_id
	)

	size_preset_option.select(preset_index)

	if preset_index == SIZE_PRESET_CUSTOM:
		_apply_custom_icon_sizes(icon_sizes)
	else:
		_apply_size_preset(preset_index)

	var fit_mode: String = str(
		settings.get(
			"fit_mode",
			ConversionOptions.FIT_CONTAIN
		)
	)

	fit_mode_option.select(
		_get_fit_mode_index_from_id(fit_mode)
	)

	var scaling_mode: String = str(
		settings.get(
			"scaling_mode",
			ConversionOptions.SCALING_SMOOTH
		)
	)

	scaling_mode_option.select(
		_get_scaling_mode_index_from_id(scaling_mode)
	)

	var background_mode: String = str(
		settings.get(
			"background_mode",
			ConversionOptions.BACKGROUND_TRANSPARENT
		)
	)

	background_mode_option.select(
		_get_background_mode_index_from_id(background_mode)
	)

	background_color_picker.color = (
		settings_service.get_background_color(settings)
	)

	_update_background_color_picker_state()

	custom_output_directory = str(
		settings.get(
			"default_output_directory",
			""
		)
	).strip_edges()

	last_output_directory = str(
		settings.get(
			"last_output_directory",
			""
		)
	).strip_edges()
	
	ask_for_output_directory = bool(
		settings.get(
			"ask_for_output_directory",
			false
		)
	)

	collision_policy = str(
		settings.get(
			"collision_policy",
			ConversionOptions.COLLISION_AUTO_NUMBER
		)
	)

	if collision_policy == ConversionOptions.COLLISION_ASK:
		collision_policy = (
			ConversionOptions.COLLISION_AUTO_NUMBER
		)

	_update_output_directory_display()
	_update_convert_button_state()

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
	
	size_preset_option.item_selected.connect(_on_size_preset_selected)
	fit_mode_option.item_selected.connect(_on_fit_mode_selected)
	scaling_mode_option.item_selected.connect(_on_scaling_mode_selected)
	background_mode_option.item_selected.connect(_on_background_mode_selected)
	
	choose_output_directory_button.pressed.connect(_on_choose_output_directory_button_pressed)
	use_source_output_button.pressed.connect(_on_use_source_output_button_pressed)
	output_directory_dialog.dir_selected.connect(_on_output_directory_selected)
	output_directory_dialog.canceled.connect(_on_output_directory_dialog_canceled)
	
	settings_button.pressed.connect(_on_settings_button_pressed)
	settings_dialog.confirmed.connect(_on_settings_dialog_confirmed)
	settings_choose_output_button.pressed.connect(_on_settings_choose_output_button_pressed)
	settings_use_source_output_button.pressed.connect(_on_settings_use_source_output_button_pressed)
	settings_output_directory_dialog.dir_selected.connect(_on_settings_output_directory_selected)
	settings_size_preset_option.item_selected.connect(_on_settings_size_preset_selected)
	settings_background_mode_option.item_selected.connect(_on_settings_background_mode_selected)
	
	about_button.pressed.connect(_on_about_button_pressed)
	
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

	# Warnings below the preview for the first UI test.
	# The status bar will handle this later.
	image_meta_label.text = "⚠ " + message


func _on_import_error(message: String) -> void:
	push_warning(message)

	preview_info_label.text = "Import issue"
	image_meta_label.text = "✕ " + message


# ==============================================================
# Queue UI
# ==============================================================

func _rebuild_queue(files: Array[Dictionary]) -> void:
	# Remove old Queue-Cards
	for child in file_queue_list.get_children():
		child.queue_free()

	queue_items_by_id.clear()

	# Create a new queue card for each imported file.
	for file_data in files:
		var queue_item := FILE_QUEUE_ITEM_SCENE.instantiate() as FileQueueItem

		# First, add to the scene tree.
		# After that, the @onready nodes are available within the component.
		file_queue_list.add_child(queue_item)
		
		# Transfer file data to the card.
		queue_item.setup(file_data)

		# Connect Queue-Card signals to MainPanel..
		queue_item.item_selected.connect(_on_queue_item_selected)
		queue_item.remove_requested.connect(_on_queue_item_remove_requested)

		# Save reference for later selection highlighting.
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

	if ask_for_output_directory:
		_request_output_directory_for_conversion(
			PendingConversionKind.SINGLE,
			selected_sizes
		)
		return

	_start_selected_conversion(
		selected_sizes,
		custom_output_directory
	)
	
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

	if ask_for_output_directory:
		_request_output_directory_for_conversion(
			PendingConversionKind.BATCH,
			selected_sizes
		)
		return

	await _start_batch_conversion(
		selected_sizes,
		custom_output_directory
	)
	
func _start_selected_conversion(
	selected_sizes: Array[int],
	output_directory: String
) -> void:
	var options: ConversionOptions = (
		_create_base_conversion_options(selected_sizes)
	)

	options.output_directory = output_directory

	convert_button.disabled = true
	convert_button.text = "Converting..."

	app_controller.convert_selected(options)
	
func _start_batch_conversion(
	selected_sizes: Array[int],
	output_directory: String
) -> void:
	var options: ConversionOptions = (
		_create_base_conversion_options(selected_sizes)
	)

	options.output_directory = output_directory

	await app_controller.convert_all(options)

func _request_output_directory_for_conversion(
	conversion_kind: int,
	selected_sizes: Array[int]
) -> void:
	if conversion_kind == PendingConversionKind.NONE:
		return

	pending_conversion_kind = conversion_kind

	pending_conversion_sizes = (
		selected_sizes.duplicate()
	)

	var initial_directory: String = custom_output_directory

	if initial_directory.is_empty():
		initial_directory = last_output_directory

	if not initial_directory.is_empty():
		if DirAccess.dir_exists_absolute(initial_directory):
			output_directory_dialog.current_dir = (
				initial_directory
			)

	if conversion_kind == PendingConversionKind.SINGLE:
		output_directory_dialog.title = (
			"Choose Output Folder for Selected File"
		)
	else:
		output_directory_dialog.title = (
			"Choose Output Folder for Batch Conversion"
		)

	preview_info_label.text = "Choose output folder"
	image_meta_label.text = (
		"Select a folder to continue the conversion."
	)

	_update_convert_button_state()

	output_directory_dialog.popup_centered_ratio(0.75)
	
func _clear_pending_output_directory_request() -> void:
	pending_conversion_kind = PendingConversionKind.NONE
	pending_conversion_sizes.clear()
	
func _is_waiting_for_output_directory() -> bool:
	return pending_conversion_kind != (
		PendingConversionKind.NONE
	)

func _create_base_conversion_options(selected_sizes: Array[int]) -> ConversionOptions:
	var options: ConversionOptions = ConversionOptions.new()

	# ConversionOptions contains default sizes.
	# For a UI-driven conversion, only the currently
	# selected sizes may be used.
	options.icon_sizes.clear()

	for icon_size: int in selected_sizes:
		options.icon_sizes.append(icon_size)

	options.fit_mode = _get_selected_fit_mode()
	options.scaling_mode = _get_selected_scaling_mode()
	options.background_mode = _get_selected_background_mode()
	options.background_color = _get_selected_background_color()
	options.output_directory = custom_output_directory

	options.collision_policy = collision_policy

	return options

func _get_preset_index_from_id(
	preset_id: String
) -> int:
	match preset_id:
		SettingsService.PRESET_SMALL:
			return SIZE_PRESET_SMALL

		SettingsService.PRESET_HIGH_RESOLUTION:
			return SIZE_PRESET_HIGH_RESOLUTION

		SettingsService.PRESET_CUSTOM:
			return SIZE_PRESET_CUSTOM

		_:
			return SIZE_PRESET_WINDOWS_STANDARD
			
func _get_fit_mode_index_from_id(
	fit_mode: String
) -> int:
	match fit_mode:
		ConversionOptions.FIT_CENTER_CROP:
			return FIT_MODE_CENTER_CROP_INDEX

		ConversionOptions.FIT_STRETCH:
			return FIT_MODE_STRETCH_INDEX

		_:
			return FIT_MODE_CONTAIN_INDEX
			
func _get_scaling_mode_index_from_id(
	scaling_mode: String
) -> int:
	if scaling_mode == ConversionOptions.SCALING_PIXEL_PERFECT:
		return SCALING_MODE_PIXEL_PERFECT_INDEX

	return SCALING_MODE_SMOOTH_INDEX
	
func _get_background_mode_index_from_id(
	background_mode: String
) -> int:
	if background_mode == ConversionOptions.BACKGROUND_SOLID_COLOR:
		return BACKGROUND_MODE_SOLID_COLOR_INDEX

	return BACKGROUND_MODE_TRANSPARENT_INDEX
	
func _apply_custom_icon_sizes(
	selected_sizes: Array[int]
) -> void:
	is_applying_size_preset = true

	size_16.set_pressed_no_signal(
		selected_sizes.has(16)
	)

	size_24.set_pressed_no_signal(
		selected_sizes.has(24)
	)

	size_32.set_pressed_no_signal(
		selected_sizes.has(32)
	)

	size_48.set_pressed_no_signal(
		selected_sizes.has(48)
	)

	size_64.set_pressed_no_signal(
		selected_sizes.has(64)
	)

	size_128.set_pressed_no_signal(
		selected_sizes.has(128)
	)

	size_256.set_pressed_no_signal(
		selected_sizes.has(256)
	)

	is_applying_size_preset = false

	_update_convert_button_state()	
	
func _on_icon_size_toggled(
	_pressed: bool
) -> void:
	if not is_applying_size_preset:
		size_preset_option.select(
			SIZE_PRESET_CUSTOM
		)

	_update_convert_button_state()
	
func _on_size_preset_selected(
	preset_index: int
) -> void:
	if preset_index == SIZE_PRESET_CUSTOM:
		return

	_apply_size_preset(preset_index)
	
func _apply_size_preset(
	preset_index: int
) -> void:
	var preset_sizes: Array[int] = []

	match preset_index:
		SIZE_PRESET_WINDOWS_STANDARD:
			preset_sizes = [16, 32, 48, 256]

		SIZE_PRESET_SMALL:
			preset_sizes = [16, 24, 32, 48]

		SIZE_PRESET_HIGH_RESOLUTION:
			preset_sizes = [64, 128, 256]

		_:
			return

	is_applying_size_preset = true

	size_16.set_pressed_no_signal(
		preset_sizes.has(16)
	)

	size_24.set_pressed_no_signal(
		preset_sizes.has(24)
	)

	size_32.set_pressed_no_signal(
		preset_sizes.has(32)
	)
	size_48.set_pressed_no_signal(
			preset_sizes.has(48)
		)

	size_64.set_pressed_no_signal(
		preset_sizes.has(64)
	)

	size_128.set_pressed_no_signal(
		preset_sizes.has(128)
	)

	size_256.set_pressed_no_signal(
		preset_sizes.has(256)
	)

	is_applying_size_preset = false

	_update_convert_button_state()
	
func _on_fit_mode_selected(
	_selected_index: int
) -> void:
	pass
	
func _on_scaling_mode_selected(
	_selected_index: int
) -> void:
	pass
	
func _on_background_mode_selected(
	_selected_index: int
) -> void:
	_update_background_color_picker_state()
	
func _update_background_color_picker_state() -> void:
	var uses_solid_color: bool = (
		background_mode_option.selected
		== BACKGROUND_MODE_SOLID_COLOR_INDEX
	)

	background_color_picker.disabled = not uses_solid_color
	
func _get_selected_fit_mode() -> String:
	match fit_mode_option.selected:
		FIT_MODE_CENTER_CROP_INDEX:
			return ConversionOptions.FIT_CENTER_CROP

		FIT_MODE_STRETCH_INDEX:
			return ConversionOptions.FIT_STRETCH

		_:
			return ConversionOptions.FIT_CONTAIN
			
func _get_selected_scaling_mode() -> String:
	if scaling_mode_option.selected == (
		SCALING_MODE_PIXEL_PERFECT_INDEX
	):
		return ConversionOptions.SCALING_PIXEL_PERFECT

	return ConversionOptions.SCALING_SMOOTH
	
func _get_selected_background_mode() -> String:
	if background_mode_option.selected == (
		BACKGROUND_MODE_SOLID_COLOR_INDEX
	):
		return ConversionOptions.BACKGROUND_SOLID_COLOR

	return ConversionOptions.BACKGROUND_TRANSPARENT
	
func _get_selected_background_color() -> Color:
	var selected_color: Color = background_color_picker.color

	# For Figulumico, "Solid Color" means an opaque fill color.
	selected_color.a = 1.0

	return selected_color

func _on_choose_output_directory_button_pressed() -> void:
	if app_controller.is_batch_running():
		return

	if _is_waiting_for_output_directory():
		return

	var initial_directory: String = custom_output_directory

	if initial_directory.is_empty():
		initial_directory = last_output_directory

	if not initial_directory.is_empty():
		if DirAccess.dir_exists_absolute(initial_directory):
			output_directory_dialog.current_dir = (
				initial_directory
			)

	output_directory_dialog.popup_centered_ratio(0.75)
	
func _on_use_source_output_button_pressed() -> void:
	if app_controller.is_batch_running():
		return

	if _is_waiting_for_output_directory():
		return

	custom_output_directory = ""

	_update_output_directory_display()
	
func _on_output_directory_selected(
	directory_path: String
) -> void:
	var clean_directory_path: String = (
		directory_path.strip_edges()
	)

	if clean_directory_path.is_empty():
		return

	if not DirAccess.dir_exists_absolute(clean_directory_path):
		preview_info_label.text = "Output folder issue"
		image_meta_label.text = (
			"✕ The selected output folder could not be found."
		)

		_clear_pending_output_directory_request()
		_update_convert_button_state()
		return

	# Ask-for-output-flow:
	# The selected folder applies only to the currently requested export.
	if _is_waiting_for_output_directory():
		var selected_sizes: Array[int] = (
			pending_conversion_sizes.duplicate()
		)

		var conversion_kind: int = pending_conversion_kind

		# Remember the last folder used, but do not change the visible
		# default output folder.
		last_output_directory = clean_directory_path

		_clear_pending_output_directory_request()

		if conversion_kind == PendingConversionKind.SINGLE:
			_start_selected_conversion(
				selected_sizes,
				clean_directory_path
			)
			return

		if conversion_kind == PendingConversionKind.BATCH:
			await _start_batch_conversion(
				selected_sizes,
				clean_directory_path
			)
			return

		return


	# Standard manual selection via "Choose Folder":
	# The folder is adopted as the active UI output folder.
	custom_output_directory = clean_directory_path
	last_output_directory = clean_directory_path

	_update_output_directory_display()

	preview_info_label.text = "Output folder selected"
	image_meta_label.text = (
		"✓ ICO files will be exported to: "
		+ custom_output_directory
	)

func _on_output_directory_dialog_canceled() -> void:
	if not _is_waiting_for_output_directory():
		return

	_clear_pending_output_directory_request()

	preview_info_label.text = "Conversion canceled"
	image_meta_label.text = (
		"Output folder selection was canceled."
	)

	_update_convert_button_state()
	
func _update_output_directory_display() -> void:
	if custom_output_directory.is_empty():
		output_directory_label.text = (
			"Source folder / converted"
		)

		output_directory_label.tooltip_text = (
			"Each ICO is exported into a converted folder "
			+ "next to its source image."
		)

		use_source_output_button.disabled = true
		return

	output_directory_label.text = custom_output_directory
	output_directory_label.tooltip_text = custom_output_directory

	use_source_output_button.disabled = false

func _on_settings_button_pressed() -> void:
	if app_controller.is_batch_running():
		return

	_copy_main_controls_to_settings_dialog()

	settings_dialog.popup_centered()

func _on_about_button_pressed() -> void:
	if app_controller.is_batch_running():
		return

	about_dialog.popup_centered()
	
func _copy_main_controls_to_settings_dialog() -> void:
	settings_dialog_output_directory = custom_output_directory

	settings_dialog_icon_sizes = (
		_get_selected_icon_sizes()
	)

	settings_output_directory_label.text = (
		_get_settings_output_directory_display_text()
	)

	settings_output_directory_label.tooltip_text = (
		_get_settings_output_directory_tooltip()
	)

	settings_ask_output_checkbox.button_pressed = (
		ask_for_output_directory
	)

	settings_size_preset_option.select(
		size_preset_option.selected
	)

	settings_fit_mode_option.select(
		fit_mode_option.selected
	)

	settings_scaling_mode_option.select(
		scaling_mode_option.selected
	)

	settings_background_mode_option.select(
		background_mode_option.selected
	)

	settings_background_color_picker.color = (
		background_color_picker.color
	)

	settings_collision_policy_option.select(
		_get_collision_policy_index(
			collision_policy
		)
	)

	_update_settings_background_color_picker_state()
	
func _on_settings_dialog_confirmed() -> void:
	var settings: Dictionary = (
		_build_settings_from_dialog()
	)

	if not settings_service.save_settings(settings):
		preview_info_label.text = "Could not save settings"
		image_meta_label.text = (
			"✕ " + settings_service.last_error
		)
		return

	_apply_settings_to_controls(settings)

	settings_dialog.hide()

	preview_info_label.text = "Settings saved"
	image_meta_label.text = (
		"✓ Settings will be used after the next application start."
	)
	
func _build_settings_from_dialog() -> Dictionary:
	var selected_color: Color = (
		settings_background_color_picker.color
	)

	selected_color.a = 1.0

	return {
		"default_output_directory": (
			settings_dialog_output_directory
		),
		"last_output_directory": (
			last_output_directory
		),
		"ask_for_output_directory": (
			settings_ask_output_checkbox.button_pressed
		),
		"size_preset": (
			_get_preset_id_from_index(
				settings_size_preset_option.selected
			)
		),
		"icon_sizes": settings_dialog_icon_sizes,
		"fit_mode": (
			_get_fit_mode_from_index(
				settings_fit_mode_option.selected
			)
		),
		"scaling_mode": (
			_get_scaling_mode_from_index(
				settings_scaling_mode_option.selected
			)
		),
		"background_mode": (
			_get_background_mode_from_index(
				settings_background_mode_option.selected
			)
		),
		"background_color": {
			"r": selected_color.r,
			"g": selected_color.g,
			"b": selected_color.b,
			"a": selected_color.a
		},
		"collision_policy": (
			_get_collision_policy_from_index(
				settings_collision_policy_option.selected
			)
		)
	}
	
func _on_settings_choose_output_button_pressed() -> void:
	var initial_directory: String = (
		settings_dialog_output_directory
	)

	if initial_directory.is_empty():
		initial_directory = last_output_directory

	if not initial_directory.is_empty():
		if DirAccess.dir_exists_absolute(initial_directory):
			settings_output_directory_dialog.current_dir = (
				initial_directory
			)

	settings_output_directory_dialog.popup_centered_ratio(0.75)
	
func _on_settings_use_source_output_button_pressed() -> void:
	settings_dialog_output_directory = ""

	settings_output_directory_label.text = (
		_get_settings_output_directory_display_text()
	)

	settings_output_directory_label.tooltip_text = (
		_get_settings_output_directory_tooltip()
	)
	
func _on_settings_output_directory_selected(
	directory_path: String
) -> void:
	var clean_directory_path: String = (
		directory_path.strip_edges()
	)

	if clean_directory_path.is_empty():
		return

	if not DirAccess.dir_exists_absolute(clean_directory_path):
		return

	settings_dialog_output_directory = clean_directory_path
	last_output_directory = clean_directory_path

	settings_output_directory_label.text = (
		_get_settings_output_directory_display_text()
	)

	settings_output_directory_label.tooltip_text = (
		_get_settings_output_directory_tooltip()
	)
	
func _on_settings_size_preset_selected(
	preset_index: int
) -> void:
	if preset_index == SIZE_PRESET_CUSTOM:
		return

	settings_dialog_icon_sizes = (
		_get_icon_sizes_for_preset(preset_index)
	)
	
func _on_settings_background_mode_selected(
	_selected_index: int
) -> void:
	_update_settings_background_color_picker_state()
	
func _update_settings_background_color_picker_state() -> void:
	settings_background_color_picker.disabled = (
		settings_background_mode_option.selected
		!= BACKGROUND_MODE_SOLID_COLOR_INDEX
	)
	
func _get_settings_output_directory_display_text() -> String:
	if settings_dialog_output_directory.is_empty():
		return "Source folder / converted"

	return settings_dialog_output_directory
	
func _get_settings_output_directory_tooltip() -> String:
	if settings_dialog_output_directory.is_empty():
		return (
			"Each ICO will be exported to a converted folder "
			+ "next to its source image."
		)

	return settings_dialog_output_directory
	
func _get_icon_sizes_for_preset(
	preset_index: int
) -> Array[int]:
	match preset_index:
		SIZE_PRESET_SMALL:
			return [16, 24, 32, 48]

		SIZE_PRESET_HIGH_RESOLUTION:
			return [64, 128, 256]

		_:
			return [16, 32, 48, 256]
			
func _get_preset_id_from_index(
	preset_index: int
) -> String:
	match preset_index:
		SIZE_PRESET_SMALL:
			return SettingsService.PRESET_SMALL

		SIZE_PRESET_HIGH_RESOLUTION:
			return SettingsService.PRESET_HIGH_RESOLUTION

		SIZE_PRESET_CUSTOM:
			return SettingsService.PRESET_CUSTOM

		_:
			return SettingsService.PRESET_WINDOWS_STANDARD
			
func _get_fit_mode_from_index(
	selected_index: int
) -> String:
	match selected_index:
		FIT_MODE_CENTER_CROP_INDEX:
			return ConversionOptions.FIT_CENTER_CROP

		FIT_MODE_STRETCH_INDEX:
			return ConversionOptions.FIT_STRETCH

		_:
			return ConversionOptions.FIT_CONTAIN
			
func _get_scaling_mode_from_index(
	selected_index: int
) -> String:
	if selected_index == SCALING_MODE_PIXEL_PERFECT_INDEX:
		return ConversionOptions.SCALING_PIXEL_PERFECT

	return ConversionOptions.SCALING_SMOOTH
	
func _get_background_mode_from_index(
	selected_index: int
) -> String:
	if selected_index == BACKGROUND_MODE_SOLID_COLOR_INDEX:
		return ConversionOptions.BACKGROUND_SOLID_COLOR

	return ConversionOptions.BACKGROUND_TRANSPARENT
	
func _get_collision_policy_index(
	policy: String
) -> int:
	match policy:
		ConversionOptions.COLLISION_OVERWRITE:
			return 1

		ConversionOptions.COLLISION_SKIP:
			return 2

		_:
			return 0
			
func _get_collision_policy_from_index(
	selected_index: int
) -> String:
	match selected_index:
		1:
			return ConversionOptions.COLLISION_OVERWRITE

		2:
			return ConversionOptions.COLLISION_SKIP

		_:
			return ConversionOptions.COLLISION_AUTO_NUMBER

func _set_export_option_controls_disabled(
	disabled: bool
) -> void:
	size_16.disabled = disabled
	size_24.disabled = disabled
	size_32.disabled = disabled
	size_48.disabled = disabled
	size_64.disabled = disabled
	size_128.disabled = disabled
	size_256.disabled = disabled

	size_preset_option.disabled = disabled
	fit_mode_option.disabled = disabled
	scaling_mode_option.disabled = disabled
	background_mode_option.disabled = disabled

	background_color_picker.disabled = (
		disabled
		or background_mode_option.selected
		!= BACKGROUND_MODE_SOLID_COLOR_INDEX
	)

	choose_output_directory_button.disabled = disabled

	if custom_output_directory.is_empty():
		use_source_output_button.disabled = true
	else:
		use_source_output_button.disabled = disabled
		
	settings_button.disabled = disabled

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
	var is_waiting_for_output_directory: bool = (
		_is_waiting_for_output_directory()
	)

	# Single conversion:
	# Active only when a file is selected.
	convert_button.disabled = not (
		has_selected_file
		and has_selected_sizes
		and not is_batch_running
		and not is_waiting_for_output_directory
	)

	convert_button.text = "Convert Selected File"

	# Batch:
	# Only makes sense with two or more files.
	batch_convert_button.disabled = not (
		queue_count >= 2
		and has_selected_sizes
		and not is_batch_running
		and not is_waiting_for_output_directory
	)

	batch_convert_button.text = (
		"Batch Convert All (%d)" % queue_count
	)
	
	_set_export_option_controls_disabled(
		is_batch_running
		or is_waiting_for_output_directory
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


func _unhandled_key_input(
	event: InputEvent
) -> void:
	if not (event is InputEventKey):
		return

	var key_event: InputEventKey = event

	if not key_event.pressed:
		return

	if key_event.echo:
		return

	if key_event.keycode != KEY_ESCAPE:
		return


	# The application must not be accidentally closed
	# during a batch conversion.
	if app_controller.is_batch_running():
		return

	# Open dialogs should first be closed or cancelled via ESC.
	if image_file_dialog.visible:
		return

	if output_directory_dialog.visible:
		return

	if settings_dialog.visible:
		return

	if settings_output_directory_dialog.visible:
		return

	if batch_results_dialog.visible:
		return
		
	if about_dialog.visible:
		return

	get_tree().quit()

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
