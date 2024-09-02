extends Node2D

@export var InfoLabel: Label
@export var SwayAndRotate: bool
@export var RandomizeMassAndGravity: bool

var Newton = PhysicsServer2D
var rb_obj = preload("res://Rigidbody-Actor.tscn")

var INSTANCE_CTR: int = 0
const SPAWN_RATE: float = 1.0 / 25.0
var actor_ct: int = 0
var accum: float = 0.0

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	
	accum += delta
	if (accum >= SPAWN_RATE):
		
		var Shrunk_screen_size = DisplayServer.screen_get_size() * 0.75
		var rand_x: float = randf_range(100.0, Shrunk_screen_size.x)
		
		var obj = rb_obj.instantiate() as RigidbodyActor
		
		obj.SpawnAsChild(self, Vector2(rand_x, 100.0), SwayAndRotate, RandomizeMassAndGravity)
		actor_ct += 1
		InfoLabel.text = "Actors Spawned: %d" % [actor_ct]
		accum = 0.0
