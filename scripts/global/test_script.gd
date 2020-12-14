extends Spatial


# Declare member variables here. Examples:



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var text_debugger = load("res://scenes/Text_Debugger_Overlay.tscn").instance()
	add_child(text_debugger)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
#	pass
