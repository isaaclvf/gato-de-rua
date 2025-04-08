extends RigidBody2D

@export var push_force = 10.0

func _integrate_forces(state):
	# This helps prevent jitter when being pushed
	if linear_velocity.length() < 1.0:
		linear_velocity = Vector2.ZERO
