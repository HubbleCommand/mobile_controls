# Mobile Controls
Some mobile virtual controls for Godot 4.x.

![virtual joystick](https://github.com/HubbleCommand/mobile_controls/blob/master/media/joystick.gif?raw=true)

## Virtual Joystick
Virtual Joystick for use on touchscreens to emulate a controller joystick.

## Screen Gestures
Screenspaces / canvas gesture detector. Reports pan, rotate, and scale gestures.

Supports floating Virtual Joystick. When adding floating Virtual Joystick, make sure to add the path to a pre-configured floating joystick. Node that this is enabled on long presses / clicks, so only one can be visible at a time.

### Project Setup
Project Settings -> Input Devices -> Pointing

Make sure to disable all input emulation, 
-	"Emulate Touch From Mouse"
-	"Emulate Mouse From Touch"
-	"Enable Long Press as Right Click"

and enable "Pan and Scale Gestures".

![project settings](https://github.com/HubbleCommand/mobile_controls/blob/master/media/project_settings.png?raw=true)

For more details, read the corresponding [documentation](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html).

