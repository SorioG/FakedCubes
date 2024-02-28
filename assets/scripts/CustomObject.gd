extends Sprite2D

@export var image_data: String

func _ready():
	var data = Marshalls.base64_to_raw(image_data)
	
	var img = Image.new()
	var err = img.load_png_from_buffer(data)
	
	if err != OK:
		#print("Failed to load custom object: Invalid image")
		queue_free()
		return
	
	var tex = ImageTexture.create_from_image(img)
	
	texture = tex
