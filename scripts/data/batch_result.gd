extends RefCounted
class_name BatchResult

# ==============================================================
# BatchResult
# ==============================================================
#
# Verantwortung:
# ✅ Speichert das Ergebnis eines vollständigen Batch-Laufs
# ✅ Enthält alle Einzel-ConversionResults
# ✅ Zählt erfolgreiche, fehlerhafte und übersprungene Dateien
#
# ❌ Kennt keine UI-Nodes
# ❌ Öffnet keine Dialoge
# ❌ Führt keine Konvertierung aus
# ❌ Ändert keine Queue-Einträge direkt
#
# ==============================================================


# --------------------------------------------------------------
# Batch data
# --------------------------------------------------------------

var total_count: int = 0
var success_count: int = 0
var warning_count: int = 0
var failed_count: int = 0
var skipped_count: int = 0

var results: Array[ConversionResult] = []


# --------------------------------------------------------------
# Public API
# --------------------------------------------------------------

func add_result(
	result: ConversionResult
) -> void:
	if result == null:
		return

	results.append(result)
	total_count += 1

	match result.status:
		ConversionResult.STATUS_CONVERTED:
			success_count += 1

		ConversionResult.STATUS_WARNING:
			success_count += 1
			warning_count += 1

		ConversionResult.STATUS_FAILED:
			failed_count += 1

		ConversionResult.STATUS_SKIPPED:
			skipped_count += 1

		_:
			failed_count += 1


func has_failures() -> bool:
	return failed_count > 0


func has_warnings() -> bool:
	return warning_count > 0


func has_skipped_files() -> bool:
	return skipped_count > 0


func get_processed_count() -> int:
	return success_count + failed_count + skipped_count


func get_summary() -> String:
	if total_count <= 0:
		return "No files were processed."

	if failed_count <= 0 and warning_count <= 0 and skipped_count <= 0:
		return "Successfully converted %d file(s)." % success_count

	var summary: String = (
		"Processed %d file(s): %d successful" % [
			total_count,
			success_count
		]
	)

	if warning_count > 0:
		summary += ", %d with warnings" % warning_count

	if failed_count > 0:
		summary += ", %d failed" % failed_count

	if skipped_count > 0:
		summary += ", %d skipped" % skipped_count

	summary += "."

	return summary


func get_failed_results() -> Array[ConversionResult]:
	var failed_results: Array[ConversionResult] = []

	for result: ConversionResult in results:
		if result.status == ConversionResult.STATUS_FAILED:
			failed_results.append(result)

	return failed_results


func get_skipped_results() -> Array[ConversionResult]:
	var skipped_results: Array[ConversionResult] = []

	for result: ConversionResult in results:
		if result.status == ConversionResult.STATUS_SKIPPED:
			skipped_results.append(result)

	return skipped_results
