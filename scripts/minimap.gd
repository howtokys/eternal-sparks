extends Control

const VISITED_RADIUS := 4
const UNVISITED_BRIGHTNESS := 0.24
const PANEL_COLOR := Color("#18151e")
const FRAME_COLOR := Color("#9b7f5d")
const FLOOR_COLOR := Color("#c6b798")
const WALL_COLOR := Color("#544b59")
const PLAYER_COLOR := Color("#8bf3e2")
const CHEST_COLOR := Color("#ffc65f")
const MARKER_OUTLINE := Color("#211923")

var level: Node
var grid: TileMapLayer
var player: Node2D
var tiles: Dictionary[Vector2i, bool] = {}
var revealed: Dictionary[Vector2i, bool] = {}
var bounds: Rect2i
var map_image: Image
var map_texture: ImageTexture
var layout_dirty := true
var layer_bounds: Dictionary[TileMapLayer, Rect2i] = {}
var last_reveal_cell: Variant = null

func _ready() -> void:
	hide()
	get_tree().node_added.connect(_on_layer_added_or_removed)
	get_tree().node_removed.connect(_on_layer_added_or_removed)
	resized.connect(queue_redraw)

func _process(_delta: float) -> void:
	var current_level := get_tree().current_scene
	if not is_instance_valid(level) or level != current_level:
		level = current_level
		player = null
		revealed.clear()
		layout_dirty = true
	if level == null:
		hide()
		return
	if layout_dirty or _layer_bounds_changed():
		_read_level_tiles()
	if tiles.is_empty():
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if is_instance_valid(player):
		var player_cell := _cell_at(player.global_position)
		if player_cell != last_reveal_cell:
			_reveal_around(player_cell)
			last_reveal_cell = player_cell
	queue_redraw()

func _on_layer_added_or_removed(node: Node) -> void:
	if node is TileMapLayer:
		_mark_layout_dirty()

func _mark_layout_dirty() -> void:
	layout_dirty = true

func _layer_bounds_changed() -> bool:
	for layer in layer_bounds:
		if not is_instance_valid(layer) or layer.get_used_rect() != layer_bounds[layer]:
			return true
	return false

func _read_level_tiles() -> void:
	layout_dirty = false
	last_reveal_cell = null
	var previous_grid := grid
	grid = null
	tiles.clear()
	layer_bounds.clear()
	bounds = Rect2i()
	for node in level.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if not layer.changed.is_connected(_mark_layout_dirty):
			layer.changed.connect(_mark_layout_dirty)
		layer_bounds[layer] = layer.get_used_rect()
		if not layer.enabled or layer.tile_set == null:
			continue
		var cells := layer.get_used_cells()
		if cells.is_empty():
			continue
		if grid == null:
			grid = layer
		for cell in cells:
			# Layers can be nested or offset. Convert each tile to the minimap grid.
			var map_cell := _cell_at(layer.to_global(layer.map_to_local(cell)))
			tiles[map_cell] = tiles.get(map_cell, false) or _is_wall(layer, cell)
			bounds = bounds.merge(Rect2i(map_cell, Vector2i.ONE)) if bounds.has_area() else Rect2i(map_cell, Vector2i.ONE)

	visible = not tiles.is_empty()
	if tiles.is_empty():
		return
	if previous_grid != grid:
		revealed.clear()
	map_image = Image.create_empty(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	for cell in revealed.keys():
		if not tiles.has(cell):
			revealed.erase(cell)
	for cell in tiles:
		_paint_cell(cell)
	map_texture = ImageTexture.create_from_image(map_image)

func _is_wall(layer: TileMapLayer, cell: Vector2i) -> bool:
	if not layer.collision_enabled:
		return false
	var data := layer.get_cell_tile_data(cell)
	if data == null:
		return false
	for physics_layer in range(layer.tile_set.get_physics_layers_count()):
		if data.get_collision_polygons_count(physics_layer) > 0:
			return true
	return false

func _cell_at(world_position: Vector2) -> Vector2i:
	return grid.local_to_map(grid.to_local(world_position))

func _reveal_around(center: Vector2i) -> void:
	var changed := false
	for y in range(-VISITED_RADIUS, VISITED_RADIUS + 1):
		for x in range(-VISITED_RADIUS, VISITED_RADIUS + 1):
			if x * x + y * y > VISITED_RADIUS * VISITED_RADIUS:
				continue
			var cell := center + Vector2i(x, y)
			if tiles.has(cell) and not revealed.has(cell):
				revealed[cell] = true
				_paint_cell(cell)
				changed = true
	if changed:
		map_texture.update(map_image)

func _paint_cell(cell: Vector2i) -> void:
	var color := WALL_COLOR if tiles[cell] else FLOOR_COLOR
	if not revealed.has(cell):
		color = color.darkened(UNVISITED_BRIGHTNESS)
	map_image.set_pixelv(cell - bounds.position, color)

func _map_position(world_position: Vector2) -> Vector2:
	var local := grid.to_local(world_position)
	var cell := grid.local_to_map(local)
	var offset := (local - grid.map_to_local(cell)) / Vector2(grid.tile_set.tile_size)
	return Vector2(cell - bounds.position) + Vector2(0.5, 0.5) + offset

func _draw() -> void:
	if not is_instance_valid(grid) or tiles.is_empty():
		return

	draw_rect(Rect2(Vector2.ZERO, size), FRAME_COLOR)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2, 2)), PANEL_COLOR)
	var inner := size - Vector2(12, 12)
	var scale_to_fit := minf(inner.x / bounds.size.x, inner.y / bounds.size.y)
	if scale_to_fit >= 1.0:
		scale_to_fit = floorf(scale_to_fit)
	var map_size := Vector2(bounds.size) * scale_to_fit
	var origin := ((size - map_size) * 0.5).floor()
	draw_texture_rect(map_texture, Rect2(origin, map_size), false)

	for node in get_tree().get_nodes_in_group("chest"):
		var chest := node as Node2D
		if chest != null and level.is_ancestor_of(chest) and revealed.has(_cell_at(chest.global_position)):
			_draw_dot(origin + _map_position(chest.global_position) * scale_to_fit, 2.0, CHEST_COLOR)
	if is_instance_valid(player):
		var position_on_map := origin + _map_position(player.global_position) * scale_to_fit
		_draw_dot(position_on_map.clamp(Vector2(4, 4), size - Vector2(4, 4)), 2.5, PLAYER_COLOR)

func _draw_dot(center: Vector2, radius: float, color: Color) -> void:
	draw_circle(center.round(), radius + 1.0, MARKER_OUTLINE)
	draw_circle(center.round(), radius, color)
