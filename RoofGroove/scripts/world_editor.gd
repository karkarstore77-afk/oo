extends Node2D







const WorldData: = preload("res://scripts/world_data.gd")
const CustomWorld: = preload("res://scripts/custom_world.gd")
const UI: = preload("res://scripts/ui_kit.gd")
const SAFE_AREA: = preload("res://scripts/safe_area.gd")
const TILE: = 16
const DEPTH: = 6
const MENU_SCENE: = "res://sence/worlds_menu.tscn"
const SELF_SCENE: = "res://sence/world_editor.tscn"
const MAX_PER_ISLAND: = 3

enum Tool{PAN, ISLAND, MONSTER, FLAG, START, FINISH, ERASE}

const TOOL_NAMES: = {
	Tool.PAN: "MOVE", Tool.ISLAND: "ISLAND", Tool.MONSTER: "MONSTER", Tool.FLAG: "CHECKPOINT", 
	Tool.START: "START", Tool.FINISH: "FINISH", Tool.ERASE: "ERASE", 
}
const TOOL_HINTS: = {
	Tool.PAN: "Drag to move the camera", 
	Tool.ISLAND: "Drag sideways to draw an island (or just tap)", 
	Tool.MONSTER: "Tap an island to place a monster", 
	Tool.FLAG: "Tap an island to add or remove a checkpoint", 
	Tool.START: "Tap an island to set where you start", 
	Tool.FINISH: "Tap an island to set the finish", 
	Tool.ERASE: "Tap a monster or an island to delete it", 
}
const MONSTER_COLORS: = {
	"slime": Color(0.55, 0.3, 0.8), "bat": Color(0.8, 0.2, 0.3), "thorn": Color(0.6, 0.6, 0.65), 
	"charger": Color(1.0, 0.55, 0.15), "jumper": Color(0.3, 0.8, 0.4), 
}

static var edit_file: = ""

var world: Dictionary = {}
var file_id: = ""
var cur_tool: int = Tool.ISLAND
var monster_type: = "slime"

var _cam: Camera2D
var _zoom: = 2.0
var _dragging: = false
var _drag_a: = Vector2i.ZERO
var _drag_b: = Vector2i.ZERO
var _panning: = false
var _name_edit: LineEdit
var _info: Label
var _hint: Label
var _status: Label
var _status_t: = 0.0
var _monster_btn: Button
var _publish_btn: Button
var _tool_group: = ButtonGroup.new()


func _ready() -> void :
	Engine.time_scale = 1.0
	get_tree().paused = false
	file_id = edit_file
	if file_id != "":
		world = WorldData.load_local(file_id)
	if world.is_empty():
		file_id = WorldData.new_file_id()
		edit_file = file_id
		world = WorldData.empty_world()
		WorldData.save_local(world, file_id)
	var passed: = false
	if CustomWorld.test_mode:
		CustomWorld.test_mode = false
		if CustomWorld.test_finished:
			CustomWorld.test_finished = false
			world["verified"] = WorldData.content_hash(world)
			WorldData.save_local(world, file_id)
			passed = true
	_build_camera()
	_build_ui()
	_refresh()
	if passed:
		_say("TEST PASSED - you can publish this world")


func _build_camera() -> void :
	_cam = Camera2D.new()
	var s: Dictionary = (world["islands"] as Array)[int(world["start"])]
	_cam.position = Vector2((int(s["x"]) + int(s["w"]) * 0.5) * TILE, int(s["y"]) * TILE)
	add_child(_cam)
	_set_zoom(2.0)


func _set_zoom(z: float) -> void :
	_zoom = clampf(z, 0.5, 5.0)
	_cam.zoom = Vector2(_zoom, _zoom)
	queue_redraw()





func _build_ui() -> void :
	var layer: = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var safe: = MarginContainer.new()
	safe.set_script(SAFE_AREA)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(safe)
	var col: = VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	safe.add_child(col)


	var top: = HFlowContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("h_separation", 6)
	top.add_theme_constant_override("v_separation", 6)
	col.add_child(top)
	var menu: = UI.button("MENU", 14, 44.0)
	menu.pressed.connect(_go_menu)
	top.add_child(menu)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = tr("World name")
	_name_edit.max_length = WorldData.NAME_MAX
	_name_edit.text = str(world["name"])
	_name_edit.custom_minimum_size = Vector2(190, 44)
	_name_edit.text_changed.connect(_on_name_changed)
	top.add_child(_name_edit)
	var test: = UI.button("TEST", 14, 44.0)
	test.pressed.connect(_on_test)
	top.add_child(test)
	_publish_btn = UI.button("PUBLISH", 14, 44.0)
	_publish_btn.pressed.connect(_on_publish)
	top.add_child(_publish_btn)
	var zin: = UI.button("+", 16, 44.0)
	zin.custom_minimum_size.x = 48
	zin.pressed.connect( func() -> void : _set_zoom(_zoom * 1.25))
	top.add_child(zin)
	var zout: = UI.button("-", 16, 44.0)
	zout.custom_minimum_size.x = 48
	zout.pressed.connect( func() -> void : _set_zoom(_zoom / 1.25))
	top.add_child(zout)

	_info = UI.label("", 11, Color(1, 1, 1))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 4)
	col.add_child(_info)

	var mid: = Control.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(mid)

	_status = UI.label("", 14, Color(1, 0.85, 0.4))
	_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_status.add_theme_constant_override("outline_size", 5)
	col.add_child(_status)
	_hint = UI.label("", 11, Color(0.9, 0.9, 0.95))
	_hint.add_theme_color_override("font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override("outline_size", 4)
	col.add_child(_hint)


	var bottom: = HFlowContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = FlowContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("h_separation", 6)
	bottom.add_theme_constant_override("v_separation", 6)
	col.add_child(bottom)
	for t in TOOL_NAMES:
		var b: = UI.button(str(TOOL_NAMES[t]), 13, 46.0)
		b.toggle_mode = true
		b.button_group = _tool_group
		b.button_pressed = (t == cur_tool)
		b.pressed.connect(_select_tool.bind(t))
		bottom.add_child(b)
	_monster_btn = UI.button("", 13, 46.0)
	_monster_btn.pressed.connect(_cycle_monster)
	bottom.add_child(_monster_btn)


func _select_tool(t: int) -> void :
	cur_tool = t
	_dragging = false
	_refresh()


func _cycle_monster() -> void :
	var types: Array = WorldData.MONSTER_TYPES
	monster_type = str(types[(types.find(monster_type) + 1) % types.size()])
	_refresh()


func _on_name_changed(t: String) -> void :
	world["name"] = t.strip_edges().left(WorldData.NAME_MAX)
	WorldData.save_local(world, file_id)


func _say(text: String) -> void :
	_status.text = tr(text)
	_status_t = 3.5


func _refresh() -> void :
	var isl: Array = world["islands"]
	var fin_txt: = tr("yes") if int(world["finish"]) >= 0 else tr("NO")
	var test_txt: = tr("yes") if WorldData.is_verified(world) else tr("NO")
	_info.text = "%s %d/%d   %s %d/%d   %s %d   %s %s   %s %s" % [
		tr("ISLANDS"), isl.size(), WorldData.MAX_ISLANDS, 
		tr("MONSTERS"), (world["monsters"] as Array).size(), WorldData.MAX_MONSTERS, 
		tr("FLAGS"), (world["checkpoints"] as Array).size(), 
		tr("FINISH"), fin_txt, tr("TESTED"), test_txt]
	_hint.text = tr(str(TOOL_HINTS[cur_tool]))
	_monster_btn.text = tr("TYPE") + ": " + tr(monster_type.to_upper())
	_monster_btn.visible = cur_tool == Tool.MONSTER
	var pid: = str(world.get("published_id", ""))
	_publish_btn.text = tr("UPDATE") if pid != "" else tr("PUBLISH")
	queue_redraw()


func _process(delta: float) -> void :
	if _status_t > 0.0:
		_status_t -= delta
		if _status_t <= 0.0:
			_status.text = ""
	if not _name_edit.has_focus():
		var v: = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		if v != Vector2.ZERO:
			_cam.position += v * 420.0 / _zoom * delta
			queue_redraw()





func _unhandled_input(event: InputEvent) -> void :
	if event is InputEventMouseButton:
		var mb: = event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_set_zoom(_zoom * 1.15)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_set_zoom(_zoom / 1.15)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_panning = mb.pressed
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					get_viewport().gui_release_focus()
					_press(get_global_mouse_position())
				else:
					_release()
	elif event is InputEventMouseMotion:
		var mm: = event as InputEventMouseMotion
		if _panning or (cur_tool == Tool.PAN and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0):
			_cam.position -= mm.relative / _zoom
			queue_redraw()
		elif _dragging:
			_drag_b = _tile_at(get_global_mouse_position())
			queue_redraw()
	elif event.is_action_pressed("ui_cancel"):
		_go_menu()


func _tile_at(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func _island_at(p: Vector2) -> int:
	var t: = _tile_at(p)
	var isl: Array = world["islands"]
	for k in range(isl.size() - 1, -1, -1):
		var e: Dictionary = isl[k]
		if t.x >= int(e["x"]) and t.x < int(e["x"]) + int(e["w"]) and t.y >= int(e["y"]) and t.y < int(e["y"]) + DEPTH:
			return k
	return -1


func _monster_pos(m: Dictionary) -> Vector2:
	var e: Dictionary = (world["islands"] as Array)[int(m["i"])]
	var half: = int(e["w"]) * TILE * 0.5 - 10.0
	return Vector2((int(e["x"]) + int(e["w"]) * 0.5) * TILE + float(m["o"]) * half * 0.8, int(e["y"]) * TILE - 7.0)


func _press(p: Vector2) -> void :
	match cur_tool:
		Tool.ISLAND:
			_dragging = true
			_drag_a = _tile_at(p)
			_drag_b = _drag_a
			queue_redraw()
		Tool.MONSTER:
			_place_monster(p)
		Tool.FLAG:
			_toggle_checkpoint(p)
		Tool.START:
			var k: = _island_at(p)
			if k >= 0:
				world["start"] = k
				(world["checkpoints"] as Array).erase(k)
				if int(world["finish"]) == k:
					world["finish"] = -1
				_changed()
		Tool.FINISH:
			var k: = _island_at(p)
			if k < 0:
				return
			if k == int(world["start"]):
				_say("Finish must be a different island")
				return
			(world["checkpoints"] as Array).erase(k)
			world["finish"] = k
			_changed()
		Tool.ERASE:
			_erase(p)


func _release() -> void :
	if not _dragging:
		return
	_dragging = false
	var r: = _drag_rect()
	if _can_place(r):
		(world["islands"] as Array).append({"x": r.position.x, "y": r.position.y, "w": r.size.x})
		_changed()
	else:
		queue_redraw()



func _drag_rect() -> Rect2i:
	var w: = absi(_drag_a.x - _drag_b.x) + 1
	var x: = mini(_drag_a.x, _drag_b.x)
	if w < WorldData.MIN_W:
		w = 6
		x = _drag_a.x - 3
	w = clampi(w, WorldData.MIN_W, WorldData.MAX_W)
	x = clampi(x, 0, WorldData.X_MAX - w)
	return Rect2i(x, clampi(_drag_a.y, WorldData.Y_MIN, WorldData.Y_MAX), w, DEPTH)


func _overlaps(r: Rect2i) -> bool:
	for e in world["islands"]:
		var er: = Rect2i(int(e["x"]), int(e["y"]), int(e["w"]), DEPTH)
		if r.intersects(er):
			return true
	return false


func _can_place(r: Rect2i) -> bool:
	if (world["islands"] as Array).size() >= WorldData.MAX_ISLANDS:
		_say("Island limit reached")
		return false
	if _overlaps(r):
		_say("Islands can't overlap")
		return false
	return true


func _place_monster(p: Vector2) -> void :
	var k: = _island_at(p)
	if k < 0:
		_say("Tap an island")
		return
	var e: Dictionary = (world["islands"] as Array)[k]
	if int(e["w"]) < 3:
		_say("Island too small for a monster")
		return
	var mons: Array = world["monsters"]
	if mons.size() >= WorldData.MAX_MONSTERS:
		_say("Monster limit reached")
		return
	var here: = 0
	for m in mons:
		if int(m["i"]) == k:
			here += 1
	if here >= MAX_PER_ISLAND:
		_say("Too many monsters on this island")
		return
	var half: = int(e["w"]) * TILE * 0.5 - 10.0
	var cx: = (int(e["x"]) + int(e["w"]) * 0.5) * TILE
	mons.append({"t": monster_type, "i": k, "o": snappedf(clampf((p.x - cx) / (half * 0.8), -1.0, 1.0), 0.05)})
	_changed()


func _toggle_checkpoint(p: Vector2) -> void :
	var k: = _island_at(p)
	if k < 0:
		return
	if k == int(world["start"]) or k == int(world["finish"]):
		_say("Pick a different island")
		return
	var cps: Array = world["checkpoints"]
	if cps.has(k):
		cps.erase(k)
	elif cps.size() >= WorldData.MAX_CHECKPOINTS:
		_say("Checkpoint limit reached")
		return
	else:
		cps.append(k)
		cps.sort()
	_changed()


func _erase(p: Vector2) -> void :
	var mons: Array = world["monsters"]
	for j in range(mons.size() - 1, -1, -1):
		if p.distance_to(_monster_pos(mons[j])) < 12.0:
			mons.remove_at(j)
			_changed()
			return
	var k: = _island_at(p)
	if k < 0:
		return
	var isl: Array = world["islands"]
	if isl.size() <= 1:
		_say("A world needs at least one island")
		return
	isl.remove_at(k)

	var new_m: Array = []
	for m in mons:
		var i: = int(m["i"])
		if i == k:
			continue
		m["i"] = i - 1 if i > k else i
		new_m.append(m)
	world["monsters"] = new_m
	var new_c: Array = []
	for c in world["checkpoints"]:
		var ci: = int(c)
		if ci == k:
			continue
		new_c.append(ci - 1 if ci > k else ci)
	world["checkpoints"] = new_c
	var st: = int(world["start"])
	world["start"] = 0 if st == k else (st - 1 if st > k else st)
	var fi: = int(world["finish"])
	world["finish"] = -1 if fi == k else (fi - 1 if fi > k else fi)
	if int(world["start"]) == int(world["finish"]):
		world["finish"] = -1
	_changed()


func _changed() -> void :
	WorldData.save_local(world, file_id)
	_refresh()





func _on_test() -> void :
	if int(world["finish"]) < 0:
		_say("Place a FINISH on an island first")
		return
	WorldData.save_local(world, file_id)
	var t: = str(world["name"])
	CustomWorld.play(get_tree(), world.duplicate(true), t if t != "" else "Test", SELF_SCENE, true)


func _on_publish() -> void :
	var problem: = WorldData.publish_problem(world)
	if problem != "":
		_say(problem)
		return
	if not WorldData.signed_in():
		_say("Sign in with Google to publish")
		return
	_publish_btn.disabled = true
	_say("Publishing ...")
	var r: Dictionary = await WorldData.publish(world)
	if not is_inside_tree():
		return
	_publish_btn.disabled = false
	if bool(r.get("ok", false)):
		world["published_id"] = str(r["id"])
		WorldData.save_local(world, file_id)
		_refresh()
		_say("Published!")
	else:
		_say(str(r.get("error", "Could not reach the server")))


func _go_menu() -> void :
	WorldData.save_local(world, file_id)
	get_tree().change_scene_to_file(MENU_SCENE)


func _notification(what: int) -> void :
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_menu()





func _draw() -> void :
	if _cam == null:
		return
	var vp: = get_viewport_rect().size / _zoom
	var r: = Rect2(_cam.position - vp * 0.5, vp)
	draw_rect(r.grow(48.0), Color(0.34, 0.45, 0.72))

	var grid: = Color(1, 1, 1, 0.1)
	var gx: = floori(r.position.x / TILE) * TILE
	while gx <= r.end.x:
		draw_line(Vector2(gx, r.position.y), Vector2(gx, r.end.y), Color(1, 1, 1, 0.35) if gx == 0 else grid)
		gx += TILE
	var gy: = floori(r.position.y / TILE) * TILE
	while gy <= r.end.y:
		draw_line(Vector2(r.position.x, gy), Vector2(r.end.x, gy), Color(1, 1, 1, 0.35) if gy == 0 else grid)
		gy += TILE

	var isl: Array = world["islands"]
	for e in isl:
		var rect: = Rect2(int(e["x"]) * TILE, int(e["y"]) * TILE, int(e["w"]) * TILE, DEPTH * TILE)
		if not rect.intersects(r):
			continue
		draw_rect(rect, Color(0.82, 0.9, 0.99))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Color(1, 1, 1))
		draw_rect(rect, Color(0.25, 0.3, 0.5), false, 1.0)


	for c in world["checkpoints"]:
		_draw_flag(isl[int(c)], Color(0.35, 0.65, 1.0), "CP")
	_draw_flag(isl[int(world["start"])], Color(0.3, 0.9, 0.4), "START")
	var fi: = int(world["finish"])
	if fi >= 0:
		_draw_flag(isl[fi], Color(1.0, 0.82, 0.2), "FINISH")

	for m in world["monsters"]:
		var pos: = _monster_pos(m)
		var col: Color = MONSTER_COLORS.get(str(m["t"]), Color.WHITE)
		draw_circle(pos, 6.0, col)
		draw_arc(pos, 6.0, 0.0, TAU, 12, Color.BLACK, 1.0)
		draw_string(UI.FONT, pos + Vector2(-3, 3), str(m["t"]).left(1).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color.WHITE)

	if _dragging:
		var pr: = _drag_rect()
		var bad: = _overlaps(pr)
		var prect: = Rect2(pr.position.x * TILE, pr.position.y * TILE, pr.size.x * TILE, DEPTH * TILE)
		draw_rect(prect, Color(1, 0.3, 0.3, 0.5) if bad else Color(1, 1, 1, 0.45))
		draw_string(UI.FONT, prect.position + Vector2(2, -3), str(pr.size.x), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color.WHITE)


func _draw_flag(e: Dictionary, color: Color, text: String) -> void :
	var fx: = int(e["x"]) * TILE + 24.0
	var by: = int(e["y"]) * TILE * 1.0
	draw_line(Vector2(fx, by), Vector2(fx, by - 28.0), Color.WHITE, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(fx, by - 28.0), Vector2(fx + 14.0, by - 21.0), Vector2(fx, by - 14.0)]), color)
	draw_string(UI.FONT, Vector2(fx - 20.0, by - 32.0), text, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 7, Color.WHITE)
