extends Node
## Local notifications (Android / iOS). Schedules a rolling window of messages
## and re-fills it every time the game is opened or resumed.

const Messages: = preload("res://scripts/notification_messages.gd")

const TITLE: = "Roof Groove"
const CHANNEL_ID: = "hourly_messages_silent"
const INTERVAL_SECONDS: = 21600
const COUNT_AHEAD: = 16
const FIRST_ID: = 1000
const LAST_ID: = 1199
const QUIET_UNTIL_HOUR: = 9
const MIN_REFRESH_GAP_MSEC: = 600000

var _scheduler: NotificationScheduler
var _initialized: = false
var _asked_permission: = false
var _last_refresh_msec: = -MIN_REFRESH_GAP_MSEC


func is_supported() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS"


func _ready() -> void :
	if not is_supported():
		return
	_scheduler = NotificationScheduler.new()
	add_child(_scheduler)
	_scheduler.initialization_completed.connect(_on_initialized)
	_scheduler.post_notifications_permission_granted.connect(_on_permission_granted)
	_scheduler.post_notifications_permission_denied.connect(_on_permission_denied)
	_scheduler.initialize()


func _notification(what: int) -> void :
	if what == NOTIFICATION_APPLICATION_RESUMED:
		if Time.get_ticks_msec() - _last_refresh_msec >= MIN_REFRESH_GAP_MSEC:
			refresh()


func _on_initialized() -> void :
	var channel: = NotificationChannel.new()
	channel.set_id(CHANNEL_ID).set_name("Messages")\
		.set_description("Silent messages from the game").set_importance(NotificationChannel.Importance.LOW)
	_scheduler.create_notification_channel(channel)
	_initialized = true
	refresh()


func _on_permission_granted(_permission: String) -> void :
	refresh()


func _on_permission_denied(_permission: String) -> void :
	# Denied: nothing is scheduled. The next time the player turns the setting off and on, we ask again.
	push_warning("HourlyNotifier: notification permission denied")
	_asked_permission = true


## user_initiated = true when the player just switched notifications on
func refresh(user_initiated: bool = false) -> void :
	if _scheduler == null or not _initialized:
		return
	_last_refresh_msec = Time.get_ticks_msec()
	_cancel_all()
	if not GameSettings.notifications_on:
		return
	if not _scheduler.has_post_notifications_permission():
		if user_initiated or not _asked_permission:
			_asked_permission = true
			_scheduler.request_post_notifications_permission()
		return
	_schedule_all()
	_last_refresh_msec = Time.get_ticks_msec()


func _cancel_all() -> void :
	for notification_id in range(FIRST_ID, LAST_ID + 1):
		_scheduler.cancel(notification_id)


func _schedule_all() -> void :
	var sequence: = _build_sequence(COUNT_AHEAD)
	for i in sequence.size():
		var data: = NotificationData.new()
		data.set_id(FIRST_ID + i)\
		.set_channel_id(CHANNEL_ID)\
		.set_title(TITLE)\
		.set_content(str(sequence[i]))\
		.set_delay(_slot_delay(i))
		_scheduler.schedule(data)


## delay (seconds) for message i; slots that land in the night are moved to the morning
func _slot_delay(i: int) -> int:
	var now: = Time.get_datetime_dict_from_system()
	var sod: = int(now.hour) * 3600 + int(now.minute) * 60 + int(now.second)
	var delay: = _interval() * (i + 1)
	var at: = (sod + delay) % 86400
	var hour: = at / 3600
	if hour < QUIET_UNTIL_HOUR:
		delay += QUIET_UNTIL_HOUR * 3600 - at
	return delay


## notification gap in seconds, chosen by the player in the settings
func _interval() -> int:
	return clampi(GameSettings.notif_every_hours, 1, 24) * 3600


func _build_sequence(count: int) -> Array:
	var pool: Array = []
	for m in Messages.for_language(Loc.current):
		var text: = str(m).strip_edges()
		if text != "":
			pool.append(text)
	var sequence: Array = []
	if pool.is_empty():
		return sequence
	var last: = ""
	while sequence.size() < count:
		var bag: Array = pool.duplicate()
		bag.shuffle()
		if bag.size() > 1 and str(bag[0]) == last:
			bag.push_back(bag.pop_front())
		for m in bag:
			sequence.append(m)
			last = str(m)
	return sequence.slice(0, count)
