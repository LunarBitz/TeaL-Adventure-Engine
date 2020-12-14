extends CanvasLayer

# Debug overlay by Gonkee - full tutorial https://youtu.be/8Us2cteHbbo

var stats = []

func add_stat(stat_name, object, stat_ref, is_method = false):
	stats.append([stat_name, object, stat_ref, is_method])

func _process(delta):
	var label_text = ""
	
	var fps = Engine.get_frames_per_second()
	label_text += str("FPS: ", fps)
	label_text += "\n"
	
	"""
	var mem = OS.get_static_memory_usage()
	label_text += str('Static Memory: ', String.humanize_size(mem))
	label_text += '\n'
	"""
	
	for s in stats:
		var value = null
		
		if is_instance_valid(s[1]):
			if s[3]:
				value = s[1].call(s[2])
			else:
				value = s[1].get(s[2])
		label_text += str(s[0], ": ", value)
		label_text += "\n"
	
	$ColorRect.get_child(0).text = label_text
