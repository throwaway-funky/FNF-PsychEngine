package mobile;

#if mobile
import flixel.input.IFlxInputManager;
import flixel.input.FlxInput;

import flixel.input.touch.FlxTouch;

import mobile.FlxTouchInput;
import Controls;

class TouchInputManager implements IFlxInputManager
{
	/**
	 * Manager for FlxTouchInputs.
	 */

	public static var keysMap:Map<Control, FlxTouchInput> = [];
	var controls:Controls;

	public function new (controls:Controls) {
		this.controls = controls;

		for (control in Type.allEnums(Control)) {
			var touchInput:FlxTouchInput = new FlxTouchInput(0);
			controls.bindTouchInput(control, touchInput);
			keysMap.set(control, touchInput);
		}
	}

	public function reset () {
		for (touchInput in keysMap.iterator()) {
			touchInput.reset();
		}
	}

	function update () {
		for (touchInput in keysMap.iterator()) {
			touchInput.update();
		}
	}

	// onFocus can remap all pressed touches, but not very necessary now
	function onFocus () {

	}

	/**
	 * Reset all touchinputs just in case
	 */
	function onFocusLost () {
		reset();
	}

	/**
	 * Don't
	 */
	public function destroy () {
		controls.flushTouchInput();
		keysMap.clear();
	}
}
#end