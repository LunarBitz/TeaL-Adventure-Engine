extends KinematicBody
class_name BitzKinematicBody


var floor_velocity = Vector3()
var floor_normal = Vector3()
var on_floor = false
var on_wall = false
var on_ceiling = false
var current_collision = KinematicCollision


func get_floor_normal():
	return floor_normal

func get_floor_velocity():
	return floor_velocity

func is_on_ceiling():
	return on_ceiling

func is_on_floor():
	return on_floor

func is_on_wall():
	return on_wall

func get_collision():
	return current_collision

func move_and_slide_custom(
		var lv, 
		var floor_direction = Vector3(0,1,0), 
		var foward_direction = Vector3(-1,0,0), 
		var physics_delta = get_physics_process_delta_time(), 
		var max_slides = 4, 
		var slope_stop_min_velocity = 0.05, 
		var floor_max_angle = deg2rad(45),
		var ceiling_max_angle = deg2rad(225),
		var update_floor = true,
		var update_wall = true,
		var update_ceiling = true):
	
	var cos_slope = cos(floor_max_angle)
	var cos_ceil = cos(ceiling_max_angle)
	var motion = (floor_velocity + lv) * physics_delta
	floor_velocity = Vector3.ZERO

	if update_floor:
		on_floor = false
	if update_ceiling:
		on_ceiling = false
	if update_wall:
		on_wall = false

	while(max_slides):
		var collision = move_and_collide(motion)
		current_collision = collision
		if collision:
			#print("collision")
			motion = collision.remainder
			floor_normal = collision.normal

			if collision.normal.dot(floor_direction) >= cos_slope:
				if update_floor:
					on_floor = true

				floor_velocity = collision.collider_velocity

				var rel_v = lv - floor_velocity
				var hor_v = rel_v - floor_direction * floor_direction.dot(rel_v)

				if collision.get_travel().length() < 0.05 and hor_v.length() < slope_stop_min_velocity:
					var gt = get_global_transform()
					gt.origin -= collision.travel 
					set_global_transform(gt)
					return (floor_velocity - floor_direction * floor_direction.dot(floor_velocity))

			elif collision.normal.dot(floor_direction) < cos_slope and collision.normal.dot(floor_direction) > cos_ceil and sqrt(lv.length_squared()) > slope_stop_min_velocity:
				if update_wall:
					on_wall = true	

					var d = collision.normal.dot(lv)
					print(d)
		
					if (d < cos_ceil or d > cos_slope):
						print("cancel")
						lv = lerp(lv, Vector3.ZERO, 0.1)
						break
			
			elif collision.normal.dot(floor_direction) <= cos_ceil:
				if update_ceiling:
					on_ceiling = true

			var n = collision.normal
			motion = motion.slide(n)
			lv = lv.slide(n)
			#move_and_slide(lv, n, false)
		else:
			#print("no collision")
			break

		max_slides -= 1

		if motion.length() == 0:
			break
	return lv
