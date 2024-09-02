class_name RigidbodyActor extends "BaseActor.gd"

@export var RigidBody: RigidBody2D
var ForceMultiplier: float
var sway_and_rotate: bool = false
var i: float = 0.0

func SpawnAsChild(_parent : Node2D, pos : Vector2, swayAndRotate: bool = false) -> void:
	Parent = _parent
	Parent.add_child(self)
	position = pos
	sway_and_rotate = swayAndRotate
	if (sway_and_rotate):
		ForceMultiplier = randf_range(-10.0, 10.0)
		RigidBody.add_constant_torque(25.0 * ForceMultiplier)

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if (sway_and_rotate == false):
		return
	i += 0.01

func _physics_process(delta: float) -> void:
	if (sway_and_rotate == false):
		return
	
	var dt = i * delta
	#self.rotate(dt)
	var new_pos = self.global_position
	new_pos.x = sin(dt * ForceMultiplier) * ForceMultiplier
	RigidBody.apply_central_force(new_pos)
