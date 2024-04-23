extends PanelContainer

const ITEM_NODE = preload("res://scenes/modlist/mod_item.tscn")

@onready var list = $box/scroll/list
@onready var btn_disableall = $box/buttons/disableall
@onready var btn_enableall = $box/buttons/enableall
@onready var btn_modsdir = $box/buttons/modsdir

var has_changed_mods: bool = false

func _ready():
	var infos = ModLoader.loaded_mod_info
	if infos.size() > 0:
		for mod in infos:
			add_mod_item(infos[mod])
	else:
		list.get_node("nomods").visible = true
		btn_disableall.disabled = true
		btn_enableall.disabled = true
	
	btn_disableall.connect("pressed", disable_all_mods)
	btn_enableall.connect("pressed", enable_all_mods)
	btn_modsdir.connect("pressed", OS.shell_open.bind(ProjectSettings.globalize_path(Global.mods_path)))
	
	$box/buttons/apiver.text = "API Version: " + ModLoader.API_VERSION

func add_mod_item(info: Dictionary):
	var item = ITEM_NODE.instantiate()
	
	item.custom_minimum_size = Vector2(0, 100)
	
	item.name = info["id"]
	
	item.get_node("item/info/name").text = info["name"]
	item.get_node("item/info/desc").text = info["description"]
	
	# Set a tooltip, so users can see the text while hovering over
	item.get_node("item/info/desc").tooltip_text = info["description"]
	item.get_node("item/info/name").tooltip_text = info["name"]
	
	if info.has("icon"):
		if info["icon"] is Texture2D:
			item.get_node("item/icon").texture = info["icon"]
	
	
	item.get_node("item/enabled").connect("toggled", enable_toggled.bind(info["id"]))
	
	item.get_node("item/enabled").set_pressed_no_signal((not Global.disabled_mods.has(info["id"])))
	
	list.add_child(item)

func enable_toggled(toggled: bool, id: String):
	#print("Toggled 'enabled' for " + id + ", value: " + str(toggled))
	
	if not toggled:
		if not Global.disabled_mods.has(id):
			Global.disabled_mods.push_back(id)
			
			#print("Disabled mod " + id)
			has_changed_mods = true
		
	elif Global.disabled_mods.has(id):
		Global.disabled_mods.erase(id)
		#print("Enabled mod " + id)
		
		has_changed_mods = true

func enable_all_mods():
	for item in list.get_children():
		if item == list.get_node("nomods"): continue
		
		item.get_node("item/enabled").button_pressed = true

func disable_all_mods():
	for item in list.get_children():
		if item == list.get_node("nomods"): continue
		
		item.get_node("item/enabled").button_pressed = false
