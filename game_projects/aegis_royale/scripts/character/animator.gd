class_name CharacterAnimator
extends Node

## Procedural pose driver. Keeps the rig readable without needing imported
## animation clips: leg cycle, arm counter-swing, aim stance, crouch, air pose.

var model: CharacterModel
var phase: float = 0.0
var lean: float = 0.0
var aim_blend: float = 0.0
var crouch_blend: float = 0.0
var hip_base_y: float = 0.90

func setup(m: CharacterModel) -> void:
	model = m
	hip_base_y = m.hips.position.y

func pose(delta: float, planar_speed: float, run_speed: float, aiming: bool, aim_pitch: float,
		grounded: bool, vertical_speed: float, crouching: bool, dead: bool) -> void:
	if model == null:
		return
	if dead:
		_death_pose(delta)
		return
	var t: float = clampf(planar_speed / maxf(run_speed, 0.001), 0.0, 1.0)
	if grounded:
		phase += delta * lerpf(3.2, 12.5, t)
	else:
		phase += delta * 1.6
	aim_blend = lerpf(aim_blend, 1.0 if aiming else 0.0, delta * 12.0)
	crouch_blend = lerpf(crouch_blend, 1.0 if crouching else 0.0, delta * 10.0)

	var swing: float = sin(phase) * lerpf(0.06, 0.80, t)
	var counter: float = -swing
	var bounce: float = absf(sin(phase)) * lerpf(0.0, 0.045, t)

	if not grounded:
		var air: float = clampf(vertical_speed * 0.06, -0.6, 0.6)
		model.hip_l.rotation.x = lerpf(model.hip_l.rotation.x, -0.5 + air, delta * 9.0)
		model.hip_r.rotation.x = lerpf(model.hip_r.rotation.x, 0.25 + air, delta * 9.0)
		model.knee_l.rotation.x = lerpf(model.knee_l.rotation.x, -0.9, delta * 9.0)
		model.knee_r.rotation.x = lerpf(model.knee_r.rotation.x, -0.35, delta * 9.0)
	else:
		model.hip_l.rotation.x = swing
		model.hip_r.rotation.x = counter
		model.knee_l.rotation.x = -maxf(0.0, -swing) * 1.15 - 0.06
		model.knee_r.rotation.x = -maxf(0.0, -counter) * 1.15 - 0.06

	var crouch_drop: float = crouch_blend * 0.30
	model.hips.position.y = hip_base_y - crouch_drop + bounce
	model.hips.rotation.x = lean + crouch_blend * 0.12

	var forward_arm: float = PI * 0.5 - aim_pitch
	var right_x: float = lerpf(-counter * 0.7, forward_arm - 0.10, aim_blend)
	var left_x: float = lerpf(swing * 0.7, forward_arm - 0.18, aim_blend)
	model.shoulder_r.rotation = Vector3(right_x, lerpf(0.0, -0.16, aim_blend), lerpf(0.0, -0.10, aim_blend))
	model.shoulder_l.rotation = Vector3(left_x, lerpf(0.0, 0.30, aim_blend), lerpf(0.0, 0.16, aim_blend))
	model.elbow_r.rotation.x = lerpf(-0.20 - maxf(0.0, counter) * 0.6, -0.34, aim_blend)
	model.elbow_l.rotation.x = lerpf(-0.20 - maxf(0.0, swing) * 0.6, -0.62, aim_blend)
	model.head.rotation.x = clampf(aim_pitch * 0.55, -0.5, 0.5)

func set_lean(amount: float) -> void:
	lean = amount

func _death_pose(delta: float) -> void:
	model.hips.rotation.x = lerpf(model.hips.rotation.x, 1.45, delta * 6.0)
	model.hips.position.y = lerpf(model.hips.position.y, 0.32, delta * 6.0)
	model.head.rotation.x = lerpf(model.head.rotation.x, -0.4, delta * 6.0)
	model.shoulder_l.rotation.x = lerpf(model.shoulder_l.rotation.x, 0.4, delta * 6.0)
	model.shoulder_r.rotation.x = lerpf(model.shoulder_r.rotation.x, 0.4, delta * 6.0)
	model.knee_l.rotation.x = lerpf(model.knee_l.rotation.x, -0.5, delta * 6.0)
	model.knee_r.rotation.x = lerpf(model.knee_r.rotation.x, -0.5, delta * 6.0)
