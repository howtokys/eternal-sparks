extends SceneTree
## Run with: godot --headless --path . --script tools/generate_player_frames.gd

const SOURCE := "res://sprites/Double.png"
const OUTPUT := "res://sprites/player/Double_animation.png"
const FRAME_SIZE := Vector2i(32, 32)
const REAR_FOOT := Rect2i(14, 28, 5, 2)
const FRONT_FOOT := Rect2i(23, 28, 5, 2)
const SCARF_TAIL := Rect2i(0, 18, 12, 14)

func _initialize() -> void:
	var art := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	if art == null or art.get_size() != FRAME_SIZE:
		push_error("Expected the original 32 by 32 player sprite.")
		quit(1)
		return
	art.convert(Image.FORMAT_RGBA8)

	var frames := [
		art,
		_shift(_bend_scarf(art, -1), Vector2i(0, -1)),
		_step(_bend_scarf(art, -3), Vector2i(-1, -1), Vector2i(2, 0)),
		_step(_bend_scarf(art, 1), Vector2i(2, 0), Vector2i(-2, -1)),
		_shift(_bend_scarf(art, -2), Vector2i(-1, -2)),
		_shift(art, Vector2i(-1, 1)),
	]
	var sheet := Image.create_empty(FRAME_SIZE.x * frames.size(), FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	for index in frames.size():
		sheet.blit_rect(frames[index], Rect2i(Vector2i.ZERO, FRAME_SIZE), Vector2i(index * FRAME_SIZE.x, 0))
	var error := sheet.save_png(ProjectSettings.globalize_path(OUTPUT))
	if error != OK:
		push_error("Could not write the player sprite sheet.")
	quit(error)

func _bend_scarf(art: Image, tip_offset: int) -> Image:
	var frame := art.duplicate() as Image
	frame.fill_rect(SCARF_TAIL, Color.TRANSPARENT)
	for x in range(SCARF_TAIL.end.x):
		# Keep the cloth pinned near the collar and move only its loose end.
		var offset := roundi(tip_offset * (1.0 - float(x) / (SCARF_TAIL.end.x - 1)))
		var column := Rect2i(x, SCARF_TAIL.position.y, 1, SCARF_TAIL.size.y)
		frame.blit_rect(art, column, column.position + Vector2i(0, offset))
	return frame

func _shift(art: Image, offset: Vector2i) -> Image:
	var frame := Image.create_empty(FRAME_SIZE.x, FRAME_SIZE.y, false, Image.FORMAT_RGBA8)
	frame.blit_rect(art, Rect2i(Vector2i.ZERO, FRAME_SIZE), offset)
	return frame

func _step(art: Image, rear_offset: Vector2i, front_offset: Vector2i) -> Image:
	var frame := art.duplicate() as Image
	frame.fill_rect(REAR_FOOT, Color.TRANSPARENT)
	frame.fill_rect(FRONT_FOOT, Color.TRANSPARENT)
	for y in range(REAR_FOOT.position.y, REAR_FOOT.end.y):
		for x in range(REAR_FOOT.position.x, REAR_FOOT.end.x):
			var color := art.get_pixel(x, y)
			if color.a > 0.0:
				frame.set_pixelv(Vector2i(x, y) + rear_offset, color)
		for x in range(FRONT_FOOT.position.x, FRONT_FOOT.end.x):
			var color := art.get_pixel(x, y)
			if color.a > 0.0:
				frame.set_pixelv(Vector2i(x, y) + front_offset, color)
	return frame
