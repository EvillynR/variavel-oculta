class_name SaveSystem
extends RefCounted
## Prompt 3 — persistência em user:// (save do jogo e configurações).
## Estático de propósito: sobrevive à troca de cena (menu ↔ jogo) sem autoload.

const SETTINGS_DEFAULTS := {
	"volume": 0.8,              # 0..1 (bus Master)
	"brightness": 1.0,          # 0,6..1,6 (Environment.adjustment_brightness)
	"camera_sensitivity": 1.0,  # 0,5..2 (giro pelas setas / resposta da câmera fixa)
	"subtitle_size": 22,        # px
	"fullscreen": false,
	"quality": 2,               # 0 leve · 1 equilibrada · 2 alta (versão 6.0)
}
## Versão 6.0 — qualidade gráfica (para computadores mais fracos). As texturas
## e os modelos são sempre os mesmos; muda só o custo de desenhar cada quadro.
const QUALITY_NAMES := ["Leve", "Equilibrada", "Alta"]
## Ações que o jogador pode remapear (rótulo exibido nas configurações).
const REMAP_ACTIONS := {
	"move_forward": "Andar para frente", "move_back": "Andar para trás",
	"move_left": "Andar para a esquerda", "move_right": "Andar para a direita",
	"run": "Correr", "crouch": "Agachar", "interact": "Interagir / esconder-se",
	"diario": "Diário de pistas", "mapa": "Mapa da escola", "pause": "Pausa",
}

static var save_path: String = "user://vo_save.json"
static var settings_path: String = "user://vo_config.cfg"
## O que a cena do jogo deve fazer ao abrir: "" (nada), "new", "continue", "checkpoint".
static var pending_action: String = ""
static var settings: Dictionary = {}
static var keys: Dictionary = {}   # ação -> physical_keycode
static var _default_keys: Dictionary = {}


# ------------------------------------------------------------------ save

static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


static func write_save(data: Dictionary) -> bool:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: não foi possível gravar %s (%s)." % [save_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	return true


static func read_save() -> Dictionary:
	if not has_save():
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: save corrompido em %s." % save_path)
		return {}
	return parsed


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))


# ----------------------------------------------------------- configurações

static func load_settings() -> Dictionary:
	_remember_default_keys()
	settings = SETTINGS_DEFAULTS.duplicate()
	keys = {}
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		for k in SETTINGS_DEFAULTS:
			settings[k] = cfg.get_value("geral", k, SETTINGS_DEFAULTS[k])
		for a in REMAP_ACTIONS:
			var code: int = int(cfg.get_value("teclas", a, 0))
			if code != 0:
				keys[a] = code
	return settings


static func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("geral", k, settings[k])
	for a in keys:
		cfg.set_value("teclas", a, keys[a])
	var err := cfg.save(settings_path)
	if err != OK:
		push_error("SaveSystem: não foi possível gravar %s." % settings_path)


static func get_setting(key: String) -> Variant:
	if settings.is_empty():
		load_settings()
	return settings.get(key, SETTINGS_DEFAULTS.get(key))


static func set_setting(key: String, value: Variant) -> void:
	if settings.is_empty():
		load_settings()
	settings[key] = value
	save_settings()


## Troca a tecla de uma ação (remapeamento básico: uma tecla por ação).
static func remap_action(action: String, physical_keycode: int) -> void:
	if settings.is_empty():
		load_settings()
	keys[action] = physical_keycode
	_apply_key(action, physical_keycode)
	save_settings()


static func reset_keys() -> void:
	_remember_default_keys()
	keys.clear()
	for a in _default_keys:
		_apply_key(a, int(_default_keys[a]))
	save_settings()


static func key_name(action: String) -> String:
	for e in InputMap.action_get_events(action) if InputMap.has_action(action) else []:
		if e is InputEventKey:
			var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
			return OS.get_keycode_string(code)
	return "—"


## Aplica o que vale para o jogo todo (som, tela, teclas).
static func apply_global() -> void:
	if settings.is_empty():
		load_settings()
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(settings.volume), 0.0001)))
	AudioServer.set_bus_mute(bus, float(settings.volume) <= 0.001)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	for a in keys:
		_apply_key(a, int(keys[a]))
	_apply_quality_global()


## Resolução 3D interna (com FSR para manter a nitidez), sombras e névoa.
static func _apply_quality_global() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var q := clampi(int(settings.get("quality", 2)), 0, 2)
	var vp := tree.root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if q == 2 else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = [0.67, 0.8, 1.0][q]
	vp.fsr_sharpness = 0.3
	vp.positional_shadow_atlas_size = [2048, 2048, 4096][q]
	var sq: int = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW][q]
	RenderingServer.positional_soft_shadow_filter_set_quality(sq)
	RenderingServer.directional_soft_shadow_filter_set_quality(sq)
	RenderingServer.environment_set_volumetric_fog_volume_size([40, 52, 64][q], [40, 52, 64][q])


## Aplica o que depende da cena do jogo (brilho, câmera).
static func apply_to_scene(scene_root: Node) -> void:
	if settings.is_empty():
		load_settings()
	var env_node := scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env_node != null and env_node.environment != null:
		env_node.environment.adjustment_enabled = true
		# versão 5.8: atmosfera sombria — o "Brilho" das configurações multiplica a base
		env_node.environment.adjustment_brightness = float(settings.brightness) * 0.85
	var cam := scene_root.get_tree().get_first_node_in_group("camera_controller")
	if cam != null:
		if not cam.has_meta("base_orbit_speed"):
			cam.set_meta("base_orbit_speed", cam.orbit_yaw_speed_degrees)
			cam.set_meta("base_fixed_smooth", cam.fixed_smooth_time)
		var s := clampf(float(settings.camera_sensitivity), 0.25, 3.0)
		cam.orbit_yaw_speed_degrees = float(cam.get_meta("base_orbit_speed")) * s
		cam.orbit_pitch_speed_degrees = float(cam.get_meta("base_orbit_speed")) * s * 0.55
		cam.fixed_smooth_time = float(cam.get_meta("base_fixed_smooth")) / s
	# Leve: as luzes da escola deixam de fazer sombra (StoryDirector.apply_quality)
	scene_root.get_tree().call_group("quality_listener", "apply_quality", int(settings.get("quality", 2)))


static func _apply_key(action: String, code: int) -> void:
	if not InputMap.has_action(action):
		return
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	var k := InputEventKey.new()
	k.physical_keycode = code as Key
	InputMap.action_add_event(action, k)


static func _remember_default_keys() -> void:
	if not _default_keys.is_empty():
		return
	for a in REMAP_ACTIONS:
		if InputMap.has_action(a):
			for e in InputMap.action_get_events(a):
				if e is InputEventKey:
					_default_keys[a] = e.physical_keycode if e.physical_keycode != 0 else e.keycode
					break
