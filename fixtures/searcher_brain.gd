extends "res://addons/gs_npc_ai/runtime/gs_npc_ai_brain.gd"

## A brain for the self-test: the shape a game's soldier takes, built from the base class's ready-made leaves. Tree: reactive selector of flee danger (a grenade beats everything), a reactive sequence on "has a target?" (attack slot walks at it, else surround), search, idle.
## No character of its own: the definition names one with `"skill"` in its meta and its squad with `"squad"`, the catalogue paths the suite asserts.

var chases: int = 0
var searches: int = 0
var idles: int = 0
var flees: int = 0
var surrounds: int = 0


func _build() -> void:
	tree = GSNpcAiSelector.new(&"root", [
		GSNpcAiLeaf.Action.new(&"flee", _flee),
		GSNpcAiSequence.reactive_with(&"fight", [
			GSNpcAiLeaf.Condition.new(&"has a target", _has_target),
			GSNpcAiSelector.new(&"engage", [
				GSNpcAiSequence.reactive_with(&"attack", [
					GSNpcAiLeaf.Condition.new(&"has a slot", _has_slot),
					GSNpcAiLeaf.Action.new(&"walk at it", _chase),
				] as Array[GSNpcAiNode]),
				GSNpcAiLeaf.Action.new(&"surround", _surround),
			] as Array[GSNpcAiNode]),
		] as Array[GSNpcAiNode]),
		GSNpcAiLeaf.Action.new(&"search", _search),
		GSNpcAiLeaf.Action.new(&"idle", _idle),
	] as Array[GSNpcAiNode])


func _has_target(_ctx: GSNpcAiContext) -> bool:
	return npc.has_target()


func _has_slot(_ctx: GSNpcAiContext) -> bool:
	return claim_attack_slot()


func _flee(ctx: GSNpcAiContext) -> int:
	var status := flee_danger(ctx, tune(&"speed", 4.0) * 1.3)

	if status != GSNpcAiNode.Status.FAILURE:
		flees += 1

	return status


func _chase(ctx: GSNpcAiContext) -> int:
	chases += 1

	var at := target_position(Vector3.INF)

	if at == Vector3.INF:
		halt()
		return GSNpcAiNode.Status.RUNNING

	var flat := at - npc.position()
	flat.y = 0.0

	if flat.length() < 1.0:
		halt()
		return GSNpcAiNode.Status.RUNNING

	steer_toward(at, tune(&"speed", 4.0), ctx.delta)
	return GSNpcAiNode.Status.RUNNING


func _surround(ctx: GSNpcAiContext) -> int:
	var status := surround(ctx, tune(&"speed", 4.0), tune(&"ring", 4.0))

	if status != GSNpcAiNode.Status.FAILURE:
		surrounds += 1

	return status


func _search(ctx: GSNpcAiContext) -> int:
	var status := search(ctx, tune(&"speed", 4.0))

	if status != GSNpcAiNode.Status.FAILURE:
		searches += 1

	return status


func _idle(_ctx: GSNpcAiContext) -> int:
	idles += 1
	halt()
	return GSNpcAiNode.Status.RUNNING
