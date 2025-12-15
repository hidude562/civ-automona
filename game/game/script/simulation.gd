# Your TileMapLayer script
extends TileMapLayer

# Per-cell data storage: Vector2i -> CellData
var cell_data_map: Dictionary = {}

# Preload the script for set_script usage
var CellDataScript = preload("res://script/CellData.gd")

func get_cell_data(coords: Vector2i) -> Resource:
	if not cell_data_map.has(coords):
		var data = Resource.new()
		data.set_script(CellDataScript)
		cell_data_map[coords] = data
	return cell_data_map[coords]

func remove_cell_data(coords: Vector2i) -> void:
	cell_data_map.erase(coords)

func move_cell_data(from: Vector2i, to: Vector2i) -> void:
	if cell_data_map.has(from):
		cell_data_map[to] = cell_data_map[from]
		cell_data_map.erase(from)

# Orientation 
func get_cell_orientation(coords: Vector2i) -> int:
	return get_cell_data(coords).orientation

func set_cell_orientation(coords: Vector2i, value: int) -> void:
	get_cell_data(coords).orientation = value

func increment_orientation(coords: Vector2i) -> void:
	var data = get_cell_data(coords)
	data.orientation = (data.orientation + 1) % 6

func get_movement_from_orientation(orientation, coords: Vector2i):
	var y_mod = abs(coords.y % 2)
	
	match orientation:
		0: return Vector2i(1, 0)
		1: return Vector2i(y_mod, 1)
		2: return Vector2i(-(1-y_mod), 1)
		3: return Vector2i(-1, 0)
		4: return Vector2i(-(1-y_mod), -1)
		5: return Vector2i(y_mod, -1)
	return Vector2i()

func get_cell_movement(coords: Vector2i) -> Vector2i:
	var orientation = get_cell_orientation(coords)
	return get_movement_from_orientation(orientation, coords)

func create_person_at(coords: Vector2i, orientation: int, tile_map: TileMapLayer, data_map: Dictionary) -> void:
	# Don't overwrite existing tiles
	if tile_map.get_cell_source_id(coords) != -1:
		return
	
	tile_map.set_cell(coords, 2, Vector2i(0, 0))
	
	var new_data = Resource.new()
	new_data.set_script(CellDataScript)
	new_data.orientation = orientation
	new_data.times_moved = 0
	data_map[coords] = new_data

func create_building_at(coords: Vector2i, tile_map: TileMapLayer, data_map: Dictionary) -> void:
	tile_map.set_cell(coords, 1, Vector2i(0, 0))
	# Buildings don't need data, so remove any existing
	data_map.erase(coords)

func tile_iterate(coords: Vector2i, old_tile_map: TileMapLayer, new_tile_map: TileMapLayer, new_data_map: Dictionary):
	var tile_type = old_tile_map.get_cell_source_id(coords)
	
	match tile_type:
		# Source tile
		0:
			var new_person_spot_delta: Vector2i = get_cell_movement(coords)
			var new_person_spot: Vector2i = new_person_spot_delta + coords
			
			# Create new person with source's current orientation
			var source_orientation = get_cell_orientation(coords)
			create_person_at(new_person_spot, source_orientation, new_tile_map, new_data_map)
			
			# Increment source orientation
			increment_orientation(coords)
			
		# Building
		1:
			pass
			
		# Person
		2:
			var movement: Vector2i = get_cell_movement(coords)
			var new_expected_tile: Vector2i = coords + movement
			var current_data = get_cell_data(coords)
			var current_orientation = current_data.orientation
			
			# Cut it from new map
			new_tile_map.set_cell(coords, -1)
			
			var new_expected_tile_source_id = old_tile_map.get_cell_source_id(new_expected_tile)
			match new_expected_tile_source_id:
				# Empty space
				-1:
					current_data.times_moved += 1
					
					# Check if person should become a building
					if current_data.times_moved >= 2:
						create_building_at(new_expected_tile, new_tile_map, new_data_map)
					else:
						# Move tile normally
						new_tile_map.set_cell(new_expected_tile, 2, Vector2i(0, 0))
						new_data_map[new_expected_tile] = current_data
					
				# Building - spawn 2 new people
				1:
					var building_coords = new_expected_tile
					
					# Orientation above (+1) and below (-1), wrapped around 0-5
					var orientation_above = (current_orientation + 4) % 6
					var orientation_below = (current_orientation - 4 + 6) % 6
					
					# Calculate spawn positions: one move outward from building
					var spawn_above = building_coords + get_movement_from_orientation(orientation_above, building_coords)
					var spawn_below = building_coords + get_movement_from_orientation(orientation_below, building_coords)
					
					# Creat  e the two new people
					create_person_at(spawn_above, orientation_above, new_tile_map, new_data_map)
					create_person_at(spawn_below, orientation_below, new_tile_map, new_data_map)
					
				# Collision with person = remove both
				2:
					pass

func iterate() -> void:
	var used_cells = get_used_cells()
	var copy_tilemap: TileMapLayer = self.duplicate(true)
	var new_data_map: Dictionary = {}
	
	for cell in used_cells:
		tile_iterate(cell, self, copy_tilemap, new_data_map)
	
	self.set_tile_map_data_from_array(copy_tilemap.tile_map_data)
	
	# Keep source tiles (type 0) data
	var sources_to_keep: Dictionary = {}
	for cell in get_used_cells():
		if get_cell_source_id(cell) == 0:
			sources_to_keep[cell] = cell_data_map.get(cell)
	
	cell_data_map = new_data_map
	cell_data_map.merge(sources_to_keep, true)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		iterate()
