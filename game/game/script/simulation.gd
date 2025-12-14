extends TileMapLayer
# Orientation 
func get_cell_orientation(coords: Vector2i) -> int:
	var orientation = 0
	
	orientation += 1 if is_cell_flipped_h(coords) else 0
	orientation += 2 if is_cell_flipped_v(coords) else 0
	
	return orientation
	
# movement (Equal to NESW)
func get_cell_movement(coords: Vector2i) -> Vector2:
	var orientation = get_cell_orientation(coords)
	var movement = Vector2i()
	
	match orientation:
		0:
			movement = Vector2i(0, 1)
		1:
			movement = Vector2i(1, 0)
		2:
			movement = Vector2i(0, -1)
		3:
			movement = Vector2i(-1, 0)
	
	return movement
func tile_iterate(coords: Vector2i, old_tile_map: TileMapLayer, new_tile_map: TileMapLayer) -> Array[Vector2i]:
	var cell_data = old_tile_map.get_cell_tile_data(coords)
	var tile_type = cell_data.terrain
	
	match tile_type:
		# Person
		# Move based off of cell movement
		# If new position will be ontop of a structure
		# Then don't commit to new movement and reverse
		# If person ontop of another person (or they both skip over each other if they are next to each other but 'skip' over each other, do some bounce logic
		# If they ram into eachother, turn the direction by 90 degrees clockwise. If one rams into someone but lets say one is facing right and one goes down into the person. Then the person continues right and down becomes left (clockwise).
		0:
			var movement: Vector2i = get_cell_movement(coords)
			var new_expected_tile: Vector2i = coords + movement
			
		# Structure
		# If 3 surrounding people to a structure, create a new person in the empty tile
		1:
			pass
		# Assuming empty tile, if 4 surrounding people, create a new structure
		_:
			
func iterate() -> void:
	var used_cells = get_used_cells()
	var copy_tilemap = self.duplicate(true)
	
	# Calculate additional tiles that must be calculated
	# (Empty tiles that may be created in the case of there being 4 people surrounding a tile, which creates a new structure)
	# (Functions as a set)
	var additional_to_calculate: Dictionary = {}
	
	for cell in used_cells:
		var potential_tiles_to_check = tile_iterate(cell, copy_tilemap, self)
		
		# Append to dict if new
		
	
	# Then index through the dictionary...


Can you finish this script in GDScript 4.4?
