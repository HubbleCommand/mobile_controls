## Helper for managing TextureButtons on Moblie and Desktop platforms
## It tries to make TouchScreenButton workable within the Control system
## It does this by tying a child TouchScreenButton to the state of a TextureButton
##
## This is only needed if emulate_mouse_from_touch is disabled
@tool
class_name TextureButtonMobile
extends TextureButton

#https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html
@onready var is_mobile = OS.has_feature("mobile")
@onready var is_pc = OS.has_feature("pc")

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray([])
	
	if get_child_count() != 1:
		warnings.append("This node should have one child")
	
	var child = get_child(0)
	if child is not TouchScreenButton:
		warnings.append("The one child node should be a TouchScreenButton")
	else:
		if child.texture_normal and child.texture_pressed and child.texture_pressed.get_size() != child.texture_normal.get_size():
			warnings.append("The normal and pressed textures of the child TouchScreenButton should be the same size")
	
	return warnings

var btns_valid = false
var ts_btn: TouchScreenButton

func _get_button() -> bool:
	var child = get_child(0)
	if not child or child is not TouchScreenButton:
		return false
	ts_btn = child as TouchScreenButton
	return true

func _ready() -> void:
	item_rect_changed.connect(_tx_btn_rect_changed)
	visibility_changed.connect(_tx_btn_visibility_changed)

func _tx_btn_rect_changed() -> void:
	_resize_ts_btn()

func _tx_btn_visibility_changed() -> void:
	ts_btn.visible = visible

func _process(delta: float) -> void:
	#if Engine.is_editor_hint():
	#	update_configuration_warnings()
	
	_resize_ts_btn()
	_reposition_ts_btn()

#this shouldnt be needed
func _reposition_ts_btn() -> void:
	pass
	#ts_btn.global_position = global_position

func _resize_ts_btn() -> void:
	if not _get_button():
		return
	var ts_btn_text_size : Vector2 = ts_btn.texture_normal.get_size()
	var tx_btn_size = size
	
	#this calc is naive, and assumes the TextureButton uses Shrink sizing
	# but it works for now
	ts_btn.scale = tx_btn_size / ts_btn_text_size
