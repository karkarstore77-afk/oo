extends Node






signal check_finished(info: Dictionary)

const FirebaseConfig: = preload("res://scripts/firebase_config.gd")
const UI: = preload("res://scripts/ui_kit.gd")

const AUTO_CHECK_DELAY: = 3.0
const RECHECK_EVERY: = 6.0 * 3600.0


var update_info_url: String = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/app/latest" % FirebaseConfig.PROJECT_ID

var latest: Dictionary = {}
var checking: = false

var _http: HTTPRequest
var _manual: = false
var _dialog: CanvasLayer
var _shown_version: = ""


var _dl: HTTPRequest
var _downloading: = false
var _save_path: = ""
var _box: VBoxContainer
var _bar: ProgressBar
var _pct_label: Label


func _ready() -> void :
	process_mode = Node.PROCESS_MODE_ALWAYS
	AppVersion.check_consistency()
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

	var timer: = Timer.new()
	timer.wait_time = RECHECK_EVERY
	timer.autostart = true
	timer.timeout.connect(_auto_check)
	add_child(timer)

	await get_tree().create_timer(AUTO_CHECK_DELAY).timeout
	_auto_check()


func _auto_check() -> void :
	if GameSettings.auto_update:
		check(false)


func current_version() -> String:
	return AppVersion.current()


func check(manual: bool = false) -> void :
	if checking:
		return
	checking = true
	_manual = manual
	var err: = _http.request(update_info_url)
	if err != OK:
		_finish({"ok": false, "error": "Could not start the check"})


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void :
	if result != HTTPRequest.RESULT_SUCCESS:
		_finish({"ok": false, "error": "No internet connection"})
		return
	if code != 200:
		_finish({"ok": false, "error": tr("Update info not found (%d)") % code})
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_finish({"ok": false, "error": "Bad update info"})
		return
	var info: = _extract(data as Dictionary)
	if str(info.get("version", "")) == "":
		_finish({"ok": false, "error": "Bad update info"})
		return
	info["ok"] = true
	info["current"] = current_version()
	info["available"] = is_newer(str(info["version"]), str(info["current"]))
	var min_version: = str(info.get("min_version", ""))
	info["required"] = min_version != "" and is_newer(min_version, str(info["current"]))
	_finish(info)



func _extract(data: Dictionary) -> Dictionary:
	var src: Dictionary = data
	if data.has("fields") and typeof(data["fields"]) == TYPE_DICTIONARY:
		src = {}
		var fields: Dictionary = data["fields"]
		for k in fields:
			if typeof(fields[k]) != TYPE_DICTIONARY:
				continue
			var typed: Dictionary = fields[k]
			for type_key in ["stringValue", "integerValue", "doubleValue", "booleanValue"]:
				if typed.has(type_key):
					src[k] = typed[type_key]
	var out: = {}
	for k in ["version", "min_version", "notes", "url", "url_android", "url_windows", "url_ios"]:
		out[k] = str(src.get(k, "")).strip_edges()
	var platform_url: = ""
	match OS.get_name():
		"Android":
			platform_url = str(out["url_android"])
		"Windows":
			platform_url = str(out["url_windows"])
		"iOS":
			platform_url = str(out["url_ios"])
	out["download_url"] = platform_url if platform_url != "" else str(out["url"])
	return out


static func is_newer(a: String, b: String) -> bool:
	var pa: = a.strip_edges().trim_prefix("v").trim_prefix("V").split(".")
	var pb: = b.strip_edges().trim_prefix("v").trim_prefix("V").split(".")
	for i in maxi(pa.size(), pb.size()):
		var x: = pa[i].to_int() if i < pa.size() else 0
		var y: = pb[i].to_int() if i < pb.size() else 0
		if x != y:
			return x > y
	return false


func _finish(info: Dictionary) -> void :
	checking = false
	latest = info
	check_finished.emit(info)
	if bool(info.get("ok", false)) and bool(info.get("available", false)):
		if _manual or str(info["version"]) != _shown_version:
			show_update_dialog()



func show_update_dialog() -> void :
	if _downloading:
		return
	if not bool(latest.get("available", false)):
		return
	_shown_version = str(latest.get("version", ""))
	_render_available()


func _is_required() -> bool:
	return bool(latest.get("required", false))



func _new_box() -> VBoxContainer:
	if _dialog == null or not is_instance_valid(_dialog):
		_dialog = CanvasLayer.new()
		_dialog.layer = 100
		add_child(_dialog)

		var dim: = ColorRect.new()
		dim.color = Color(0, 0, 0, 0.78)
		_dialog.add_child(dim)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var center: = CenterContainer.new()
		_dialog.add_child(center)
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

		var panel: = PanelContainer.new()
		center.add_child(panel)

		var margin: = MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + side, 28)
		panel.add_child(margin)

		_box = VBoxContainer.new()
		_box.custom_minimum_size = Vector2(480, 0)
		_box.add_theme_constant_override("separation", 14)
		margin.add_child(_box)
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_bar = null
	_pct_label = null
	return _box





func _render_available() -> void :
	var box: = _new_box()
	box.add_child(UI.label("UPDATE AVAILABLE", 28, Color(1, 0.85, 0.4)))
	box.add_child(UI.label(tr("Version %s is out\nYou have %s") % [latest["version"], current_version()], 16, Color.WHITE, 480.0))
	var notes: = str(latest.get("notes", ""))
	if notes != "":
		box.add_child(UI.label(notes, 14, Color(0.8, 0.8, 0.85), 480.0))

	var update_btn: = UI.button("UPDATE NOW", 20, 56.0)
	update_btn.pressed.connect(_on_update_pressed)
	box.add_child(update_btn)
	if not _is_required():
		var later_btn: = UI.button("LATER", 18, 48.0)
		later_btn.pressed.connect(_close_dialog)
		box.add_child(later_btn)


func _render_downloading() -> void :
	var box: = _new_box()
	box.add_child(UI.label("DOWNLOADING UPDATE", 24, Color(1, 0.85, 0.4)))
	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 100.0
	_bar.value = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(480, 28)
	box.add_child(_bar)
	_pct_label = UI.label("0%", 16, Color.WHITE, 480.0)
	box.add_child(_pct_label)
	var cancel_btn: = UI.button("CANCEL", 18, 48.0)
	cancel_btn.pressed.connect(_on_cancel_download)
	box.add_child(cancel_btn)


func _render_ready() -> void :
	var box: = _new_box()
	box.add_child(UI.label("UPDATE DOWNLOADED", 24, Color(0.5, 1, 0.6)))
	var msg: = "The game will close and restart to finish the update."
	if OS.get_name() == "Android":
		msg = "Android will ask you to confirm the install. After it finishes, open the game again."
	box.add_child(UI.label(msg, 16, Color.WHITE, 480.0))
	var install_btn: = UI.button("INSTALL & RESTART", 20, 56.0)
	install_btn.pressed.connect(_on_install_pressed)
	box.add_child(install_btn)
	if not _is_required():
		var later_btn: = UI.button("LATER", 18, 48.0)
		later_btn.pressed.connect(_close_dialog)
		box.add_child(later_btn)


func _render_message(title: String, text: String, retry: bool, open_page: bool) -> void :
	var box: = _new_box()
	box.add_child(UI.label(title, 24, Color(1, 0.5, 0.5)))
	box.add_child(UI.label(text, 16, Color.WHITE, 480.0))
	if retry:
		var retry_btn: = UI.button("RETRY", 20, 52.0)
		retry_btn.pressed.connect(_on_update_pressed)
		box.add_child(retry_btn)
	if open_page:
		var page_btn: = UI.button("OPEN DOWNLOAD PAGE", 18, 48.0)
		page_btn.pressed.connect( func(): OS.shell_open(str(latest.get("download_url", ""))))
		box.add_child(page_btn)
	var back_btn: = UI.button("BACK" if _is_required() else "CLOSE", 18, 48.0)
	back_btn.pressed.connect(_render_available if _is_required() else _close_dialog)
	box.add_child(back_btn)





func _on_update_pressed() -> void :
	var url: = str(latest.get("download_url", ""))
	if url == "":
		_render_message("UPDATE FAILED", "No download link for this platform", false, false)
		return

	if not _can_self_install(url):
		OS.shell_open(url)
		if not _is_required():
			_close_dialog()
		return
	_start_download(url)


func _can_self_install(url: String) -> bool:
	var f: = _file_name_from_url(url).to_lower()
	match OS.get_name():
		"Android":
			return f.ends_with(".apk")
		"Windows":
			return f.ends_with(".zip") or f.ends_with(".exe")
	return false


func _file_name_from_url(url: String) -> String:
	var clean: = url.split("?")[0].split("#")[0]
	var f: = clean.get_file().uri_decode()
	f = f.replace(" ", "_")
	for bad in ["\\", "/", ":", "*", "\"", "<", ">", "|"]:
		f = f.replace(bad, "_")
	return f


func _start_download(url: String) -> void :
	var dir_abs: = ProjectSettings.globalize_path("user://updates")
	DirAccess.make_dir_recursive_absolute(dir_abs)
	_save_path = "user://updates/" + _file_name_from_url(url)
	_remove_file(_save_path)

	_dl = HTTPRequest.new()
	_dl.use_threads = true
	_dl.download_chunk_size = 262144
	_dl.timeout = 0.0
	_dl.download_file = _save_path
	add_child(_dl)
	_dl.request_completed.connect(_on_download_done)
	var err: = _dl.request(url)
	if err != OK:
		_dl.queue_free()
		_dl = null
		_render_message("UPDATE FAILED", "Could not start the download", true, true)
		return
	_downloading = true
	_render_downloading()


func _process(_delta: float) -> void :
	if not _downloading or _dl == null or _bar == null or _pct_label == null:
		return
	var total: = _dl.get_body_size()
	var got: = _dl.get_downloaded_bytes()
	if total > 0:
		var pct: = clampf(float(got) / float(total) * 100.0, 0.0, 100.0)
		_bar.value = pct
		_pct_label.text = "%d%%   (%.1f / %.1f MB)" % [int(pct), got / 1048576.0, total / 1048576.0]
	else:
		_pct_label.text = "%.1f MB" % (got / 1048576.0)


func _on_download_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void :
	_downloading = false
	if _dl != null:
		_dl.queue_free()
		_dl = null
	var size_ok: = false
	if FileAccess.file_exists(_save_path):
		var f: = FileAccess.open(_save_path, FileAccess.READ)
		if f != null:
			size_ok = f.get_length() > 0
			f.close()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200 or not size_ok:
		_remove_file(_save_path)
		_render_message("DOWNLOAD FAILED", "Check your internet connection and try again", true, true)
		return
	_render_ready()


func _on_cancel_download() -> void :
	_downloading = false
	if _dl != null:
		_dl.cancel_request()
		_dl.queue_free()
		_dl = null
	_remove_file(_save_path)
	_render_available()





func _on_install_pressed() -> void :
	if OS.has_feature("editor"):
		_render_message("EDITOR MODE", "The update was downloaded to:\n" + ProjectSettings.globalize_path(_save_path) + "\n(Installing only works in an exported build)", false, false)
		return
	match OS.get_name():
		"Windows":
			if not _install_windows():
				_render_message("INSTALL FAILED", "Could not install the update automatically", false, true)
		"Android":
			var res: = _install_android()
			if res == "permission":
				_render_message("PERMISSION NEEDED", "Allow this app to install updates in the settings page that just opened, come back, then press INSTALL again.", false, false)
				_add_back_to_ready()
			elif res != "ok":
				_render_message("INSTALL FAILED", "Could not open the installer", false, true)
		_:
			OS.shell_open(str(latest.get("download_url", "")))


func _add_back_to_ready() -> void :
	if _box == null or not is_instance_valid(_box):
		return
	var again: = UI.button("INSTALL", 20, 52.0)
	again.pressed.connect(_on_install_pressed)
	_box.add_child(again)
	_box.move_child(again, _box.get_child_count() - 2)


func _install_windows() -> bool:
	var file_abs: = ProjectSettings.globalize_path(_save_path)
	if file_abs.to_lower().ends_with(".exe"):

		OS.create_process(file_abs, [])
		get_tree().quit()
		return true


	var out_dir: = ProjectSettings.globalize_path("user://updates/extracted")
	_clear_dir(out_dir)
	if not _extract_zip(file_abs, out_dir):
		return false
	var src: = _find_content_root(out_dir)
	var exe: = OS.get_executable_path()
	var install_dir: = exe.get_base_dir()

	var w: = func(p: String) -> String: return p.replace("/", "\\")
	var bat_path: = ProjectSettings.globalize_path("user://updates/apply_update.bat")
	var lines: = PackedStringArray([
		"@echo off", 
		"set tries=0", 
		"ping 127.0.0.1 -n 4 >nul", 
		":retry", 
		"xcopy \"%s\\*\" \"%s\\\" /E /Y /I /Q >nul" % [w.call(src), w.call(install_dir)], 
		"if not errorlevel 1 goto done", 
		"set /a tries+=1", 
		"if %tries% geq 10 goto done", 
		"ping 127.0.0.1 -n 3 >nul", 
		"goto retry", 
		":done", 
		"start \"\" \"%s\"" % w.call(exe), 
		"rmdir /s /q \"%s\"" % w.call(out_dir), 
		"del \"%~f0\"", 
	])
	var f: = FileAccess.open(bat_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string("\r\n".join(lines) + "\r\n")
	f.close()
	OS.create_process("cmd.exe", ["/c", w.call(bat_path)])
	get_tree().quit()
	return true




func _install_android() -> String:
	if not Engine.has_singleton("AndroidRuntime"):
		return "fail"
	var rt = Engine.get_singleton("AndroidRuntime")
	var activity = rt.getActivity()
	if activity == null:
		return "fail"
	var Intent = JavaClassWrapper.wrap("android.content.Intent")
	var JFile = JavaClassWrapper.wrap("java.io.File")
	var FileProvider = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
	if Intent == null or JFile == null or FileProvider == null:
		return "fail"
	var pkg: String = str(activity.getPackageName())


	var pm = activity.getPackageManager()
	if pm != null and not bool(pm.canRequestPackageInstalls()):
		var Settings = JavaClassWrapper.wrap("android.provider.Settings")
		var Uri = JavaClassWrapper.wrap("android.net.Uri")
		if Settings == null or Uri == null:
			return "fail"
		var si = Intent.Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:" + pkg))
		si.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		activity.startActivity(si)
		return "permission"

	var apk = JFile.File(ProjectSettings.globalize_path(_save_path))
	var uri = FileProvider.getUriForFile(activity, pkg + ".fileprovider", apk)
	if uri == null:
		return "fail"
	var intent = Intent.Intent(Intent.ACTION_VIEW)
	intent.setDataAndType(uri, "application/vnd.android.package-archive")
	intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION | Intent.FLAG_ACTIVITY_NEW_TASK)
	activity.startActivity(intent)
	return "ok"





func _extract_zip(zip_abs: String, out_dir: String) -> bool:
	var zr: = ZIPReader.new()
	if zr.open(zip_abs) != OK:
		return false
	DirAccess.make_dir_recursive_absolute(out_dir)
	for entry in zr.get_files():
		if ".." in entry:
			continue
		var target: = out_dir.path_join(entry)
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(target)
			continue
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var data: = zr.read_file(entry)
		var f: = FileAccess.open(target, FileAccess.WRITE)
		if f == null:
			zr.close()
			return false
		f.store_buffer(data)
		f.close()
	zr.close()
	return true



func _find_content_root(dir_abs: String) -> String:
	var d: = DirAccess.open(dir_abs)
	if d == null:
		return dir_abs
	var files: = d.get_files()
	var dirs: = d.get_directories()
	if files.is_empty() and dirs.size() == 1:
		return dir_abs.path_join(dirs[0])
	return dir_abs


func _clear_dir(dir_abs: String) -> void :
	var d: = DirAccess.open(dir_abs)
	if d == null:
		return
	for sub in d.get_directories():
		_clear_dir(dir_abs.path_join(sub))
		DirAccess.remove_absolute(dir_abs.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(dir_abs.path_join(f))


func _remove_file(path: String) -> void :
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _close_dialog() -> void :
	if _dialog != null and is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null
	_box = null
	_bar = null
	_pct_label = null
