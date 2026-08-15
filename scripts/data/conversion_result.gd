extends RefCounted
class_name ConversionResult

# ==============================================================
# ConversionResult
# ==============================================================
#
# Verantwortung:
# ✅ Beschreibt das Ergebnis einer einzelnen ICO-Konvertierung
# ✅ Speichert Erfolg, Fehler, Warnings und Zielpfad
# ✅ Enthält Statusinformationen für Queue und Batch-Auswertung
#
# ❌ Kennt keine UI-Nodes
# ❌ Öffnet keine Dialoge
# ❌ Schreibt keine Dateien
# ❌ Lädt keine Bilder
#
# ==============================================================


# --------------------------------------------------------------
# Status identifiers
# --------------------------------------------------------------

const STATUS_READY := "ready"
const STATUS_PROCESSING := "processing"
const STATUS_CONVERTED := "converted"
const STATUS_WARNING := "warning"
const STATUS_FAILED := "failed"
const STATUS_SKIPPED := "skipped"


# --------------------------------------------------------------
# Result data
# --------------------------------------------------------------

var success: bool = false

var source_path: String = ""
var output_path: String = ""

var selected_sizes: Array[int] = []

var warnings: Array[String] = []
var error_message: String = ""

var status: String = STATUS_READY


# --------------------------------------------------------------
# Public API
# --------------------------------------------------------------

func mark_processing() -> void:
	success = false
	error_message = ""
	status = STATUS_PROCESSING


func mark_success(new_output_path: String) -> void:
	success = true
	output_path = new_output_path
	error_message = ""

	if warnings.is_empty():
		status = STATUS_CONVERTED
	else:
		status = STATUS_WARNING


func mark_failed(message: String) -> void:
	success = false
	error_message = message.strip_edges()
	status = STATUS_FAILED


func mark_skipped(message: String = "") -> void:
	success = false
	error_message = message.strip_edges()
	status = STATUS_SKIPPED


func add_warning(message: String) -> void:
	var clean_message : String = message.strip_edges()

	if clean_message.is_empty():
		return

	if clean_message not in warnings:
		warnings.append(clean_message)

	if success:
		status = STATUS_WARNING


func has_warnings() -> bool:
	return not warnings.is_empty()


func is_failed() -> bool:
	return status == STATUS_FAILED


func is_skipped() -> bool:
	return status == STATUS_SKIPPED


func get_summary() -> String:
	if status == STATUS_CONVERTED:
		return "Conversion completed successfully."

	if status == STATUS_WARNING:
		return "Conversion completed with warnings."

	if status == STATUS_FAILED:
		return "Conversion failed: " + error_message

	if status == STATUS_SKIPPED:
		return "Conversion skipped: " + error_message

	if status == STATUS_PROCESSING:
		return "Conversion is processing."

	return "Conversion is ready."
