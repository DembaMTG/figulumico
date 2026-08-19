extends RefCounted
class_name IcoEncoder

# ==============================================================
# IcoEncoder
# ==============================================================
#
# Responsibility:
# ✅ Creates a valid ICO file
# ✅ Writes the ICONDIR header
# ✅ Writes ICONDIRENTRY entries
# ✅ Embeds PNG byte blocks into the ICO file
#
# ❌ Has no knowledge of UI nodes
# ❌ Does not open FileDialogs
# ❌ Does not load source images
# ❌ Does not scale images
# ❌ Does not manage a queue
#
# ==============================================================


const ICONDIR_SIZE: int = 6
const ICONDIRENTRY_SIZE: int = 16

const ICON_TYPE: int = 1
const ICON_PLANES: int = 1
const ICON_BIT_COUNT: int = 32


# --------------------------------------------------------------
# Public API
# --------------------------------------------------------------

func write_ico(
	images: Array[Image],
	output_path: String,
	source_path: String = ""
) -> ConversionResult:
	var result: ConversionResult = ConversionResult.new()
	var clean_output_path: String = output_path.strip_edges()

	result.source_path = source_path
	result.mark_processing()

	if clean_output_path.is_empty():
		result.mark_failed("No output path was provided.")
		return result

	if images.is_empty():
		result.mark_failed("No icon images were provided.")
		return result

	var png_buffers: Array[PackedByteArray] = []
	var icon_sizes: Array[int] = []

	for image: Image in images:
		if image == null or image.is_empty():
			result.mark_failed("An icon image is empty or invalid.")
			return result

		var image_width: int = image.get_width()
		var image_height: int = image.get_height()

		if image_width != image_height:
			result.mark_failed(
				"ICO images must be square. Received: %d × %d." % [
					image_width,
					image_height
				]
			)
			return result

		if image_width <= 0 or image_width > 256:
			result.mark_failed(
				"Unsupported icon size: %d. ICO sizes must be between 1 and 256." % [
					image_width
				]
			)
			return result

		if icon_sizes.has(image_width):
			result.mark_failed(
				"Duplicate icon size detected: %d × %d." % [
					image_width,
					image_height
				]
			)
			return result

		var png_buffer: PackedByteArray = image.save_png_to_buffer()

		if png_buffer.is_empty():
			result.mark_failed(
				"Could not encode %d × %d image as PNG data." % [
					image_width,
					image_height
				]
			)
			return result

		icon_sizes.append(image_width)
		png_buffers.append(png_buffer)

	var ico_data: PackedByteArray = _build_ico_data(
		png_buffers,
		icon_sizes
	)

	if ico_data.is_empty():
		result.mark_failed("Could not build ICO binary data.")
		return result

	var file: FileAccess = FileAccess.open(
		clean_output_path,
		FileAccess.WRITE
	)

	if file == null:
		result.mark_failed(
			"Could not open output file for writing: " + clean_output_path
		)
		return result

	var write_success: bool = file.store_buffer(ico_data)
	file.close()

	if not write_success:
		result.mark_failed(
			"Could not write ICO data to: " + clean_output_path
		)
		return result

	result.selected_sizes = icon_sizes
	result.mark_success(clean_output_path)

	return result


# --------------------------------------------------------------
# ICO data construction
# --------------------------------------------------------------

func _build_ico_data(
	png_buffers: Array[PackedByteArray],
	icon_sizes: Array[int]
) -> PackedByteArray:
	var image_count: int = png_buffers.size()

	if image_count <= 0:
		return PackedByteArray()

	if image_count != icon_sizes.size():
		return PackedByteArray()

	var directory_end_offset: int = (
		ICONDIR_SIZE + (ICONDIRENTRY_SIZE * image_count)
	)

	var ico_data: PackedByteArray = PackedByteArray()

	# Reserve header + all directory entries.
	ico_data.resize(directory_end_offset)
	ico_data.fill(0)

	# ----------------------------------------------------------
	# ICONDIR
	#
	# Reserved: 0
	# Type: 1 = ICO
	# Count: Number of embedded images
	# ----------------------------------------------------------

	_write_u16_le(ico_data, 0, 0)
	_write_u16_le(ico_data, 2, ICON_TYPE)
	_write_u16_le(ico_data, 4, image_count)

	# The first PNG block begins immediately after all directory entries.
	var image_data_offset: int = directory_end_offset

	for index: int in range(image_count):
		var entry_offset: int = (
			ICONDIR_SIZE + (index * ICONDIRENTRY_SIZE)
		)

		var icon_size: int = icon_sizes[index]
		var png_buffer: PackedByteArray = png_buffers[index]
		var png_data_size: int = png_buffer.size()

		# ------------------------------------------------------
		# ICONDIRENTRY
		#
		# 0  Width
		# 1  Height
		# 2  Color Count
		# 3  Reserved
		# 4  Planes          (2 bytes)
		# 6  Bit Count       (2 bytes)
		# 8  Bytes In Res    (4 bytes)
		# 12 Image Offset    (4 bytes)
		# ------------------------------------------------------

		ico_data[entry_offset] = _encode_icon_dimension(icon_size)
		ico_data[entry_offset + 1] = _encode_icon_dimension(icon_size)

		# Color Count = 0
		# Reserved = 0
		ico_data[entry_offset + 2] = 0
		ico_data[entry_offset + 3] = 0

		_write_u16_le(
			ico_data,
			entry_offset + 4,
			ICON_PLANES
		)

		_write_u16_le(
			ico_data,
			entry_offset + 6,
			ICON_BIT_COUNT
		)

		_write_u32_le(
			ico_data,
			entry_offset + 8,
			png_data_size
		)

		_write_u32_le(
			ico_data,
			entry_offset + 12,
			image_data_offset
		)

		image_data_offset += png_data_size

	# Append all PNG data blocks after the header.
	for png_buffer: PackedByteArray in png_buffers:
		ico_data.append_array(png_buffer)

	return ico_data


# --------------------------------------------------------------
# ICO helpers
# --------------------------------------------------------------

func _encode_icon_dimension(icon_size: int) -> int:
	# ICO saves 256 × 256 as Bytevalue 0.
	if icon_size == 256:
		return 0

	return icon_size


func _write_u16_le(
	target: PackedByteArray,
	offset: int,
	value: int
) -> void:
	target[offset] = value & 0xFF
	target[offset + 1] = (value >> 8) & 0xFF


func _write_u32_le(
	target: PackedByteArray,
	offset: int,
	value: int
) -> void:
	target[offset] = value & 0xFF
	target[offset + 1] = (value >> 8) & 0xFF
	target[offset + 2] = (value >> 16) & 0xFF
	target[offset + 3] = (value >> 24) & 0xFF
