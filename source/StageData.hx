package;

#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#else
import openfl.utils.Assets;
#end
import haxe.Json;
import haxe.format.JsonParser;
import Song;

using StringTools;

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	var isPixelStage:Bool;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	var hide_girlfriend:Bool;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;
}

class StageData {
	public static var FALLBACK(get, never):StageFile;
	public static function get_FALLBACK ():StageFile
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			isPixelStage: false,
		
			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,
		
			camera_boyfriend: [0., 0.],
			camera_opponent: [0., 0.],
			camera_girlfriend: [0., 0.],
			camera_speed: 1.
		};
	}

	inline public static function hardcoded(songName:String) {
		return switch (Paths.formatToSongPath(songName)) {
			case 'spookeez' | 'south' | 'monster':
				'spooky';
			case 'pico' | 'blammed' | 'philly' | 'philly-nice':
				'philly';
			case 'milf' | 'satin-panties' | 'high':
				'limo';
			case 'cocoa' | 'eggnog':
				'mall';
			case 'winter-horrorland':
				'mallEvil';
			case 'senpai' | 'roses':
				'school';
			case 'thorns':
				'schoolEvil';
			case 'ugh' | 'guns' | 'stress':
				'tank';
			default:
				'stage';
		}
	}

	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';
		if(SONG.stage != null) {
			stage = SONG.stage;
		} else if(SONG.song != null) {
			stage = hardcoded(SONG.song);
		} else {
			stage = 'stage';
		}

		var stageFile:StageFile = getStageFile(stage);
		if (stageFile == null) { //preventing crashes
			forceNextDirectory = '';
		} else {
			forceNextDirectory = stageFile.directory;
		}
	}

	public static function getStageFile(stage:String):StageFile {
		var rawJson:String = null;
		var path:String = Paths.getPreloadPath('stages/' + stage + '.json');

		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders('stages/' + stage + '.json');
		if (Paths.exists(modPath)) {
			rawJson = Paths.getText(modPath);
		} else 
		#end
		if (Paths.exists(path)) {
			rawJson = Paths.getText(path);
		} else {
			return null;
		}
		return cast Json.parse(rawJson);
	}
}