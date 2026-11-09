class_name UiAudioBridge
extends RefCounted
## Skill v2 audio (docs/skill-v2/10-audio-system-design.md §3, §7): menu and flow sounds. ONLY LISTENS to existing
## signals ([signal GameFlow.phase_changed], [signal RunController.paused_changed]) and posts [AudioEventRules] cues to
## an injected [AudioDirector]; screens may also call [method tap] / [method toggle] / [method back] for their own
## buttons (the settings rows do). The battle's UI sounds (cards, Blocks) live in [CombatAudioBridge].

## Phases left without a navigation tap (a battle starts or ends with its own sounds).
const SILENT_PHASES: Array[int] = [GameFlow.Phase.IN_NODE]

var _director: AudioDirector
var _links: Array[Array] = []


## A bridge posting to [param director].
func _init(director: AudioDirector) -> void:
	_director = director


## Listens to [param flow] (phase changes = a navigation tap).
func attach_flow(flow: GameFlow) -> void:
	_link(flow.phase_changed, _on_phase_changed)


## Listens to a run controller's pause (the pause menu opening / closing = a toggle).
func attach_controller(controller: RunController) -> void:
	if controller != null:
		_link(controller.paused_changed, _on_paused_changed)


## Disconnects everything.
func detach() -> void:
	for l: Array in _links:
		var sig: Signal = l[0]
		if not sig.is_null() and sig.is_connected(l[1]):
			sig.disconnect(l[1])
	_links.clear()


## A button tap.
func tap() -> void:
	_director.apply(AudioEventRules.ui_cue(_director.get_bank(), "tap"))


## A toggle / value change.
func toggle() -> void:
	_director.apply(AudioEventRules.ui_cue(_director.get_bank(), "toggle"))


## Back / close.
func back() -> void:
	_director.apply(AudioEventRules.ui_cue(_director.get_bank(), "back"))


func _link(sig: Signal, fn: Callable) -> void:
	if not sig.is_connected(fn):
		sig.connect(fn)
	_links.append([sig, fn])


func _on_phase_changed(phase: int) -> void:
	if not SILENT_PHASES.has(phase):
		tap()


func _on_paused_changed(paused: bool) -> void:
	_director.set_paused(paused)
	toggle()
