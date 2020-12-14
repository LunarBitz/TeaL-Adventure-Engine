extends Spatial

const EPSILON = 0.0001
export(float, 0, 8, 0.1) var mouse_yaw_speed = 4.0
export(bool) var invert_yaw = true 
export(float, 0, 8, 0.1) var mouse_pitch_speed = 4.0
export(bool) var invert_pitch = true 
var player_input = PlayerInputClass
var player_velocity = Vector3()
export(float, 1, 256, 1) var max_position_lag_offset = 256.0
export(float, 1, 100, 0.1) var position_lag_speed = 50.0
export(float, 1, 180, 1) var max_rotation_input_lag_angle = 5.0
export(float, 0.1, 16, 0.1) var rotation_input_lag_time = 0.2
export(float, 1, 180, 1) var max_rotation_align_lag_angle = 5.0
export(float, 0.1, 16, 0.1) var rotation_align_lag_time = 0.2

export(NodePath) var target_parent_path
onready var target_parent = get_node(target_parent_path)

var cam_rot = Vector3()
var smooth_cam_rot = Vector3()
var lag_input_rot = Vector3()
var lag_align_rot = Quat()



func _ready() -> void:
	pass


func _physics_process(delta: float) -> void:
	if target_parent != null:
		rotate_camera(delta)

		# Simulate springarm attachment by getting it's intended camera mount position
		#var camera_socket = Vector3.ZERO#target_parent.global_transform.basis.z * target_parent.spring_length

		# Movement Lag
		#var pos_lag = player_velocity * max_position_lag_offset * delta * delta # Set value of max position lag
		#global_transform.origin = global_transform.origin.linear_interpolate(target_parent.global_transform.origin + camera_socket + pos_lag, 1 / position_lag_speed)
	pass


func rotate_camera(delta):
	if player_input.input_axis.has("mouse_yaw"):
		cam_rot.y += player_input.input_axis["mouse_yaw"] * mouse_yaw_speed * delta * (-1 if invert_yaw else 1)
		#cam_rot.y = wrapf(cam_rot.y, -180.0, 180.0)
		player_input.input_axis["mouse_yaw"] = 0.0
	if player_input.input_axis.has("mouse_pitch"):
		cam_rot.x += player_input.input_axis["mouse_pitch"] * mouse_pitch_speed * delta * (-1 if invert_pitch else 1)
		cam_rot.x = clamp(cam_rot.x, -85.0, 5.0)
		player_input.input_axis["mouse_pitch"] = 0.0

	smooth_cam_rot = lerp(smooth_cam_rot, cam_rot, delta / rotation_input_lag_time)

	lag_input_rot.y = deg2rad(smooth_cam_rot.y)
	lag_input_rot.x = deg2rad(smooth_cam_rot.x)

	rotation = lag_input_rot


	
