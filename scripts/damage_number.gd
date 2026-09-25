extends Label

var tween: Tween

func display(count, pos):
	text = str(count)
	global_position = pos
	modulate.a = 1.0 #reset opacity back to full
	
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position:y", pos.y - 30, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.chain().tween_callback(queue_free)
