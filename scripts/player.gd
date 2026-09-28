extends CharacterBody2D

const SPEED = 150.0

func _ready() -> void:
	GlobalData.player = self
	if GlobalData.is_loading_save:
		global_position = GlobalData.saved_position	
		GlobalData.is_loading_save = false
		
	#temporary test : to check the save function 
	GlobalData.save_game()

func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input_direction * SPEED
	move_and_slide()
 
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_left"):
		get_node("Gun").shoot()
