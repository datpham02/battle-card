class_name AudioRig
extends Node
## Skill v2 audio wiring (docs/skill-v2/10-audio-system-design.md §2, §9): the one node GameFlow adds to get sound. It
## owns the [AudioDirector] in the tree, applies the audio settings (and re-applies them on
## [signal SettingsStore.audio_changed]), attaches a [UiAudioBridge] to the flow and a [CombatAudioBridge] to every
## battle a RunController spawns, and pauses / backgrounds the director with the app. Gameplay never calls it.
## The director is injected ([member director]) or the shared one ([method AudioDirector.shared], silent when headless).

## The flow node name (GameFlow adds the rig as a child named so).
const NODE_NAME: String = "AudioRig"

## The director this rig drives; null at _ready = [method AudioDirector.shared].
var director: AudioDirector = null
## True while Godot records a movie (--write-movie sets the "movie" feature tag): the capture window runs unfocused, so
## focus-out must not background the director or the recording has no sound. An app pause still backgrounds it.
var keep_audio_unfocused: bool = OS.has_feature("movie")

var _flow: GameFlow = null
var _ui: UiAudioBridge = null
var _settings: SettingsStore = null
var _combat: CombatAudioBridge = null


func _init(with_director: AudioDirector = null) -> void:
	director = with_director
	name = NODE_NAME
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	if director == null:
		director = AudioDirector.shared()
	if director.get_parent() == null:
		add_child(director)
	_flow = get_parent() as GameFlow
	_ui = UiAudioBridge.new(director)
	if _flow != null:
		_ui.attach_flow(_flow)
		_flow.controller_changed.connect(_on_controller_changed)
	# GameFlow resolves its settings later in its own _ready.
	_bind_settings.call_deferred()


func _exit_tree() -> void:
	if _ui != null:
		_ui.detach()


func _notification(what: int) -> void:
	if director == null:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			director.set_background(true)
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not keep_audio_unfocused:
				director.set_background(true)
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			director.set_background(false)


## The UI bridge (screens call tap / toggle / back on it).
func get_ui() -> UiAudioBridge:
	return _ui


## The current battle's bridge, or null.
func get_combat_bridge() -> CombatAudioBridge:
	return _combat if is_instance_valid(_combat) else null


## The rig under [param flow], or null (screens use it to reach the UI bridge).
static func of(flow: Node) -> AudioRig:
	return flow.get_node_or_null(NODE_NAME) as AudioRig if flow != null else null


func _bind_settings() -> void:
	var store: SettingsStore = _flow.get_settings() if _flow != null and _flow.get_settings() != null else null
	if store == null:
		return
	_settings = store
	director.apply_settings(store)
	if not store.audio_changed.is_connected(_on_audio_changed):
		store.audio_changed.connect(_on_audio_changed)


func _on_audio_changed() -> void:
	if _settings != null:
		director.apply_settings(_settings)


func _on_controller_changed(controller: RunController) -> void:
	director.reset_combat()
	director.set_paused(false)
	if controller == null:
		return
	_ui.attach_controller(controller)
	if not controller.battle_spawned.is_connected(_on_battle_spawned):
		controller.battle_spawned.connect(_on_battle_spawned)
	# The first battle spawns in the controller's _ready, before GameFlow announces the controller.
	if controller.get_battle() != null:
		_on_battle_spawned(controller.get_battle())


func _on_battle_spawned(battle: Node) -> void:
	var view := battle.get_node_or_null(RunController.COMBAT_VIEW_NODE) as CombatView
	if view == null:
		return
	_combat = CombatAudioBridge.attach_view(director, view)
