extends "res://addons/gs_npc_ai/runtime/gs_npc_ai_brain.gd"

## A brain for the self-test: something that fights at range. Tree: reactive selector of flee danger, a reactive sequence on "has a target?" (the squad's one flank role goes round to its back, firing; otherwise suppress), search, idle.
## Counts the shots it was allowed to take, so the suite can ask whether it fired at all and whether it held fire when it should.

var shots: int = 0


func _build() -> void:
	tree = GSNpcAiSelector.new(&"root", [
		GSNpcAiLeaf.Action.new(&"flee", func(c: GSNpcAiContext) -> int: return flee_danger(c, 5.0)),
		GSNpcAiSequence.reactive_with(&"fight", [
			GSNpcAiLeaf.Condition.new(&"has a target", func(_c: GSNpcAiContext) -> bool: return npc.has_target()),
			GSNpcAiSelector.new(&"engage", [
				GSNpcAiSequence.reactive_with(&"flank", [
					GSNpcAiLeaf.Condition.new(&"flank role", func(_c: GSNpcAiContext) -> bool:
						return tactics() >= 0.5 and claim_role(ROLE_FLANK, 1)),
					GSNpcAiLeaf.Action.new(&"go round", _flank),
				] as Array[GSNpcAiNode]),
				GSNpcAiLeaf.Action.new(&"suppress", _engage),
			] as Array[GSNpcAiNode]),
		] as Array[GSNpcAiNode]),
		GSNpcAiLeaf.Action.new(&"search", func(c: GSNpcAiContext) -> int: return search(c, 4.0)),
		GSNpcAiLeaf.Action.new(&"idle", func(_c: GSNpcAiContext) -> int:
			halt()
			return GSNpcAiNode.Status.RUNNING),
	] as Array[GSNpcAiNode])


func _engage(ctx: GSNpcAiContext) -> int:
	var status := hold_range(ctx, tune(&"speed", 4.0), tune(&"near", 8.0), tune(&"far", 14.0))
	var muzzle := npc.position() + Vector3(0, 1.4, 0)

	if ready_to_fire(muzzle):
		var _aim := aim_solution(muzzle)
		shots += 1

	return status


var flanks: int = 0


func _flank(ctx: GSNpcAiContext) -> int:
	flanks += 1
	var center := target_position(Vector3.INF)

	if center == Vector3.INF:
		return GSNpcAiNode.Status.FAILURE

	var here := npc.position()
	var radius := (tune(&"near", 8.0) + tune(&"far", 14.0)) * 0.5
	var point := GSNpcAiTactics.ring_point(center, here, radius, _enemy_facing(center), flank_lead)
	var flat := point - here
	flat.y = 0.0

	if flat.length() > 1.0:
		steer_with_spacing(point, tune(&"speed", 4.0), ctx.delta)
	else:
		halt()

	face(center - here)
	var muzzle := here + Vector3(0, 1.4, 0)

	if ready_to_fire(muzzle):
		var _aim := aim_solution(muzzle)
		shots += 1

	return GSNpcAiNode.Status.RUNNING
