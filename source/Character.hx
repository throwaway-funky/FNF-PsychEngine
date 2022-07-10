package;

import flixel.math.FlxPoint;
import animateatlas.AtlasFrameMaker;
import flixel.FlxSprite;
import flixel.tweens.FlxTween;
import flixel.util.FlxSort;
import helper.NoteLoader;
#if MODS_ALLOWED
import sys.io.File;
import sys.FileSystem;
#end
import haxe.Json;

using StringTools;

typedef CharacterFile = {
	var animations:Array<AnimArray>;
	var image:String;
	var scale:Float;
	var sing_duration:Float;
	var healthicon:String;

	var position:Array<Float>;
	var camera_position:Array<Float>;

	var flip_x:Bool;
	var no_antialiasing:Bool;
	var healthbar_colors:Array<Int>;
}

typedef AnimArray = {
	var anim:String;
	var name:String;
	var fps:Int;
	var loop:Bool;
	var indices:Array<Int>;
	var offsets:Array<Int>;
}

class Character extends FlxSprite
{
	public var animOffsets:Map<String, Array<Dynamic>>;

	public var isPlayer:Bool = false;
	public var curCharacter:String = DEFAULT_CHARACTER;

	public var colorTween:FlxTween;
	public var holdTimer:Float = 0;
	public var heyTimer:Float = 0;
	public var specialAnim:Bool = false;
	public var stunned:Bool = false;
	public var singDuration:Float = 4; //Multiplier of how long a character holds the sing pose

	// Camera
	// public var cameraOffset:FlxPoint = new FlxPoint(0, 0);
	// public var cameraPosition:FlxPoint = new FlxPoint(0, 0);
	public var cameraPosition:Array<Float> = [0, 0];

	public var animName = null;

	// Idle dance stuff
	public var idling:Bool = false;
	public var idleSuffix:String = '';
	public var danceIdle:Bool = false; // Character use "danceLeft" and "danceRight" instead of "idle"
	public var danceEveryNumBeats:Int = 2;
	public var skipDance:Bool = false; // Character don't dance at all
	public var danced:Bool = false;
	private var dancedBase:Bool = false;
	public var skipResetDance:Bool = false;
	private var capturingDance:Bool = true;
	private var settingCharacterUp:Bool = true;

	// Sing stuff
	public var singing:Bool = false;
	public var singTime:Float = -1000;
	public var holdChecks:Array<Void -> Bool> = [];
	public var noteDataSet:Map<Int, Int> = [];
	public var noteAnimSet:Array<Int> = [];

	public var psaAnim:String = '';
	public var psaSuffix:String = '';
	public var psaCheck:Bool = false; 
	public var psaTrigger:Bool = false; 

	public var healthIcon:String = 'face';
	public var animationsArray:Array<AnimArray> = [];

	public var positionArray:Array<Float> = [0, 0];

	public var hasMissAnimations:Bool = false;

	//Used on Character Editor
	public var debugMode:Bool = false;
	public var imageFile:String = '';
	public var jsonScale:Float = 1;
	public var noAntialiasing:Bool = false;
	public var originalFlipX:Bool = false;
	public var healthColorArray:Array<Int> = [255, 0, 0];

	public static final DEFAULT_CHARACTER:String = 'bf'; //In case a character is missing, it will use BF on its place
	public function new(x:Float, y:Float, ?character:String = 'bf', ?isPlayer:Bool = false)
	{
		super(x, y);

		animOffsets = new Map();

		curCharacter = character;
		this.isPlayer = isPlayer;
		antialiasing = ClientPrefs.globalAntialiasing;
		// var library:String = null;
		switch (curCharacter)
		{
			//case 'your character name in case you want to hardcode them instead':

			// For subclasses that doesn't load a character file. May segfault if used without loading actual sprites
			case '.none':		

			default:
				var characterPath:String = 'characters/' + curCharacter + '.json';

				#if MODS_ALLOWED
				var path:String = Paths.modFolders(characterPath);
				if (!Paths.exists(path)) {
					path = Paths.getPreloadPath(characterPath);
				}
				#else
				var path:String = Paths.getPreloadPath(characterPath);
				#end
				if (!Paths.exists(path))
				{
					path = Paths.getPreloadPath('characters/' + DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
				}

				var rawJson = Paths.getText(path);

				var json:CharacterFile = cast Json.parse(rawJson);
				var spriteType = "sparrow";
				//sparrow
				//packer
				//texture
				#if MODS_ALLOWED
				var modTxtToFind:String = Paths.modsTxt(json.image);
				var txtToFind:String = Paths.getPath('images/' + json.image + '.txt', TEXT);
				
				//var modTextureToFind:String = Paths.modFolders("images/"+json.image);
				//var textureToFind:String = Paths.getPath('images/' + json.image, new AssetType();
				
				if (Paths.exists(modTxtToFind) || Paths.exists2(txtToFind))
				#else
				if (Paths.exists(Paths.getPath('images/' + json.image + '.txt', TEXT)))
				#end
				{
					spriteType = "packer";
				}
				
				#if MODS_ALLOWED
				var modAnimToFind:String = Paths.modFolders('images/' + json.image + '/Animation.json');
				var animToFind:String = Paths.getPath('images/' + json.image + '/Animation.json', TEXT);
				
				//var modTextureToFind:String = Paths.modFolders("images/"+json.image);
				//var textureToFind:String = Paths.getPath('images/' + json.image, new AssetType();
				
				if (Paths.exists(modAnimToFind) || Paths.exists2(animToFind))
				#else
				if (Paths.exists(Paths.getPath('images/' + json.image + '/Animation.json', TEXT)))
				#end
				{
					spriteType = "texture";
				}

				switch (spriteType){
					
					case "packer":
						frames = Paths.getPackerAtlas(json.image);
					
					case "sparrow":
						frames = Paths.getSparrowAtlas(json.image);
					
					case "texture":
						frames = AtlasFrameMaker.construct(json.image);
				}
				imageFile = json.image;

				if (json.scale != 1) {
					jsonScale = json.scale;
					setGraphicSize(Std.int(width * jsonScale));
					updateHitbox();
				}

				positionArray = json.position;
				cameraPosition = json.camera_position;

				healthIcon = json.healthicon;
				singDuration = json.sing_duration;
				flipX = json.flip_x;
				if (json.no_antialiasing) antialiasing = false;

				if(json.healthbar_colors != null && json.healthbar_colors.length > 2)
					healthColorArray = json.healthbar_colors;

				animationsArray = json.animations;
				if (animationsArray != null) {
					for (anim in animationsArray) {
						var animAnim:String = anim.anim;
						var animName:String = anim.name;
						var animFps:Int = anim.fps;
						var animLoop:Bool = anim.loop;
						var animIndices:Array<Int> = anim.indices;
						if(animIndices != null && animIndices.length > 0) {
							animation.addByIndices(animAnim, animName, animIndices, "", animFps, animLoop);
						} else {
							animation.addByPrefix(animAnim, animName, animFps, animLoop);
						}

						if(anim.offsets != null && anim.offsets.length > 1) {
							addOffset(anim.anim, anim.offsets[0], anim.offsets[1]);
						}
					}
				} else {
					quickAnimAdd('idle', 'BF idle dance');
				}
				//trace('Loaded file to character ' + curCharacter);
		}
		originalFlipX = flipX;

		recalculateDanceIdle();
		dance();

		if (isPlayer)
		{
			flipX = !flipX;
		}
	}

	override function update(elapsed:Float)
	{
		if (psaTrigger) {
			playSingAnim(psaSuffix, psaAnim, psaCheck);
			singing = true;
			psaTrigger = false;
		}

		if(!debugMode && animName != null)
		{

			if(heyTimer > 0)
			{
				heyTimer -= elapsed;
				if(heyTimer <= 0)
				{
					if(specialAnim && animName == 'hey' || animName == 'cheer')
					{
						specialAnim = false;
						dance();
					}
					heyTimer = 0;
				}
			} else if(specialAnim && (animation.curAnim == null || animation.curAnim.finished)) {
				specialAnim = false;
				dance();
			}

			if (!isPlayer)
			{
				if (animName.startsWith('sing'))
				{
					holdTimer += elapsed;
				}

				if (holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration)
				{
					dance();
					holdTimer = 0;
				}
			}

			if (animation.curAnim != null && animation.curAnim.finished && animation.getByName(animName + '-loop') != null) {
				playAnim(animName + '-loop');
			}
		}
		super.update(elapsed);
	}

	/**
	 * FOR GF DANCING SHIT
	 */
	public function dance()
	{
		if (!debugMode && !skipDance && !specialAnim)
		{
			if(danceIdle)
			{
				danced = !danced;

				if (danced)
					playAnim('danceRight' + idleSuffix, true);
				else
					playAnim('danceLeft' + idleSuffix, true);
			}
			else tryPlayAnim('idle', idleSuffix, true);

			idling = true;
		}
	}

	public function tryDance()
	{
		if (stunned) return;
		if (!animName.startsWith('sing')) dance();
	}

	/**
	 * Keeps track of sung notes, allowing multi-arrow animations
	 */
	public function sing(noteData:Int, suffix:String = '', realNoteData:Int, noteID:Int, noteTime:Float, holdCheck:Void -> Bool = null)
	{
		var noteName:String = Note.NAME_SCHEME[noteData];
		if (noteTime > singTime + 1) { // ahead: replace
			singTime = noteTime;
			holdChecks = [];
			noteDataSet.clear();
			noteAnimSet = [];

			if (holdCheck != null) holdChecks.push(holdCheck);

			noteDataSet[realNoteData] = noteID;
			noteAnimSet.push(Note.SCHEME[noteData]);
			lazyPlaySingAnim(suffix, noteName, false); // Single key pressed. No need to checkSet yet
		} else if (noteTime >= singTime - 1) { // same cluster: append to list
			if (holdCheck != null) holdChecks.push(holdCheck);

			var oldID:Null<Int> = noteDataSet[realNoteData];
			if (oldID == null) noteDataSet[realNoteData] = oldID = noteID;
			if (oldID == noteID) {
				noteAnimSet.push(Note.SCHEME[noteData]);
				lazyPlaySingAnim(suffix, noteName);
			}
		} else { // behind (wrong order): Still play, but disregard in cluster
			lazyPlaySingAnim(suffix, noteName, false);
		}

		holdTimer = 0;
		singing = true;
	}

	inline function lazyPlaySingAnim(suffix:String, noteName:String, checkSet:Bool = true)
	{
		psaTrigger = true;
		psaCheck = checkSet;
		psaAnim = noteName;
		psaSuffix = suffix;
	}

	public function playSingAnim(suffix:String, noteName:String, checkSet:Bool = true)
	{
		if (checkSet) {
			var ar:Array<Int> = noteAnimSet;
			ar.sort((a, b) -> a - b);
			
			var singAnim:String = 'sing' + ar.map(x -> NoteList.keys[x].id).join('-');

			if (tryPlayAnim(singAnim, suffix, true)) return;
		}

		var singAnim:String = 'sing' + noteName;
		tryPlayAnim(singAnim, suffix, true);
	}

	/**
	 * Trigger miss animation, resets multihit.
	 */
	public function miss(noteData:Int, suffix:String = '')
	{
		if (hasMissAnimations) tryPlayAnim('sing' + Note.NAME_SCHEME[noteData] + 'miss', suffix, true);
		singTime = -1000;

		psaTrigger = false;
	}

	/**
	 * Check if the multihit buttons are still held, reset after a while is not.
	 */
	public function updateSing()
	{
		if (singing) {
			var held:Bool = true;
			if (holdChecks.length == 0) {
				held = false;
			} else {
				for (holdCheck in holdChecks) held = held && holdCheck(); // all of them have to be held because yes

				if (!held) { holdChecks = []; }
			}

			if (!held && holdTimer >= Conductor.stepCrochet * 0.0011 * singDuration) {
				dance();
			}
		}
	}

	/**
	 * Tries to play an anim with suffix, then without if it doesn't work
	 * @param singAnim String, animation name 
	 * @param suffix String, animation suffix to test
	 * @param force Bool, force parameter passed to playAnim 
	 * @return Bool, true if the animation is found and played, false otherwise.
	 */
	public function tryPlayAnim(singAnim:String, suffix:String, force:Bool = false):Bool {
		if (animOffsets.exists(singAnim + suffix)) {
			playAnim(singAnim + suffix, force);
			return true;
		} else if (animOffsets.exists(singAnim)) {
			playAnim(singAnim, force);
			return true;
		} else return false;
	}

	/**
	 * Tries to play a special anim with suffix, setting timer if it works.
	 * @param singAnim String, animation name
	 * @return Bool, true if the animation is found and played, false otherwise.
	 */
	public function tryPlaySpecialAnim(singAnim:String):Bool {
		if (animOffsets.exists(singAnim)) {
			playAnim(singAnim, true);
			specialAnim = true;
			heyTimer = 0.6;

			// reset multihit. Not sure if needed.
			singTime = -1000;
			psaTrigger = false;
			return true;
		} else return false;
	}


	public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0):Void
	{
		idling = false;
		singing = false;
		specialAnim = false;
		animation.play(AnimName, Force, Reversed, Frame);

		var daOffset = animOffsets.get(AnimName);
		if (animOffsets.exists(AnimName))
		{
			offset.set(daOffset[0], daOffset[1]);
		}
		else
			offset.set(0, 0);

		if (curCharacter.startsWith('gf'))
		{
			if (~/^sing[LW]\d$/.match(AnimName))
			{
				danced = true;
			}
			else if (~/^sing[RE]\d$/.match(AnimName))
			{
				danced = false;
			}
			else if (~/^sing[UDNS]\d$/.match(AnimName))
			{
				danced = !danced;
			}
		}

		animName = animation.name;
	}

	function sortAnims(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	public function recalculateDanceIdle() 
	{
		var lastDanceIdle:Bool = danceIdle;
		danceIdle = (animation.getByName('danceLeft' + idleSuffix) != null && animation.getByName('danceRight' + idleSuffix) != null);

		if(settingCharacterUp)
		{
			danceEveryNumBeats = (danceIdle ? 1 : 2);
			settingCharacterUp = false;
		}
		else if(lastDanceIdle != danceIdle)
		{
			var calc:Float = danceEveryNumBeats;
			if(danceIdle)
				calc /= 2;
			else
				calc *= 2;

			danceEveryNumBeats = Math.round(Math.max(calc, 1));
		}
	}

	public function resetDance()
	{
		if (skipResetDance) return;

		if (capturingDance) {
			dancedBase = danced;
			capturingDance = false;
		} else danced = dancedBase;
	}

	public function addOffset(name:String, x:Float = 0, y:Float = 0)
	{
		animOffsets[name] = [x, y];
	}

	public function quickAnimAdd(name:String, anim:String)
	{
		animation.addByPrefix(name, anim, 24, false);
	}

	public function postprocess(scheme:Array<NoteEK>, warn:Bool = true)
	{
		NoteLoader.postprocessCharacter(scheme, this, warn);
		return this;
	}
}
