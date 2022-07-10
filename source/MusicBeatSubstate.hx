package;

import Conductor.BPMChangeEvent;
#if mobile
import mobile.TouchBar;
#end
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSubState;
import flixel.FlxBasic;
import flixel.FlxSprite;

class MusicBeatSubstate extends FlxSubState
{
	public function new()
	{
		super();
	}

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

	var camSub:FlxCamera;
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
	#end

	override function create()
	{
		super.create();
		camSub = new FlxCamera();
		camSub.bgColor.alpha = 0;
		FlxG.cameras.add(camSub);
		cameras = [camSub];

		#if mobile
		setupBar();
		#end
	}

	override function close()
	{
		#if mobile
		FlxG.cameras.remove(camBar);
		#end

		FlxG.cameras.remove(camSub);
		super.close();
	}

	override function update(elapsed:Float)
	{
		//everyStep();
		var oldStep:Int = curStep;

		updateCurStep();
		if (curStep != oldStep) recalculateBeat(oldStep);
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
