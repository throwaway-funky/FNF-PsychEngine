package;

import Note.NoteSetting;

typedef SwagSection =
{
	var sectionNotes:Array<Dynamic>;
	var lengthInSteps:Int;
	var typeOfSection:Int;
	var mustHitSection:Bool;
	var gfSection:Bool;
	var bpm:Float;
	var changeBPM:Bool;
	var altAnim:Bool;

	var ?noteSettings:NoteSetting;
}

class Section
{
	public static var FALLBACK(get, never):SwagSection;
	public static function get_FALLBACK ():SwagSection
	{
		return {
			lengthInSteps: 16,
			bpm: 150.0,
			changeBPM: false,
			mustHitSection: true,
			gfSection: false,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};
	}
}
