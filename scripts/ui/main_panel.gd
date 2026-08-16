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


var queue_items_by_id: Dictionary = {}
var selected_queue_file_id := ""
var last_batch_result: BatchResult = null
var is_applying_size_preset: bool = false
var custom_output_directory: String = ""
var last_output_directory: String = ""
var settings_service: SettingsService = (SettingsService.new())


func _ready() -> void:
	_configure_file_dialog()
	_configure_output_directory_dialog()
	_configure_export_option_controls()
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

func _apply_settings_to_controls(
	settings: Dictionary
) -> void:
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

	options.fit_mode = _get_selected_fit_mode()
	options.scaling_mode = _get_selected_scaling_mode()
	options.background_mode = _get_selected_background_mode()
	options.background_color = _get_selected_background_color()
	options.output_directory = custom_output_directory

	options.collision_policy = (ConversionOptions.COLLISION_AUTO_NUMBER)

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

	# Solid Color bedeutet für Iconify Wizard deckende Auffüllfarbe.
	selected_color.a = 1.0

	return selected_color

func _on_choose_output_directory_button_pressed() -> void:
	if app_controller.is_batch_running():
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
		return

	custom_output_directory = clean_directory_path
	last_output_directory = clean_directory_path

	_update_output_directory_display()

	preview_info_label.text = "Output folder selected"
	image_meta_label.text = (
		"✓ ICO files will be exported to: "
		+ custom_output_directory
	)
	
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
	
	_set_export_option_controls_disabled(
		is_batch_running
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
