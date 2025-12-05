extends TileMapLayer

# IMPORTANT: Don't confuse these two concepts:
# - source_id: The ID of the tileset source (usually 0 unless you have multiple tilesets)
# - tile_type: Our custom type to distinguish person (0) vs structure (1)

# Constants for tile types - adjust these to match your tileset!
const PERSON_ATLAS_COORDS = Vector2i(0, 0)  # Adjust to your person tile position
const STRUCTURE_ATLAS_COORDS = Vector2i(1, 0)  # Adjust to your structure tile position

# Orientation 
func get_cell_orientation(coords: Vector2i) -> int:
	var alternative = get_cell_alternative_tile(coords)
	
	# Decode orientation from alternative tile
	var orientation = 0
	if alternative == TileSetAtlasSource.TRANSFORM_FLIP_H:
		orientation = 1
	elif alternative == TileSetAtlasSource.TRANSFORM_FLIP_V:
		orientation = 2
	elif alternative == (TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V):
		orientation = 3
	
	return orientation
	
# movement (Equal to NESW)
func get_cell_movement(coords: Vector2i) -> Vector2i:
	var orientation = get_cell_orientation(coords)
	
	match orientation:
		0: return Vector2i(0, 1)   # South
		1: return Vector2i(1, 0)   # East
		2: return Vector2i(0, -1)  # North
		3: return Vector2i(-1, 0)  # West
		_: return Vector2i(0, 1)   # Default South

# Helper function to rotate direction clockwise
func rotate_clockwise(direction: Vector2i) -> Vector2i:
	return Vector2i(-direction.y, direction.x)

# Get alternative tile value for a given movement direction
func get_alternative_for_movement(movement: Vector2i) -> int:
	if movement == Vector2i(0, 1):  # South
		return 0
	elif movement == Vector2i(1, 0):  # East
		return TileSetAtlasSource.TRANSFORM_FLIP_H
	elif movement == Vector2i(0, -1):  # North
		return TileSetAtlasSource.TRANSFORM_FLIP_V
	elif movement == Vector2i(-1, 0):  # West
		return TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V
	return 0

# Determine tile type from atlas coordinates
func get_tile_type(atlas_coords: Vector2i) -> int:
	if atlas_coords == PERSON_ATLAS_COORDS:
		return 0  # Person
	elif atlas_coords == STRUCTURE_ATLAS_COORDS:
		return 1  # Structure
	return -1  # Unknown

func iterate() -> void:
	var used_cells = get_used_cells()
	if used_cells.is_empty():
		return
	
	print("\n=== Starting iteration ===")
	
	# Store the current state
	var current_state: Dictionary = {}
	
	# Read all cells
	for cell in used_cells:
		var source_id = get_cell_source_id(cell)
		if source_id == -1:
			continue  # Invalid cell
			
		var atlas_coords = get_cell_atlas_coords(cell)
		var alternative = get_cell_alternative_tile(cell)
		var tile_type = get_tile_type(atlas_coords)
		
		current_state[cell] = {
			"source_id": source_id,
			"atlas_coords": atlas_coords,
			"alternative": alternative,
			"tile_type": tile_type  # This must remain tile_type, not source_id!
		}
		
		if tile_type == 0:
			var movement = get_cell_movement(cell)
			print("Person at ", cell, " facing ", movement)
		elif tile_type == 1:
			print("Structure at ", cell)
	
	# Build new state
	var new_state: Dictionary = {}
	
	# Step 1: Copy all structures and check for person spawning
	for cell in current_state:
		var info = current_state[cell]
		if info.tile_type == 1:  # Structure
			# Keep structure in place
			new_state[cell] = info.duplicate()
			
			# Check surrounding cells for person spawning
			var adjacent_cells = [
				cell + Vector2i(0, 1),   # South
				cell + Vector2i(1, 0),   # East
				cell + Vector2i(0, -1),  # North
				cell + Vector2i(-1, 0)   # West
			]
			
			var people_count = 0
			var empty_pos = null
			
			for adj in adjacent_cells:
				if adj in current_state:
					if current_state[adj].tile_type == 0:  # Person
						people_count += 1
				else:
					# Empty cell
					empty_pos = adj
			
			# Spawn person if exactly 3 people surround this structure
			if people_count == 3 and empty_pos != null:
				var spawn_direction = empty_pos - cell
				new_state[empty_pos] = {
					"source_id": info.source_id,
					"atlas_coords": PERSON_ATLAS_COORDS,
					"alternative": get_alternative_for_movement(spawn_direction),
					"tile_type": 0
				}
				print("Structure at ", cell, " spawning person at ", empty_pos)
	
	# Step 2: Process all person movements
	# First, figure out where everyone wants to go
	var movement_map: Dictionary = {}  # from -> to
	var collision_map: Dictionary = {}  # to -> [from, from, ...]
	
	for cell in current_state:
		var info = current_state[cell]
		if info.tile_type == 0:  # Person
			var movement = get_cell_movement(cell)
			var target = cell + movement
			
			movement_map[cell] = target
			
			if not target in collision_map:
				collision_map[target] = []
			collision_map[target].append(cell)
	
	# Process each person
	var processed: Dictionary = {}
	
	for cell in current_state:
		var info = current_state[cell]
		if info.tile_type == 0:  # Person
			# Skip if already processed (e.g., newly spawned)
			if cell in new_state or cell in processed:
				continue
			
			var movement = get_cell_movement(cell)
			var target = cell + movement
			
			# Check what's at the target position
			var target_is_structure = false
			var target_is_person = false
			
			# Check if target is a structure (in current or new state)
			if target in current_state and current_state[target].tile_type == 1:
				target_is_structure = true
			elif target in new_state and new_state[target].tile_type == 1:
				target_is_structure = true
			
			# Check if target will have a person
			if target in current_state and current_state[target].tile_type == 0:
				target_is_person = true
			
			if target_is_structure:
				# Hit a structure - bounce (reverse direction immediately)
				movement = -movement
				new_state[cell] = {
					"source_id": info.source_id,
					"atlas_coords": PERSON_ATLAS_COORDS,
					"alternative": get_alternative_for_movement(movement),
					"tile_type": 0
				}
				processed[cell] = true
				print("Person at ", cell, " bounced off structure, now facing ", movement)
				
			elif len(collision_map.get(target, [])) > 1:
				# Multiple people want this cell
				var others_wanting_target = collision_map[target]
				
				# Check for swap (two people moving into each other)
				var can_swap = false
				if target_is_person and target in movement_map:
					var target_destination = movement_map[target]
					if target_destination == cell:
						# They want to swap!
						can_swap = true
						
				if can_swap:
					# Perform swap
					new_state[target] = {
						"source_id": info.source_id,
						"atlas_coords": PERSON_ATLAS_COORDS,
						"alternative": info.alternative,  # Keep same direction
						"tile_type": 0
					}
					processed[cell] = true
					print("Person swapping from ", cell, " to ", target)
				else:
					# Collision - rotate clockwise and stay in place
					movement = rotate_clockwise(movement)
					new_state[cell] = {
						"source_id": info.source_id,
						"atlas_coords": PERSON_ATLAS_COORDS,
						"alternative": get_alternative_for_movement(movement),
						"tile_type": 0
					}
					processed[cell] = true
					print("Person at ", cell, " rotated due to collision, now facing ", movement)
			else:
				# Clear to move
				new_state[target] = {
					"source_id": info.source_id,
					"atlas_coords": PERSON_ATLAS_COORDS,
					"alternative": info.alternative,  # Keep same direction
					"tile_type": 0
				}
				processed[cell] = true
				print("Person moved from ", cell, " to ", target)
	
	# Step 3: Check for structure spawning (4 people around empty tile)
	# First, find all empty cells that are adjacent to people
	var empty_cells: Dictionary = {}
	
	for pos in new_state:
		if new_state[pos].tile_type == 0:  # Person
			var adjacent = [
				pos + Vector2i(0, 1),
				pos + Vector2i(1, 0),
				pos + Vector2i(0, -1),
				pos + Vector2i(-1, 0)
			]
			
			for adj in adjacent:
				# Check if this cell is empty (not in new_state)
				if not adj in new_state:
					empty_cells[adj] = true
	
	# Now check each empty cell to see if it has 4 people around it
	for empty_pos in empty_cells:
		var adjacent = [
			empty_pos + Vector2i(0, 1),
			empty_pos + Vector2i(1, 0),
			empty_pos + Vector2i(0, -1),
			empty_pos + Vector2i(-1, 0)
		]
		
		var people_count = 0
		var sample_source_id = 0
		
		for adj in adjacent:
			if adj in new_state and new_state[adj].tile_type == 0:
				people_count += 1
				if sample_source_id == 0:
					sample_source_id = new_state[adj].source_id
		
		if people_count == 4:
			# Spawn a structure!
			new_state[empty_pos] = {
				"source_id": sample_source_id,
				"atlas_coords": STRUCTURE_ATLAS_COORDS,
				"alternative": 0,
				"tile_type": 1
			}
			print("Spawning structure at ", empty_pos, " (surrounded by 4 people)")
	
	# Step 4: Apply the new state
	print("Applying new state: ", new_state.size(), " cells")
	clear()
	
	for pos in new_state:
		var info = new_state[pos]
		if info.source_id >= 0:
			set_cell(pos, info.source_id, info.atlas_coords, info.alternative)
	
	print("=== Iteration complete ===\n")

# Manual iteration
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		iterate()

# Helper to set up a test pattern
func setup_test_pattern() -> void:
	clear()
	var source = 0  # Change this if your tiles are in a different source
	
	# Test 1: People that will collide
	set_cell(Vector2i(0, 0), source, PERSON_ATLAS_COORDS, TileSetAtlasSource.TRANSFORM_FLIP_H)  # East
	set_cell(Vector2i(2, 0), source, PERSON_ATLAS_COORDS, TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V)  # West
	
	# Test 2: Person heading toward structure
	set_cell(Vector2i(5, 0), source, PERSON_ATLAS_COORDS, 0)  # South
	set_cell(Vector2i(5, 2), source, STRUCTURE_ATLAS_COORDS, 0)  # Structure
	
	# Test 3: Setup for structure spawning (4 people around empty)
	set_cell(Vector2i(10, 0), source, PERSON_ATLAS_COORDS, 0)  # South - top person
	set_cell(Vector2i(9, 1), source, PERSON_ATLAS_COORDS, TileSetAtlasSource.TRANSFORM_FLIP_H)  # East - left person
	set_cell(Vector2i(11, 1), source, PERSON_ATLAS_COORDS, TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V)  # West - right person
	set_cell(Vector2i(10, 2), source, PERSON_ATLAS_COORDS, TileSetAtlasSource.TRANSFORM_FLIP_V)  # North - bottom person
	# Empty at (10, 1) should spawn structure
	
	# Test 4: Structure surrounded by 3 people (should spawn 4th)
	set_cell(Vector2i(15, 5), source, STRUCTURE_ATLAS_COORDS, 0)  # Structure
	set_cell(Vector2i(15, 4), source, PERSON_ATLAS_COORDS, 0)  # Person above
	set_cell(Vector2i(14, 5), source, PERSON_ATLAS_COORDS, 0)  # Person left
	set_cell(Vector2i(15, 6), source, PERSON_ATLAS_COORDS, 0)  # Person below
	# Should spawn person at (16, 5)
	
	print("Test pattern set up - Press Enter/Space to iterate")

# Helper to create a box of 4 people facing inward (should create structure in center)
func create_structure_spawn_setup(center: Vector2i, source_id: int = 0) -> void:
	# Place 4 people facing toward center
	set_cell(center + Vector2i(0, -1), source_id, PERSON_ATLAS_COORDS, 0)  # Top, facing south
	set_cell(center + Vector2i(1, 0), source_id, PERSON_ATLAS_COORDS, TileSetAtlasSource.TRANSFORM_FLIP_H | TileSetAtlasSource.TRANSFORM_FLIP_V)  # Right, facing west
	set_cell(center + Vector2i(0, 1), source_id, PERSON_ATLAS_COORDS, TileSetAtlasSource.TRANSFORM_FLIP_V)  # Bottom, facing north
	set_cell(center + Vector2i(-1, 0), source_id, PERSON_ATLAS_COORDS, TileSetAtlasSource.TRANSFORM_FLIP_H)  # Left, facing east
	print("Created structure spawn setup at ", center)
