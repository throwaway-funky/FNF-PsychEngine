package;

import Section.SwagSection;
import haxe.Json;
import Note;

using StringTools;

typedef ExtraCharacter = 
{
	var character:String;
	var offset:Array<Float>;
}

typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;

	var ?extraPlayer1:Array<ExtraCharacter>;
	var ?extraPlayer2:Array<ExtraCharacter>;

	var arrowSkin:String;
	var splashSkin:String;
	var validScore:Bool;

	var keyScheme:Array<String>;

	var ?noteSettings:NoteSetting;
}

class Song
{
	public static var FALLBACK(get, never):SwagSong;
	public static function get_FALLBACK ():SwagSong
	{
		return {
			song: 'Test',
			notes: [Section.FALLBACK],
			events: [],
			bpm: 150.0,
			needsVoices: true,
			speed: 1.0,
			
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			
			arrowSkin: '',
			splashSkin: 'noteSplashes',
			validScore: false,

			keyScheme: ["L1", "D1", "U1", "R1"]
		};
	}
	public static var curPlaying(default, set):SwagSong = FALLBACK; // Replace PlayState.SONG
	public static var curSongName:String = 'Test';
	public static function set_curPlaying(song:SwagSong)
	{
		if (curPlaying == song) return curPlaying; // No updates needed

		curPlaying = song;

		Note.updateScheme(song.keyScheme);

		return curPlaying;
	}

	private static function onLoadJson(songJson:Dynamic) // Convert old charts to newest format
	{
		// Fix for player3 -> gfVersion rename
		if(songJson.gfVersion == null)
		{
			songJson.gfVersion = songJson.player3;
			songJson.player3 = null;
		}

		// Fix for "negative number" event notes.
		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}

		// Fix for no keyScheme.
		if(songJson.keyScheme == null) songJson.keyScheme = FALLBACK.keyScheme;
	}

	// public function new(song, notes, bpm)
	// {
	// 	this.song = song;
	// 	this.notes = notes;
	// 	this.bpm = bpm;
	// }

	/**
	 * Produces SwagSong from a json file, given the "folder" and "file" names (spaces replaced with hyphens)
	 * <p> All song file paths are assumed to be in the format ["mods" or "assets"]/data/[folder]/[file].
	 * 
	 * @param jsonInput	String file name
	 * @param folder 	(optional) String folder name. If omitted, it is the same as jsonInput
	 * @return 			SwagSong parsed given the file and path names
	 */
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		var rawJson = null;
		if (folder == null) folder = jsonInput;
		
		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsJson(formattedFolder + '/' + formattedSong);
		if(Paths.exists(moddyFile)) {
			rawJson = Paths.getText(moddyFile).trim();
		}
		#end

		if(rawJson == null) {
			rawJson = Paths.getText(Paths.json(formattedFolder + '/' + formattedSong)).trim();
		}

		while (!rawJson.endsWith("}"))
		{
			rawJson = rawJson.substr(0, rawJson.length - 1);
			// LOL GOING THROUGH THE BULLSHIT TO CLEAN IDK WHATS STRANGE
		}

		// FIX THE CASTING ON WINDOWS/NATIVE
		// Windows???
		// trace(songData);

		// trace('LOADED FROM JSON: ' + songData.notes);
		/* 
			for (i in 0...songData.notes.length)
			{
				trace('LOADED FROM JSON: ' + songData.notes[i].sectionNotes);
				// songData.notes[i].sectionNotes = songData.notes[i].sectionNotes
			}

				daNotes = songData.notes;
				daSong = songData.song;
				daBpm = songData.bpm; */

		var songJson:Dynamic = parseJSONshit(rawJson);
		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		onLoadJson(songJson);
		return songJson;
	}

	/**
	 * Produces SwagSong from raw json string.
	 * 
	 * @param rawJson	String to parse
	 * @return 			SwagSong parsed from the string
	 */
	public static function parseJSONshit(rawJson:String):SwagSong
	{
		var swagShit:SwagSong = cast Json.parse(rawJson).song;
		swagShit.validScore = true;
		return swagShit;
	}

	/**
	 * Given a song and step number, return the section and beat number
	 * 
	 * @param song	SwagSong context
	 * @param step	Int step number
	 * @return 		Struct containing beat and section numbers.
	 */
	public static function songStepPosition(song:SwagSong, step:Int):{ section:Int, beat:Int, sectionStep:Int, beatStep:Int }
	{
		if (step <= 0 || song == null) return null;
		var daStep:Int = 0;
		var daBeat:Int = 0;
		for (i in 0...song.notes.length) if (song.notes[i] != null) {
			if (daStep + song.notes[i].lengthInSteps > step) { 
				var daSectionStep:Int = step - daStep;
				var daBeatStep:Int = daSectionStep % Conductor.stepsPerBeat;

				return { 
					section: i, 
					beat: daBeat + Math.floor(daSectionStep / Conductor.stepsPerBeat),
					sectionStep: daSectionStep,
					beatStep: daBeatStep
				};
			}

			daBeat += Math.ceil(song.notes[i].lengthInSteps / Conductor.stepsPerBeat);
			daStep += song.notes[i].lengthInSteps;
		}
		return null;
	}

	/**
	 * Get the start time of a song section
	 * 
	 * @param song	SwagSong context
	 * @param index	Int index of the section
	 * @return	 	Float songPosition 
	 */
	public static function songSectionStartTime(song:SwagSong, index:Int):Float
	{
		var daStepCrochet:Float = (1000 * 60 / song.bpm) / Conductor.stepsPerBeat;
		var daPos:Float = 0;
		for (i in 0...index) if (song.notes[i] != null)	{
			if (song.notes[i].changeBPM) daStepCrochet = (1000 * 60 / song.notes[i].bpm) / Conductor.stepsPerBeat;
			daPos += song.notes[i].lengthInSteps * daStepCrochet;
		}
		return daPos;
	}
}
