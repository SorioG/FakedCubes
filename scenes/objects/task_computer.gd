extends InteractableObject

var task_type: int = 1
var already_completed: bool = false

var fake_task_titles = [
	"WARNING: FAKE",
	"FAKE",
	"AAAAAA",
	"oh hello :)",
	"Nice Computer, can i have it?",
	"I'm staring at you.",
	"Um, woof?",
	"Egg! Egg! Where-",
	"You vs anyone, can you win?",
	"2763",
	"get a load of this guy",
	"clip loves ya",
	"dont give your uuid, i dare you not to"
]

func _ready():
	super()
	
	task_type = 1

func on_used(_action: int):
	if _action != 1: return
	var player = c_game.local_player
	if player:
		if already_completed:
			Global.alert("This task is already completed")
			return
		if player.current_role == Global.PLAYER_ROLE.IMPOSTOR:
			player.hud.get_node("FakeTask").popup_centered()
			player.hud.get_node("FakeTask/AspectRatio/VBox/Title").text = fake_task_titles.pick_random()
		elif task_type == 1:
			var task_math = player.hud.get_node("TaskMath")
			task_math.popup_centered()
			var num1 = randi_range(1, 10)
			var num2 = randi_range(1, 10)
			task_math.get_node("AspectRatio/VBox/MathProblem").text = "{0} + {1}".format([num1, num2])
			player.hud.task_current_node_path = str(get_path())
			player.hud.task_math_correct_answer = (num1 + num2)
