class_name BaseActor extends Node2D

@export var Collider: CollisionShape2D
@export var BaseSprite: Sprite2D

var Ref_Id: RID
var Col_Id: RID
var Parent: Node2D = get_parent()

func _ready() -> void:
	pass
