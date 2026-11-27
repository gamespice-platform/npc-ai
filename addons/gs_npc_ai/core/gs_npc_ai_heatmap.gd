class_name GSNpcAiHeatmap
extends RefCounted

## Where players go on a map, learned by watching them, and kept between rounds: a grid of cells with a weight per channel ([constant TRAFFIC], [constant DEATHS], or a game's own) that decays with a half-life, so it pictures recent play.
## Knowing where players GO lets a monster patrol the corridors they use and wait where they come through, not meet a wall. [method to_dictionary] and [method from_dictionary] keep it across restarts.

# No log channel: written by a game's tick and read by brains; the game logs persistence.

const TRAFFIC := &"traffic"
const DEATHS := &"deaths"

const META := &"gs_npc_ai_heatmap"

## Metres per cell. Three is about a corridor's width: fine enough that the left and the
## right corridor are different cells, coarse enough that a map is a few hundred of them.
var cell_size: float = 3.0

## Seconds for a cell's weight to halve with nothing added. Ten minutes is a few rounds:
## a map's habits outlast one round's oddities, and a new habit shows within a match.
var half_life: float = 600.0

## Cells kept per channel. The coldest go first when it is full. A map is a few hundred
## cells and a walked-on one a few dozen; this is a bound against a game that records
## something that is not on a floor.
var capacity: int = 4096

## Channel -> { Vector2i cell -> [weight, last_updated] }.
var _channels: Dictionary = {}
## Read-only stand-in for a channel with no cells, so lookups allocate nothing.
const _NONE := {}


## Adds [param weight] at [param position] in [param channel], at [param now].
func record(channel: StringName, position: Vector3, now: float, weight: float = 1.0) -> void:
	var cells: Dictionary = _channels.get(channel, _NONE)
	if cells.is_read_only():
		cells = {}
		_channels[channel] = cells
	var key := cell_of(position)
	var found: Variant = cells.get(key)
	if found is Array:
		# Updated in place: a heat source records every tick, and a fresh pair per call is garbage.
		var entry: Array = found
		entry[0] = _decayed(float(entry[0]), float(entry[1]), now) + weight
		entry[1] = now
	else:
		cells[key] = [weight, now]

	if cells.size() > capacity:
		_evict(cells, now)


## The weight of [param channel] at [param position], decayed to [param now].
func value_at(channel: StringName, position: Vector3, now: float) -> float:
	var cells: Dictionary = _channels.get(channel, _NONE)
	var entry: Variant = cells.get(cell_of(position))

	if not (entry is Array):
		return 0.0

	return _decayed(float(entry[0]), float(entry[1]), now)


## The centres of the [param count] hottest cells of [param channel] within [param radius]
## of [param near], hottest first. Only cells at or above [param minimum].
func hottest(
	channel: StringName,
	near: Vector3,
	radius: float,
	now: float,
	count: int = 4,
	minimum: float = 0.5
) -> Array[Vector3]:
	var cells: Dictionary = _channels.get(channel, _NONE)
	var scored: Array = []
	var radius_sq := radius * radius

	for key in cells.keys():
		var centre := centre_of(key)
		var flat := centre - Vector3(near.x, centre.y, near.z)

		if flat.length_squared() > radius_sq:
			continue

		var entry: Array = cells[key]
		var weight := _decayed(float(entry[0]), float(entry[1]), now)

		if weight >= minimum:
			scored.append([weight, centre])

	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))

	var out: Array[Vector3] = []

	for i in mini(count, scored.size()):
		out.append(scored[i][1])

	return out


## The heaviest direction of travel through [param position]'s neighbourhood: the sum of
## the directions to the hotter neighbouring cells. What an ambusher faces — the way the
## traffic comes from. Zero where there is no gradient.
func flow_at(channel: StringName, position: Vector3, now: float) -> Vector3:
	var here := value_at(channel, position, now)
	var sum := Vector3.ZERO

	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			if dx == 0 and dz == 0:
				continue

			var offset := Vector3(dx, 0, dz) * cell_size
			var gain := value_at(channel, position + offset, now) - here

			if gain > 0.0:
				sum += offset.normalized() * gain

	return sum.normalized() if sum.length_squared() > 0.0001 else Vector3.ZERO


func cell_of(position: Vector3) -> Vector2i:
	return Vector2i(floori(position.x / cell_size), floori(position.z / cell_size))


## The centre of [param cell], on the floor (y 0) — a game snaps it to its navigation.
func centre_of(cell: Vector2i) -> Vector3:
	return Vector3((float(cell.x) + 0.5) * cell_size, 0.0, (float(cell.y) + 0.5) * cell_size)


func _decayed(weight: float, at: float, now: float) -> float:
	if half_life <= 0.0 or now <= at:
		return weight

	return weight * pow(0.5, (now - at) / half_life)


func _evict(cells: Dictionary, now: float) -> void:
	var coldest: Variant = null
	var coldest_weight := INF

	for key in cells.keys():
		var entry: Array = cells[key]
		var weight := _decayed(float(entry[0]), float(entry[1]), now)

		if weight < coldest_weight:
			coldest_weight = weight
			coldest = key

	if coldest != null:
		cells.erase(coldest)


func cell_count(channel: StringName) -> int:
	return (_channels.get(channel, _NONE) as Dictionary).size()


func clear() -> void:
	_channels.clear()



## A document of every channel, decayed to [param now] and stamped at zero, so a map loaded
## on a server whose clock started again carries the weights rather than the timestamps.
func to_dictionary(now: float) -> Dictionary:
	var channels := {}

	for channel in _channels.keys():
		var rows: Array = []
		var cells: Dictionary = _channels[channel]

		for key in cells.keys():
			var entry: Array = cells[key]
			var weight := _decayed(float(entry[0]), float(entry[1]), now)

			# Cells that have cooled to nothing are not worth a line in a file.
			if weight >= 0.01:
				rows.append([key.x, key.y, snappedf(weight, 0.001)])

		channels[String(channel)] = rows

	return {"version": 1, "cell_size": cell_size, "half_life": half_life, "channels": channels}


## Reads [method to_dictionary]'s document, stamping every cell at [param now].
## A different cell size is refused, not reinterpreted: three-metre cells read as two-metre put every hot corridor in the wrong place.
static func from_dictionary(data: Dictionary, now: float = 0.0) -> GSResult:
	var out := GSNpcAiHeatmap.new()
	out.cell_size = float(data.get("cell_size", out.cell_size))
	out.half_life = float(data.get("half_life", out.half_life))

	if out.cell_size <= 0.0:
		return GSResult.fail(GSError.CODE_INVALID, "A heat map needs a positive cell size.")

	var channels: Variant = data.get("channels", {})

	if not (channels is Dictionary):
		return GSResult.fail(GSError.CODE_INVALID, "A heat map's channels must be a dictionary.")

	for channel in (channels as Dictionary).keys():
		var rows: Variant = channels[channel]

		if not (rows is Array):
			continue

		var cells := {}

		for row in rows:
			if row is Array and (row as Array).size() >= 3:
				cells[Vector2i(int(row[0]), int(row[1]))] = [float(row[2]), now]

		out._channels[StringName(channel)] = cells

	return GSResult.success(out)


## Writes this to [param path] as JSON. For a game keeping a map's heat across restarts.
func save(path: String, now: float) -> GSResult:
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return GSResult.fail(
			GSError.CODE_IO, "Could not write the heat map.", error_string(FileAccess.get_open_error())
		)

	file.store_string(JSON.stringify(to_dictionary(now)))
	file.close()
	GSWeb.sync_filesystem()
	return GSResult.success(path)


## Reads a heat map written by [method save]. A missing file is not an error: it is a map
## nobody has played yet, and the result is an empty heat map.
static func load_from(path: String, now: float = 0.0) -> GSResult:
	if not FileAccess.file_exists(path):
		return GSResult.success(GSNpcAiHeatmap.new())

	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)

	if not (parsed is Dictionary):
		return GSResult.fail(GSError.CODE_PARSE, "The heat map file is not a JSON object.", path)

	return from_dictionary(parsed, now)


func attach(director: Node) -> void:
	if director != null:
		director.set_meta(META, self)


static func of(director: Object) -> GSNpcAiHeatmap:
	if director == null or not director.has_meta(META):
		return null

	return director.get_meta(META) as GSNpcAiHeatmap


func describe() -> Dictionary:
	var out := {"cell": cell_size, "half_life": half_life}

	for channel in _channels.keys():
		out[String(channel)] = (_channels[channel] as Dictionary).size()

	return out
