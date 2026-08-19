extends RefCounted
class_name ConversionService

# ==============================================================
# ConversionService
# ==============================================================
#
# Responsibility:
# ✅ Orchestrates a complete single conversion
# ✅ Validates ConversionOptions
# ✅ Creates target directories when needed
# ✅ Handles file name collisions
# ✅ Calls ImageProcessor and IcoEncoder
# ✅ Always returns a ConversionResult
#
# ❌ Has no knowledge of UI nodes
# ❌ Does not open FileDialogs
# ❌ Does not manage a queue
# ❌ Does not update labels or ProgressBars
#
# ==============================================================


var image_processor: ImageProcessor = ImageProcessor.new()
var ico_encoder: IcoEncoder = IcoEncoder.new()


# --------------------------------------------------------------
# Public API
# --------------------------------------------------------------

func convert(
	options: ConversionOptions
) -> ConversionResult:
	var result: ConversionResult = ConversionResult.new()

	if options == null:
		result.mark_failed("Conversion options are missing.")
		return result

	result.source_path = options.source_path

	for icon_size: int in options.icon_sizes:
		result.selected_sizes.append(icon_size)

	var validation_errors: Array[String] = (
		options.get_validation_errors()
	)

	if not validation_errors.is_empty():
		var first_error: String = validation_errors[0]

		result.mark_failed(first_error)
		return result

	var output_directory: String = (
		options.output_directory.strip_edges()
	)

	var requested_output_path: String = (
		options.get_output_path()
	)

	if output_directory.is_empty():
		result.mark_failed("No output directory was provided.")
		return result

	if requested_output_path.is_empty():
		result.mark_failed("No output filename was provided.")
		return result

	if not _ensure_output_directory_exists(output_directory, result):
		return result

	var resolved_output_path: String = (
		_resolve_output_path(options, result)
	)

	if resolved_output_path.is_empty():
		return result

	var prepared_images: Array[Image] = (
		image_processor.prepare_all_sizes(options)
	)

	if prepared_images.is_empty():
		result.mark_failed(
			"Could not prepare icon images from the selected source file."
		)
		return result

	if prepared_images.size() != options.icon_sizes.size():
		result.mark_failed(
			"Not all selected icon sizes could be prepared."
		)
		return result

	var encoder_result: ConversionResult = ico_encoder.write_ico(
		prepared_images,
		resolved_output_path,
		options.source_path
	)

	if not encoder_result.success:
		return encoder_result

	_add_conversion_warnings(
		encoder_result,
		options
	)

	return encoder_result


# --------------------------------------------------------------
# Output directory
# --------------------------------------------------------------

func _ensure_output_directory_exists(
	output_directory: String,
	result: ConversionResult
) -> bool:
	if DirAccess.dir_exists_absolute(output_directory):
		return true

	var create_error: int = (
		DirAccess.make_dir_recursive_absolute(output_directory)
	)

	if create_error != OK:
		result.mark_failed(
			"Could not create output directory: " + output_directory
		)
		return false

	return true


# --------------------------------------------------------------
# Collision handling
# --------------------------------------------------------------

func _resolve_output_path(
	options: ConversionOptions,
	result: ConversionResult
) -> String:
	var requested_output_path: String = (
		options.get_output_path()
	)

	if not FileAccess.file_exists(requested_output_path):
		return requested_output_path

	match options.collision_policy:
		ConversionOptions.COLLISION_OVERWRITE:
			return requested_output_path

		ConversionOptions.COLLISION_AUTO_NUMBER:
			var numbered_output_path: String = (
				_build_numbered_output_path(requested_output_path)
			)

			if numbered_output_path.is_empty():
				result.mark_failed(
					"Could not generate a unique output filename."
				)
				return ""

			return numbered_output_path

		ConversionOptions.COLLISION_SKIP:
			result.mark_skipped(
				"Output file already exists: " + requested_output_path
			)
			return ""

		ConversionOptions.COLLISION_ASK:
			result.mark_skipped(
				"Output file already exists and requires user confirmation: "
				+ requested_output_path
			)
			return ""

		_:
			result.mark_failed(
				"Unknown collision policy: " + options.collision_policy
			)
			return ""


func _build_numbered_output_path(
	requested_output_path: String
) -> String:
	var base_path: String = requested_output_path.get_basename()
	var extension: String = requested_output_path.get_extension()

	var counter: int = 1

	while counter <= 9999:
		var numbered_path: String = "%s_%02d.%s" % [
			base_path,
			counter,
			extension
		]

		if not FileAccess.file_exists(numbered_path):
			return numbered_path

		counter += 1

	return ""


# --------------------------------------------------------------
# Warnings
# --------------------------------------------------------------

func _add_conversion_warnings(
	result: ConversionResult,
	options: ConversionOptions
) -> void:
	var source_extension: String = (
		options.source_path.get_extension().to_lower()
	)

	if source_extension == "jpg" or source_extension == "jpeg":
		result.add_warning(
			"This image has no transparency. Existing background colors were kept."
		)

	if options.fit_mode == ConversionOptions.FIT_STRETCH:
		result.add_warning(
			"Stretch mode was used. Image proportions may be distorted."
		)

	if result.output_path != options.get_output_path():
		result.add_warning(
			"Output filename already existed. A numbered filename was created instead."
		)
