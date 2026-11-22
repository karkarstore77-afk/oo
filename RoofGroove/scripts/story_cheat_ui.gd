extends RefCounted


const Cheats: = preload("res://scripts/story_cheats.gd")


static func open(parent: Node) -> void :

	var net: = parent.get_node_or_null("/root/Network")
	if net != null and net.get("cloud") != null and net.cloud.has_method("fetch_cheat_codes"):
		var r: Dictionary = await net.cloud.fetch_cheat_codes()
		if bool(r.get("ok", false)):
			if bool(r.get("enabled", true)):
				Cheats.set_codes(r["codes"])
			else:
				Cheats.disable_all()
	var dlg: = AcceptDialog.new()
	dlg.title = parent.tr("ENTER CODE")
	dlg.get_ok_button().text = parent.tr("OK")
	var le: = LineEdit.new()
	le.placeholder_text = "CODE"
	le.custom_minimum_size = Vector2(300, 44)
	dlg.add_child(le)
	parent.add_child(dlg)
	dlg.confirmed.connect( func() -> void :
		var msg: = Cheats.submit(le.text)
		var res: = AcceptDialog.new()
		res.dialog_text = parent.tr(msg if msg != "" else "INVALID CODE")
		res.get_ok_button().text = parent.tr("OK")
		parent.add_child(res)
		res.popup_centered()
		dlg.queue_free())
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(380, 150))
	le.grab_focus()
