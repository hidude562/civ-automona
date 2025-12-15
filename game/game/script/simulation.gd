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

# Movement (Equal to NESW for hex)
func get_cell_movement(coords: Vector2i) -> Vector2i:
	var orientation = get_cell_orientation(coords)
	match orientation:
		0: return Vector2i(1, 0)
		1: return Vector2i(0, 1)
		2: return Vector2i(-1, 1)
		3: return Vector2i(-1, 0)
		4: return Vector2i(-1, -1)
		5: return Vector2i(0, -1)
	return Vector2i()

func tile_iterate(coords: Vector2i, old_tile_map: TileMapLayer, new_tile_map: TileMapLayer, new_data_map: Dictionary):
	var tile_type = old_tile_map.get_cell_source_id(coords)
	
	match tile_type:
		# Source tile
		0:
			var new_person_spot_delta: Vector2i = get_cell_movement(coords)
			var new_person_spot: Vector2i = new_person_spot_delta + coords
			
			# Put new person there
			new_tile_map.set_cell(new_person_spot, 2, Vector2i(0, 0))
			
			# Create new cell data with copied orientation
			var new_data = Resource.new()
			new_data.set_script(CellDataScript)
			new_data.orientation = get_cell_data(coords).orientation
			new_data_map[new_person_spot] = new_data
			
			# Increment source orientation
			increment_orientation(coords)
			
		# Building
		1:
			pass
			
		# Person
		2:
			var movement: Vector2i = get_cell_movement(coords)
			var new_expected_tile: Vector2i = coords + movement
			
			# Cut it from new map
			new_tile_map.set_cell(coords, -1)
			
			var new_expected_tile_source_id = old_tile_map.get_cell_source_id(new_expected_tile)
			match new_expected_tile_source_id:
				# Empty space
				-1:
					var current_data = get_cell_data(coords)
					current_data.times_moved += 1
					
					# Move tile
					new_tile_map.set_cell(new_expected_tile, 2, Vector2i(0, 0))
					
					# Move data to new position
					new_data_map[new_expected_tile] = current_data
					
				# Building logic
				1:
					pass
				# Collision with person = remove
				2:
					pass

func iterate() -> void:
	var used_cells = get_used_cells()
	var copy_tilemap: TileMapLayer = self.duplicate(true)
	var new_data_map: Dictionary = {}
	
	for cell in used_cells:
		tile_iterate(cell, self, copy_tilemap, new_data_map)
	
	self.set_tile_map_data_from_array(copy_tilemap.tile_map_data)
	
	# Update cell data map with new positions
	# Keep source tiles (type 0) data, replace everything else
	var sources_to_keep: Dictionary = {}
	for cell in get_used_cells():
		if get_cell_source_id(cell) == 0:
			sources_to_keep[cell] = cell_data_map.get(cell)
	
	cell_data_map = new_data_map
	cell_data_map.merge(sources_to_keep, true)

func _input(event):
	if event.is_action_pressed("ui_accept"):
		iterate()
