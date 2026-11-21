extends RefCounted
## Kontroller koddan kurulur, Project Settings > Input Map'e dokunmaya gerek yok.
## WASD / ok tuslari = yuru, sol tik = turev at, Q veya Space = Agir Atlama, E = Logaritma


static func setup() -> void:
	if InputMap.has_action("shoot"):
		return  # zaten kurulmus (sahne yeniden yuklendiginde)
	_keys("move_left", [KEY_A, KEY_LEFT])
	_keys("move_right", [KEY_D, KEY_RIGHT])
	_keys("move_up", [KEY_W, KEY_UP])
	_keys("move_down", [KEY_S, KEY_DOWN])
	_keys("ulti_slam", [KEY_Q, KEY_SPACE])
	_keys("ulti_log", [KEY_E])

	InputMap.add_action("shoot")
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("shoot", mb)


static func _keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
