extends TileMapLayer
# Orientation 
func get_cell_orientation(coords: Vector2i) -> int:
	var orientation: int
	
	# Get cell orientation using object metadata
	# Ensure cast to MoreTileData
	var cell: MoreTileData = get_cell_tile_data(coords) as MoreTileData
	
	"""
	if cell.has_meta("orientation"):
		orientation = cell.get_meta("orientation")
	else:
		cell.set_meta("orientation", 0)
		orientation = 0
	"""
	
	return cell.orientation

func increment_orientation(obj: MoreTileData):
	obj.orientation =  ((obj.orientation + 1) % 6)

# Movement delta
func get_cell_movement(coords: Vector2i) -> Vector2:
	var orientation = get_cell_orientation(coords)
	var movement = Vector2i()

	match orientation:
		0:
			movement = Vector2i(1, 0)
		1:
			movement = Vector2i(0, 1)
		2:
			movement = Vector2i(-1, 1)
		3:
			movement = Vector2i(-1, 0)
		4:
			movement = Vector2i(-1, -1)
		5:
			movement = Vector2i(0, -1)
			

	return movement

func tile_iterate(coords: Vector2i, old_tile_map: TileMapLayer, new_tile_map: TileMapLayer):
	var tile_type = old_tile_map.get_cell_source_id(coords)
	var cell_data = old_tile_map.get_cell_tile_data(coords)

	match tile_type:
		# Source tile
		0:
			var new_person_spot_delta: Vector2i = get_cell_movement(coords)
			var new_person_spot: Vector2i = new_person_spot_delta + coords
			
			# Put new person there with orientation
			new_tile_map.set_cell(new_person_spot, 2, Vector2i(0, 0))
			
			# Copy orientation of this
			var new_person_data = new_tile_map.get_cell_tile_data(new_person_spot)
			new_person_data.set_meta("orientation", cell_data.get_meta("orientation"))
			
			increment_orientation(cell_data)
		# Building
		1:
			pass
		# Person
		2:
			var movement: Vector2i = get_cell_movement(coords)
			var new_expected_tile: Vector2i = coords + movement
			
			# Cut it
			new_tile_map.set_cell(coords, -1)
			
			# If empty space..
			var new_expected_tile_source_id = old_tile_map.get_cell_source_id(new_expected_tile)
			match new_expected_tile_source_id:
				# Empty space
				-1:
					# Increment times moved
					if cell_data.has_meta("times_moved"):
						var times_moved = cell_data.get_meta("times_moved")
						cell_data.set_meta("times_moved", times_moved + 1)
					else:
						cell_data.set_meta("times_moved", 1)
					
					# Move
					new_tile_map.set_cell(new_expected_tile, 2, Vector2i(0, 0))
					
					# Copy data
					var new_tile_map_data = new_tile_map.get_cell_tile_data(new_expected_tile)
					
					new_tile_map_data.set_meta("times_moved", cell_data.get_meta("times_moved"))
					new_tile_map_data.set_meta("orientation", cell_data.get_meta("orientation"))
					
					print(cell_data.get_meta("orientation") )
					
					
				# Building logic
				1:
					pass
				# Default = remove
				2:
					pass
			
			
			
func iterate() -> void:
	var used_cells = get_used_cells()
	var copy_tilemap: TileMapLayer = self.duplicate(true)
	
	for cell in used_cells:
		tile_iterate(cell, self, copy_tilemap)
	
	self.set_tile_map_data_from_array(copy_tilemap.tile_map_data)
	
	# Calculate additional tiles that must be calculated
	# (Empty tiles that may be created in the case of there being 4 people surrounding a tile, which creates a new structure)
	# (Functions as a set)
	var additional_to_calculate: Dictionary = {}

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Space or Enter
		iterate()
