extends "res://scripts/player/bitz_kinematic_body.gd"

var player_input = preload("res://scripts/player/bitz_input_class.gd").new([],[])

const EPSILON = 0.0001
var mouse_sens = 0.3
var camera_anglev = 0
export(float, -19.62, -0.01, 0.01) var GRAVITY = -9.81
var gravity_scalar = 0.0
var speed_scalar = 0.0
var smooth_speed_scalar = 0.0
var target_input_vector = Vector3()
var raw_input_vector = Vector3()

var gravity_vel = Vector3()
var movement_vel = Vector3()
var composite_vel = Vector3()

var pitch_transform: Transform
var roll_transform: Transform
var velocity_direction = Vector3()

export(float, 1, 64, 1) var MAX_SPEED = 20
export(float, 1, 64, 1) var JUMP_SPEED = 18
export(float, 1, 16, 0.25) var ACCEL = 2.7*2
export(float, 1, 16, 0.25) var DEACCEL = 5.4*2
var direction = Vector3()
var floor_rays = {
	"Front": Object(),
	"Back": Object(),
	"Left": Object(),
	"Right": Object(),
}
var floor_normals = {
	"Front": Vector3(0, 1, 0),
	"Back": Vector3(0, 1, 0),
	"Left": Vector3(0, 1, 0),
	"Right": Vector3(0, 1, 0),
}
var average_normal = Vector3()
var player_basis = Basis()

export(float, 0, 90, 1) var MAX_SLOPE_ANGLE = 40
export(float, 0, 90, 1) var MAX_CEILING_ANGLE = 40
export(float, 0, 90, 1) var MAX_STEP_ANGLE = 7.0


func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	var text_debugger = load("res://scenes/Text_Debugger_Overlay.tscn").instance()
	text_debugger.add_stat("On Floor", $".", "is_on_floor", true)
	text_debugger.add_stat("On Wall", $".", "is_on_wall", true)
	text_debugger.add_stat("On Ceil", $".", "is_on_ceiling", true)

	add_child(text_debugger)

	for ray in $Rays.get_children():
		if ray.get_class() == "RayCast":
			ray.set_cast_to(Vector3(0, -1.5, 0))
			
	floor_rays["Front"] = $Rays/RaycastFront
	floor_rays["Back"] = $Rays/RaycastBack
	floor_rays["Left"] = $Rays/RaycastLeft
	floor_rays["Right"] = $Rays/RaycastRight


func get_capsule_basis(dir, length = 1, offset = Vector3(0, 0, 0)):
	return $CollisionShape.transform.origin + ($CollisionShape.get_shape().get_radius() * (dir * length)) + offset
	
	
func get_capsule_bottom():
	return $CollisionShape.transform.origin + $CollisionShape.get_shape().get_height()


func _physics_process(delta):
	process_input()
	process_movement(delta)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		player_input.input_axis["mouse_yaw"] = event.relative.x
		player_input.input_axis["mouse_pitch"] = event.relative.y
		

func process_input():
	# ----------------------------------
	# Walking
	direction = Vector3()

	player_input.input_axis["movement_forward"] = Input.get_action_strength("player_move_backward") - Input.get_action_strength("player_move_forward")
	player_input.input_axis["movement_side"] = Input.get_action_strength("player_move_right") - Input.get_action_strength("player_move_left")

	raw_input_vector = Vector3(player_input.input_axis["movement_side"], 0, player_input.input_axis["movement_forward"]).normalized()
	target_input_vector = target_input_vector.linear_interpolate(raw_input_vector, 0.1)

	# Basis vectors are already normalized.
	var target_q = global_transform.basis.get_rotation_quat() * Quat(Vector3(0.0, $SpringArm.rotation.y, 0.0))
	#  
	direction = target_q.xform(raw_input_vector).normalized()

	# ----------------------------------

	# ----------------------------------
	
	
	# Jumping
	#if is_on_floor():
		#if Input.is_action_just_pressed("movement_jump"):
			#vel.y = JUMP_SPEED
	# ----------------------------------

	# ----------------------------------
	# Capturing/Freeing the cursor
	if Input.is_action_just_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# ----------------------------------
	get_node("SpringArm").player_input = player_input


func process_movement(delta):
	handle_gravity(delta)
	align_to_floor()
	rotate_mesh_to_velocity(delta)
	
	movement_vel = apply_input_to_velocity(delta, direction, movement_vel, ACCEL, DEACCEL, 6.0, MAX_SPEED)
	#VelocityDeacceleration(DeltaTime, Deceleration, 0.0f, AdditionalVelocity_1)

	movement_vel = move_and_slide_custom(
		movement_vel, average_normal, velocity_direction,
		delta, 8, 0.05, 
		deg2rad(MAX_SLOPE_ANGLE), deg2rad(180 + MAX_CEILING_ANGLE), 
		false, true, true
	)
	gravity_vel = move_and_slide_custom(
		gravity_vel, average_normal, velocity_direction,
		delta, 4, 0.05, 
		deg2rad(MAX_STEP_ANGLE), deg2rad(180 + MAX_STEP_ANGLE), 
		true, false, false
	)
	
	get_node("SpringArm").player_velocity = composite_vel
	

func accelerate_scalar(delta, scalar, vel, dir, max_speed = 1.0, acc = 0.01, deacc = 0.1):
	if abs(dir.length()) > 0.01:
		scalar += (acc if dir.dot(vel) > 0 else deacc)
	else:
		scalar = lerp(scalar, 0.0, delta * deacc)

	scalar = clamp(scalar, -max_speed, max_speed)	
	print(scalar)		
	return scalar


func handle_gravity(delta):
	if is_on_floor():
		gravity_scalar = delta * GRAVITY
	else:
		gravity_scalar += delta * GRAVITY
		
	gravity_vel = global_transform.basis.y * gravity_scalar
	
	
func align_to_floor():
	# Calculate Pitch
	if floor_rays.has_all(["Front", "Back"]):
		# Front-Back Ray
		update_ray_normal(["Front", "Back"], deg2rad(MAX_SLOPE_ANGLE))
			
		var forward_normal = (floor_normals["Front"] + floor_normals["Back"]).normalized()
		average_normal += forward_normal
		pitch_transform = get_y_align(global_transform, forward_normal)
	
	# Calculate Roll
	if floor_rays.has_all(["Left", "Right"]):
		# Left-Right Ray
		update_ray_normal(["Left", "Right"], deg2rad(MAX_SLOPE_ANGLE))
		
		var side_normal = (floor_normals["Left"] + floor_normals["Right"]).normalized()
		average_normal += side_normal
		roll_transform = get_y_align(global_transform, side_normal)

	average_normal = average_normal.normalized()

	# Combine and apply transforms	
	global_transform = global_transform.interpolate_with(pitch_transform, 0.1)
	global_transform = global_transform.interpolate_with(roll_transform, 0.1)


func update_ray_normal(ray_pair, max_angle = 40, default_value = Vector3.UP):

	var cos_slope = cos(max_angle + EPSILON)

	# Ray 1
	var v1t = default_value
	if floor_rays[ray_pair[0]].is_colliding():
		v1t = floor_rays[ray_pair[0]].get_collision_normal() if floor_rays[ray_pair[0]].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
	elif floor_rays[ray_pair[1]].is_colliding() and not floor_rays[ray_pair[0]].is_colliding():
		v1t = floor_rays[ray_pair[1]].get_collision_normal() if floor_rays[ray_pair[1]].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
	else:
		v1t = default_value
	floor_normals[ray_pair[0]] = lerp(floor_normals[ray_pair[0]], v1t, 0.5)

	# Ray 2
	var v2t = default_value
	if floor_rays[ray_pair[1]].is_colliding():
		v2t = floor_rays[ray_pair[1]].get_collision_normal() if floor_rays[ray_pair[1]].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
	elif floor_rays[ray_pair[0]].is_colliding() and not floor_rays[ray_pair[1]].is_colliding():
		v2t = floor_rays[ray_pair[1]].get_collision_normal() if floor_rays[ray_pair[0]].get_collision_normal().dot(global_transform.basis.y) >= cos_slope else default_value
	else:
		v2t = default_value
	floor_normals[ray_pair[1]] = lerp(floor_normals[ray_pair[1]], v2t, 0.5)


func get_y_align(base_transform, normal):
	base_transform.basis.y = normal
	base_transform.basis.x = -base_transform.basis.z.cross(normal)
	base_transform.basis = base_transform.basis.orthonormalized()
	
	return base_transform


func rotate_mesh_to_velocity(delta):	
	var arc_tan_2 = atan2(-target_input_vector.x, -target_input_vector.z)
	var target_angle = (arc_tan_2 - rotation.y + $SpringArm.rotation.y)
	var up_fix = (deg2rad(-180.0) if global_transform.basis.y.y <= -0.001 else 0.0)

	$HelperVel.rotation.y = target_angle + up_fix
	velocity_direction = -$HelperVel.transform.basis.z

	if movement_vel.length_squared() >= delta:
		$VisualMesh.rotation.y = lerp_angle($VisualMesh.rotation.y, target_angle + up_fix, delta * 8.0)


func get_clamped_vector3(vector, maxLength):
	var sqrmag = vector.length_squared()
	if sqrmag > maxLength * maxLength:
		var mag = sqrt(sqrmag)

		# these intermediate variables force the intermediate result to be
		# of float precision. without this, the intermediate result can be of higher
		# precision, which changes behavior.
		var normalized_x = vector.x / mag
		var normalized_y = vector.y / mag
		var normalized_z = vector.z / mag

		return Vector3(
			normalized_x * maxLength,
			normalized_y * maxLength,
			normalized_z * maxLength
		);
	
	return vector;


func apply_input_to_velocity(DeltaTime, input_vect, vect, Acceleration, Deacceleration, TurnBoost, TargetSpeed):
	var temp_vec = vect
	var ControlAcceleration = get_clamped_vector3(input_vect, 1.0)
	var AnalogInputModifier = (ControlAcceleration.length() if ControlAcceleration.length_squared() > 0.0 else 0.0)
	var MaxPawnSpeed = TargetSpeed * AnalogInputModifier
	var bExceedingMaxSpeed = (true if vect.length() >= TargetSpeed else false)
	
	if AnalogInputModifier > 0.0 and not bExceedingMaxSpeed:
		# Apply change in velocity direction
		if vect.length_squared() > 0.0:
			# Change direction faster than only using acceleration, but never increase velocity magnitude.
			var TimeScale = clamp(DeltaTime * TurnBoost, 0.0, 1.0)
			vect = vect + (ControlAcceleration * vect.length() - vect) * TimeScale
	else:
		# Dampen velocity magnitude based on deceleration.
		if vect.length_squared() > 0.0:
			var OldVelocity = vect
			var VelSize = max(vect.length() - abs(Deacceleration) * DeltaTime, 0.0)
			vect = vect.normalized() * VelSize

			# Don't allow braking to lower us below max speed if we started above it.
			if bExceedingMaxSpeed and vect.length_squared() < pow(MaxPawnSpeed, 2):
				vect = OldVelocity.GetSafeNormal() * MaxPawnSpeed

	# Apply acceleration and clamp velocity magnitude.
	var NewMaxSpeed = (vect.Size() if bExceedingMaxSpeed else TargetSpeed)
	vect += ControlAcceleration * abs(Acceleration) * DeltaTime
	return get_clamped_vector3(vect, NewMaxSpeed)
		

func velocity_deacceleration(DeltaTime, Deacceleration, vec):
	# Dampen velocity magnitude based on deceleration.
	if vec.length_squared() > 0.0:
		var VelSize = max(vec.length() - abs(Deacceleration) * DeltaTime, 0.0);
		vec = vec.normalized() * VelSize;
