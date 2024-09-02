class_name RigidbodyActor extends "BaseActor.gd"

@export var RigidBody: RigidBody2D

func SpawnAsChild(_parent : Node2D, pos : Vector2) -> void:
	Parent = _parent
	Parent.add_child(self)
	position = pos

func _ready() -> void:
	pass
