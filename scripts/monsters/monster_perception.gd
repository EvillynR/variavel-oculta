class_name MonsterPerception
extends Node3D
## Visão simples: distância, cone de visão e linha de visada por raycast.
## Fica na altura dos olhos do monstro.
## Audição (Etapa 5, Fase 3): evaluate_sound() diz se um SoundStimulus é
## ouvido e com que nível, segundo o HearingProfile do MonsterConfig.
## Só avalia o som; a decisão de investigar (estado, duplicatas) é do
## MonsterController, que recebe os estímulos em hear_stimulus /
## receive_sound_stimulus.

## Obstruções abaixo desta altura (m) não abafam o som (carteiras, mesas).
const LOW_OBSTACLE_HEIGHT := 1.0
## Camadas consideradas no teste de parede (cenário = camada 1).
const SOUND_OCCLUSION_MASK := 1

var config: MonsterConfig
var body: CharacterBody3D


func can_see(target: Node3D) -> bool:
	if target == null or config == null or body == null:
		return false
	# Prompt 2: escondida, só quem a viu entrar sabe onde ela está.
	if target.has_method("is_hidden") and target.is_hidden():
		return target.is_witness(body)

	var eye := global_position
	var target_points := [
		target.global_position + Vector3.UP * 1.4,
		target.global_position + Vector3.UP * 0.5,
	]
	var forward := -body.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	for point in target_points:
		var to_target: Vector3 = point - eye
		if to_target.length() > config.sight_distance:
			continue
		var flat := Vector3(to_target.x, 0.0, to_target.z)
		if flat.length() > 0.01:
			var angle := rad_to_deg(forward.angle_to(flat.normalized()))
			if angle > config.sight_fov_degrees * 0.5:
				continue
		if _has_line_of_sight(eye, point, target):
			return true
	return false


func _has_line_of_sight(from: Vector3, to: Vector3, target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target


## Resultado: {"heard": bool, "reaction": SoundStimulus.Reaction (OUT_OF_RANGE,
## BELOW_THRESHOLD, IGNORED_KIND, DEAF ou INVESTIGATE), "level": 0..1,
## "distance": m, "range": m, "occluded": bool}.
func evaluate_sound(stimulus: SoundStimulus) -> Dictionary:
	var result := {"heard": false, "reaction": SoundStimulus.Reaction.OUT_OF_RANGE,
		"level": 0.0, "distance": INF, "range": 0.0, "occluded": false}
	if stimulus == null or config == null or body == null:
		return result
	result["distance"] = body.global_position.distance_to(stimulus.position)

	if stimulus.scripted:
		result["heard"] = true
		result["level"] = 1.0
		result["reaction"] = SoundStimulus.Reaction.INVESTIGATE
		return result

	var hearing := config.get_hearing()
	if hearing.sensitivity <= 0.0:
		result["reaction"] = SoundStimulus.Reaction.DEAF
		return result
	if stimulus.kind in hearing.ignored_kinds:
		result["reaction"] = SoundStimulus.Reaction.IGNORED_KIND
		return result

	var intensity := stimulus.loudness * hearing.weight_for(stimulus.kind)
	if _is_occluded(stimulus):
		result["occluded"] = true
		intensity *= hearing.wall_occlusion
	var hear_range := hearing.hearing_radius * intensity * hearing.sensitivity
	result["range"] = hear_range
	if hear_range <= 0.0 or result["distance"] > hear_range:
		return result

	result["heard"] = true
	result["level"] = clampf(1.0 - result["distance"] / hear_range, 0.0, 1.0)
	if result["level"] < hearing.investigate_threshold:
		result["reaction"] = SoundStimulus.Reaction.BELOW_THRESHOLD
	else:
		result["reaction"] = SoundStimulus.Reaction.INVESTIGATE
	return result


## Parede entre o som e os "ouvidos" (altura dos olhos)? Ignora o próprio
## corpo, a fonte, personagens e obstáculos baixos (carteiras).
func _is_occluded(stimulus: SoundStimulus) -> bool:
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var to := stimulus.position + Vector3.UP * 1.2
	var exclude: Array[RID] = [body.get_rid()]
	if stimulus.source_body != null:
		exclude.append(stimulus.source_body.get_rid())
	for i in 6:
		var query := PhysicsRayQueryParameters3D.create(global_position, to, SOUND_OCCLUSION_MASK, exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		var collider: Object = hit.collider
		if collider is CharacterBody3D or hit.position.y < LOW_OBSTACLE_HEIGHT:
			exclude.append(hit.rid)
			continue
		return true
	return false
