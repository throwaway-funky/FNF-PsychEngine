package mobile;

#if mobile
import flixel.input.FlxInput;

import flixel.input.touch.FlxTouch;

class FlxTouchInput extends FlxInput<Int>
{
	/**
	 * FlxInput wrapper for FlxTouch.
	 * Note that registering new touches in this input is done externally.
	 */

	var touchs:Array<FlxTouch> = [];

	public var pressPulseCallback:Void->Void = null;
	public var releasePulseCallback:Void->Void = null;

	/**
	 * Register a new FlxTouch for tracking, and triggers a just_pressed action.
	 * If this touch is released, it will also send a release signal.
	 */
	public function newTouch (touch:FlxTouch) {
		if (touchs.length == 0 && pressPulseCallback != null) pressPulseCallback();
		touchs.push(touch);

		last = current;
		current = FlxInputState.JUST_PRESSED;
	}

	/**
	 * Trigger a just_released action.
	 * If supplied with a FlxTouch, it will attempt to remove the touch from the tracking list.
	 */
	public function triggerRelease (?touch:FlxTouch) {
		last = current;
		current = FlxInputState.JUST_RELEASED;

		if (touch != null) {
			touchs.remove(touch);
			if (touchs.length == 0 && releasePulseCallback != null) releasePulseCallback();
		}
	}

	/**
	 * Updates the list of tracked touches. If any of them are released, 
	 * filter them out and trigger just_released.
	 */
	override function update () {
		var oldSize:Int = touchs.length;
		touchs = touchs.filter(function (touch:FlxTouch) { return touch.pressed; });

		if (touchs.length < oldSize) { // Less touches, trigger 1-pulse JR
			current = FlxInputState.JUST_RELEASED;
			if (touchs.length == 0 && releasePulseCallback != null) releasePulseCallback();
		} else if (last == current && (justReleased || justPressed)) { // Same level, reevaluate pressedness
			current = touchs.length > 0 ? FlxInputState.PRESSED : FlxInputState.RELEASED;
		} // otherwise unchanged
		last = current;
	}
}
#end