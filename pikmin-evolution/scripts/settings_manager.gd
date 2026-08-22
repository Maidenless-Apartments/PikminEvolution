extends Node

signal debugger_changed(enabled: bool)

var debugger_enabled := false

func set_debugger_enabled(enabled: bool) -> void:
	if debugger_enabled == enabled:
		return

	debugger_enabled = enabled
	debugger_changed.emit(debugger_enabled)
