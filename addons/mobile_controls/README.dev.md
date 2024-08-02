# Developer README

Green color taken from Control node, joystick icons based off of InputEventJoypadMotion (previously JoyAxis).

Screen gesture icon based on InputEventScreen* phone parts, and hand taken from XRHandModifier3D


## VirtualJoystick
`_input` is used instead of `_gui_input` as we want to handle inputs made outside of the bounds of this control.

Global positions are generally used to compare with mouse position.
This is to avoid a bunch of global-to-local-to-global conversions.
CanvasItem / Control nodes also lack some of the helpers present in Node2D and Node3D for converting between local and global space.
Also cannot use relative position as described [here](https://docs.godotengine.org/en/latest/classes/class_inputeventmouse.html#class-inputeventmouse-property-position).


## Screen Gestures
Input events should NEVER be emulated.
Unlike VirtualJoystick, `_gui_input` is used instead of `_input` as we only consider events within this control.
