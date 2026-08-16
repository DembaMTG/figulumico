extends RefCounted
class_name ConversionOptions

# ==============================================================
# ConversionOptions
# ==============================================================
#
# Verantwortung:
# ✅ Beschreibt einen einzelnen ICO-Konvertierungsauftrag
# ✅ Speichert Quellbild, Zielpfad und Exportoptionen
# ✅ Liefert einfache Validierungsfehler für den Auftrag
#
# ❌ Kennt keine UI-Nodes
# ❌ Öffnet keine FileDialogs
# ❌ Lädt keine Bilder
# ❌ Skaliert keine Bilder
# ❌ Schreibt keine ICO-Dateien
#
# ==============================================================


# --------------------------------------------------------------
# Option identifiers
# --------------------------------------------------------------

const FIT_CONTAIN := "contain"
const FIT_CENTER_CROP := "center_crop"
const FIT_STRETCH := "stretch"

const SCALING_SMOOTH := "smooth"
const SCALING_PIXEL_PERFECT := "pixel_perfect"

const BACKGROUND_TRANSPARENT := "transparent"
const BACKGROUND_SOLID_COLOR := "solid_color"

const COLLISION_ASK := "ask"
const COLLISION_AUTO_NUMBER := "auto_number"
const COLLISION_OVERWRITE := "overwrite"
const COLLISION_SKIP := "skip"


# --------------------------------------------------------------
# Source and output
# --------------------------------------------------------------

var source_path: String = ""

var output_directory: String = ""
var output_filename: String = ""


# --------------------------------------------------------------
# ICO options
# --------------------------------------------------------------

var icon_sizes: Array[int] = [
	16,
	32,
	48,
	256
]

var fit_mode: String = FIT_CONTAIN
var scaling_mode: String = SCALING_SMOOTH

var background_mode: String = BACKGROUND_TRANSPARENT
var background_color: Color = Color.TRANSPARENT

var collision_policy: String = COLLISION_AUTO_NUMBER


# --------------------------------------------------------------
# Public API
# --------------------------------------------------------------

func get_output_path() -> String:
	if output_directory.is_empty():
		return ""

	if output_filename.is_empty():
		return ""

	var filename : String = output_filename

	if filename.get_extension().to_lower() != "ico":
		filename += ".ico"

	return output_directory.path_join(filename)


func get_validation_errors() -> Array[String]:
	var errors: Array[String] = []

	if source_path.strip_edges().is_empty():
		errors.append("No source image was selected.")

	if icon_sizes.is_empty():
		errors.append("Select at least one icon size.")

	var seen_sizes: Dictionary = {}

	for icon_size: int in icon_sizes:
		if seen_sizes.has(icon_size):
			errors.append(
				"Duplicate icon size detected: %d px." % icon_size
			)
			break

		seen_sizes[icon_size] = true

		if icon_size <= 0:
			errors.append("Icon sizes must be greater than zero.")
			break

		if icon_size > 256:
			errors.append(
				"Icon sizes above 256 pixels are not supported in v0.1.0."
			)
			break

	if not _is_valid_fit_mode(fit_mode):
		errors.append("Invalid image fit mode: " + fit_mode)

	if not _is_valid_scaling_mode(scaling_mode):
		errors.append("Invalid scaling mode: " + scaling_mode)

	if not _is_valid_background_mode(background_mode):
		errors.append("Invalid background mode: " + background_mode)

	if not _is_valid_collision_policy(collision_policy):
		errors.append("Invalid collision policy: " + collision_policy)

	return errors


func is_valid() -> bool:
	return get_validation_errors().is_empty()


# --------------------------------------------------------------
# Internal validation
# --------------------------------------------------------------

func _is_valid_fit_mode(value: String) -> bool:
	return value == FIT_CONTAIN \
		or value == FIT_CENTER_CROP \
		or value == FIT_STRETCH


func _is_valid_scaling_mode(value: String) -> bool:
	return value == SCALING_SMOOTH \
		or value == SCALING_PIXEL_PERFECT


func _is_valid_background_mode(value: String) -> bool:
	return value == BACKGROUND_TRANSPARENT \
		or value == BACKGROUND_SOLID_COLOR


func _is_valid_collision_policy(value: String) -> bool:
	return value == COLLISION_ASK \
		or value == COLLISION_AUTO_NUMBER \
		or value == COLLISION_OVERWRITE \
		or value == COLLISION_SKIP
