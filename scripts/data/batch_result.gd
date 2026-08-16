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
	
func get_detailed_summary() -> String:
	if total_count <= 0:
		return "[b]No files were processed.[/b]"

	var lines: Array[String] = []

	lines.append("[b]Batch conversion complete[/b]")
	lines.append("")
	lines.append("Total: %d" % total_count)
	lines.append("Successful: %d" % success_count)
	lines.append("Warnings: %d" % warning_count)
	lines.append("Skipped: %d" % skipped_count)
	lines.append("Failed: %d" % failed_count)

	return "\n".join(lines)


func get_error_report() -> String:
	var lines: Array[String] = []

	lines.append("Iconify Wizard — Batch Report")
	lines.append("")
	lines.append(get_summary())
	lines.append("")

	var has_report_entries: bool = false

	for result: ConversionResult in results:
		if result == null:
			continue

		var source_filename: String = result.source_path.get_file()

		if result.status == ConversionResult.STATUS_FAILED:
			has_report_entries = true

			lines.append("[FAILED] " + source_filename)

			if result.error_message.strip_edges().is_empty():
				lines.append("  No detailed error message was provided.")
			else:
				lines.append("  " + result.error_message)

			lines.append("")
			continue

		if result.status == ConversionResult.STATUS_SKIPPED:
			has_report_entries = true

			lines.append("[SKIPPED] " + source_filename)

			if result.error_message.strip_edges().is_empty():
				lines.append("  Output was skipped.")
			else:
				lines.append("  " + result.error_message)

			lines.append("")
			continue

		if result.has_warnings():
			has_report_entries = true

			lines.append("[WARNING] " + source_filename)

			for warning: String in result.warnings:
				lines.append("  " + warning)

			lines.append("")

	if not has_report_entries:
		lines.append("No warnings, skipped files, or failures were reported.")

	return "\n".join(lines)
