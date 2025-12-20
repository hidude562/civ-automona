# Your TileMapLayer script
extends TileMapLayer

# Preload the script for set_script usage
var CellDataScriptPath = "res://script/CellData.gd"
#var CellDataScript = preload()

# Team colors as hue values (0.0 to 1.0)
const TEAM_HUES: Array[float] = [0.0, 0.33, 0.66, 0.15, 0.5, 0.85]

func _ready() -> void:
	setup_team_materials()

func setup_team_materials() -> void:
	# Create alternative tiles for each team with hue-shifted materials
	var ts = tile_set
	if ts == null:
		return
	
	for source_id in ts.get_source_count():
		var source = ts.get_source(ts.get_source_id(source_id))
		if source is TileSetAtlasSource:
			var atlas_source = source as TileSetAtlasSource
			# For each tile in the atlas
			for tile_idx in atlas_source.get_tiles_count():
				var tile_coords = atlas_source.get_tile_id(tile_idx)
				
				# Create alternatives for teams 1-5 (0 is base)
				for team in range(1, TEAM_HUES.size()):
					if not atlas_source.has_alternative_tile(tile_coords, team):
						atlas_source.create_alternative_tile(tile_coords, team)
					
					# Set modulate color based on team hue
					var tile_data = atlas_source.get_tile_data(tile_coords, team)
					tile_data.modulate = Color.from_hsv(TEAM_HUES[team], 0.7, 1.0)

func get_cell_data(coords: Vector2i) -> TileData:
	var cell_tile_data = get_cell_tile_data(coords)
	if "orientation" not in cell_tile_data:
		var script_copy = load(CellDataScriptPath)
		cell_tile_data.set_script(script_copy)
	return get_cell_tile_data(coords)

func get_cell_team(coords: Vector2i) -> int:
	return get_cell_data(coords).team

func set_cell_team(coords: Vector2i, value: int) -> void:
	get_cell_data(coords).team = value
	# Update the visual to match
	update_cell_visual(coords)

func update_cell_visual(coords: Vector2i) -> void:
	var source_id = get_cell_source_id(coords)
	if source_id == -1:
		return
	var atlas_coords = get_cell_atlas_coords(coords)
	var team = get_cell_team(coords)
	set_cell(coords, source_id, atlas_coords, team)

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

func set_cell_with_team(coords: Vector2i, source_id: int, atlas_coords: Vector2i, team: int) -> void:
	# Clamp team to valid range
	var alt_id = clampi(team, 0, TEAM_HUES.size() - 1)
	set_cell(coords, source_id, atlas_coords, alt_id)

func create_person_at(coords: Vector2i, orientation: int, team: int, tile_map: TileMapLayer) -> void:
	# Don't overwrite existing tiles
	if tile_map.get_cell_source_id(coords) != -1:
		return
	
	# Use team as alternative tile ID for coloring
	tile_map.set_cell_with_team(coords, 2, Vector2i(0, 0), team)
	
	var new_data = tile_map.get_cell_tile_data(coords)
	new_data.set_script(load(CellDataScriptPath))
	new_data.orientation = orientation
	new_data.times_moved = 0
	new_data.team = team

func create_building_at(coords: Vector2i, team: int, tile_map: TileMapLayer) -> void:
	tile_map.set_cell_with_team(coords, 1, Vector2i(0, 0), team)
	
	var new_data = tile_map.get_cell_tile_data(coords)
	new_data.set_script(load(CellDataScriptPath))
	new_data.team = team
	new_data.orientation = 0

func tile_iterate(coords: Vector2i, old_tile_map: TileMapLayer, new_tile_map: TileMapLayer):
	var tile_type = old_tile_map.get_cell_source_id(coords)
	
	match tile_type:
		# Source tile
		0:
			var new_person_spot_delta: Vector2i = get_cell_movement(coords)
			var new_person_spot: Vector2i = new_person_spot_delta + coords
			"""
			var cell_team = get_cell_team(coords)
			if cell_team == 0:
				set_cell_team(coords,  randi_range(0, 5))
			"""
			# Create new person with source's current orientation
			var source_orientation = get_cell_orientation(coords)
			create_person_at(new_person_spot, source_orientation, get_cell_team(coords), new_tile_map)
			
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
					if current_data.times_moved >= 3:
						create_building_at(new_expected_tile, current_data.team, new_tile_map)
					else:
						# Move tile normally with team color
						new_tile_map.set_cell_with_team(new_expected_tile, 2, Vector2i(0, 0), current_data.team)
						
					
				# Building - spawn 2 new people
				1:
					var building_coords = new_expected_tile
					
					# Transfer building team
					set_cell_team(building_coords, current_data.team)
					
					# Increment building orientation each time it's hit
					increment_orientation(building_coords)
					
					# Orientation above (+1) and below (-1), wrapped around 0-5
					var orientation_above = (current_orientation + 2) % 6
					var orientation_below = (current_orientation - 2 + 6) % 6 
					
					# Calculate spawn positions: one move outward from building
					var spawn_above = building_coords + get_movement_from_orientation(orientation_above, building_coords)
					var spawn_below = building_coords + get_movement_from_orientation(orientation_below, building_coords)
					
					# Create one new person based off orientation
					print(get_cell_orientation(building_coords))
					
					if(get_cell_orientation(building_coords) % 2 == 0):
						create_person_at(spawn_above, orientation_above, current_data.team, new_tile_map)
					else:
						create_person_at(spawn_below, orientation_below, current_data.team, new_tile_map)
					
					
				# Collision with person = remove both
				2:
					current_data.times_moved = 0
					# If team different..
					if true or get_cell_team(new_expected_tile) != current_data.team:
						# Remove
						pass
					else:
						create_person_at(coords, (current_data.orientation+2)%6, current_data.team, new_tile_map)

func iterate() -> void:
	var used_cells = get_used_cells()
	var copy_tilemap: TileMapLayer = self.duplicate(true)
	# Copy the helper method to the duplicate
	copy_tilemap.set_script(get_script())
	var new_data_map: Dictionary = {}
	
	for cell in used_cells:
		tile_iterate(cell, self, copy_tilemap)
	
	# Set this tilemap to new_data_map
	add_sibling(copy_tilemap)
	
	# Free self
	queue_free()

func _process(delta: float):
	pass
	#iterate()

func _input(event):
	if event.is_action_pressed("ui_accept"):
		iterate()
