extends Node
## Content patch loader (Android/iOS/desktop). Instead of installing a whole new APK (which modern
## Android versions often refuse), the updater downloads a small .pck with only the changed files.
## It is loaded here, as early as possible, and replaces the matching files in the installed game.
## BASE_BUILD is the build number of the INSTALLED app (APK). Change it only when you ship a new APK;
## a patch made for another base build is deleted automatically. Never include this file in a patch.

const BASE_BUILD: = 21
const DIR: = "user://patches"
const CFG: = "user://patches/patch.cfg"
const PACK: = "user://patches/current.pck"

static var loaded_version: = ""


func _init() -> void :
	load_installed_patch()


static func load_installed_patch() -> bool:
	var cfg: = ConfigFile.new()
	if cfg.load(CFG) != OK or not FileAccess.file_exists(PACK):
		return false
	if int(cfg.get_value("patch", "base_build", -1)) != BASE_BUILD:
		clear_patch()
		return false
	if not ProjectSettings.load_resource_pack(PACK, true):
		clear_patch()
		return false
	loaded_version = str(cfg.get_value("patch", "version", ""))
	return true


static func install_patch(downloaded_abs_or_user_path: String, version: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	if FileAccess.file_exists(PACK):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PACK))
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(downloaded_abs_or_user_path), ProjectSettings.globalize_path(PACK)) != OK:
		return false
	var cfg: = ConfigFile.new()
	cfg.set_value("patch", "version", version)
	cfg.set_value("patch", "base_build", BASE_BUILD)
	return cfg.save(CFG) == OK


static func clear_patch() -> void :
	for p in [PACK, CFG]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
