package mobile;

#if mobile
import flixel.FlxG;
import flixel.math.FlxRect;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.group.FlxSpriteGroup;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.FlxBasic;
import Controls;
import mobile.TouchInputManager;

import flixel.input.touch.FlxTouch;

enum BarMode {
	NONE;
	ACCEPT;
	YESNO;
	NORMAL;
	RESET;
	GAME_CENTER;
	GAME_LEFT;
	GAME_PRIM; // for testing
}

class TouchBox extends FlxSpriteGroup
{
	var bg:FlxSprite = null;
	var txt:FlxText = null;
	public var label:String = null;
	public var bound:FlxSprite = null;
	public var key:Control = null;
	public var numTouch:Int = 0;
	
	public function new (width:Int, x:Int, ?label:String, color:FlxColor = FlxColor.WHITE, ?key:Control) {
		super();

		bg = new FlxSprite(x, 0).makeGraphic(width, FlxG.height, FlxColor.TRANSPARENT, true);
		FlxGradient.overlayGradientOnFlxSprite(bg, width - 2, Std.int(FlxG.height / 8), [0x66000000 | 0x00FFFFFF & color, 0x00FFFFFF & color], 1, 0);
		add(bg);

		if (label != null) {
			txt = new FlxText(x, 10, width, label);
			txt.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			txt.borderSize = 1;
			add(txt);
		}

		this.key = key;
		this.label = label;

		bound = new FlxSprite(x, 0).makeGraphic(width, FlxG.height, 0x33000000 | 0x00FFFFFF & color);
		bound.alpha = 0;
		add(bound);

		focus();
	}

	/**
	 * Get touchInput callbacks
	 */
	public function focus () {
		var touchInput = TouchInputManager.keysMap.get(key);
		touchInput.pressPulseCallback = function () { bound.alpha = 1; }
		touchInput.releasePulseCallback = function () { bound.alpha = 0; }
	}

	override public function destroy () {
		var touchInput = TouchInputManager.keysMap.get(key);
		touchInput.pressPulseCallback = null; // This will cause problems with substates but TODO: for now
		touchInput.releasePulseCallback = null;
		super.destroy();
	}
}

class TouchBar extends FlxTypedSpriteGroup<TouchBox>
{
	var mode:BarMode;
	var controls:Controls;
	static var inputActive:Bool = false;

	final unit:Float = FlxG.width / 16;

	public function new (mode:BarMode = BarMode.NORMAL, ?controls:Controls) {
		super();
		this.mode = mode;
		this.controls = controls;

		if (!inputActive) {
			trace(FlxG.inputs.list);
			FlxG.inputs.add(new TouchInputManager(controls));
			inputActive = true;
		}

		switch (mode) {
			case NONE:
			case ACCEPT:
				add(new TouchBox(Std.int(unit * 16), Std.int(unit * 0), "Accept", FlxColor.LIME, Control.ACCEPT));	
			case YESNO:
				add(new TouchBox(Std.int(unit * 8), Std.int(unit * 8), "Back", FlxColor.GRAY, Control.BACK));						
				add(new TouchBox(Std.int(unit * 8), Std.int(unit * 0), "Accept", FlxColor.LIME, Control.ACCEPT));
			case NORMAL:
				add(new TouchBox(Std.int(unit * 4), Std.int(unit * 12), "Accept", FlxColor.LIME, Control.ACCEPT));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 10), "Back", FlxColor.GRAY, Control.BACK));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 6), "Right", FlxColor.WHITE, Control.UI_RIGHT));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 4), "Up", FlxColor.WHITE, Control.UI_UP));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 2), "Down", FlxColor.WHITE, Control.UI_DOWN));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 0), "Left", FlxColor.WHITE, Control.UI_LEFT));
			case RESET:
				add(new TouchBox(Std.int(unit * 4), Std.int(unit * 12), "Accept", FlxColor.LIME, Control.ACCEPT));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 10), "Back", FlxColor.GRAY, Control.BACK));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 8), "Reset", FlxColor.RED, Control.RESET));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 6), "Right", FlxColor.WHITE, Control.UI_RIGHT));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 4), "Up", FlxColor.WHITE, Control.UI_UP));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 2), "Down", FlxColor.WHITE, Control.UI_DOWN));
				add(new TouchBox(Std.int(unit * 2), Std.int(unit * 0), "Left", FlxColor.WHITE, Control.UI_LEFT));
			case GAME_CENTER:
				add(new TouchBox(Std.int(unit * 1), Std.int(unit * 7), "Pause", FlxColor.GRAY, Control.PAUSE));
				add(new TouchBox(Std.int(unit * 1), Std.int(unit * 0), "Reset", FlxColor.RED, Control.RESET));
			case GAME_LEFT:
				add(new TouchBox(Std.int(unit * 1), Std.int(unit * 1), "Pause", FlxColor.GRAY, Control.PAUSE));
				add(new TouchBox(Std.int(unit * 1), Std.int(unit * 0), "Reset", FlxColor.RED, Control.RESET));
			default:
		}

		scrollFactor.set(0, 0);
	}

	/**
	 * Get touchInput callbacks for each box
	 */
	public function focus () {
		forEachExists(function (box:TouchBox) {
			box.focus();
		});
	}

	override public function update (elapsed:Float) {
		super.update(elapsed);

		if (controls == null) return;
		for (touch in FlxG.touches.justStarted()) {
			forEachExists(function (box:TouchBox) {
				if (touch.overlaps(box.bound)) {
					var touchInput:FlxTouchInput = TouchInputManager.keysMap.get(box.key);

					trace('pressed ' + box.label);
					touchInput.newTouch(touch);
				}
			});
		}

		/* Old ver
		for (touch in FlxG.touches.justStarted()) {
			var overlapped:Bool = false;
			forEachExists(function (box:TouchBox) {
				if (!overlapped && touch.overlaps(box.bound)) {
					overlapped = true;

					box.numTouch += 1;
					box.bound.alpha = 1;

					touchMap.set(touch, box);

					controls.bindTouch(box.key, touch);
					trace('pressed ' + box.label);
				}
			});
		}

		for (touch in FlxG.touches.justReleased()) {
			var box:TouchBox = touchMap.get(touch);
			if (box != null) {
				box.numTouch -= 1;
				if (box.numTouch == 0) box.bound.alpha = 0;
				controls.unbindTouch(box.key, touch);
				touchMap.remove(touch);
			}
		}
		*/
	}
}
#end