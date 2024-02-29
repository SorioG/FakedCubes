extends Node2D

@onready var camera = $camera
@onready var map = $map
@onready var spawns = $spawns
@onready var objects = $objects

var MAX_SPEED = 50

enum TOOL {
	SELECT,
	MOVE,
	DELETE,
	DRAW
}

enum DRAW_TOOL {
	SOLID,
	GROUND,
	ERASE
}

var current_tool = TOOL.SELECT

var current_draw_tool = DRAW_TOOL.SOLID

var selected_object: Node2D

var is_mouse_pressed: bool = false
var mouse_starting_pos: Vector2
var starting_pos: Vector2

var is_drawing: bool = false

var is_following_player = false

var current_game: Game

var gamemode: int

func _ready():
	$hud/tools/btns/selectbtn.connect("pressed", set_tool.bind(TOOL.SELECT))
	$hud/tools/btns/movebtn.connect("pressed", set_tool.bind(TOOL.MOVE))
	$hud/tools/btns/deletebtn.connect("pressed", set_tool.bind(TOOL.DELETE))
	$hud/tools/btns/drawbtn.connect("pressed", set_tool.bind(TOOL.DRAW))
	
	$hud/drawpanel/btns/solidbtn.connect("pressed", set_draw_tool.bind(DRAW_TOOL.SOLID))
	$hud/drawpanel/btns/groundbtn.connect("pressed", set_draw_tool.bind(DRAW_TOOL.GROUND))
	$hud/drawpanel/btns/erasebtn.connect("pressed", set_draw_tool.bind(DRAW_TOOL.ERASE))
	
	$hud/menu/btns/filebtn.get_popup().connect("id_pressed", _file_selected)
	$hud/menu/btns/objectbtn.get_popup().connect("id_pressed", _object_selected)
	$hud/menu/btns/gamebtn.get_popup().connect("id_pressed", _game_pressed)
	
	$hud/objecttool.connect("id_pressed", _object_tool_selected)
	$hud/gamemodemenu.connect("id_pressed", _gamemode_pressed)
	
	$hud/newfileconfirm.connect("confirmed", get_tree().reload_current_scene)
	
	$hud/customobjectfile.connect("file_selected", add_custom_object)
	$hud/savemapdiag.connect("file_selected", save_map)
	$hud/loadmapdiag.connect("file_selected", load_map)
	$hud/exportdiag.connect("file_selected", export_to_scene)
	
	setup_gamemodes()

func _process(_delta):
	set_cursor()
	
	if current_tool == TOOL.DRAW and is_drawing:
		draw_tile()
	
	if is_instance_valid(current_game):
		if is_following_player:
			if current_game.local_player:
				camera.position = current_game.local_player.position
			
			if is_mouse_pressed:
				is_following_player = false
		else:
			if current_game.local_player:
				if current_game.local_player.velocity != Vector2.ZERO:
					is_following_player = true
		
		$hud/tools.visible = false
	else:
		$hud/tools.visible = true

func draw_tile():
	var pos = map.local_to_map(get_local_mouse_position())
	if current_draw_tool == DRAW_TOOL.SOLID:
		map.set_cell(0, pos, 0, Vector2i(1, 0))
	elif current_draw_tool == DRAW_TOOL.GROUND:
		map.set_cell(0, pos, 0, Vector2i(0, 0))
	elif current_draw_tool == DRAW_TOOL.ERASE:
		map.set_cell(0, pos, -1)

func move_camera():
	var mv_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var mv_y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	var vel = Vector2(mv_x, mv_y)
	
	camera.position += vel * MAX_SPEED

func set_cursor():
	if is_mouse_pressed:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_DRAG)
	elif current_tool == TOOL.DRAW:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CROSS)
	else:
		DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)

func set_tool(t: TOOL):
	current_tool = t
	
	$hud/drawpanel.visible = (current_tool == TOOL.DRAW)
	
	if current_tool == TOOL.DRAW:
		current_draw_tool = DRAW_TOOL.SOLID

func set_draw_tool(t: DRAW_TOOL):
	current_draw_tool = t

func _exit_tree():
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			mouse_starting_pos = event.position
			starting_pos = camera.position
			is_mouse_pressed = event.pressed
		
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_drawing = event.pressed
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_tool == TOOL.SELECT:
				pass
	
	if event is InputEventMouseMotion:
		if is_mouse_pressed:
			camera.position = starting_pos - (event.position - mouse_starting_pos)



func _file_selected(id: int):
	if id == 0:
		$hud/newfileconfirm.popup_centered()
	elif id == 1:
		$hud/loadmapdiag.popup_centered_ratio()
	elif id == 2:
		$hud/savemapdiag.popup_centered_ratio()
	elif id == 3:
		Global.change_scene_file("res://scenes/menu_screen.tscn")
	elif id == 5:
		$hud/exportdiag.popup_centered_ratio()

func _object_selected(id: int):
	if id == 0:
		$hud/objecttool.popup()
	elif id == 1:
		for obj in objects.get_children():
			obj.queue_free()
		
		for spw in spawns.get_children():
			spw.queue_free()

func _object_tool_selected(id: int):
	if id == 0:
		var sprite = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/gameicon.png")
		sprite.position = camera.position
		sprite.add_to_group("Spawn", true)
		objects.add_child(sprite)
		
		#add_collision(sprite)
	elif id == 1:
		var sprite = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/computer.png")
		sprite.position = camera.position
		sprite.add_to_group("Computer", true)
		objects.add_child(sprite)
		
		#add_collision(sprite)
	elif id == 2:
		var sprite = Sprite2D.new()
		sprite.texture = load("res://assets/sprites/button1.png")
		sprite.position = camera.position
		sprite.add_to_group("ReportButton", true)
		objects.add_child(sprite)
		
		#add_collision(sprite)
	elif id == 3:
		$hud/customobjectfile.popup_centered_ratio()

func _game_pressed(id: int):
	if id == 0:
		if is_instance_valid(current_game):
			playtest()
		else:
			$hud/gamemodemenu.popup()

func _gamemode_pressed(id: int):
	var text = $hud/gamemodemenu.get_item_text(id)
	
	if text == "Lobby":
		gamemode = -1
	else:
		gamemode = id-1
	
	playtest()

func playtest():
	if is_instance_valid(current_game):
		is_following_player = false
		
		current_game.queue_free()
		
		$hud/menu/btns/gamebtn.get_popup().set_item_text(0, "Playtest")
		$hud/menu/btns/objectbtn.disabled = false
		$hud/menu/btns/filebtn.disabled = false
		
		$map.visible = true
		$spawns.visible = true
		$objects.visible = true
	else:
		if get_tree().get_nodes_in_group("Spawn").size() < 1:
			Global.alert("This map must have player spawns before playtesting")
			return
		
		var scene := get_packed_scene()
		
		if scene == null:
			Global.alert("Cannot playtest the map.")
			return
		
		var game = Global.GAME_NODE.instantiate()
		game.num_bots = 0
		
		if gamemode == -1:
			game.get_node("hud").visible = false
		
		Global.net_mode = Global.GAME_TYPE.SINGLEPLAYER
		
		add_child(game)
		
		if is_instance_valid(game.current_map):
			game.current_map.free()
		
		var cmap = scene.instantiate()
		
		game.is_using_custom_map = true
		
		game.current_map = cmap
		
		game.can_change_map = false
		
		game.get_node("map").add_child(cmap)
		
		game.move_players()
		
		game.connect("player_spawned", _player_spawned_signal)
		game.connect("game_ended", _game_ended)
		
		current_game = game
		
		is_following_player = true
		
		current_tool = TOOL.SELECT
		
		$hud/menu/btns/gamebtn.get_popup().set_item_text(0, "Stop Playtesting")
		$hud/menu/btns/objectbtn.disabled = true
		$hud/menu/btns/filebtn.disabled = true
		
		$map.visible = false
		$spawns.visible = false
		$objects.visible = false
		
		if gamemode != -1:
			game.current_gamemode = Global.game_modes[gamemode]
			
			var numbots = 1
			while game.can_start_game() != "OK":
				game.spawn_player(false, "Bot" + str(numbots), true, true)
				
				numbots += 1
				#game.num_bots += 1
			
			game._on_start_pressed.call_deferred()

func _player_spawned_signal(_plr: Player):
	pass

func _game_ended():
	Global.alert("This gamemode has now ended.")
	
	playtest()

func add_custom_object(path: String):
	var image = Image.load_from_file(path)
	
	var texture = ImageTexture.create_from_image(image)
	
	var sprite = Sprite2D.new()
	sprite.texture = texture
	sprite.position = camera.position
	sprite.name = path.md5_text()
	sprite.add_to_group("CustomObject", true)
	objects.add_child(sprite)
	
	#add_collision(sprite)

func add_collision(node: Sprite2D):
	var area = Area2D.new()
	
	var col = CollisionShape2D.new()
	
	var ret = RectangleShape2D.new()
	
	ret.size = node.texture.get_size()
	col.shape = ret
	
	area.add_child(col)
	
	node.add_child(area)

func save_map(path: String):
	var writer := ZIPPacker.new()
	
	# Automatically add .fcmap to the end of name if it wasn't used
	if not path.ends_with(".fcmap"):
		path += ".fcmap"
	
	var err = writer.open(path)
	
	if err != OK:
		Global.alert("Failed to save map")
		return
	
	var mapdata = JSON.stringify(get_map_json())
	
	writer.start_file("map.json")
	writer.write_file(mapdata.to_utf8_buffer())
	writer.close_file()
	
	var objdata = JSON.stringify(get_object_json())
	
	writer.start_file("objects.json")
	writer.write_file(objdata.to_utf8_buffer())
	writer.close_file()
	
	writer.start_file("version.txt")
	writer.write_file(Global.version.to_utf8_buffer())
	writer.close_file()
	
	var saved_filenames := [] # To Avoid duplicate file names
	
	for cobj in get_tree().get_nodes_in_group("CustomObject"):
		if cobj is Sprite2D:
			var filename = cobj.name + ".png"
			
			if saved_filenames.has(filename): continue
			
			var image: Image = cobj.texture.get_image()
			
			var buffer = image.save_png_to_buffer()
			
			writer.start_file(filename)
			writer.write_file(buffer)
			writer.close_file()
			
			saved_filenames.push_back(filename)
		
	
	writer.close()
	
	Global.alert("Successfully saved map to file")

func load_map(path: String):
	var reader := ZIPReader.new()
	
	var err = reader.open(path)
	
	if err != OK:
		Global.alert("Failed to load map: Invalid .fcmap file")
		return
	
	if not (reader.file_exists("version.txt") and reader.file_exists("map.json")):
		Global.alert("Failed to load map: Invalid .fcmap file")
		return
	
	
	var mapversion := reader.read_file("version.txt").get_string_from_utf8()
	
	if mapversion != Global.version:
		Global.alert("Failed to load map: Version mismatch (" + mapversion + ")")
		reader.close()
		return
	
	#var progress: float = 0
	
	LoadingScreen.show_screen()
	LoadingScreen.loadlabel.text = "Loading Map..."
	LoadingScreen.set_progress(0)
	
	var mapdata := reader.read_file("map.json")
	var mapjson = JSON.parse_string(mapdata.get_string_from_utf8())
	
	load_map_json(mapjson)
	
	LoadingScreen.loadlabel.text = "Adding Objects..."
	LoadingScreen.set_progress(50)
	
	var objdata := reader.read_file("objects.json")
	var objjson = JSON.parse_string(objdata.get_string_from_utf8())
	
	load_object_json(objjson, reader)
	
	reader.close()
	
	LoadingScreen.hide_screen()

func get_map_json() -> Dictionary:
	var data := {}
	for cell in map.get_used_cells(0):
		var id = map.get_cell_source_id(0, cell)
		var atlas = map.get_cell_atlas_coords(0, cell)
		
		data[str(cell.x) + "," + str(cell.y)] = {
			"id": id,
			"atlas": {
				"x": atlas.x,
				"y": atlas.y
			}
		}
	
	return data

func get_object_json() -> Array:
	var data := []
	
	for obj in objects.get_children():
		if obj is Node2D:
			if obj.is_in_group("CustomObject"):
				data.push_back({
					"type": "custom",
					"pos": {
						"x": obj.position.x,
						"y": obj.position.y
					},
					"filename": obj.name + ".png"
				})
			
			else:
				for group in obj.get_groups():
					if not group.begins_with("_"):
						data.push_back({
							"type": group.to_lower(),
							"pos": {
								"x": obj.position.x,
								"y": obj.position.y
							},
						})
						break
	
	return data

func load_map_json(data: Dictionary):
	map.clear()
	for cell in data:
		var split = cell.split(",")
		var pos = Vector2i(int(split[0]), int(split[1]))
		var info = data[cell]
		
		map.set_cell(0, pos, info["id"], Vector2i(info["atlas"]["x"], info["atlas"]["y"]))

func load_object_json(data: Array, reader: ZIPReader):
	_object_selected(1)
	
	for obj in data:
		var type = obj["type"]
		var pos = Vector2(obj["pos"]["x"], obj["pos"]["y"])
		if type == "custom":
			var image = Image.new()
			var imgdata = reader.read_file(obj["filename"])
			
			image.load_png_from_buffer(imgdata)
			
			var texture = ImageTexture.create_from_image(image)
			
			var sprite = Sprite2D.new()
			sprite.texture = texture
			sprite.position = pos
			sprite.name = obj["filename"].split(".")[0]
			sprite.add_to_group("CustomObject", true)
			objects.add_child(sprite)
			
			add_collision(sprite)
		elif type == "computer":
			var sprite = Sprite2D.new()
			sprite.texture = load("res://assets/sprites/computer.png")
			sprite.position = pos
			sprite.add_to_group("Computer", true)
			objects.add_child(sprite)
			
			add_collision(sprite)
		elif type == "spawn":
			var sprite = Sprite2D.new()
			sprite.texture = load("res://assets/sprites/gameicon.png")
			sprite.position = pos
			sprite.add_to_group("Spawn", true)
			objects.add_child(sprite)
			
			add_collision(sprite)
		elif type == "reportbutton":
			var sprite = Sprite2D.new()
			sprite.texture = load("res://assets/sprites/button1.png")
			sprite.position = pos
			sprite.add_to_group("ReportButton", true)
			objects.add_child(sprite)
			
			add_collision(sprite)

func setup_gamemodes():
	var gamemodes = Global.game_modes
	
	var gm_options: PopupMenu = $hud/gamemodemenu
	
	#gm_options.clear()
	
	for gm in gamemodes:
		gm_options.add_icon_item(gm["icon"], gm["name"])

func export_to_scene(path: String):
	
	if get_tree().get_nodes_in_group("Spawn").size() < 1:
		Global.alert("This map must have player spawns before exporting to a scene")
		return
	
	var pscene = get_packed_scene()
	
	if pscene == null:
		Global.alert("Failed to export to scene: This map cannot be packed")
		return
	
	var res = ResourceSaver.save(pscene, path)
	if res != OK:
		Global.alert("Failed to export to scene: Failed to save the scene")
	else:
		Global.alert("Successfully exported to scene")

func get_packed_scene() -> PackedScene:
	var base_map = preload("res://scenes/maps/base_map.tscn").instantiate()
	
	var tilemap: TileMap = base_map.get_node("TileMap")
	
	for cell in map.get_used_cells(0):
		var id = map.get_cell_source_id(0, cell)
		var atlas = map.get_cell_atlas_coords(0, cell)
		
		tilemap.set_cell(0, cell, id, atlas)
	
	var spawns2 = base_map.get_node("spawns")
	
	var i = 1
	for spawn in get_tree().get_nodes_in_group("Spawn"):
		var nd = Node2D.new()
		nd.name = "spawn" + str(i)
		nd.position = spawn.position
		
		spawns2.add_child(nd)
		nd.owner = base_map
		
		i += 1
	
	var computer = preload("res://scenes/objects/computer.tscn")
	for comp in get_tree().get_nodes_in_group("Computer"):
		var clone = computer.instantiate()
		
		clone.position = comp.position
		
		base_map.add_child(clone)
		
		clone.owner = base_map
	
	var reportbutton = preload("res://scenes/objects/reportbutton.tscn")
	for rep in get_tree().get_nodes_in_group("ReportButton"):
		var clone = reportbutton.instantiate()
		
		clone.position = rep.position
		
		base_map.add_child(clone)
		
		clone.owner = base_map
	
	for custom in get_tree().get_nodes_in_group("CustomObject"):
		var sprite = preload("res://assets/scripts/CustomObject.gd").new()
		
		var img: Image = custom.texture.get_image()
		
		var buff = img.save_png_to_buffer()
		
		sprite.image_data = Marshalls.raw_to_base64(buff)
		sprite.position = custom.position
		sprite.name = custom.name
		
		base_map.add_child(sprite)
		sprite.owner = base_map
	
	var pscene = PackedScene.new()
	var err = pscene.pack(base_map)
	
	if err != OK:
		#Global.alert("Failed to export to scene: This map cannot be packed")
		return null
	
	return pscene
