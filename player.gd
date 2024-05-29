extends CharacterBody2D
class_name Player

@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var coyote_timer = $CoyoteTimer
@onready var wall_jump_timer = $WallJumpTimer
@onready var camera = $Camera2D

# Raycasts for _is_on_wall_only() "polyfill"
@onready var raycast_left = $RaycastLeft
@onready var raycast_bottom_left = $RaycastBottomLeft
@onready var raycast_right = $RaycastRight
@onready var raycast_bottom_right = $RaycastBottomRight

@export var movement_data : PlayerMovementData

var air_jump_count : int
var just_wall_jumped = false
var latest_wall_normal = Vector2.ZERO

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready():
	air_jump_count = movement_data.air_jumps


func _physics_process(delta):
	### gravity
	apply_gravity(delta)
	
	### jumping
	handle_fall_through()
	handle_wall_jump() # this must come before handle_jump()
	handle_jump()
	
	### directional movement
	var input_axis = Input.get_axis("move_left", "move_right")
	handle_acceleration(input_axis, delta)
	handle_air_acceleration(input_axis, delta)
	apply_friction(input_axis, delta)
	
	handle_look(delta)
	
	### animations
	update_animations(input_axis)
	
	### get and store latest positional states before we move and slide
	var was_on_floor = is_on_floor()
	var was_on_wall = _is_on_wall_only()
	if was_on_wall:
		latest_wall_normal = get_wall_normal()
	
	### move and sliiide
	move_and_slide()
	
	### get and store positional states after we move and slide
	just_wall_jumped = false
	var just_left_ledge = was_on_floor and not is_on_floor() and velocity.y >= 0
	if just_left_ledge:
		coyote_timer.start()
	var just_left_wall = was_on_wall and not _is_on_wall_only()
	if just_left_wall:
		wall_jump_timer.start()


func apply_gravity(delta):
	if is_on_floor():
		return

	if _is_on_wall_only() and velocity.y > 0: # if player is jumping (positive y velocity), don't wall slide
		velocity.y = movement_data.wall_sliding_friction * delta
	else:
		velocity.y += gravity * movement_data.gravity_scale * delta


func handle_fall_through():
	if not is_on_floor():
		return
		
	# allows player to fall through thin platforms when pressing down
	if Input.is_action_just_pressed("down"):
		global_position.y += 1	


func handle_wall_jump():
	if not _is_on_wall_only() and wall_jump_timer.time_left <= 0.0:
		return
		
	var wall_normal = get_wall_normal()
	if wall_jump_timer.time_left > 0.0:
		wall_normal = latest_wall_normal
	
	if Input.is_action_just_pressed("jump"):
		just_wall_jumped = true
		velocity.x = wall_normal.x * movement_data.speed * 2 # multiply base speed by 2 for extra spicy wall jumps
		velocity.y = movement_data.jump_velocity

func handle_jump():
	if is_on_floor():
		air_jump_count = movement_data.air_jumps				
		
	if is_on_floor() or coyote_timer.time_left > 0.0: # player can still jump for a few frames after leaving a ledge
		if Input.is_action_just_pressed("jump"):
			velocity.y = movement_data.jump_velocity
	else:
		if Input.is_action_just_pressed("jump") and air_jump_count > 0 and not just_wall_jumped: # air jump
			air_jump_count -= 1
			velocity.y = movement_data.air_jump_velocity
			
		if Input.is_action_just_released("jump") and velocity.y < movement_data.jump_velocity * 0.5:
			velocity.y = movement_data.jump_velocity * 0.5


func apply_friction(input_axis, delta):
	if not input_axis:
		velocity.x = move_toward(velocity.x, 0, movement_data.friction * delta)


func handle_acceleration(input_axis, delta):
	if not is_on_floor():
		return
		
	if input_axis:
		velocity.x = move_toward(velocity.x, input_axis * movement_data.speed, movement_data.acceleration * delta)


func handle_air_acceleration(input_axis, delta):
	if is_on_floor():
		return
		
	if input_axis:
		velocity.x = move_toward(velocity.x, input_axis * movement_data.speed, movement_data.air_acceleration * delta)


func handle_look(delta):
	camera.offset = Vector2.ZERO if Input.get_vector("look_left", "look_right", "look_up", "look_down").is_zero_approx() else Vector2.ZERO.lerp(Input.get_vector("look_left", "look_right", "look_up", "look_down") * 60, 1.0)


func update_animations(input_axis):
	if input_axis:
		animated_sprite_2d.flip_h = input_axis < 0
		animated_sprite_2d.play("run")
	else:
		animated_sprite_2d.play("idle")
		
	if not is_on_floor():
		
			
		if velocity.y < 0:
			animated_sprite_2d.play("jump")
		else:
			animated_sprite_2d.play("fall")
			
		if _is_on_wall_only() and velocity.y > 0: # if player is jumping (positive y velocity), don't wall slide
			animated_sprite_2d.play("wall_slide")
	

func apply_force(axis : String, force : float):
	velocity[axis] = force

### Polyfill for godot's native "is_on_wall_only()" function
### -- the native function is buggy and inconsistent.
func _is_on_wall_only():
	if is_on_floor():
		return
	
	# player raycasts set to -5.1/5.1
	var collision_left = raycast_bottom_left.is_colliding() and raycast_left.is_colliding()
	var collision_right = raycast_bottom_right.is_colliding() and raycast_right.is_colliding()

	return collision_left or collision_right
