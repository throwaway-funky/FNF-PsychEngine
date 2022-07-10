package;

import flixel.FlxState;
import Section.SwagSection;
import Song.SwagSong;
import Conductor;

/**
 * MusicBeatState with section tracking.
 * Requires a SwagSong instance to create.
 */
class SongBeatState extends MusicBeatState
{
	// New variables
	/**
	 * This variable is unused, like lastStep and lastBeat.
	 */
	private var lastSection:Float = 0;

	private var curSection:Int = 0;
	private var curSectionStep:Int = 0;

	private var curDecSection:Float = 0;

	// Extra variables for tracking post-chart steps. 
	private var outroStep:Int = 0;
	private var outroBeat:Int = 0;
	private var outroBeatsPerSection:Int = 4;
	private var outroSection:Int = 0;
	private var outroSectionLength:Int = 16;
	private function updateSongVars () {
		outroStep = 0;
		outroBeat = 0;
		outroBeatsPerSection = 4;
		outroSection = songData.notes.length;
		outroSectionLength = 16;
		for (section in songData.notes) {
			outroSectionLength = section.lengthInSteps;
			outroStep += outroSectionLength;
			outroBeatsPerSection = Math.ceil(section.lengthInSteps / Conductor.stepsPerBeat);
			outroBeat += outroBeatsPerSection;
		}
	}

	public var songData(default, null):SwagSong = null;
	public var songName(default, null):String = null;

	public function loadSong(song:SwagSong, ?name:String):SongBeatState {
		if (name == null) {
			name = song.song;
		}
		if (songData != null) {
			trace("Warning: Reloading song");
		}

		songData = song;
		songName = name;
		updateSongVars();

		return this; // Meant for chaining
	}

	override function switchTo(nextState:FlxState):Bool
	{
		// Inherit current songData if new state data is null
		if (Std.isOfType(nextState, SongBeatState) && (cast nextState).songData == null) { 
			(cast nextState).loadSong(songData, songName);
		}

		return super.switchTo(nextState);
	}

	override private function updateDecimals()
	{
		var stepsPerBeat:Int = Conductor.stepsPerBeat;
		var lengthInSteps:Int = 16;

		if (songData != null) {
			if (songData.notes[curSection] != null) { // Normal calculation
				lengthInSteps = songData.notes[curSection].lengthInSteps;
				stepsPerBeat = Std.int(Math.min(lengthInSteps - (curSectionStep - curBeatStep), stepsPerBeat)); // Weird formula, I hope it works

				curDecBeat = curBeat + (curDecStep - curStep + curBeatStep) / stepsPerBeat;
				curDecSection = curSection + (curDecStep - curStep + curSectionStep) / lengthInSteps;
			} else if (curStep < 0) { // Before start: lengthInSteps is infinity, but we round towards decSection being 0.
				curDecBeat = curBeat + (curDecStep - curStep + curBeatStep) / stepsPerBeat;
				curDecSection = 0;
			} else if (curStep >= outroStep) { // After end: lengthInSteps is infinity, but we round towards decSection being the last section.
				curDecBeat = curBeat + (curDecStep - curStep + curBeatStep) / stepsPerBeat;
				curDecSection = songData.notes.length;
			} // Other cases shouldn't happen.
		} else { // Assume lengthInSteps is 16.
			curDecBeat = curBeat + (curDecStep - curStep + curBeatStep) / stepsPerBeat;
			curDecSection = curSection + (curDecStep - curStep + curSectionStep) / 16;
		}
	}

	override function recalculateBeat (?oldStep:Null<Int>) {
		var resolved:Bool = false;

		if (songData != null && oldStep != null && songData.notes[curSection] != null) { // Try to lazy-evaluate given the chance:
			var delta:Int = curStep - oldStep;
			var stepsPerSection = songData.notes[curSection].lengthInSteps;
			if (delta == 1) { // Forward
				curBeatStep += 1;
				curSectionStep += 1;
				if (curSectionStep == stepsPerSection) { // Next section
					curSection += 1;
					curSectionStep = 0;
					curBeat += 1;
					curBeatStep = 0;
				} else if (curBeatStep == Conductor.stepsPerBeat) { // Next beat
					curBeat += 1;
					curBeatStep = 0;
				}
				return;
			} else if (delta == -1 && curSectionStep > 0) { // Backward within section
				if (curBeatStep > 0) {
					curBeatStep -= 1;
				} else {
					curBeatStep = Conductor.stepsPerBeat - 1;
					curBeat -= 1;
				}
				curSectionStep -= 1;
				return;
			}
		}

		if (curStep < 0) { // Special case for negative steps
			curSection = -1;
			curSectionStep = curStep;
			curBeat = Math.floor(curStep / Conductor.stepsPerBeat);
			curBeatStep = curStep % Conductor.stepsPerBeat;
			return;
		} else if (curStep >= outroStep) { // And for post-chart steps
			curSection = songData.notes.length;
			curSectionStep = curStep - outroStep;
			var extraBeat:Int = Math.floor(curSectionStep / outroBeatsPerSection);
			curBeat = outroBeat + extraBeat;
			curBeatStep = curSectionStep % outroBeatsPerSection;
			return;
		}

		var result = Song.songStepPosition(songData, curStep);
		if (result == null) result = {
			section: Std.int(curStep / 16), 
			beat: Std.int(curStep / Conductor.stepsPerBeat),
			sectionStep: curStep % 16,
			beatStep: curStep % Conductor.stepsPerBeat
		};
		curSection = result.section;
		curBeat = result.beat;
		curSectionStep = result.sectionStep;
		curBeatStep = result.beatStep; 
		// trace('now: $curBeat:$curBeatStep $curSection:$curSectionStep');
	}

	override function create():Void
	{
		if (songData == null) {
			trace("Warning: Created with no songData");
		}
		super.create();
	}

	override function update(elapsed:Float):Void
	{
		if (songData == null) {
			trace("Warning: Running with no songData");
		}
		super.update(elapsed);
	}

	override function stepHit():Void
	{
		if (curSectionStep == 0)
			sectionHit();
		super.stepHit();
	}

	public function sectionHit():Void
	{
		// pass
	}
}