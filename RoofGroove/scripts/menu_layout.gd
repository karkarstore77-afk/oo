extends RefCounted
## Shared layout constants for menu screens that show the top toolbar (see top_bar.gd).

const BAR_HEIGHT: = 76.0
const SPACE: = 88
const MENU_SCENES: = ["main_menu", "account_hub", "account_menu", "shop_menu", "friends_menu", "profile_menu",
	"settings_menu", "play_menu", "online_menu", "worlds_menu", "information", "checkpoint_selector"]


static func is_menu_scene_path(path: String) -> bool:
	return path != "" and MENU_SCENES.has(path.get_file().get_basename())


static func is_menu_node(n: Node) -> bool:
	var tree: SceneTree = n.get_tree()
	if tree == null:
		return false
	var cur: Node = n
	while cur.get_parent() != null and cur.get_parent() != tree.root:
		cur = cur.get_parent()
	return is_menu_scene_path(cur.scene_file_path)
