class_name GSNpcAiSquads
extends RefCounted

## Every squad in one world, by name. Put on a director so its brains can find theirs.
## A brain joins the squad its definition names (`"squad"` in its meta) or the one its game assigns. Metadata on the director, not [GSRegistry], as [GSNpcAiSkill]: two servers in one process must not share squads.

const META := &"gs_npc_ai_squads"

var _squads: Dictionary = {}

## Token settings every squad made from now on shares. Null leaves each squad its own (off) defaults.
var tokens: GSNpcAiTokenConfig = null

## [member GSNpcAiSquad.pull_reports] for every squad, made now or later.
var pull_reports: bool = false:
	set(value):
		pull_reports = value
		for found in _squads.values():
			(found as GSNpcAiSquad).pull_reports = value


## The squad called [param squad_name], made if it does not exist yet.
func squad(squad_name: StringName) -> GSNpcAiSquad:
	var found: GSNpcAiSquad = _squads.get(squad_name)

	if found == null:
		found = GSNpcAiSquad.new(squad_name)

		if tokens != null:
			found.tokens = tokens

		found.pull_reports = pull_reports

		_squads[squad_name] = found

	return found


func find(squad_name: StringName) -> GSNpcAiSquad:
	return _squads.get(squad_name)


## Drops squads nobody is in. A squad name per wave is a name per wave for ever otherwise.
func prune() -> int:
	var dropped := 0

	for key in _squads.keys():
		if (_squads[key] as GSNpcAiSquad).is_empty():
			_squads.erase(key)
			dropped += 1

	return dropped


func names() -> PackedStringArray:
	var out := PackedStringArray()

	for key in _squads.keys():
		out.append(String(key))

	return out


func attach(director: Node) -> void:
	if director != null:
		director.set_meta(META, self)


static func of(director: Object) -> GSNpcAiSquads:
	if director == null or not director.has_meta(META):
		return null

	return director.get_meta(META) as GSNpcAiSquads


func describe_lines() -> PackedStringArray:
	var out := PackedStringArray()

	for key in _squads.keys():
		out.append_array((_squads[key] as GSNpcAiSquad).describe_lines())

	return out
