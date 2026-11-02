class_name WeaponData
extends Resource

enum WeaponKind {
	MELEE,
	RANGED,
	STAFF,
}

enum AttackAnim {
	SWING,
	POKE,
}

@export var id: String = ""
@export var display_name: String = ""
@export var kind: WeaponKind = WeaponKind.RANGED
@export var damage: int = 1
@export var fire_rate: float = 1.0
@export var mana_cost: float = 0.0
@export var projectile_speed: int = 0
@export var projectile_lifetime: float = 0.0
@export var pierce: int = 0
@export var pellet_count: int = 1
@export var spread_degrees: float = 0.0
@export var range_px: float = 0.0
@export var knockback: float = 0.0
@export var element: String = ""
@export var texture: Texture2D
@export var projectile_texture: Texture2D
@export var muzzle_offset: Vector2
@export var hitbox_offset: Vector2
@export var hitbox_radius: float = 0.0
@export var hitbox_size: Vector2
@export var attack_anim: AttackAnim = AttackAnim.SWING
@export var swing_angle_degrees: float = 100.0
@export var anim_duration: float = 0.15
@export var poke_distance: float = 12.0
