package;

import Conductor.BPMChangeEvent;
#if mobile
import mobile.TouchBar;
import flixel.FlxSubState;
#end
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.addons.ui.FlxUIState;
import flixel.addons.transition.FlxTransitionableState;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.FlxState;
import flixel.FlxBasic;

class MusicBeatState extends FlxUIState
{
	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;
	private var curBeatStep:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	/**
	 * Default camera.
	 * By default all cameras will be reset with camGame only active.
	 * To override this initialize camGame before calling super.create()
	 */
	public var camGame:FlxCamera;
	#if mobile
	var bar:TouchBar;
	var camBar:FlxCamera;
	var barMode:BarMode = BarMode.NORMAL;

	function setupBar () {
		camBar = new FlxCamera();
		camBar.bgColor.alpha = 0;
		FlxG.cameras.add(camBar);
		bar = new TouchBar(barMode, controls);
		bar.cameras = [camBar];
		add(bar);		
	}

	override function openSubState (SubState:FlxSubState) {
		if (bar != null) bar.active = false;
		if (camBar != null) camBar.alpha = 0;
		super.openSubState(SubState);
	}

	override function closeSubState () {
		super.closeSubState();
		if (camBar != null) camBar.alpha = 1;
		if (bar != null) {
			bar.active = true;
			bar.focus();
		}
	}
	#end

	override function create() {
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		super.create();

		if(!skip) {
			openSubState(new CustomFadeTransition(0.7, true));
		}
		FlxTransitionableState.skipNextTransOut = false;

		if (camGame == null) { // camGame is not initialized at this point (usually after child finishes), so do it here
			camGame = new FlxCamera();
			FlxG.cameras.reset(camGame);
			FlxCamera.defaultCameras = [camGame]; // Just to be extremely sure. Screw deprecation warnings.
		}
		#if mobile
		setupBar();
		#end
	}

	override function update(elapsed:Float)
	{
		//everyStep();
		var oldStep:Int = curStep;

		updateCurStep();
		if (curStep != oldStep) recalculateBeat(oldStep);
		updateDecimals();
		if (curStep > oldStep && curStep >= 0) stepHit();

		if(FlxG.save.data != null) FlxG.save.data.fullscreen = FlxG.fullscreen;

		super.update(elapsed);
	}

	private function updateDecimals()
	{
		curDecBeat = curStep / Conductor.stepsPerBeat;
	}

	private function recalculateBeat(?oldStep:Null<Int>):Void
	{
		if (oldStep != null && curStep == oldStep + 1) { // Lazy evaluation
			curBeatStep += 1;
			if (curBeatStep == Conductor.stepsPerBeat) {
				curBeat += 1;
				curBeatStep = 0;
			}
		} else { // recalculate
			curBeat = Math.floor(curDecBeat);
			curBeatStep = curStep % Conductor.stepsPerBeat;
		}
	}

	private function updateCurStep():Void
	{
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var shit = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	public static function switchState(nextState:FlxState) {
		// Custom made Trans in
		var curState:Dynamic = FlxG.state;
		var leState:MusicBeatState = curState;
		if(!FlxTransitionableState.skipNextTransIn) {
			leState.openSubState(new CustomFadeTransition(0.6, false));
			if(nextState == FlxG.state) {
				CustomFadeTransition.finishCallback = function() {
					FlxG.resetState();
				};
				//trace('resetted');
			} else {
				CustomFadeTransition.finishCallback = function() {
					FlxG.switchState(nextState);
				};
				//trace('changed state');
			}
			return;
		}
		FlxTransitionableState.skipNextTransIn = false;
		FlxG.switchState(nextState);
	}

	public static function resetState() {
		MusicBeatState.switchState(FlxG.state);
	}

	public static function getState():MusicBeatState {
		var curState:Dynamic = FlxG.state;
		var leState:MusicBeatState = curState;
		return leState;
	}

	public function stepHit():Void
	{
		if (curBeatStep == 0)
			beatHit();
	}

	public function beatHit():Void
	{
		// do nothing again
	}
}
