extends Logger
## Prompt 3: conta erros e avisos do motor durante um teste (OS.add_logger).
var errors: Array[String] = []
var warnings: Array[String] = []
var ignore: Array[String] = []


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var text := "%s (%s:%d %s)" % [rationale if rationale != "" else code, file.get_file(), line, function]
	for ig in ignore:
		if text.contains(ig):
			return
	if error_type == ERROR_TYPE_WARNING:
		warnings.append(text)
	else:
		errors.append(text)


func _log_message(_message: String, _error: bool) -> void:
	pass
