## Performs screen transition effect.
extends CanvasLayer
class_name Fade

## The default directory for storing patterns.
const DEFAULT_PATTERN_DIRECTORY = "res://addons/UniversalFade/Patterns"
const DEFAULT_OPTIONS := {
	"time": 1.0,
	"color": Color.BLACK,
	"pattern": "",
	"texture": null,
	"smooth": false,
	"z_index": 100
}

## Emitted when the effect finishes.
signal finished

## Fades out the screen, so it becomes a single color. Use the parameters to customize it.
static func fade_out(options := {}) -> Fade:
	options.merge(DEFAULT_OPTIONS)
	if not "reverse" in options:
		options.reverse = false
	var fader := _create_fader(options)
	fader._fade(&"FadeOut", options.time)
	return fader

## Fades in the screen, so it's visible again. Use the parameters to customize it.
static func fade_in(options := {}) -> Fade:
	options.merge(DEFAULT_OPTIONS)
	if not "reverse" in options:
		options.reverse = true
	var fader := _create_fader(options)
	fader._fade(&"FadeIn", options.time)
	return fader

## Starts a crossfade effect. It will take snapshot of the current screen and freeze it (visually) until [method crossfade_execute] is called. Use the parameters to customize it.
static func crossfade_prepare(options := {}) -> void:
	options.merge(DEFAULT_OPTIONS)
	if not "reverse" in options:
		options.reverse = false
	_get_scene_tree_root().set_meta(&"__crossfade__", true)
	var fader := _create_fader(options)
	fader.set_meta(&"time", options.time)
	_get_scene_tree_root().set_meta(&"__crossfade__", fader)

## Executes the crossfade. [b]Before[/b] calling this method, make sure to call [method crossfade_prepare] [b]and[/b] e.g. change the scene. The screen will fade from the snapshotted image to the new scene.
static func crossfade_execute() -> Fade:
	assert(_get_scene_tree_root().has_meta(&"__crossfade__"), "No crossfade prepared. Use Fade.crossfade_prepare() first")
	var fader := _get_scene_tree_root().get_meta(&"__crossfade__") as Fade
	_get_scene_tree_root().remove_meta(&"__crossfade__")
	
	fader._fade(&"FadeIn", fader.get_meta(&"time"))
	return fader

static func _create_fader(options: Dictionary) -> Fade:
	if _get_scene_tree_root().has_meta(&"__current_fade__"):
		var old = _get_scene_tree_root().get_meta(&"__current_fade__")
		if is_instance_valid(old):
			old.queue_free()
	
	var texture: Texture2D = options.texture
	if texture == null:
		if options.pattern.is_empty():
			options.smooth = true
			options.reverse = false
			
			if _get_scene_tree_root().has_meta(&"__1px_pattern__"):
				texture = _get_scene_tree_root().get_meta(&"__1px_pattern__")
			else:
				var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
				image.fill(Color.WHITE)
				
				texture = ImageTexture.create_from_image(image)
				_get_scene_tree_root().set_meta(&"__1px_pattern__", texture)
		else:
			var pattern_path := DEFAULT_PATTERN_DIRECTORY.path_join(options.pattern) + ".png"
			assert(ResourceLoader.exists(pattern_path, "Texture2D"), "Pattern not found: '%s'. Make sure a PNG file with this name is located in '%s'." % [options.pattern, DEFAULT_PATTERN_DIRECTORY])
			texture = load(pattern_path)
	
	var fader:Fade = load("res://addons/UniversalFade/Fade.tscn").instantiate()
	fader.layer = options.z_index
	fader._prepare_fade(options.color, texture, options.reverse, options.smooth, _get_scene_tree_root().get_meta(&"__crossfade__", false))
	_get_scene_tree_root().set_meta(&"__current_fade__", fader)
	_get_scene_tree_root().add_child(fader)
	return fader

static func _get_scene_tree_root() -> Viewport:
	return Engine.get_main_loop().root as Viewport

func _prepare_fade(color: Color, pattern: Texture2D, reverse: bool, smooth: bool, crossfade: bool):
	var mat := $TextureRect.material as ShaderMaterial
	mat.set_shader_parameter(&"color", color)
	mat.set_shader_parameter(&"reverse", reverse)
	mat.set_shader_parameter(&"smooth_mode", smooth)
	
	if crossfade:
		mat.set_shader_parameter(&"use_custom_texture", true)
		mat.set_shader_parameter(&"custom_texture", pattern)
		$TextureRect.texture = ImageTexture.create_from_image(_get_scene_tree_root().get_texture().get_image())
	else:
		$TextureRect.texture = pattern

func _fade(animation: StringName, time: float):
	assert(time >= 0, "Time must be greater than 0.")
	var player := $AnimationPlayer as AnimationPlayer
	if time == 0:
		player.play(animation)
		player.advance(INF)
	else:
		player.play(animation, -1, 1.0 / time)
		player.advance(0)

func _fade_finished(anim_name: StringName) -> void:
	finished.emit()
	
	if anim_name == &"FadeIn":
		queue_free()
