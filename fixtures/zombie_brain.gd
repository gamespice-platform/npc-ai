extends "res://addons/dot_npc_ai/runtime/dot_npc_ai_brain.gd"

## A brain for the self-test: a machine of three states over a tree of two branches.
## Extends a PATH, not [code]GSNpcAiBrain[/code], and the suite asserts it loads through GameSpice NPC's spawner: that is the shape a brain in a mounted GameSpice Cloud pack must have.

var chases: int = 0
var wanders: int = 0
var heard_something: int = 0


func _build() -> void:
	initial_state = &"idle"

	machine = GSNpcAiMachine.new()
	machine.add(
		GSNpcAiState.make(&"idle")
			.when(func(_c: GSNpcAiContext) -> bool: return npc.has_target(), &"chasing")
	)
	machine.add(
		GSNpcAiState.make(&"chasing")
			.when(func(_c: GSNpcAiContext) -> bool: return not npc.has_target(), &"searching")
	)
	machine.add(
		GSNpcAiState.make(&"searching")
			.when(func(_c: GSNpcAiContext) -> bool: return npc.has_target(), &"chasing")
			.after(3.0, &"idle")
	)

		# REACTIVE, because this is a guard followed by an action that never finishes: a plain sequence
		# resumes at the action and never asks the guard again, so the zombie chases a target it no longer
		# has for ever.
	tree = GSNpcAiSelector.new(&"root", [
		GSNpcAiSequence.reactive_with(&"chase", [
			GSNpcAiLeaf.Condition.new(&"has a target", _has_target),
			GSNpcAiLeaf.Action.new(&"walk at it", _chase),
		]),
		GSNpcAiLeaf.Action.new(&"wander", _wander),
	])


func _has_target(_ctx: GSNpcAiContext) -> bool:
	return npc.has_target()


func _chase(ctx: GSNpcAiContext) -> int:
	chases += 1

	# The last seen position, remembered for six seconds. What "searching" walks to.
	ctx.put(&"last_seen", target_position(), 6.0)

	steer_with_spacing(target_position(), tune(&"speed", 4.0), ctx.delta)

	return GSNpcAiNode.Status.RUNNING


func _wander(ctx: GSNpcAiContext) -> int:
	wanders += 1

	if ctx.blackboard.has(&"last_seen", ctx.now):
		heard_something += 1

	halt()

	return GSNpcAiNode.Status.RUNNING
