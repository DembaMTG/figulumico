extends Node

# ==============================================================
# IcoEncoderTest
# ==============================================================
#
# Testet die vollständige Core-Pipeline:
#
# ConversionOptions
# → ConversionService
# → ImageProcessor
# → IcoEncoder
# → ICO-Datei
#
# ==============================================================


const TEST_SOURCE_RESOURCE_PATH: String = (
	"res://tests/input/test_icon.png"
)

const TEST_OUTPUT_RESOURCE_PATH: String = (
	"res://tests/output"
)


func _ready() -> void:
	var source_path: String = ProjectSettings.globalize_path(
		TEST_SOURCE_RESOURCE_PATH
	)

	var output_directory: String = ProjectSettings.globalize_path(
		TEST_OUTPUT_RESOURCE_PATH
	)

	var options: ConversionOptions = ConversionOptions.new()

	options.source_path = source_path
	options.output_directory = output_directory
	options.output_filename = "iconify_core_test.ico"

	options.icon_sizes = [
		16,
		32,
		48,
		256
	]

	options.fit_mode = ConversionOptions.FIT_CONTAIN
	options.scaling_mode = ConversionOptions.SCALING_SMOOTH
	options.background_mode = ConversionOptions.BACKGROUND_TRANSPARENT
	options.collision_policy = ConversionOptions.COLLISION_OVERWRITE

	var conversion_service: ConversionService = (
		ConversionService.new()
	)

	var result: ConversionResult = conversion_service.convert(
		options
	)

	_print_result(result)

	if not result.success:
		return

	_validate_ico_header(
		result.output_path,
		options.icon_sizes.size()
	)
	
	_validate_ico_entries(
		result.output_path,
		options.icon_sizes
	)


func _print_result(
	result: ConversionResult
) -> void:
	print("========================================")
	print("ICONIFY WIZARD — ICO CORE TEST")
	print("========================================")
	print("Success: ", result.success)
	print("Status: ", result.status)
	print("Source: ", result.source_path)
	print("Output: ", result.output_path)
	print("Sizes: ", result.selected_sizes)
	print("Warnings: ", result.warnings)
	print("Error: ", result.error_message)
	print("Summary: ", result.get_summary())
	print("========================================")


func _validate_ico_header(
	ico_path: String,
	expected_image_count: int
) -> void:
	if not FileAccess.file_exists(ico_path):
		push_error("ICO test failed: Output file does not exist.")
		return

	var ico_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		ico_path
	)

	if ico_bytes.size() < 6:
		push_error("ICO test failed: File is too small for an ICO header.")
		return

	var reserved: int = _read_u16_le(
		ico_bytes,
		0
	)

	var icon_type: int = _read_u16_le(
		ico_bytes,
		2
	)

	var image_count: int = _read_u16_le(
		ico_bytes,
		4
	)

	print("ICO Header Validation")
	print("Reserved: ", reserved)
	print("Type: ", icon_type)
	print("Image count: ", image_count)

	if reserved != 0:
		push_error("ICO test failed: Reserved header value is not 0.")
		return

	if icon_type != 1:
		push_error("ICO test failed: File type is not ICO.")
		return

	if image_count != expected_image_count:
		push_error(
			"ICO test failed: Unexpected image count. Expected %d, got %d." % [
				expected_image_count,
				image_count
			]
		)
		return

	print("ICO HEADER TEST PASSED ✅")


func _read_u16_le(
	data: PackedByteArray,
	offset: int
) -> int:
	if offset < 0:
		return 0

	if offset + 1 >= data.size():
		return 0

	var low_byte: int = int(data[offset])
	var high_byte: int = int(data[offset + 1])

	return low_byte | (high_byte << 8)
	
func _validate_ico_entries(
	ico_path: String,
	expected_sizes: Array[int]
) -> void:
	if not FileAccess.file_exists(ico_path):
		push_error("ICO entry test failed: Output file does not exist.")
		return

	var ico_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		ico_path
	)

	var required_header_size: int = 6 + (
		expected_sizes.size() * 16
	)

	if ico_bytes.size() < required_header_size:
		push_error(
			"ICO entry test failed: File is too small for all directory entries."
		)
		return

	print("========================================")
	print("ICO DIRECTORY ENTRY VALIDATION")
	print("========================================")

	for index: int in range(expected_sizes.size()):
		var expected_size: int = expected_sizes[index]

		var entry_offset: int = 6 + (index * 16)

		var raw_width: int = int(ico_bytes[entry_offset])
		var raw_height: int = int(ico_bytes[entry_offset + 1])

		var actual_width: int = raw_width
		var actual_height: int = raw_height

		# ICO-Sonderfall:
		# Der Bytewert 0 repräsentiert 256 Pixel.
		if raw_width == 0:
			actual_width = 256

		if raw_height == 0:
			actual_height = 256

		var planes: int = _read_u16_le(
			ico_bytes,
			entry_offset + 4
		)

		var bit_count: int = _read_u16_le(
			ico_bytes,
			entry_offset + 6
		)

		var png_data_size: int = _read_u32_le(
			ico_bytes,
			entry_offset + 8
		)

		var png_data_offset: int = _read_u32_le(
			ico_bytes,
			entry_offset + 12
		)

		print("Entry ", index + 1)
		print("  Size: ", actual_width, " × ", actual_height)
		print("  Planes: ", planes)
		print("  Bit Count: ", bit_count)
		print("  PNG Data Size: ", png_data_size)
		print("  PNG Data Offset: ", png_data_offset)

		if actual_width != expected_size:
			push_error(
				"ICO entry test failed: Unexpected width in entry %d." % [
					index + 1
				]
			)
			return

		if actual_height != expected_size:
			push_error(
				"ICO entry test failed: Unexpected height in entry %d." % [
					index + 1
				]
			)
			return

		if planes != 1:
			push_error(
				"ICO entry test failed: Invalid planes value in entry %d." % [
					index + 1
				]
			)
			return

		if bit_count != 32:
			push_error(
				"ICO entry test failed: Invalid bit count in entry %d." % [
					index + 1
				]
			)
			return

		if png_data_size <= 0:
			push_error(
				"ICO entry test failed: Empty PNG data in entry %d." % [
					index + 1
				]
			)
			return

		if png_data_offset < required_header_size:
			push_error(
				"ICO entry test failed: Invalid PNG offset in entry %d." % [
					index + 1
				]
			)
			return

		if png_data_offset + png_data_size > ico_bytes.size():
			push_error(
				"ICO entry test failed: PNG data exceeds file bounds in entry %d." % [
					index + 1
				]
			)
			return

		if not _has_png_signature(
			ico_bytes,
			png_data_offset
		):
			push_error(
				"ICO entry test failed: Missing PNG signature in entry %d." % [
					index + 1
				]
			)
			return

	print("ICO DIRECTORY ENTRY TEST PASSED ✅")
	print("========================================")
	
func _read_u32_le(
	data: PackedByteArray,
	offset: int
) -> int:
	if offset < 0:
		return 0

	if offset + 3 >= data.size():
		return 0

	var byte_0: int = int(data[offset])
	var byte_1: int = int(data[offset + 1])
	var byte_2: int = int(data[offset + 2])
	var byte_3: int = int(data[offset + 3])

	return byte_0 \
		| (byte_1 << 8) \
		| (byte_2 << 16) \
		| (byte_3 << 24)


func _has_png_signature(
	data: PackedByteArray,
	offset: int
) -> bool:
	if offset < 0:
		return false

	if offset + 7 >= data.size():
		return false

	return int(data[offset]) == 137 \
		and int(data[offset + 1]) == 80 \
		and int(data[offset + 2]) == 78 \
		and int(data[offset + 3]) == 71 \
		and int(data[offset + 4]) == 13 \
		and int(data[offset + 5]) == 10 \
		and int(data[offset + 6]) == 26 \
		and int(data[offset + 7]) == 10
