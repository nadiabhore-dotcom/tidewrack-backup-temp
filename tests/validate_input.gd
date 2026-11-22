extends SceneTree
## Run: godot --headless --path . --script tests/validate_input.gd
## Use real device events, not action_press(), to catch missing bindings.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player = load("res://scripts/player.gd").new()
	root.add_child(player)
	player.set_physics_process(false)
	var directions := {
		KEY_LEFT: Vector2.LEFT, KEY_RIGHT: Vector2.RIGHT,
		KEY_UP: Vector2.UP, KEY_DOWN: Vector2.DOWN,
	}
	for key in directions:
		var event := InputEventKey.new()
		event.keycode = key
		_check_movement(player, event, directions[key], "keyboard %s" % key)
	for axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		for direction in [-1.0, 1.0]:
			var event := InputEventJoypadMotion.new()
			event.axis = axis
			event.axis_value = direction
			var expected := Vector2(direction, 0) if axis == JOY_AXIS_LEFT_X else Vector2(0, direction)
			_check_movement(player, event, expected, "stick %s/%s" % [axis, direction])
	for key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		var event := InputEventKey.new()
		event.keycode = key
		var action := "ui_cancel" if key == KEY_ESCAPE else "ui_accept"
		_check_action(event, action)
	for button in [JOY_BUTTON_A, JOY_BUTTON_B]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		_check_action(event, "ui_accept" if button == JOY_BUTTON_A else "ui_cancel")
	player.free()
	if failures == 0:
		print("PASS: keyboard and controller movement, accept/cancel, and movement lock")
	quit(1 if failures else 0)


func _send(event: InputEvent, pressed: bool) -> void:
	event = event.duplicate()
	if event is InputEventJoypadMotion:
		if not pressed:
			event.axis_value = 0.0
	else:
		event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _check_movement(player: Node2D, event: InputEvent, expected: Vector2, label: String) -> void:
	player.position = Vector2(640, 360)
	player.can_move = true
	_send(event, true)
	player._physics_process(0.1)
	_expect(player.position.is_equal_approx(Vector2(640, 360) + expected * 22.0), label)
	player.can_move = false
	var before := player.position
	player._physics_process(0.1)
	_expect(player.position == before, label + " movement lock")
	_send(event, false)
	_expect(Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") == Vector2.ZERO, label + " release")


func _check_action(event: InputEvent, action: String) -> void:
	_send(event, true)
	_expect(Input.is_action_pressed(action), action + " press: " + event.as_text())
	_send(event, false)
	_expect(not Input.is_action_pressed(action), action + " release")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
