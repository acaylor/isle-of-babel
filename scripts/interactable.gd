class_name Interactable
extends StaticBody3D
## A solid object the player can target with the camera ray and activate
## with E. Builders attach a prompt string and a Callable to run.

var prompt := "Interact"
var action: Callable

static func make(shape: Shape3D, prompt_text: String, on_interact: Callable, xform := Transform3D.IDENTITY) -> Interactable:
	var node := Interactable.new()
	node.prompt = prompt_text
	node.action = on_interact
	node.transform = xform
	var cs := CollisionShape3D.new()
	cs.shape = shape
	node.add_child(cs)
	return node

func interact(player: Node) -> void:
	if action.is_valid():
		action.call(player)
