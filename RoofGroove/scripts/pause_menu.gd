extends CanvasLayer







const UI: = preload("res://scripts/ui_kit.gd")
const MAIN_MENU: = "res://sence/main_menu.tscn"

var _session: Node = null
var _open: = false
var _paused_before: = false
var _root: Control
var _main_view: VBoxContainer
var _tp_view: VBoxContainer
var _tp_list: VBoxContainer
var _title: Label


func setup(session: Node) -> void :
	_session = session


func _ready() -> void :
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _open


func open() -> void :
	if _open:
		return
	_open = true
	_paused_before = get_tree().paused
	get_tree().paused = true
	_show_main()
	_root.visible = true


func close() -> void :
	if not _open:
		return
	_open = false
	_root.visible = false
	get_tree().paused = _paused_before



func _build() -> void :
	_root = Control.new()
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim: = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: = CenterContainer.new()
	_root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var holder: = VBoxContainer.new()
	holder.custom_minimum_size = Vector2(440, 0)
	holder.add_theme_constant_override("separation", 14)
	center.add_child(holder)

	_title = UI.label("PAUSED", 34)
	holder.add_child(_title)


	_main_view = VBoxContainer.new()
	_main_view.add_theme_constant_override("separation", 12)
	holder.add_child(_main_view)
	_add_button(_main_view, "CONTINUE", close, 20, 56.0)
	_add_button(_main_view, "TELEPORT", _show_teleport, 20, 56.0)
	_add_button(_main_view, "MAIN MENU", _go_main_menu, 20, 56.0)


	_tp_view = VBoxContainer.new()
	_tp_view.add_theme_constant_override("separation", 12)
	holder.add_child(_tp_view)
	_tp_list = VBoxContainer.new()
	_tp_list.add_theme_constant_override("separation", 10)
	_tp_view.add_child(_tp_list)
	_add_button(_tp_view, "BACK", _show_main, 18, 48.0)


func _add_button(parent: Control, text: String, callback: Callable, size: int, height: float) -> Button:
	var b: = UI.button(text, size, height)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	parent.add_child(b)
	return b


func _show_main() -> void :
	_title.text = "PAUSED"
	_main_view.visible = true
	_tp_view.visible = false


func _show_teleport() -> void :
	_title.text = "TELEPORT"
	_main_view.visible = false
	_tp_view.visible = true
	_refresh_teleport_list()


func _refresh_teleport_list() -> void :
	for c in _tp_list.get_children():
		_tp_list.remove_child(c)
		c.queue_free()

	var best: = int(Network.best_checkpoint)
	var best_btn: = UI.button(tr("BEST CHECKPOINT %d") % best, 18, 52.0)
	best_btn.focus_mode = Control.FOCUS_NONE
	best_btn.disabled = best <= 0
	best_btn.pressed.connect(_teleport_to_checkpoint.bind(best))
	_tp_list.add_child(best_btn)

	var first_btn: = UI.button("FIRST CHECKPOINT", 18, 52.0)
	first_btn.focus_mode = Control.FOCUS_NONE
	first_btn.pressed.connect(_teleport_to_checkpoint.bind(0))
	_tp_list.add_child(first_btn)

	var positions: Dictionary = {}
	if _session != null and _session.has_method("get_player_positions"):
		positions = _session.get_player_positions()
	if positions.is_empty():
		_tp_list.add_child(UI.label("No other players in the game", 14, Color(0.8, 0.8, 0.85), 440.0))
	else:
		for id in positions:
			var pname: = str(Network.members.get(id, "Player"))
			var btn: = UI.button(tr("GO TO %s") % pname, 16, 48.0)
			btn.focus_mode = Control.FOCUS_NONE
			btn.pressed.connect(_teleport_to_player.bind(id))
			_tp_list.add_child(btn)



func _world() -> Node:
	return _session.get_parent() if _session != null else null


func _teleport_to_checkpoint(n: int) -> void :
	var world: = _world()
	if world == null or not world.has_method("teleport_to_checkpoint"):
		return
	close()
	world.call("teleport_to_checkpoint", n)


func _teleport_to_player(id: int) -> void :
	var world: = _world()
	if world == null or not world.has_method("teleport_to_position"):
		return
	var positions: Dictionary = _session.get_player_positions()
	if not positions.has(id):
		return
	close()
	world.call("teleport_to_position", positions[id])


func _go_main_menu() -> void :
	var was_in_room: = Network.in_room()
	Network.reset_run()
	if was_in_room:
		Network.leave()
	_open = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MAIN_MENU)



func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_cancel()


func _on_cancel() -> void :
	if not _open:
		if _session != null and _session.has_method("can_pause") and _session.can_pause():
			open()
	elif _tp_view.visible:
		_show_main()
	else:
		close()
