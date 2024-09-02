class_name RigidbodyActor extends "BaseActor.gd"

@export var RigidBody: RigidBody2D
var ForceMultiplier: float
var sway_and_rotate: bool = false
var i: float = 0.0

func SpawnAsChild(_parent : Node2D, pos : Vector2, swayAndRotate: bool = false, scaleMassAndGravity: bool = false) -> void:
	Parent = _parent
	Parent.add_child(self)
	position = pos
	sway_and_rotate = swayAndRotate
	
	if (sway_and_rotate):
		ForceMultiplier = randf_range(-5.0, 5.0)
		RigidBody.add_constant_torque(25.0 * ForceMultiplier)
	
	if (scaleMassAndGravity):
		RigidBody.gravity_scale *= randf_range(0.25, 2.5)
		RigidBody.mass *= randf_range(0.25, 2.5)

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if (sway_and_rotate == false):
		return
	
	i += delta
	var pos = self.global_position
	var new_pos = pos
	new_pos.x += sin(i) * ForceMultiplier
	RigidBody.apply_central_force(new_pos - pos)
