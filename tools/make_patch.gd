extends SceneTree
## Used by make_patch.py:  godot --headless --path RoofGroove -s tools/make_patch.gd -- OUT.pck file1 file2 ...
## Each file is a path relative to the RoofGroove folder (for example scripts/player.gd).
func _initialize():
	var args = OS.get_cmdline_user_args()
	var out = args[0]
	var p = PCKPacker.new()
	p.pck_start(out)
	for rel in args.slice(1):
		var src = ProjectSettings.globalize_path("res://" + rel)
		if not FileAccess.file_exists(src):
			printerr("MISSING ", rel); quit(2); return
		p.add_file("res://" + rel, src)
	print("PACKED ", p.flush())
	quit()
