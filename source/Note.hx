package;

import helper.CoolMacro;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxRect;
import editors.ChartingState;
import helper.NoteLoader;
import StrumNote;

using StringTools;

typedef EventNote = {
	strumTime:Float,
	event:String,
	value1:String,
	value2:String
}

typedef NoteSetting = {
	var ?anims:Array<Array<Dynamic>>;
	var ?animsScheme:Array<Array<Array<Dynamic>>>;

	var ?noteType:String;

	var ?hitHealth:Float;
	var ?missHealth:Float;
	var ?score:Int;
	var ?multScroll:Int;
}

class Note extends FlxSprite
{
	// State Variables
	public var spawned:Bool = false;
	public var canBeHit:Bool = false;
	public var canEverBeHit(get, never):Bool; // Helper variable for determining whether this note can be counted as a goodNoteHit
	public var tooLate:Bool = false;
	public var wasGoodHit:Bool = false;
	public var hitByOpponent:Bool = false; // wasGoodHit equivalent for opponent notes. should this be kept?

	public var distance:Float = 2000;
	public var scroll(default, set):Float = 1;
	// For clipping sustains
	public var clipTop(default, set):Float = -1;
	public var clipBottom(default, set):Float = -1;
	public var susHeight(default, null):Float = 0;

	public var rating:String = 'unknown';
	public var ratingMod:Float = 0; //9 = unknown, 0.25 = shit, 0.5 = bad, 0.75 = good, 1 = sick

	public var inEditor:Bool = false;

	// Note Parameters
	public var mustPress:Bool = false;
	public var noteData:Int = 0;
	public var strumTime(default, set):Float = 0;
	public var entranceTime:Float = 0;
	public var earlyHitMult:Float = 0.25;
	public var lateHitMult:Float = 1;

	public var sustainLength:Float = 0;
	public var isSustainNote:Bool = false;
	public var isSustainNoteEnd:Bool = false;

	public var noteType(default, set):String = null;
	// NoteType Properties
	public var hitHealth:Float = 0.023;
	public var missHealth:Float = 0.0475;
	public var ratingDisabled:Bool = false;

	public var score:Int = 350;
	public var horizontalLink:Bool = false; // Affects goodNoteHit and noteMiss, only used by 'Union' (hopefully)
	public var zIndex:Int = 0; // For layering notes above others

	public var activation:Int = 1; // Bitmap, 1: Press, 2: Hold, 4: Release
	public var hitConsequence:Int = 2; // Enum, 0: Miss, 1: Nothing, 2: Hit
	public var missConsequence:Int = 0; // Same as above

	public var noAnimation:Bool = false;
	public var noMissAnimation:Bool = false;
	public var ignoreNote:Bool = false; // Opponent Ignores Note 
	public var hitsoundDisabled:Bool = false;

	public var anims:Array<Array<Dynamic>> = [[0, -1, '']]; // Array of tuples (singer, noteData, animSuffix)

	// Strum Reference
	public var strum:StrumNote = null;

	// Lua
	public var extraData:Map<String,Dynamic> = [];

	// Internal reference
	public var prevNote:Note;
	public var nextNote:Note;
	public var tail:Array<Note> = [];
	public var parent:Note;

	// Event Note Parameters
	public var eventName:String = '';
	public var eventLength:Int = 0;
	public var eventVal1:String = '';
	public var eventVal2:String = '';

	// "Constants"
	public static final swagScaleConstant:Float = 0.7;
	public static final swagWidthConstant:Float = 160 * swagScaleConstant;
	public static final yScaleErrorTerm:Float = 0; // To cover up some 1-pixel rounding errors

	public static var TOTAL(default, null):Int = 4;
	public static var SCHEME(default, null):Array<NoteEK> = [L1, D1, U1, R1];
	public static var NAME_SCHEME(default, null):Array<NoteNameEK> = [L1, D1, U1, R1];

	public static var swagScaleSpacing(default, null):Float = 1;
	public static var swagWidthSpacing(default, null):Float = swagWidthConstant * swagScaleSpacing; // Controls the spacing between strums.
	public static var swagScaleVariable(default, null):Float = 1;
	public static var swagWidthVariable(default, null):Float = swagWidthConstant * swagScaleVariable; // Controls the size of notes.
	public static var swagOffsetStrum(default, null):Float = 0; // Controls the offset of the strums.

	public static function updateScheme (keyScheme:Array<String>)
	{
		var scheme:Array<NoteEK> = [];
		for (key in keyScheme) {
			var id:Null<NoteEK> = NoteList.keyEnums[key];
			if (id == null) {
				trace('Unknown key name $key. It\'s an up arrow now.');
				id = U1;
			}
			scheme.push((id : NoteEK));
		}

		SCHEME = scheme;
		NAME_SCHEME = [for (id in scheme) NoteList.keys[id].id];
		if (scheme.length != TOTAL) {
			TOTAL = scheme.length;

			swagScaleSpacing = 14/3 * (1/TOTAL - 1/(1.75 * TOTAL * TOTAL));
			swagWidthSpacing = swagWidthConstant * swagScaleSpacing;
			swagScaleVariable = Math.max(1/3, Math.sqrt(swagScaleSpacing)); // I have no guarantee this look nice.
			swagWidthVariable = swagWidthConstant * swagScaleVariable;
			swagOffsetStrum = (swagWidthSpacing * (TOTAL - 1) + swagWidthVariable - swagWidthConstant * 4) / 2;

			var gridSize:Int = Std.int(Math.min(40, ChartingState.UI_X / (2 * TOTAL + 1)));
			if (gridSize == 0) {
				trace("Warning: Calculated grid size is 0. You\'ve gone too far.");
				trace("Size will be set to 2 to prevent freezes, but do not expect Charting to work properly.");
				gridSize = 2;
			}
			ChartingState.GRID_SIZE = gridSize;
			ChartingState.CAM_OFFSET = Std.int(Math.min(FlxG.width / 2, ChartingState.GRID_SIZE * (2 * TOTAL + 1)));
			ChartingState.PERMUTE = [for (i in 0...TOTAL) i < ChartingState.PERMUTE.length && ChartingState.PERMUTE[i] < Note.TOTAL ? ChartingState.PERMUTE[i] : i]; // Lazily stretch/clip permutation. Too troublesome to guess.
		}
	}

	inline public static function setGfNote(note:Note, force:Bool = true)
	{
		if (force) note.anims = [[-1, -1, '']];
		else note.anims.push([-1, -1, '']);
	}

	inline public static function setAnimSuffix(note:Note, str:String, force:Bool = true)
	{
		for (anim in note.anims) if (force || anim[2] == '') anim[2] = str;
	}

	// How much slowdown will this cause?
	public static function applyNoteSetting(note:Note, ns:NoteSetting, ?noteType:String)
	{
		if (ns != null) {
			if (ns.animsScheme != null) note.anims = ns.animsScheme[note.noteData].map(a -> a.copy());
			else if (ns.anims != null) note.anims = ns.anims.map(a -> a.copy());
			if (ns.noteType != null && noteType == '') noteType = ns.noteType; // Weak override on notetypes
		}

		note.noteType = noteType;

		if (ns != null) { // Modifiers made after setting notetypes
			if (ns.hitHealth != null) note.hitHealth = ns.hitHealth;
			if (ns.missHealth != null) note.missHealth = ns.missHealth;
			if (ns.score != null) note.score = ns.score;
			if (ns.multScroll != null) note.multScroll = ns.multScroll;
		}
	}

	/**
	 * Creates a NoteSetting based on 2 NoteSettings with different priorities.
	 */
	public static function overrideNoteSetting(nsBottom:NoteSetting, nsTop:NoteSetting):NoteSetting
	{
		if (nsTop == null) return nsBottom;
		if (nsBottom == null) return nsTop;
		return CoolMacro.merge(nsBottom, nsTop);
	}
	//

	// Rendering Modifiers
	public var noteSplashDisabled:Bool = false;
	public var noteSplashTexture:String = null;
	public var noteSplashHue:Float = 0;
	public var noteSplashSat:Float = 0;
	public var noteSplashBrt:Float = 0;

	public var colorSwap:ColorSwap;

	public var offsetX:Float = 0;
	public var offsetY:Float = 0;
	public var offsetAngle:Float = 0;
	public var offsetDistance:Float = 0;
	public var offsetNormal:Float = 0; // offset in direction normal to trajectory
	public var multAlpha:Float = 1;
	public var multScroll(default, set):Float = 1.;

	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAngleDirection:Bool = true;
	public var copyAlpha:Bool = true;

	public var prefix:String = null;
	public var texture(default, set):String = null;

	private var noteTypeToPrefix:Map<String, String> = [
		'Hurt Note' => 'HURT',
		'Adlib' => 'ADLIB',
		'Avoid' => 'AVOID',
		'Fuzzy' => 'FUZZY',
		'Flick' => 'FLICK',
		'Score' => 'SCORE',
		'Union' => 'UNION'
	];

	private static var textureCache:Map<String, FlxSprite> = [];
	public static function resetCache() textureCache.clear();

	private function set_texture(value:String):String 
	{
		if (texture != value) {
			reloadNote(prefix, value);
		}
		texture = value;
		return value;
	}

	inline public function set_strumTime(value:Float):Float {
		strumTime = value;

		// Update entranceTime accordingly
		entranceTime = -3000;
		if (SongPlayState.instance != null) entranceTime = -SongPlayState.instance.spawnOffset;
		if (Math.abs(scroll) < 1) entranceTime = entranceTime / Math.abs(scroll);

		entranceTime += strumTime;

		return value;
	}

	private function set_scroll(value:Float):Float {
		if (isSustainNoteEnd) {
			if ((value < 0) != (scroll < 0)) flipY = !flipY;
		} else if (isSustainNote) {
			var rat:Float = Math.abs(value / scroll);
			susHeight *= rat;
			scale.y = (susHeight + yScaleErrorTerm) / frameHeight;
			updateHitbox();
		}
		scroll = value;
		// Force update entranceTime
		strumTime = strumTime;

		return value;
	}

	public function set_multScroll(value:Float):Float { // Updates scroll.
		scroll = value * (SongPlayState.instance != null ? SongPlayState.instance.songSpeed : 1);
		multScroll = value;

		return value;
	}

	inline public function set_clipTop(value:Float):Float {
		if (value >= 1) {
			if (!(clipTop >= 1)) {
				visible = false;
				scale.y = (susHeight + yScaleErrorTerm) / frameHeight;
				updateHitbox();
			}
		} else if (value <= 0 &&! (clipTop <= 0)) {
			if (!(clipTop <= 0)) {
				visible = true;
				scale.y = (susHeight + yScaleErrorTerm) / frameHeight;
				updateHitbox();
			}
		} else {
			if (value != clipTop) {
				visible = true;
				scale.y = (susHeight * (1 - value) + yScaleErrorTerm) / frameHeight;
				updateHitbox();
			}
		}
		clipTop = value;
		return value;
	}

	inline public function set_clipBottom(value:Float):Float {
		if (value <= 0) {
			clipRect = null;
		} else {
			if (clipBottom != value) {
				var swagRect:FlxRect = clipRect;
				if (swagRect == null) swagRect = new FlxRect(0, 0, frameWidth, frameHeight);
				swagRect.height += swagRect.y;
				swagRect.y = frameHeight * value;
				swagRect.height -= swagRect.y;

				clipRect = swagRect;
			}
		}
		clipBottom = value;
		return value;
	}

	private function set_noteType(value:String):String {
		noteSplashTexture = Song.curPlaying.splashSkin;

		var arrowHSV = ClientPrefs.arrowHSV[SCHEME[noteData]];
		colorSwap.hue = arrowHSV[0] / 360;
		colorSwap.saturation = arrowHSV[1] / 100;
		colorSwap.brightness = arrowHSV[2] / 100;

		if(noteData > -1 && noteType != value) {
			var newPrefix = noteTypeToPrefix.get(value);
			if (newPrefix == null) newPrefix = '';
			if (newPrefix != prefix) {
				prefix = newPrefix;
				reloadNote(prefix, texture);
			}

			switch(value) {
				case 'Hurt Note':
					noteSplashTexture = 'HURTnoteSplashes';
					colorSwap.hue = 0;
					colorSwap.saturation = 0;
					colorSwap.brightness = 0;
					zIndex = -1;
					if (isSustainNote) {
						hitHealth = -0.1;
					} else {
						hitHealth = -0.3;
					}
					missHealth = 0;
					hitConsequence = 0;
					missConsequence = 1;
				case 'Alt Animation':
					setAnimSuffix(this, '-alt', true);
				case 'No Animation':
					noAnimation = true;
					noMissAnimation = true;
				case 'GF Sing':
					setGfNote(this, true);
				case 'Hey!': // Puts GF on BF notes if it's not already there
					if (mustPress) {
						var hasGF:Bool = false;
						for (anim in anims) if (anim[0] < 0) hasGF = true;
						if (!hasGF) anims.push([-1, -1, '']);
					}
				case 'Adlib':
					multAlpha *= 0.8;
					missHealth = 0.01;
					missConsequence = 1;
					noAnimation = true;
				case 'Fuzzy':
					hitHealth /= 2;
					missHealth /= 2;
					score = Std.int(score / 2);
					activation = 2;
				case 'Flick':
					activation = 4;
					if (isSustainNote) {
						noAnimation = true;
					}
					zIndex = 1;
				case 'Avoid':
					activation = 2;
					if (isSustainNote) {
						hitHealth = -0.1;
					} else {
						hitHealth = -0.3;
					}
					missHealth = 0;
					hitConsequence = 0;
					missConsequence = 2;
					noAnimation = true;
					noteSplashDisabled = true; // temporarily. need a way to differentiate between hit-miss and miss-hits.
				case 'Score':
					hitHealth *= 2;
					score *= 2;
					noteSplashDisabled = true; // temporarily. want a new splash animation for this.
				case 'Union':
					horizontalLink = true;
					if (isSustainNote) {
						scale.x = swagWidthSpacing * 0.9 / frameWidth;
						zIndex = -1;
					}
				case 'Ghost': // Theoretically just a fake note. Not sure if I will ever use this.
					multAlpha *= 0.8;
					activation = 0;
					ignoreNote = true;
					missConsequence = 1;
					missHealth = 0;
			}
			noteType = value;
		}
		noteSplashHue = colorSwap.hue;
		noteSplashSat = colorSwap.saturation;
		noteSplashBrt = colorSwap.brightness;
		return value;
	}

	public function get_canEverBeHit():Bool
	{
		return missConsequence == 2 || (hitConsequence != 0 && activation != 0);
	}

	public function new(strumTime:Float, noteData:Int, ?prevNote:Note, ?sustainNote:Bool = false, ?inEditor:Bool = false, ?noteType:String = '') 
	// noteType here is an ugly hack, but reloading twice every note is very slow
	{
		super();

		if (prevNote == null) prevNote = this;
		this.prevNote = prevNote;
		prevNote.nextNote = this;

		isSustainNote = sustainNote; 
		isSustainNoteEnd = sustainNote;
		this.inEditor = inEditor;

		x += (ClientPrefs.middleScroll ? SongPlayState.STRUM_X_MIDDLESCROLL : SongPlayState.STRUM_X) + 50;
		// MAKE SURE ITS DEFINITELY OFF SCREEN?
		y -= 2000;

		this.strumTime = strumTime;
		if(!inEditor) this.strumTime += ClientPrefs.noteOffset;
		if (SongPlayState.instance != null) {
			scroll = SongPlayState.instance.songSpeed;
		}

		this.noteData = noteData;

		if (noteData > -1) {
			if (noteType != '') prefix = noteTypeToPrefix.get(noteType);
			if (prefix == null) prefix = '';
			texture = '';
			colorSwap = new ColorSwap();
			shader = colorSwap.shader;

			x += swagWidthVariable * (noteData % Note.TOTAL);
			if (!isSustainNote) { //Doing this 'if' check to fix the warnings on Senpai songs
				var tmp = noteData >= Note.TOTAL ? Note.TOTAL - 1 : noteData;
				animation.play(NAME_SCHEME[tmp] + 'scroll');
			}

			updateHitbox();
		}

		if (isSustainNote) {
			alpha = 0.6;
			multAlpha = 0.6;
			hitsoundDisabled = true;
			if (ClientPrefs.downScroll) flipX = true;

			copyAngle = false;

			var tmp = noteData >= Note.TOTAL ? Note.TOTAL - 1 : noteData;
			animation.play(NAME_SCHEME[tmp] + 'holdend');

			updateHitbox();

			if (prevNote.isSustainNote) {
				prevNote.isSustainNoteEnd = false;

				var tmp = prevNote.noteData >= Note.TOTAL ? Note.TOTAL - 1 : prevNote.noteData;
				prevNote.animation.play(NAME_SCHEME[tmp] + 'hold');
				prevNote.updateHitbox();

				prevNote.susHeight = 0.45 * Conductor.stepCrochet * Math.abs(scroll);
				prevNote.scale.y = (prevNote.susHeight + yScaleErrorTerm) / prevNote.frameHeight;
				prevNote.updateHitbox();
			}
		} else {
			earlyHitMult = 1;
		}
	}

	function reloadNote(?prefix:String = '', ?texture:String = '', ?suffix:String = '') {
		if(prefix == null) prefix = '';
		if(texture == null) texture = '';
		if(suffix == null) suffix = '';
		// trace("reloading to " + prefix + texture);

		var skin:String = texture;
		if(texture.length < 1) {
			skin = Song.curPlaying.arrowSkin;
			if(skin == null || skin.length < 1) {
				skin = 'NOTE_assets';
			}
		}

		var animName:String = null;
		if(animation.curAnim != null) {
			animName = animation.curAnim.name;
		}

		var lastScaleY:Float = scale.y;
		var blahblah:String = ~/([^\/]*)$/.replace(skin, prefix + "$1" + suffix);
		var hash:String = blahblah + (isSustainNote ? 'S' : ' ');
		if (SongPlayState.isPixelStage) {
			blahblah = 'pixelUI/' + blahblah;
			if (isSustainNote) blahblah += 'ENDS';
		}

		if (textureCache.exists(hash)) {
			loadGraphicFromSprite(textureCache.get(hash));

			if (SongPlayState.isPixelStage) {
				setGraphicSize(Std.int(width * SongPlayState.PIXEL_ZOOM * Note.swagScaleVariable));
			} else {
				setGraphicSize(Std.int(width * swagScaleConstant * swagScaleVariable));
			} 

			updateHitbox();
		} else {
			if (SongPlayState.isPixelStage) {
				var column_n:Int = 4;

				if(isSustainNote) {
					loadGraphic(Paths.image(blahblah));
					height = height / 2;
					column_n = Std.int(width / (height * 7/6)); // Temporary hack. Not sure how to fix
					width = width / column_n;
					// originalHeightForCalcs = height;
					loadGraphic(Paths.image(blahblah), true, Math.floor(width), Math.floor(height));
				} else {
					loadGraphic(Paths.image(blahblah));
					height = height / 5;
					column_n = Std.int(width / height); // A less wild assumption here
					width = width / column_n;
					loadGraphic(Paths.image(blahblah), true, Math.floor(width), Math.floor(height));
				}
				loadPixelNoteAnims(column_n);
				// antialiasing = false;

				textureCache.set(hash, clone());
			} else {
				frames = Paths.getSparrowAtlas(blahblah);
				loadNoteAnims();
				// antialiasing = ClientPrefs.globalAntialiasing;

				textureCache.set(hash, clone());
			}
		}

		antialiasing = !SongPlayState.isPixelStage && ClientPrefs.globalAntialiasing;

		if (this.texture != null && isSustainNote) { // Force this to only happen on reload
			scale.y = lastScaleY;
		}

		if (animName != null) animation.play(animName, true);

		if (inEditor) {
			setGraphicSize(ChartingState.GRID_SIZE, ChartingState.GRID_SIZE);
		}
		updateHitbox();
	}

	function loadNoteAnims() {
		if (isSustainNote) NoteLoader.loadNoteAnimsByKeyScheme(SCHEME, this, [' ', ' hold end', ' hold piece'], ['scroll', 'holdend', 'hold']);
		else NoteLoader.loadNoteAnimsByKeyScheme(SCHEME, this, [' '], ['scroll']);

		setGraphicSize(Std.int(width * swagScaleConstant * swagScaleVariable));
		updateHitbox();
	}

	function loadPixelNoteAnims(column_n:Int) {
		if (isSustainNote) NoteLoader.loadPixelNoteAnimsByKeyScheme(SCHEME, this, column_n, ['hold', 'holdend'], [[0], [1]]);
		else NoteLoader.loadPixelNoteAnimsByKeyScheme(SCHEME, this, column_n, ['scroll'], [[1]]);

		setGraphicSize(Std.int(width * SongPlayState.PIXEL_ZOOM * Note.swagScaleVariable));
		updateHitbox();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (mustPress)
		{
			// ok river
			if (strumTime > Conductor.songPosition - (Conductor.safeZoneOffset * lateHitMult)
				&& strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
				canBeHit = true;
			else
				canBeHit = false;

			if (strumTime < Conductor.songPosition - Conductor.safeZoneOffset && !wasGoodHit)
				tooLate = true;
		}
		else
		{
			if (strumTime < Conductor.songPosition + (Conductor.safeZoneOffset * earlyHitMult))
			{
				if (strumTime <= Conductor.songPosition) 
					canBeHit = true;
				else
					canBeHit = false;
			}
		}

		if (tooLate && !inEditor)
		{
			if (alpha > 0.3)
				alpha = 0.3;
		}
	}

	override function destroy()
	{
		prevNote = null;
		nextNote = null;
		super.destroy();
	}
}
