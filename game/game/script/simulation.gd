extends TileMapLayer

@export var person_source_id: int = 0
@export var structure_source_id: int = 1

func get_cell_orientation(coords: Vector2i) -> int:
	var alt = get_cell_alternative_tile(coords)
	var orientation = 0
	if alt & TileSetAtlasSource.TRANSFORM_FLIP_H:
		orientation += 2
	if alt & TileSetAtlasSource.TRANSFORM_FLIP_V:
		orientation += 1
	return orientation

func get_cell_movement(orientation: int) -> Vector2i:
	match orientation:
		0: return Vector2i(0, 1)   # South
		1: return Vector2i(1, 0)   # East
		2: return Vector2i(0, -1)  # North
		3: return Vector2i(-1, 0)  # West
	return Vector2i.ZERO

func orientation_to_alt_tile(orientation: int) -> int:
	var alt = 0
	if orientation & 1:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if orientation & 2:
		alt |= TileSetAtlasSource.TRANSFORM_FLIP_V
	return alt

func rotate_clockwise(orientation: int) -> int:
	return (orientation + 1) % 4

func reverse_orientation(orientation: int) -> int:
	return (orientation + 2) % 4


class CellState:
	var source_id: int
	var atlas_coords: Vector2i
	var orientation: int
	var alt_tile: int
	
	func _init(src: int, atlas: Vector2i, ori: int, alt: int):
		source_id = src
		atlas_coords = atlas
		orientation = ori
		alt_tile = alt
	
	func duplicate() -> CellState:
		return CellState.new(source_id, atlas_coords, orientation, alt_tile)


func is_person(source_id: int) -> bool:
	return source_id == person_source_id

func is_structure(source_id: int) -> bool:
	return source_id == structure_source_id


func iterate() -> void:
	# Snapshot current state
	var old_state: Dictionary = {}  # Vector2i -> CellState
	
	for cell in get_used_cells():
		var src = get_cell_source_id(cell)
		var atlas = get_cell_atlas_coords(cell)
		var ori = get_cell_orientation(cell)
		var alt = get_cell_alternative_tile(cell)
		old_state[cell] = CellState.new(src, atlas, ori, alt)
	
	# Track intended movements: where each person WANTS to go
	var intended_dest: Dictionary = {}   # from_pos -> dest_pos
	var movers_to_dest: Dictionary = {}  # dest_pos -> Array of from_pos
	
	# Gather all intended moves for people
	for cell in old_state:
		var state: CellState = old_state[cell]
		if is_person(state.source_id):
			var movement = get_cell_movement(state.orientation)
			var dest = cell + movement
			intended_dest[cell] = dest
			
			if not movers_to_dest.has(dest):
				movers_to_dest[dest] = []
			movers_to_dest[dest].append(cell)
	
	# Determine which moves are blocked
	var blocked: Dictionary = {}  # from_pos -> new_orientation
	
	for dest in movers_to_dest:
		var movers: Array = movers_to_dest[dest]
		
		# Case: Multiple people trying to move to same cell
		if movers.size() > 1:
			for from_pos in movers:
				blocked[from_pos] = rotate_clockwise(old_state[from_pos].orientation)
			continue
		
		var from_pos: Vector2i = movers[0]
		var mover_state: CellState = old_state[from_pos]
		
		# Case: Destination has a structure
		if old_state.has(dest) and is_structure(old_state[dest].source_id):
			blocked[from_pos] = reverse_orientation(mover_state.orientation)
			continue
		
		# Case: Destination has a person
		if old_state.has(dest) and is_person(old_state[dest].source_id):
			var dest_person_dest = intended_dest.get(dest, dest)  # Where is dest person going?
			
			# Head-on collision: they're trying to swap
			if dest_person_dest == from_pos:
				blocked[from_pos] = rotate_clockwise(mover_state.orientation)
				continue
			
			# Dest person is stationary (not moving at all)
			if not intended_dest.has(dest):
				blocked[from_pos] = rotate_clockwise(mover_state.orientation)
				continue
			
			# Otherwise: dest person is moving away, so this move MIGHT succeed
			# (depends on whether dest person's move succeeds - resolved below)
	
	# Propagate blocking through chains
	# If A wants to move to B's spot, and B is blocked, then A is also blocked
	var changed = true
	while changed:
		changed = false
		for from_pos in intended_dest:
			if blocked.has(from_pos):
				continue  # Already blocked
			
			var dest = intended_dest[from_pos]
			
			# Check if destination has a person who is now blocked
			if old_state.has(dest) and is_person(old_state[dest].source_id):
				if blocked.has(dest):
					# The person we're following got blocked, so we're blocked too
					blocked[from_pos] = rotate_clockwise(old_state[from_pos].orientation)
					changed = true
	
	# Now determine final positions
	var new_state: Dictionary = {}  # Vector2i -> CellState (for final output)
	
	# Place blocked people (stay in place with new orientation)
	for from_pos in blocked:
		var state: CellState = old_state[from_pos].duplicate()
		state.orientation = blocked[from_pos]
		state.alt_tile = orientation_to_alt_tile(state.orientation)
		new_state[from_pos] = state
	
	# Place successfully moving people
	for from_pos in intended_dest:
		if blocked.has(from_pos):
			continue
		var dest = intended_dest[from_pos]
		var state: CellState = old_state[from_pos].duplicate()
		new_state[dest] = state
	
	# Copy structures (they don't move)
	for cell in old_state:
		if is_structure(old_state[cell].source_id):
			new_state[cell] = old_state[cell]
	
	# Structure spawning: 3 people around structure -> spawn in empty spot
	for cell in old_state:
		var state: CellState = old_state[cell]
		if not is_structure(state.source_id):
			continue
		
		var surrounding = get_surrounding_cells(cell)
		var people_count = 0
		var empty_spots: Array[Dictionary] = []
		
		for i in surrounding.size():
			var neighbor = surrounding[i]
			if old_state.has(neighbor) and is_person(old_state[neighbor].source_id):
				people_count += 1
			elif not old_state.has(neighbor) and not new_state.has(neighbor):
				empty_spots.append({"pos": neighbor, "dir": i})
		
		if people_count == 3 and empty_spots.size() > 0:
			var spawn = empty_spots[0]
			var person_atlas = _find_person_atlas(old_state)
			var new_person = CellState.new(
				person_source_id, 
				person_atlas, 
				spawn["dir"], 
				orientation_to_alt_tile(spawn["dir"])
			)
			new_state[spawn["pos"]] = new_person
	
	# Empty cell with 4 surrounding people -> create structure
	var checked_empty: Dictionary = {}
	for cell in old_state:
		if not is_person(old_state[cell].source_id):
			continue
		for neighbor in get_surrounding_cells(cell):
			if old_state.has(neighbor) or checked_empty.has(neighbor):
				continue
			checked_empty[neighbor] = true
			
			# Count adjacent people in OLD state
			var people_count = 0
			for adj in get_surrounding_cells(neighbor):
				if old_state.has(adj) and is_person(old_state[adj].source_id):
					people_count += 1
			
			if people_count == 4 and not new_state.has(neighbor):
				var structure_atlas = _find_structure_atlas(old_state)
				new_state[neighbor] = CellState.new(structure_source_id, structure_atlas, 0, 0)
	
	# Apply new state to tilemap
	# First, erase all old cells
	for cell in old_state:
		erase_cell(cell)
	
	# Then set all new cells
	for cell in new_state:
		var state: CellState = new_state[cell]
		set_cell(cell, state.source_id, state.atlas_coords, state.alt_tile)


func _find_person_atlas(state: Dictionary) -> Vector2i:
	for cell in state:
		if is_person(state[cell].source_id):
			return state[cell].atlas_coords
	return Vector2i.ZERO

func _find_structure_atlas(state: Dictionary) -> Vector2i:
	for cell in state:
		if is_structure(state[cell].source_id):
			return state[cell].atlas_coords
	return Vector2i.ZERO
func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space or Enter
		iterate()    
