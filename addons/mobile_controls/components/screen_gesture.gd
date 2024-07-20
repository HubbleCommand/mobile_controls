@tool
extends Control
class_name ScreenGesture

# General Control to handle multiple gestures; panning, zoom, rotating, double tap
# This class DOES NOT hold any state relevant to any pan or scale, only detects the gestures

#Note, some of the input settings in Project Settings make some funky shit
# also fixes InputEventMouseMotion being sent when holding a press on Android & then panning
#TODO Required settings in Project Settings -> Input Devices -> Pointing
#	-> https://docs.godotengine.org/en/stable/classes/class_projectsettings.html
# Disable 
#	"Emulate Touch From Mouse"
#	"Emulate Mouse From Touch"
#	"Enable Long Press as Right Click"
# Enable 
#	"Enable Pan and Scale Gestures"

# There are some other projects, however, I don't like how any of these have been done
# https://github.com/godotengine/godot/issues/13139
# https://github.com/Federico-Ciuffardi/GodotTouchInputManager
# https://github.com/arypbatista/godot-swipe-detector
# https://www.youtube.com/watch?v=7XlMqjikI9A

@export var touchscreen_only: bool = false

@export var show_ui_feedback := false	#TODO add UI feeback (?)
@export var print_debug_gestures = true

@export var pan_icon: Texture2D = load("res://addons/mobile_controls/icons/pan_icon.svg"):
	set(value):
		pan_icon = value
		if Engine.is_editor_hint():
			btn_mode.texture = value
			notify_property_list_changed()
@export var rotate_icon: Texture2D = load("res://addons/mobile_controls/icons/rotate_icon.svg"):
	set(value):
		rotate_icon = value
		if Engine.is_editor_hint():
			btn_mode.texture = value
			notify_property_list_changed()

@export_subgroup("Gestures Configuration")
@export var consider_input_gesture_as_handled = true
## Timeout in milliseconds for two consecutive screen taps 
## from the same pointer to be considered a double tap (mouse only)
@export var double_tap_timeout : float = 500
## Timeout in milliseconds for detecting a long press / hold
@export var long_press_timeout : float = 1000

#Basic gestures
signal double_tap_gesture(target: Vector2)
signal long_press_gesture(gesture: Vector2)
signal pan_gesture(position: Vector2, direction: Vector2)
signal scale_gesture(position: Vector2, strength: float) #Also handles pan I guess, or merge both pan & scale
signal rotate_gesture(position: Vector2, direction: Vector2)
signal gesture_end() #Signifies the end of a previous set of gestures (useful for scale / pan combos)

class Pointer :
	var index : int
	var timestamp: float
	var position: Vector2
	
	func _init(i: int, time: float, pos: Vector2):
		index = i
		timestamp = time
		position = pos

enum ETouchScreenMode { PAN, ROTATE }

class ScreenGestureState:
	var pointers : int = 0
	var last_pointer_down : Pointer = null
	var tscreen_mode := ETouchScreenMode.PAN

var state = ScreenGestureState.new()


var tmr_long_press: Timer
#var btn_mode: TextureRect
var btn_mode: TextureButton
var clr_rct: ColorRect

func _ready():
	if touchscreen_only and not DisplayServer.is_touchscreen_available():
		modulate = Color(1, 1, 1, 0)
		process_mode = ProcessMode.PROCESS_MODE_DISABLED
	
	#Build for addon
	tmr_long_press = Timer.new()
	tmr_long_press.wait_time = 0.5
	tmr_long_press.one_shot = true
	tmr_long_press.timeout.connect(_long_press_timeout)
	add_child(tmr_long_press)
	
	clr_rct = ColorRect.new()
	clr_rct.color = Color8(255, 255, 255, 30)
	clr_rct.grow_vertical = Control.GROW_DIRECTION_BOTH
	clr_rct.grow_horizontal = Control.GROW_DIRECTION_BOTH
	clr_rct.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clr_rct.set_anchors_preset(PRESET_FULL_RECT)
	clr_rct.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(clr_rct)
	
	var container = MarginContainer.new()
	container.name = "ButtonModeMarginContainer"
	btn_mode = TextureButton.new()
	btn_mode.name = "ButtonMode"
	btn_mode.ignore_texture_size = true
	btn_mode.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT
	btn_mode.custom_minimum_size = mode_button_minimum_size
	
	var margin_value = 20
	add_theme_constant_override("margin_top", margin_value)
	add_theme_constant_override("margin_left", margin_value)
	add_theme_constant_override("margin_bottom", margin_value)
	add_theme_constant_override("margin_right", margin_value)
	
	
	add_child(container)
	container.add_child(btn_mode)
	_toggle_touchscreen_mode()
	
	tmr_long_press.wait_time = long_press_timeout / 1000
	
	container.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_WIDTH, 0.0)


func _toggle_touchscreen_mode():
	var resource : Texture2D
	if state.tscreen_mode == ETouchScreenMode.PAN:
		state.tscreen_mode = ETouchScreenMode.ROTATE
		resource = rotate_icon
	else:
		state.tscreen_mode = ETouchScreenMode.PAN
		resource = pan_icon
	#btn_mode.texture = resource
	btn_mode.texture_normal = resource

# We use _gui_input instead of _input to only consider events within this control
func _gui_input(event):
	match event.get_class():
		"InputEventMouseButton":
			#TODO need an action to map to here I guess, or something... i.e. only zoom when CTRL is pressed
			if event.pressed:
				var factor = 1 if event.factor == 0 else event.factor
				match event.button_index:
					MOUSE_BUTTON_WHEEL_UP:
						_pring_gesture_debug("scale", "mouse")
						scale_gesture.emit(event.position, factor)
					MOUSE_BUTTON_WHEEL_DOWN:
						_pring_gesture_debug("scale", "mouse")
						scale_gesture.emit(event.position, -factor)
					MOUSE_BUTTON_LEFT:
						state.pointers += 1
						if _detect_double_tap(state.last_pointer_down, event):
							double_tap_gesture.emit(event.position)
							tmr_long_press.stop()
						else:
							tmr_long_press.start()
						state.last_pointer_down = Pointer.new(-1, Time.get_ticks_msec(), event.position)
			elif event.button_index == MOUSE_BUTTON_LEFT:#Don't just ELSE here
				state.pointers -= 1
				if state.pointers == 0:
					gesture_end.emit()
				tmr_long_press.stop()
		"InputEventMouseMotion":
			if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) && Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_pring_gesture_debug("rotate", "mouse")
				if consider_input_gesture_as_handled: get_viewport().set_input_as_handled()
				rotate_gesture.emit(event.position, event.velocity)
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) && !Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_pring_gesture_debug("pan", "mouse")
				if consider_input_gesture_as_handled: get_viewport().set_input_as_handled()
				pan_gesture.emit(event.position, event.velocity)
	# Screen part
	# I don't really like how when Magnify is triggered, so is the pan...
	# It might be better to just have a toggle button to switch between Pan & Rotate
	# But... this is fine for now...
		"InputEventPanGesture":
			if state.tscreen_mode == ETouchScreenMode.PAN:
				pan_gesture.emit(event.position, event.delta)
			else:
				rotate_gesture.emit(event.position, event.delta)
		"InputEventMagnifyGesture":
			_pring_gesture_debug("scale", "screen")
			scale_gesture.emit(event.position, event.factor)
	
	# Usually no index means that it's a "generic" gesture, so can probably ignore
	# i.e. dragging the mouse (InputEventMouseMotion) with no buttons pressed
	# previous events don't have indicies
	# TODO check for iOS
	print(event)
	if not "index" in event:
		print("returning due to no event index")
		return
	
	if event is InputEventScreenTouch:
		if event.is_pressed():
			state.last_pointer_down = Pointer.new(event.index, Time.get_ticks_msec(), event.position)
			state.pointers += 1
			if state.pointers > 1:
				_pring_gesture_debug("long press - stopping timer", "screen")
				tmr_long_press.stop()
			tmr_long_press.start()
		if !event.is_pressed():
			state.pointers -= 1
			if state.pointers == 0:
				gesture_end.emit()
			tmr_long_press.stop()
		if event.double_tap:
			_pring_gesture_debug("double tap", "screen")
			double_tap_gesture.emit(event.position)
			#tmr_long_press.stop()
	elif event is InputEventScreenDrag:
		if state.tscreen_mode == ETouchScreenMode.PAN:
			pan_gesture.emit(event.position, event.relative)
		else:
			rotate_gesture.emit(event.position, event.relative)

#Only for mouse, screen already has double tap, but still should work for screen
func _detect_double_tap(last_event: Pointer, event: InputEvent) -> bool:
	if last_event != null and state.pointers == 1 \
		and Time.get_ticks_msec() - last_event.timestamp < double_tap_timeout \
		and abs(last_event.position.distance_to(event.position)) < 25 :
		_pring_gesture_debug("double tap")
		return true
	_pring_gesture_debug("double tap FAILED")
	return false

func _long_press_timeout():
	_pring_gesture_debug("long press - timeout")
	if state.pointers == 1:
		_pring_gesture_debug("long press")
		long_press_gesture.emit(state.last_pointer_down.position)

func _pring_gesture_debug(gesture : String, source: String = ""):
	if !print_debug_gestures:
		return
	if source.is_empty():	print("		gesture debug --- gesture : ", gesture)
	else:					print("		gesture debug --- gesture : ", gesture, " - from source : ", source)
