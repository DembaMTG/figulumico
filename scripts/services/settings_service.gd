extends RefCounted
class_name SettingsService

# ==============================================================
# SettingsService
# ==============================================================
#
# Verantwortung:
# ✅ Lädt lokale Anwendungseinstellungen aus user://settings.json
# ✅ Speichert Einstellungen als JSON
# ✅ Liefert bei fehlender oder fehlerhafter Datei sichere Defaults
# ✅ Validiert gespeicherte Werte defensiv
#
# ❌ Kennt keine UI-Nodes
# ❌ Öffnet keine Dialoge
# ❌ Führt keine Konvertierung aus
# ❌ Kennt keine Queue
#
# ==============================================================


const SETTINGS_PATH: String = "user://settings.json"

const PRESET_WINDOWS_STANDARD: String = "windows_standard"
const PRESET_SMALL: String = "small"
const PRESET_HIGH_RESOLUTION: String = "high_resolution"
const PRESET_CUSTOM: String = "custom"


var last_warning: String = ""
var last_error: String = ""


# --------------------------------------------------------------
# Public API
# --------------------------------------------------------------

func get_default_settings() -> Dictionary:
	return {
		"default_output_directory": "",
		"last_output_directory": "",
		"ask_for_output_directory": false,
		"size_preset": PRESET_WINDOWS_STANDARD,
		"icon_sizes": [16, 32, 48, 256],
		"fit_mode": ConversionOptions.FIT_CONTAIN,
		"scaling_mode": ConversionOptions.SCALING_SMOOTH,
		"background_mode": ConversionOptions.BACKGROUND_TRANSPARENT,
		"background_color": _color_to_dictionary(Color.WHITE),
		"collision_policy": ConversionOptions.COLLISION_AUTO_NUMBER
	}


func load_settings() -> Dictionary:
	last_warning = ""
	last_error = ""

	var default_settings: Dictionary = get_default_settings()

	if not FileAccess.file_exists(SETTINGS_PATH):
		return default_settings

	var settings_file: FileAccess = FileAccess.open(
		SETTINGS_PATH,
		FileAccess.READ
	)

	if settings_file == null:
		last_warning = (
			"Could not open saved settings. Default settings were used."
		)
		return default_settings

	var json_text: String = settings_file.get_as_text()

	settings_file.close()

	if json_text.strip_edges().is_empty():
		last_warning = (
			"Saved settings were empty. Default settings were used."
		)
		return default_settings

	var json: JSON = JSON.new()

	var parse_error: Error = json.parse(json_text)

	if parse_error != OK:
		last_warning = (
			"Saved settings were invalid. Default settings were used."
		)
		return default_settings

	var parsed_data: Variant = json.data

	if not (parsed_data is Dictionary):
		last_warning = (
			"Saved settings had an invalid format. Default settings were used."
		)
		return default_settings

	var raw_settings: Dictionary = parsed_data

	return _normalize_settings(raw_settings)


func save_settings(
	settings: Dictionary
) -> bool:
	last_error = ""

	var normalized_settings: Dictionary = (
		_normalize_settings(settings)
	)

	var json_text: String = JSON.stringify(
		normalized_settings,
		"\t"
	)

	var settings_file: FileAccess = FileAccess.open(
		SETTINGS_PATH,
		FileAccess.WRITE
	)

	if settings_file == null:
		last_error = (
			"Could not write settings file: "
			+ SETTINGS_PATH
		)
		return false

	settings_file.store_string(json_text)
	settings_file.close()

	return true


func get_background_color(
	settings: Dictionary
) -> Color:
	var color_value: Variant = settings.get(
		"background_color",
		_color_to_dictionary(Color.WHITE)
	)

	if not (color_value is Dictionary):
		return Color.WHITE

	var color_data: Dictionary = color_value

	var red: float = float(color_data.get("r", 1.0))
	var green: float = float(color_data.get("g", 1.0))
	var blue: float = float(color_data.get("b", 1.0))
	var alpha: float = float(color_data.get("a", 1.0))

	return Color(
		clampf(red, 0.0, 1.0),
		clampf(green, 0.0, 1.0),
		clampf(blue, 0.0, 1.0),
		clampf(alpha, 0.0, 1.0)
	)


# --------------------------------------------------------------
# Validation and normalization
# --------------------------------------------------------------

func _normalize_settings(
	raw_settings: Dictionary
) -> Dictionary:
	var settings: Dictionary = get_default_settings()

	var default_output_value: Variant = raw_settings.get(
		"default_output_directory",
		""
	)

	if default_output_value is String:
		settings["default_output_directory"] = (
			str(default_output_value).strip_edges()
		)

	var last_output_value: Variant = raw_settings.get(
		"last_output_directory",
		""
	)

	if last_output_value is String:
		settings["last_output_directory"] = (
			str(last_output_value).strip_edges()
		)

	var ask_output_value: Variant = raw_settings.get(
		"ask_for_output_directory",
		false
	)

	if ask_output_value is bool:
		settings["ask_for_output_directory"] = ask_output_value

	var preset_value: Variant = raw_settings.get(
		"size_preset",
		PRESET_WINDOWS_STANDARD
	)

	if preset_value is String:
		var preset_id: String = str(preset_value)

		if _is_valid_preset_id(preset_id):
			settings["size_preset"] = preset_id

	var sizes_value: Variant = raw_settings.get(
		"icon_sizes",
		[]
	)

	if sizes_value is Array:
		var sanitized_sizes: Array[int] = (
			_sanitize_icon_sizes(sizes_value)
		)

		if not sanitized_sizes.is_empty():
			settings["icon_sizes"] = sanitized_sizes

	var fit_mode_value: Variant = raw_settings.get(
		"fit_mode",
		ConversionOptions.FIT_CONTAIN
	)

	if fit_mode_value is String:
		var fit_mode: String = str(fit_mode_value)

		if _is_valid_fit_mode(fit_mode):
			settings["fit_mode"] = fit_mode

	var scaling_mode_value: Variant = raw_settings.get(
		"scaling_mode",
		ConversionOptions.SCALING_SMOOTH
	)

	if scaling_mode_value is String:
		var scaling_mode: String = str(scaling_mode_value)

		if _is_valid_scaling_mode(scaling_mode):
			settings["scaling_mode"] = scaling_mode

	var background_mode_value: Variant = raw_settings.get(
		"background_mode",
		ConversionOptions.BACKGROUND_TRANSPARENT
	)

	if background_mode_value is String:
		var background_mode: String = str(background_mode_value)

		if _is_valid_background_mode(background_mode):
			settings["background_mode"] = background_mode

	var background_color_value: Variant = raw_settings.get(
		"background_color",
		_color_to_dictionary(Color.WHITE)
	)

	if background_color_value is Dictionary:
		var background_color: Color = get_background_color(
			{
				"background_color": background_color_value
			}
		)

		settings["background_color"] = _color_to_dictionary(
			background_color
		)

	var collision_policy_value: Variant = raw_settings.get(
		"collision_policy",
		ConversionOptions.COLLISION_AUTO_NUMBER
	)

	if collision_policy_value is String:
		var collision_policy: String = str(collision_policy_value)

		if collision_policy == ConversionOptions.COLLISION_ASK:
			settings["collision_policy"] = (
				ConversionOptions.COLLISION_AUTO_NUMBER
			)
		elif _is_valid_collision_policy(collision_policy):
			settings["collision_policy"] = collision_policy

	return settings


func _sanitize_icon_sizes(
	raw_sizes: Array
) -> Array[int]:
	var sizes: Array[int] = []
	var seen_sizes: Dictionary = {}

	for raw_size: Variant in raw_sizes:
		if not (raw_size is int or raw_size is float):
			continue

		var icon_size: int = int(raw_size)

		if not _is_supported_icon_size(icon_size):
			continue

		if seen_sizes.has(icon_size):
			continue

		seen_sizes[icon_size] = true
		sizes.append(icon_size)

	sizes.sort()

	return sizes


func _is_supported_icon_size(
	icon_size: int
) -> bool:
	return icon_size == 16 \
		or icon_size == 24 \
		or icon_size == 32 \
		or icon_size == 48 \
		or icon_size == 64 \
		or icon_size == 128 \
		or icon_size == 256


func _is_valid_preset_id(
	preset_id: String
) -> bool:
	return preset_id == PRESET_WINDOWS_STANDARD \
		or preset_id == PRESET_SMALL \
		or preset_id == PRESET_HIGH_RESOLUTION \
		or preset_id == PRESET_CUSTOM


func _is_valid_fit_mode(
	fit_mode: String
) -> bool:
	return fit_mode == ConversionOptions.FIT_CONTAIN \
		or fit_mode == ConversionOptions.FIT_CENTER_CROP \
		or fit_mode == ConversionOptions.FIT_STRETCH


func _is_valid_scaling_mode(
	scaling_mode: String
) -> bool:
	return scaling_mode == ConversionOptions.SCALING_SMOOTH \
		or scaling_mode == ConversionOptions.SCALING_PIXEL_PERFECT


func _is_valid_background_mode(
	background_mode: String
) -> bool:
	return background_mode == ConversionOptions.BACKGROUND_TRANSPARENT \
		or background_mode == ConversionOptions.BACKGROUND_SOLID_COLOR


func _is_valid_collision_policy(
	collision_policy: String
) -> bool:
	return collision_policy == ConversionOptions.COLLISION_ASK \
		or collision_policy == ConversionOptions.COLLISION_AUTO_NUMBER \
		or collision_policy == ConversionOptions.COLLISION_OVERWRITE \
		or collision_policy == ConversionOptions.COLLISION_SKIP


func _color_to_dictionary(
	color: Color
) -> Dictionary:
	return {
		"r": color.r,
		"g": color.g,
		"b": color.b,
		"a": color.a
	}
