extends RefCounted
class_name ImageProcessor

# ==============================================================
# ImageProcessor
# ==============================================================
#
# Responsibility:
# ✅ Loads source images at runtime
# ✅ Converts images to RGBA8
# ✅ Creates square target images
# ✅ Supports Contain, Center Crop, and Stretch
# ✅ Supports Smooth and Pixel Perfect scaling
#
# ❌ Has no knowledge of UI nodes
# ❌ Does not open FileDialogs
# ❌ Does not write ICO files
# ❌ Does not manage a queue
#
# ==============================================================


# --------------------------------------------------------------
# Public API
# --------------------------------------------------------------

func load_source_image(source_path: String) -> Image:
	var clean_path: String = source_path.strip_edges()

	if clean_path.is_empty():
		return null

	if not FileAccess.file_exists(clean_path):
		return null

	var image: Image = Image.load_from_file(clean_path)

	if image == null or image.is_empty():
		return null

	# Convert all images to a uniform working format.
	image.convert(Image.FORMAT_RGBA8)

	return image


func prepare_icon(
	source_image: Image,
	target_size: int,
	options: ConversionOptions
) -> Image:
	if source_image == null or source_image.is_empty():
		return null

	if target_size <= 0:
		return null

	if options == null:
		return null

	# Never modify the source graphic directly.
	var working_image: Image = source_image.duplicate() as Image

	if working_image == null or working_image.is_empty():
		return null

	working_image.convert(Image.FORMAT_RGBA8)

	var interpolation: int = _get_interpolation(
		options.scaling_mode
	)

	match options.fit_mode:
		ConversionOptions.FIT_CONTAIN:
			return _prepare_contain(
				working_image,
				target_size,
				options,
				interpolation
			)

		ConversionOptions.FIT_CENTER_CROP:
			return _prepare_center_crop(
				working_image,
				target_size,
				interpolation
			)

		ConversionOptions.FIT_STRETCH:
			return _prepare_stretch(
				working_image,
				target_size,
				interpolation
			)

		_:
			# Defensive Fallback:
			# If an unknown mode appears, use Contain.
			return _prepare_contain(
				working_image,
				target_size,
				options,
				interpolation
			)


func prepare_all_sizes(
	options: ConversionOptions
) -> Array[Image]:
	var prepared_images: Array[Image] = []

	if options == null:
		return prepared_images

	var source_image: Image = load_source_image(
		options.source_path
	)

	if source_image == null:
		return prepared_images

	for icon_size: int in options.icon_sizes:
		var prepared_image: Image = prepare_icon(
			source_image,
			icon_size,
			options
		)

		if prepared_image != null and not prepared_image.is_empty():
			prepared_images.append(prepared_image)

	return prepared_images


# --------------------------------------------------------------
# Fit modes
# --------------------------------------------------------------

func _prepare_contain(
	source_image: Image,
	target_size: int,
	options: ConversionOptions,
	interpolation: int
) -> Image:
	var source_width: int = source_image.get_width()
	var source_height: int = source_image.get_height()

	if source_width <= 0 or source_height <= 0:
		return null

	var width_scale: float = (
		float(target_size) / float(source_width)
	)

	var height_scale: float = (
		float(target_size) / float(source_height)
	)

	var scale_factor: float = width_scale

	if height_scale < width_scale:
		scale_factor = height_scale

	var resized_width: int = int(
		round(float(source_width) * scale_factor)
	)

	var resized_height: int = int(
		round(float(source_height) * scale_factor)
	)

	if resized_width < 1:
		resized_width = 1

	if resized_height < 1:
		resized_height = 1

	source_image.resize(
		resized_width,
		resized_height,
		interpolation
	)

	# Generate the target canvas at full icon size.
	var result_image: Image = Image.create_empty(
		target_size,
		target_size,
		false,
		Image.FORMAT_RGBA8
	)

	result_image.fill(
		_get_background_color(options)
	)

	# Place the image exactly in the center.
	var destination_x: int = int(
		(target_size - resized_width) / 2
	)

	var destination_y: int = int(
		(target_size - resized_height) / 2
	)

	var destination_position: Vector2i = Vector2i(
		destination_x,
		destination_y
	)

	var source_rect: Rect2i = Rect2i(
		Vector2i.ZERO,
		source_image.get_size()
	)

	result_image.blit_rect(
		source_image,
		source_rect,
		destination_position
	)

	return result_image


func _prepare_center_crop(
	source_image: Image,
	target_size: int,
	interpolation: int
) -> Image:
	var source_width: int = source_image.get_width()
	var source_height: int = source_image.get_height()

	if source_width <= 0 or source_height <= 0:
		return null

	var width_scale: float = (
		float(target_size) / float(source_width)
	)

	var height_scale: float = (
		float(target_size) / float(source_height)
	)

	var scale_factor: float = width_scale

	if height_scale > width_scale:
		scale_factor = height_scale

	var resized_width: int = int(
		round(float(source_width) * scale_factor)
	)

	var resized_height: int = int(
		round(float(source_height) * scale_factor)
	)

	if resized_width < target_size:
		resized_width = target_size

	if resized_height < target_size:
		resized_height = target_size

	source_image.resize(
		resized_width,
		resized_height,
		interpolation
	)

	# Determine the centered square cutout.
	var crop_x: int = int(
		(resized_width - target_size) / 2
	)

	var crop_y: int = int(
		(resized_height - target_size) / 2
	)

	var crop_rect: Rect2i = Rect2i(
		crop_x,
		crop_y,
		target_size,
		target_size
	)

	var cropped_image: Image = source_image.get_region(
		crop_rect
	)

	return cropped_image


func _prepare_stretch(
	source_image: Image,
	target_size: int,
	interpolation: int
) -> Image:
	source_image.resize(
		target_size,
		target_size,
		interpolation
	)

	return source_image


# --------------------------------------------------------------
# Helpers
# --------------------------------------------------------------

func _get_interpolation(
	scaling_mode: String
) -> int:
	if scaling_mode == ConversionOptions.SCALING_PIXEL_PERFECT:
		return Image.INTERPOLATE_NEAREST

	# Lanczos delivers high-quality results, particularly during downscaling.
	return Image.INTERPOLATE_LANCZOS


func _get_background_color(
	options: ConversionOptions
) -> Color:
	if options.background_mode == ConversionOptions.BACKGROUND_SOLID_COLOR:
		return options.background_color

	return Color.TRANSPARENT
