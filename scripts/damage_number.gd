extends Label

var tween: Tween

func display(count, pos):
	text = str(count)
	z_index = 100
	modulate.a = 1.0
	visible = true
	
	global_position = pos
	
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", pos.y - 30, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(queue_free)
