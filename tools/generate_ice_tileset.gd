extends SceneTree
## Run with: godot --headless --path . --script tools/generate_ice_tileset.gd
## Add -- --rebuild-tilesets only when the forest tile definitions need to be recaptured.

const FOREST_ATLAS := "res://sprites/Forest_titlesset.png"
const FOREST_ROOM := "res://scenes/First_Room.tscn"
const ICE_ATLAS := "res://sprites/Ice_tileset.png"
const ICE_FLOOR := "res://sprites/ice_floor_tiles.tres"
const ICE_WALLS := "res://sprites/ice_wall_tiles.tres"
const TILE_SIZE := 16
const FLOOR_BASES := [
	Color("#345867"), Color("#263f53"), Color("#3a5e70"), Color("#426b76"),
	Color("#203a49"), Color("#315461"), Color("#3d6573"), Color("#294657"),
]
const INKS := {
	"o": Color("#1b313c"),
	"d": Color("#263f50"),
	"b": Color("#375a6c"),
	"c": Color("#4d7381"),
	"f": Color("#658c98"),
	"l": Color("#80a2ac"),
	"h": Color("#9bb7bf"),
}
const FROST_BANK := [
	"....ccc.....",
	"..ccccfc....",
	".ccflfffcc..",
	"ccffffcccc..",
	".ccccc...c..",
]
const HAIRLINE_CRACK := [
	"c.......",
	".c......",
	"..cd....",
	"...dcd..",
	"......cd",
]
const ICE_MASONRY := [
	"oobbbccbbbbbddoo",
	"obcfcclccfccbbdo",
	"bcflccflfccbbbdo",
	"bcfcccccccbbcbdo",
	"bccbcbbccbccccdo",
	"dcbccdbbbcbcccdo",
	"dccbbddbbcccbbdo",
	"ddcbbddbcbbbbddo",
	"ddbdbddbcbbdddoo",
	"oddbdddbbbdddooo",
	"ocffccbccfcdddoo",
	"occlffccccdccbdo",
	"dbccfccbddbccbdo",
	"dbbcbbdbbbccbbdo",
	"dbbcbbdbbcccbbdo",
	"dbbbbbdbcccbbddo",
	"dbbbdbdbbbbbbddo",
	"dbbdddodbbbddooo",
	"oddddoooddddoooo",
	"oooooooooooooooo",
	"oooooooooooooooo",
	"oooooooooooooooo",
]
const CRATE_FROST := [
	".ccflcc...",
	"cflffc..c.",
	".c..c..c..",
]
const CRATE_EDGE_FROST := [
	"...c.",
	"..cf.",
	".ccfc",
	"..cc.",
]
const REINFORCED_CRATE_RIM := [
	"dbclc...cflcbd",
	"bflfc..ccfflcb",
	"bfc.c......cdb",
	"dc..........bd",
]
const CRATE_CORNER_BRACKET := [
	"db.",
	"bfc",
	"bcd",
]
const EDGE_FROST := [
	"ccffcc....cc..",
	"bcccffc..cffc.",
	"..c.ccb...cc..",
	"....cb.....b..",
	".....b........",
]
const WALL_CHIP := [
	"..f...",
	".flc..",
	".lfcb.",
	"..cb..",
]

func _initialize() -> void:
	var forest := Image.load_from_file(ProjectSettings.globalize_path(FOREST_ATLAS))
	if forest == null or forest.get_size() != Vector2i(640, 360):
		push_error("Expected the original 640 by 360 forest atlas.")
		quit(1)
		return
	forest.convert(Image.FORMAT_RGBA8)
	var ice := forest.duplicate() as Image
	_draw_floors(ice)
	_draw_walls(ice)
	_draw_crates(ice)
	var error := _save_atlas(ice)
	var rebuild := "--rebuild-tilesets" in OS.get_cmdline_user_args()
	var save_floor := rebuild or not FileAccess.file_exists(ICE_FLOOR)
	var save_walls := rebuild or not FileAccess.file_exists(ICE_WALLS)
	# Existing TileSets already reference this PNG. Keep their paint data intact on art updates.
	if error == OK and (save_floor or save_walls):
		error = _save_tile_sets(ice, save_floor, save_walls)
	if error != OK:
		push_error("Could not generate the ice theme: %s" % error_string(error))
	quit(error)

func _save_atlas(ice: Image) -> Error:
	var png := ice.save_png_to_buffer()
	if png.is_empty():
		return ERR_CANT_CREATE
	if FileAccess.file_exists(ICE_ATLAS) and FileAccess.get_file_as_bytes(ICE_ATLAS) == png:
		return OK
	var file := FileAccess.open(ICE_ATLAS, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(png)
	return file.get_error()

func _draw_floors(ice: Image) -> void:
	for variant in FLOOR_BASES.size():
		var origin := Vector2i(18 + variant % 4, 6 + floori(variant / 4.0)) * TILE_SIZE
		var base: Color = FLOOR_BASES[variant]
		for y in TILE_SIZE:
			for x in TILE_SIZE:
				var color := base.darkened(0.20) if x == 0 or y == 0 else base
				_paint(ice, origin + Vector2i(x, y), color)

		match variant:
			3:
				_stamp(ice, origin + Vector2i(3, 9), FROST_BANK, true)
			7:
				_stamp(ice, origin + Vector2i(6, 7), HAIRLINE_CRACK, true)

func _draw_walls(ice: Image) -> void:
	var foliage := Vector2i(23, 6) * TILE_SIZE
	for y in range(2 * TILE_SIZE):
		for x in TILE_SIZE:
			_paint(ice, foliage + Vector2i(x, y), INKS["o"])
	_stamp(ice, foliage + Vector2i(0, 1), ICE_MASONRY)

	# Preserve the masonry frames. Replace moss along their edges with ice.
	for column in [22, 26]:
		var origin := Vector2i(column, 6) * TILE_SIZE
		for y in range(2 * TILE_SIZE):
			for x in TILE_SIZE:
				var pixel := origin + Vector2i(x, y)
				var color := ice.get_pixelv(pixel)
				if color.g > color.r * 1.2 and color.g > color.b * 1.12:
					_paint(ice, pixel, INKS["c"] if color.g > 0.42 else INKS["d"])
		_stamp(ice, origin + Vector2i(1, 1), EDGE_FROST, column == 26)
		_stamp(ice, origin + Vector2i(4, 14), WALL_CHIP, column != 26)

	var interior_wall := Vector2i(13, 6) * TILE_SIZE
	_stamp(ice, interior_wall + Vector2i(1, 1), EDGE_FROST, true)

func _draw_crates(ice: Image) -> void:
	for cell: Vector2i in [Vector2i(11, 6), Vector2i(12, 6), Vector2i(14, 6), Vector2i(25, 8)]:
		var origin := cell * TILE_SIZE
		_stamp(ice, origin + Vector2i(1, 0), CRATE_FROST)
		_stamp(ice, origin + Vector2i(10, 12), CRATE_EDGE_FROST)

	# The immovable crate keeps its slats and gets reinforced corners.
	var reinforced := Vector2i(16, 6) * TILE_SIZE
	_stamp(ice, reinforced + Vector2i(1, 0), REINFORCED_CRATE_RIM)
	_stamp(ice, reinforced + Vector2i(0, 13), CRATE_CORNER_BRACKET)
	_stamp(ice, reinforced + Vector2i(13, 13), CRATE_CORNER_BRACKET, true)
	_stamp(ice, reinforced + Vector2i(1, 18), CRATE_EDGE_FROST, true)

func _stamp(ice: Image, origin: Vector2i, rows: Array, mirror := false) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ink := row[x]
			if ink != ".":
				var offset := Vector2i(row.length() - x - 1 if mirror else x, y)
				_paint(ice, origin + offset, INKS[ink])

func _paint(ice: Image, pixel: Vector2i, color: Color) -> void:
	var alpha := ice.get_pixelv(pixel).a
	if alpha > 0.0:
		color.a = alpha
		ice.set_pixelv(pixel, color)

func _save_tile_sets(ice: Image, save_floor: bool, save_walls: bool) -> Error:
	var scene := load(FOREST_ROOM) as PackedScene
	if scene == null:
		return ERR_CANT_OPEN
	var room := scene.instantiate()
	var floor_layer := room.get_node("Floor") as TileMapLayer
	var wall_layer := floor_layer.get_node("Wall_IndestructibleObject") as TileMapLayer
	# Use the just-generated image while saving a reference to the imported PNG.
	var atlas := ImageTexture.create_from_image(ice)
	atlas.take_over_path(ICE_ATLAS)
	var error := OK
	if save_floor:
		error = _save_tile_set(floor_layer.tile_set, atlas, ICE_FLOOR)
	if error == OK and save_walls:
		error = _save_tile_set(wall_layer.tile_set, atlas, ICE_WALLS)
	room.free()
	return error

func _save_tile_set(source: TileSet, texture: Texture2D, path: String) -> Error:
	var tiles := source.duplicate(true) as TileSet
	for index in tiles.get_source_count():
		var source_id := tiles.get_source_id(index)
		var original := source.get_source(source_id) as TileSetAtlasSource
		if original != null and original.texture != null and original.texture.resource_path == FOREST_ATLAS:
			var themed := tiles.get_source(source_id) as TileSetAtlasSource
			themed.texture = texture
	return ResourceSaver.save(tiles, path)
