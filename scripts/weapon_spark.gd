extends Sprite2D

const SHEET := preload("res://sprites/effects/weapon_sparks.png")
const MUZZLE_GLOW := preload("res://sprites/effects/muzzle_glow.tres")
const GLOW_COLORS := [
	Color("#ffb751"), Color("#ffbc64"), Color("#ffa64b"), Color("#ff8c49"),
	Color("#83dfff"), Color("#c88cfa"), Color("#65e7f1"),
]
const FRAME_COUNT := 3
const STYLE_COUNT := 7
const STYLES := {
	"auto_rifle": 1,
	"shotgun": 2,
	"ember_staff": 3,
	"frost_staff": 4,
	"storm_staff": 5,
	"laser_gun": 6,
}

var animation: Tween
var glow: Sprite2D

func _init() -> void:
	texture = SHEET
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hframes = FRAME_COUNT
	vframes = STYLE_COUNT * 2
	z_index = 2
	hide()

func play_spark(weapon_id: String, impact: bool, frame_time: float, loop := false) -> void:
	stop_spark()
	var style: int = STYLES.get(weapon_id, 0)
	var row := style + (STYLE_COUNT if impact else 0)
	if not impact:
		scale = Vector2.ONE * 1.25
		if glow == null:
			glow = Sprite2D.new()
			glow.texture = MUZZLE_GLOW
			glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			glow.show_behind_parent = true
			glow.position.x = 2.0
			var additive := CanvasItemMaterial.new()
			additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			glow.material = additive
			add_child(glow)
		glow.modulate = GLOW_COLORS[style]
		glow.show()
	elif glow != null:
		glow.hide()
		scale = Vector2.ONE
	frame_coords = Vector2i(0, row)
	show()
	animation = create_tween()
	if loop:
		animation.set_loops()
	for column in range(FRAME_COUNT):
		animation.tween_callback(set_frame_coords.bind(Vector2i(column, row)))
		if not impact:
			animation.tween_callback(glow.set_indexed.bind(NodePath("modulate:a"), 1.0 - 0.28 * column))
		animation.tween_interval(frame_time)
	if not loop:
		animation.tween_callback(hide)

func stop_spark() -> void:
	if animation != null:
		animation.kill()
	hide()
