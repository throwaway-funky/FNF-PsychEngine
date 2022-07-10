package hardcoded;

import Character;
using StringTools;

import flixel.FlxG;
import Section.SwagSection;

class ShootingPico extends Character
{
	public var animationNotes:Array<Dynamic> = [];

	public function new(x:Float, y:Float, ?char:String = 'pico-speaker')
	{
		super(x, y, char, false);
		
		skipDance = true;
		loadMappedAnims();
		playAnim("shoot1");
	}

	override function update(elapsed:Float)
	{
		if (!debugMode && animName != null) {
			if (animationNotes.length > 0 && Conductor.songPosition > animationNotes[0][0]) {
				var noteData:Int = 1;
				if(animationNotes[0][1] > 2) noteData = 3;

				noteData += FlxG.random.int(0, 1);
				playAnim('shoot' + noteData, true);
				animationNotes.shift();
			}
			if(animation.curAnim.finished) playAnim(animName, false, false, animation.curAnim.frames.length - 3);
		}

		super.update(elapsed);
	}

	function loadMappedAnims():Void
	{
		var noteData:Array<SwagSection> = Song.loadFromJson('picospeaker', Paths.formatToSongPath(Song.curSongName)).notes;
		for (section in noteData) {
			for (songNotes in section.sectionNotes) {
				animationNotes.push(songNotes);
			}
		}
		TankmenBG.animationNotes = animationNotes;
		animationNotes.sort(sortAnims);
	}
}