class_name PlayerInputClass

export var input_axis = {"": 0.0}
export var input_actions = {"": 0}

func _init(axis_names = [], action_names = []):
	for ax in axis_names:
		input_axis[ax] = 0.0

	for act in action_names:
		input_actions[act] = 0
		input_actions[act + "_pressed"] = 0
		input_actions[act + "_released"] = 0
