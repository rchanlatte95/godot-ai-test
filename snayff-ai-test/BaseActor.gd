extends Node2D

@export var Collider: CollisionShape2D
@export var BaseSprite: Sprite2D
@export_range (0.1, 100.0) var Collider_Size: float

var Ref_Id: RID
var Col_Id: RID
var Parent: Node2D = get_parent()

func _ready() -> void:
	pass
