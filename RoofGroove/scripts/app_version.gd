class_name AppVersion
extends RefCounted














const VERSION: = "1.1.7"
const BUILD: = 21




static func current() -> String:
	return VERSION



static func check_consistency() -> void :
	if not OS.has_feature("editor"):
		return
	var ps: String = str(ProjectSettings.get_setting("application/config/version", ""))
	if ps != VERSION:
		push_warning("AppVersion.VERSION (%s) != Project Settings version (%s) - غيّر Project Settings > Application > Config > Version" % [VERSION, ps])
