extends RefCounted






const WorldData: = preload("res://scripts/world_data.gd")
const StoryState: = preload("res://scripts/story_state.gd")
const CustomWorld: = preload("res://scripts/custom_world.gd")
const TRIES: = 3



static func go(host: Node) -> String:
	StoryState.active = false
	if Network.room_mode == "pvp":
		host.get_tree().change_scene_to_file("res://sence/pvp_arena.tscn")
		return ""
	var race: = Network.room_mode == "race"
	if Network.room_world == "":
		if race:
			var rw: = WorldData.generate_race(Network.room_seed)
			Network.run_active = false
			Network.teleported_run = false
			CustomWorld.play(host.get_tree(), rw, "Race Track", "res://sence/main_menu.tscn", false, true)
		else:
			host.get_tree().change_scene_to_file("res://sence/checkpoint_selector.tscn")
		return ""
	if Network.room_world == Network.BUILTIN_ENDLESS_WORLD or Network.room_world == Network.BUILTIN_CLASSIC_WORLD:
		if race:
			return "Choose a published world with a finish line for race mode."
		Network.run_active = false
		Network.teleported_run = false
		var scene_path := "res://sence/world_generated.tscn" if Network.room_world == Network.BUILTIN_ENDLESS_WORLD else "res://sence/world.tscn"
		host.get_tree().change_scene_to_file(scene_path)
		return ""
	var id: = Network.room_world
	var world_name: = Network.room_world_name
	var err: = "Could not load the world"
	for attempt in TRIES:
		var r: Dictionary = await WorldData.fetch_online(id)
		if not host.is_inside_tree():
			return ""
		if bool(r.get("ok", false)):
			var w: Dictionary = r["world"]
			Network.run_active = false
			Network.teleported_run = false
			CustomWorld.play(host.get_tree(), w.duplicate(true), world_name if world_name != "" else str(w["name"]), "res://sence/main_menu.tscn", false, race)
			return ""
		err = str(r.get("error", err))
		await host.get_tree().create_timer(1.5).timeout
		if not host.is_inside_tree():
			return ""
	return err
