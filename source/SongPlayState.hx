package;

#if mobile
import flash.events.TouchEvent;
import mobile.TouchBar;
import mobile.TouchUtil;
#end
#if sys
import sys.FileSystem;
#end
import Conductor.Rating;
import FunkinLua;
import Note.EventNote;
import Note.NoteSetting;
import Section.SwagSection;
import StageData;
import helper.NoteLoader.NoteList;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxSave;
import flixel.util.FlxSort;
import flixel.util.FlxTimer;
import openfl.events.KeyboardEvent;
using StringTools;

/**
 * SongBeatState with Chart-playing (+ some lua tinkering) support.
 * Base Class for both PlayState and EditorPlayState.
 */
class SongPlayState extends SongBeatState
{
	inline static function nullCall(func:(Void -> Bool)) return (func != null && func());

	// New Variables (following the SongBeatState chain)
	public var lastStepHit:Int = -1;
	public var lastBeatHit:Int = -1;
	public var lastSectionHit:Int = -1;

	public var camHUD:FlxCamera;
	public var camOther:FlxCamera;

	public var insts:FlxSound;
	public var vocals:FlxSound;

	public var stageData(default, null):StageFile = null;

	// Other Overrides
	override function stepHit():Void
	{
		super.stepHit();

		if (!endingSong) {
			inline resyncSound(insts, insts.time);
			if (songData.needsVoices) inline resyncSound(vocals, insts.time);
		}

		if (curStep == lastStepHit) return;
		lastStepHit = curStep;

		stepUpdate();

		setOnLuas('curStep', curStep);
		setOnLuas('curBeatStep', curBeatStep);
		setOnLuas('curSectionStep', curSectionStep);
		callOnLuas('onStepHit', []);
	}

	override function beatHit():Void
	{
		super.beatHit();

		if (lastBeatHit >= curBeat) return;
		lastBeatHit = curBeat;

		if (generatedMusic) sortNotes();

		beatUpdate();

		setOnLuas('curBeat', curBeat);
		callOnLuas('onBeatHit', []);
	}

	override function sectionHit():Void
	{
		super.sectionHit();

		lastSectionHit = curSection;

		if (songData.notes[curSection] != null)
		{
			if (songData.notes[curSection].changeBPM)
			{
				Conductor.changeBPM(songData.notes[curSection].bpm);
				setOnLuas('curBpm', Conductor.bpm);
				setOnLuas('crochet', Conductor.crochet);
				setOnLuas('stepCrochet', Conductor.stepCrochet);
			}
			setOnLuas('mustHitSection', songData.notes[curSection].mustHitSection);
			setOnLuas('altAnim', songData.notes[curSection].altAnim);
			setOnLuas('gfSection', songData.notes[curSection].gfSection);
		}

		sectionUpdate();

		setOnLuas('curSection', curSection);
		callOnLuas('onSectionHit', []);
	}

	override public function onFocus():Void
	{
		super.onFocus();
	}

	override public function onFocusLost():Void
	{
		super.onFocusLost();
	}

	// Beat-related functions (to be overridden)
	function stepUpdate() {}
	function beatUpdate() {}
	function sectionUpdate() {}

	// Constants
	public static final STRUM_X:Int = 42;
	public static final STRUM_X_MIDDLESCROLL:Int = -278;
	public static final PIXEL_ZOOM:Int = 6;

	public static final noteKillOffsetConst:Float = 500;
	public static final noteClearOffsetConst:Float = 350;
	public static final spawnOffsetConst:Float = 2000;
	public static final sustainOffset:Float = 0; // Offset of sustain notes (visual) distance wrt number of steps. 1 means the sustain ends where the sprite ends. 

	// Settings
	/// Gameplay settings
	public var healthGain:Float = 1;
	public var healthLoss:Float = 1;
	public var instakillOnMiss:Bool = false;
	public var cpuControlled:Bool = false;
	public var practiceMode:Bool = false;

	public var songSpeed(default, set):Float = 1;
	public var songSpeedType(default, null):String = "multiplicative";
	public var noteKillOffset:Float = noteKillOffsetConst;
	public var noteClearOffset:Float = noteClearOffsetConst;
	public var spawnOffset:Float = spawnOffsetConst;

	function set_songSpeed(value:Float):Float
	{
		songSpeed = value;
		if (generatedMusic) {
			// Bump the scroll by setting multscroll to itself
			for (note in notes) note.multScroll = note.multScroll;
			for (note in unspawnNotes) note.multScroll = note.multScroll;
		}
		return value;
	}

	/// Gameplay preferences, so they can be changed temporarily
	public var prefGhostTapping:Bool = true;
	public var prefWrongNoteMiss:Bool = true;

	/// "Gamemode" settings
	public var gmDrainMult:Float = 0;
	public var gmDrainThreshold:Float = 2;
	public var gmPoisonMult:Float = 0;
	public var gmPoisonThreshold:Float = 2;

	/// Other settings
	public static var isPixelStage:Bool = false;

	public var skipArrowStartTween:Bool = false; //for lua

	public var showCombo:Bool = false;
	public var showComboNum:Bool = true;
	public var showRating:Bool = true;
	public var popupLinger:Float = 0.2;

	// Game State
	public var health:Float = 1;
	public var combo:Int = 0;
	public var songLength(default, null):Float = 0;

	public var generatedMusic(default, null):Bool = false;
	public var startedCountdown(default, null):Bool = false;
	public var startedSong(default, null):Bool = false;
	public var startingSong(get, never):Bool;
	public function get_startingSong():Bool return !startedSong; // For compatibility
	public var endingSong(default, null):Bool = false;

	public var paused:Bool = false;
	public var responsive(get, never):Bool;
	public function get_responsive():Bool return !paused && !endingSong;
	public var isDead(default, null):Bool = false;

	// Tweens
	var songSpeedTween:FlxTween;

	// Game Logic
	function doDeathCheck():Bool
	{
		if (health <= 0) return gameOver();
		return false;
	}

	function gameOver():Bool
	{
		if (practiceMode || isDead) return false; 

		var ret:Dynamic = callOnLuas('onGameOver', [], false);
		if (ret != FunkinLua.Function_Stop) {
			_gameOver();
			return true;
		}
		return false;
	}

	function _gameOver():Void
	{
		paused = true;

		stopSong();

		persistentUpdate = false;
		persistentDraw = false;

		isDead = true;
	}

	// Scoring
	public static var ratingStuff:Array<Array<Dynamic>> = [
		['You Suck!', 0.2], //From 0% to 19%
		['Shit', 0.4], //From 20% to 39%
		['Bad', 0.5], //From 40% to 49%
		['Bruh', 0.6], //From 50% to 59%
		['Meh', 0.69], //From 60% to 68%
		['Nice', 0.7], //69%
		['Good', 0.8], //From 70% to 79%
		['Great', 0.9], //From 80% to 89%
		['Sick!', 1], //From 90% to 99%
		['Perfect!!', 1] //The value on this one isn't used actually, since Perfect is always "1"
	];
	public static var ratingsData:Array<Rating> = [];
	public static var ratingWrong:Rating = new Rating('wrong', 0, 0, false);
	public var sicks:Int = 0;
	public var goods:Int = 0;
	public var bads:Int = 0;
	public var shits:Int = 0; // TODO: Don't use reflections here?

	public var score:Int = 0;
	public var hitCount:Int = 0;
	public var missCount:Int = 0;
	public var ratingDenom:Int = 0;
	public var ratingNumer:Float = 0.0;

	public var ratingName:String = '?';
	public var ratingPercent:Float = 0;
	public var ratingFC:String = '';

	public function updateScore(note:Note, rating:Rating)
	{
		note.ratingMod = rating.ratingMod;
		note.rating = rating.name;

		if (practiceMode || cpuControlled) return;
		score += note.score;

		if (!note.ratingDisabled) {
			rating.increase();

			hitCount++;
			ratingNumer += rating.ratingMod;
			ratingDenom++;
			recalculateRating();
		}
	}

	// Notes
	public var notes:FlxTypedGroup<Note>;
	public var unspawnNotes:Array<Note> = [];
	public var eventNotes:Array<EventNote> = [];

	/// HUD
	private var strumLine:FlxSprite; // Apparently the only use of this is the .y data member?
	private var comboGroup:FlxTypedGroup<FlxSprite>;
	public var strumLineNotes:FlxTypedGroup<StrumNote>;
	public var opponentStrums:FlxTypedGroup<StrumNote>;
	public var playerStrums:FlxTypedGroup<StrumNote>;
	public var grpNoteSplashes:FlxTypedGroup<NoteSplash>;
	public var noteOverlay:FlxTypedGroup<FlxSprite>;

	//// Strum Update
	public var grpStrumHint:FlxTypedGroup<FlxText>;
	public var strumsByData:Array<FlxTypedGroup<StrumNote>>;
	public function getStrumByTag(noteTag:Dynamic):StrumNote
	{
		if (Std.isOfType(noteTag, Int)) {
			var note:Int = cast noteTag;
			if (note < 0) note = 0;
			return strumLineNotes.members[note % strumLineNotes.length];
		} else if (Std.isOfType(noteTag, String)) {
			var tag:String = cast noteTag;
			var thing:Dynamic = modchartObjects.get(tag);
			if (Std.isOfType(thing, StrumNote)) return cast thing;
			else return null;
		} else return null;
	}

	/// Graphic Stuff
	var precacheList:Map<String, String> = new Map<String, String>();

	// Controls
	private var keysArray:Array<Array<FlxKey>> = [];
	private var controlHoldArray:Array<Bool> = [for (_ in 0...Note.TOTAL) false];
	// private var linkedHoldArray:Array<Bool> = [for (_ in 0...Note.TOTAL) false];
	private var notePressCheckers:Array<Void -> Bool>;
	private var noteCheckers:Array<Void -> Bool>;
	private var noteReleaseCheckers:Array<Void -> Bool>;
	inline public function getKeyByNote(i:Int):FlxKey {
		if (keysArray == null || keysArray.length <= i) return NONE;
		else if (keysArray[i][0] != NONE) return keysArray[i][0];
		else return keysArray[i][1];
	}

	/// Input Testing
	inline public function getControl(key:String) return Reflect.getProperty(controls, key);
	inline public function getControlNoteCheckerP(j:Int) return nullCall(controls.noteCheckerP(j));
	inline public function getControlNoteCheckerQ(j:Int) return nullCall(controls.noteCheckerQ(j));
	inline public function getControlNoteCheckerR(j:Int) return nullCall(controls.noteCheckerR(j));
	inline public function getNoteCheckerP(i:Int) return nullCall(notePressCheckers[i]);
	inline public function getNoteCheckerQ(i:Int) return nullCall(noteCheckers[i]);
	inline public function getNoteCheckerR(i:Int) return nullCall(noteReleaseCheckers[i]);

	/// Input Handling
	#if mobile
	private function onTouchBegin(event:TouchEvent):Void
	{
		if (cpuControlled || paused || !startedCountdown) return;
		//trace(event.stageX + ', ' + event.stageY);
		//trace(event);
		var point:FlxPoint = TouchUtil.stageToWorldPoint(event.stageX, event.stageY, camHUD);

		//trace(point);
		for (i in 0...Note.TOTAL) {
			var strumPoint:FlxPoint = playerStrums.members[i].getMidpoint();
			//trace(strumPoint);
			var dist:Float = TouchUtil.distanceToScroll(point, strumPoint, playerStrums.members[i].direction);
			//trace(dist);
			if (dist <= playerStrums.members[i].width * 0.6) keyPressTrigger(i); // Allow a bit more leeway for triggers.
		}
	}

	private function checkTouchHold():Void
	{
		var point:FlxPoint = new FlxPoint();
		var strumPoints:Array<FlxPoint> = [];
		var hits:Int = 0; 
		for (i in 0...Note.TOTAL) {
			if (controlHoldArray[i]) hits += 1;
			strumPoints.push(playerStrums.members[i].getMidpoint());
		}

		for (touch in FlxG.touches.list) if (touch.pressed) {
			point = touch.getWorldPosition(camHUD, point);
			for (i in 0...Note.TOTAL) if (!controlHoldArray[i]) {
				var dist:Float = TouchUtil.distanceToScroll(point, strumPoints[i], playerStrums.members[i].direction);
				if (dist <= playerStrums.members[i].width * 0.6) {
					hits += 1;
					controlHoldArray[i] = true;
					if (hits == Note.TOTAL) return; // To save some tiny bit of time
				}
			}
		}
	}

	private function onTouchEnd(event:TouchEvent):Void
	{
		if (cpuControlled || paused || !startedCountdown) return;
		var point:FlxPoint = TouchUtil.stageToWorldPoint(event.stageX, event.stageY, camHUD);

		for (i in 0...Note.TOTAL) {
			var strumPoint:FlxPoint = playerStrums.members[i].getMidpoint();
			var dist:Float = TouchUtil.distanceToScroll(point, strumPoint, playerStrums.members[i].direction);
			if (dist <= playerStrums.members[i].width * 0.6) keyReleaseTrigger(i);
		}
	}
	#end

	private function getKeyFromEvent(key:FlxKey):Int
	{
		if (key != NONE) for (i in 0...keysArray.length) for (j in 0...keysArray[i].length) if(key == keysArray[i][j]) return i;
		return -1;
	}

	private function onKeyPress(event:KeyboardEvent):Void
	{
		// trace('press $cpuControlled $paused $startedCountdown');
		if (cpuControlled || paused || !startedCountdown) return;
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);
		//trace('Pressed: ' + eventKey);

		if (key > -1 && FlxG.keys.checkStatus(eventKey, JUST_PRESSED)) keyPressTrigger(key);
	}

	private function onKeyRelease(event:KeyboardEvent):Void
	{
		if (cpuControlled || paused || !startedCountdown) return;
		var eventKey:FlxKey = event.keyCode;
		var key:Int = getKeyFromEvent(eventKey);

		if (key > -1) keyReleaseTrigger(key);
	}

	private function checkInput():Void
	{
		var oldHoldArray:Array<Bool> = controlHoldArray.copy();

		// HOLDING
		for (i in 0...Note.TOTAL) controlHoldArray[i] = getNoteCheckerQ(i);
		#if mobile
		checkTouchHold();
		for (i in 0...Note.TOTAL) if (controlHoldArray[i] != oldHoldArray[i]) { // Update strum animations here
			if (controlHoldArray[i]) {
				strumsByData[i].forEach(function (spr:StrumNote) {
					if (spr.animation.curAnim.name != 'confirm') {
						spr.playAnim('pressed');
						spr.resetAnim = 0;
					}
				});
			} else {
				strumsByData[i].forEach(function (spr:StrumNote) {
					spr.playAnim('static');
					spr.resetAnim = 0;
				});
			}
		}
		#end
		// linkedHoldArray = controlHoldArray.copy();

		// TODO: Find a better way to handle controller inputs, this should work for now
		if (ClientPrefs.controllerMode)
		{
			for (i in 0...notePressCheckers.length) if (getNoteCheckerP(i)) keyPressTrigger(i);
		}

		keyHoldTrigger();

		// TODO: Find a better way to handle controller inputs, this should work for now
		if(ClientPrefs.controllerMode)
		{
			for (i in 0...noteReleaseCheckers.length) if (getNoteCheckerR(i)) keyReleaseTrigger(i);
		}
	}

	/// Note Trigger Handling
	private function keyPressTrigger(key:Int):Void
	{
		if (responsive && generatedMusic) judgeNoteTrigger(key, 1);

		if (responsive) strumsByData[key].forEach(function (spr:StrumNote) {
			if (spr.animation.curAnim.name != 'confirm') {
				spr.playAnim('pressed');
				spr.resetAnim = 0;
			}
		});
		callOnLuas('onKeyPress', [key]);
	}

	private function keyHoldTrigger():Void
	{
		notes.forEachAlive(function(daNote:Note)
		{
			if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit) {
				// hurt note functions
				if (daNote.hitConsequence == 0) {
					var timing:Float = daNote.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset;

					if (timing < -ClientPrefs.sickWindow) { // Make hurt notes a bit more forgiving by disabling them after the sick window
						daNote.tooLate = true;
					}
				}

				// hold note functions
				if (((daNote.activation != 0) && controlHoldArray[daNote.noteData]) || 
					((daNote.activation == 4) && daNote.isSustainNote)) {
					if (daNote.isSustainNote) hitNote(daNote);

					else if ((daNote.activation & 2) == 2) { // Hold Note Activation
						var timing:Float = daNote.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset;

						if (timing < ClientPrefs.sickWindow) hitNote(daNote);
					}
				}

				// miss-equals-hit note functions
				if (daNote.missConsequence == 2) {
					var timing:Float = daNote.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset;

					if (timing < 0) {
						health -= daNote.missHealth * healthLoss;
						goodNote(daNote);
						deleteNoteUnlessSus(daNote);
					}
				}
			}
		});
	}

	private function keyReleaseTrigger(key:Int):Void
	{
		if (responsive && generatedMusic) judgeNoteTrigger(key, 4, false);

		if (responsive) strumsByData[key].forEach(function (spr:StrumNote) {
			spr.playAnim('static');
			spr.resetAnim = 0;
		});
		callOnLuas('onKeyRelease', [key]);
	}

	/// Note Logic Handling
	private function judgeNote(note:Note):Rating
	{
		var noteDiff:Float = Math.abs(note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset);
		return Conductor.judgeNote(note, noteDiff);
	}

	/**
	 * Checks and triggers note hit, or note press miss where necessary.
	 * @param key Int index of the key
	 * @param activation Int bitmap activation of the keypress
	 * @param checkMisses (Optional) Checks for missPress triggers
	 */
	private function judgeNoteTrigger(key:Int, activation:Int, ?checkMisses:Bool = true):Void
	{
		// Wrong Note Miss happens when: 
		// (1) Checking enabled
		// (2) No same key note
		// (3) Exists different key same activation note
		var wrongNoteMiss:Bool = prefWrongNoteMiss && checkMisses; // Cond (1)
		var wrongNoteTrigger:Bool = false; // Cond (3)

		// Ghost Miss happens when:
		// (1) Checking enabled
		// (2) No same key note
		var ghostMiss:Bool = !prefGhostTapping && checkMisses; // Cond (1)

		//more accurate hit time for the ratings?
		var lastTime:Float = Conductor.songPosition;
		Conductor.songPosition = insts.time;

		// Gather notes that can be counted as hit
		var sortedNotesList:Array<Note> = [];
		notes.forEachAlive(function(daNote:Note)
		{
			if (daNote.canBeHit && daNote.mustPress && !daNote.tooLate && !daNote.wasGoodHit && !daNote.isSustainNote)
			{
				if (daNote.noteData == key) // Key match
				{
					if (daNote.activation != 0) sortedNotesList.push(daNote); // Cond (2) failed
				} else if ((daNote.activation & activation) != 0) wrongNoteTrigger = true; // Cond (3) satisfied
			}
		});
		sortedNotesList.sort((a, b) -> Std.int(a.strumTime - b.strumTime));

		if (sortedNotesList.length > 0) { // If some notes can be hit
			// if (sortedNotesList.length > 1) for (sortedNote in sortedNotesList) CoolUtil.traceNote(sortedNote);
			var index:Int = 0;
			var refStrumTime:Float = 0;
			var triggered:Bool = false; // is a noteHit triggered
			while (index < sortedNotesList.length) {
				if (!triggered) {
					if (sortedNotesList[index].activation & activation != 0) { // Activation bitmap overlap
						hitNote(sortedNotesList[index]);
						refStrumTime = sortedNotesList[index].strumTime;
						triggered = true;
					} else if (sortedNotesList[index].strumTime > Conductor.songPosition) break; // block if a wrong-activation note come after the strum bar
				} else if (Math.abs(sortedNotesList[index].strumTime - refStrumTime) < 1) { // noteHit triggered, find dupe notes
					if (sortedNotesList[index].activation & activation != 0) { // Activation bitmap overlap
						sortedNotesList[index].kill();
						notes.remove(sortedNotesList[index], true);
						sortedNotesList[index].destroy();
					}
				}
				++index;
			}
		} else if (ghostMiss || (wrongNoteMiss && wrongNoteTrigger)) { // else Cond (2) satisfied, check other conditions
			callOnLuas('wrongNote', [key]);
			missPress(key);
		}

		//more accurate hit time for the ratings? part 2 (Now that the calculations are done, go back to the time it was before for not causing a note stutter)
		Conductor.songPosition = lastTime;
	}

	/**
	 * Given an (assumed sustain) note, check if the note is activated
	 */
	inline private function sustainActivated(note:Note):Bool
	{
		if (note.activation == 4 || note.missConsequence == 2) return true;
		if (controlHoldArray[note.noteData]) return true;
		if (note.horizontalLink) return true; // Temporary. Need a better plan for this one
		return false;
	}

	public function opponentHitNote(note:Note):Void
	{
		vocals.volume = 1;

		// "Gamemode": Draining. Like Tabi. 
		if (health > gmDrainThreshold) {
			if (note.hitConsequence == 0 && note.missConsequence == 2) health -= note.missHealth * gmDrainMult; // Special case for miss-cause-hit notes
			else health -= note.hitHealth * gmDrainMult;
		}

		var time:Float = 0.15;
		if (note.isSustainNote && !note.isSustainNoteEnd) time = 0.30;
		strumPlayAnim(note, time);

		note.hitByOpponent = true;

		deleteNoteUnlessSus(note);

		callOnLuas('opponentHitNote', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote, note.ID]);
	}

	public function hitNote(note:Note):Void // TODO: add support for recognizing (activation:Int = 0)
	{
		if (note.wasGoodHit) return;
		note.wasGoodHit = true;	

		health += note.hitHealth * healthGain;

		if (note.horizontalLink) { // Union notes
			filterHorizontalNote(note);
		}

		if (!cpuControlled && note.hitConsequence == 0) { // Hit Causes Miss (Unless it's CPU)
			shitNote(note);
		} else {
			goodNote(note);
		}

		callOnLuas('hitNote', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote, note.ID]);

		deleteNoteUnlessSus(note);
	}

	public function goodNote(note:Note):Void 
	{
		if (!note.isSustainNote) {
			combo += 1;
			if (combo > 9999) combo = 9999;

			var rating:Rating = judgeNote(note);
			updateScore(note, rating);
			popUpScore(note, rating, showComboNum);
		}

		vocals.volume = 1;

		if (ClientPrefs.hitsoundVolume > 0 && !note.hitsoundDisabled) {
			FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.hitsoundVolume);
		}

		var time:Null<Float> = null;
		if (cpuControlled) {
			if (note.isSustainNote && !note.isSustainNoteEnd) time = 0.30;
			else time = 0.15;
		} else {
			if (!controlHoldArray[note.noteData]) {
				if (note.isSustainNoteEnd) time = 0.15;
				else time = 0.30;
			}
		}
		strumPlayAnim(note, time);

		callOnLuas('goodNote', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote, note.ID]);
	}

	public function shitNote(note:Note):Void 
	{
		_miss(note.noteData);

		if (!note.noteSplashDisabled && !note.isSustainNote) {
			spawnNoteSplashOnNote(note);
		}

		callOnLuas('shitNote', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote, note.ID]);
	}

	public function missNote(note:Note):Bool
	{
		var ret:Dynamic = callOnLuas('missNote', [notes.members.indexOf(note), note.noteData, note.noteType, note.isSustainNote, note.ID], false);
		if (ret != FunkinLua.Function_Stop) {
			_miss(note.noteData);
			return true;
		}
		return false;
	}

	public function missPress(direction:Int = 0):Bool
	{
		var ret:Dynamic = callOnLuas('missPress', [direction], false);
		if (ret != FunkinLua.Function_Stop) {
			_missPress(direction);
			return true;
		}
		return false;
	}

	private function _miss(?direction:Int):Void
	{
		combo = 0;
		vocals.volume = 0;
		missCount++;

		if (instakillOnMiss) gameOver();
		if (!practiceMode) score -= 10;

		ratingDenom++;
		recalculateRating();
	}

	private function _missPress(direction:Int = 0):Void
	{
		health -= 0.05 * healthLoss;

		if (ClientPrefs.showMissPress) popUpScore(null, ratingWrong, false);
		_miss(direction);

		if (prefGhostTapping) return;
		FlxG.sound.play(Paths.soundRandom('missnote', 1, 3), FlxG.random.float(0.1, 0.2));
	}

	/**
	 * Like filterDupeNote, but ignoring noteData
	 * @param daNote Note for reference
	 * @param ignoreSus (default false) ignore isSustainNote checks. Otherwise only nonsus filters sus notes
	 */
	private function filterHorizontalNote(daNote:Note, ignoreSus:Bool = false):Void
	{
		var deadNotes:Array<Note> = [];

		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress == note.mustPress && 
				daNote.noteType == note.noteType && (ignoreSus || !daNote.isSustainNote || note.isSustainNote)
				&& Math.abs(daNote.strumTime - note.strumTime) < 1) {
				if (!note.isSustainNote)
				{
					noteMap.remove(note.ID);
					note.kill();
					deadNotes.push(note);
				} else {
					note.wasGoodHit = true;
					note.tooLate = false; // This is done to prevent missed union horizontal notes from double-counting
				}
			}
		});

		for (deadNote in deadNotes) {
			notes.remove(deadNote, true);
			deadNote.destroy();
		}
	} 

	/**
	 * Filters all notes that coincide with the reference note, in strum time, note data and type (broadly speaking)
	 * @param daNote Note for reference
	 */
	private function filterDupeNote(daNote:Note):Void
	{
		var deadNotes:Array<Note> = [];

		notes.forEachAlive(function(note:Note) {
			if (daNote != note && daNote.mustPress == note.mustPress && 
			daNote.noteData == note.noteData && daNote.noteType == note.noteType && daNote.isSustainNote == note.isSustainNote 
			&& Math.abs(daNote.strumTime - note.strumTime) < 1) {
				noteMap.remove(note.ID);
				note.kill();
				deadNotes.push(note);
			}
		});

		for (deadNote in deadNotes) {
			notes.remove(deadNote, true);
			deadNote.destroy();
		}
	}

	public function clearNotesBefore(time:Float)
	{
		unspawnNotes = unspawnNotes.filter(function (note:Note) {
			var ret:Bool = note.strumTime >= time + noteClearOffset;
			if (!ret) noteMap.remove(note.ID);
			return ret;
			});

		var deadNotes:Array<Note> = [];

		notes.forEachAlive(function(note:Note) {
			if (note.strumTime < time + noteClearOffset) {
				noteMap.remove(note.ID);
				note.kill();
				deadNotes.push(note);
			}
		});

		for (deadNote in deadNotes) {
			notes.remove(deadNote, true);
			deadNote.destroy();
		}
	}

	public function clearAllNotes() {
		while(notes.length > 0) {
			var daNote:Note = notes.members[0];
			daNote.active = false;
			daNote.visible = false;

			deleteNote(daNote);
		}
		unspawnNotes = [];
		eventNotes = [];
	}

	private function killNote(daNote:Note):Bool
	{
		var ret:Dynamic = callOnLuas('noteKilled', [notes.members.indexOf(daNote), daNote.noteData, daNote.noteType, daNote.isSustainNote, daNote.ID], false);
		if (ret != FunkinLua.Function_Stop) {
			_killNote(daNote);
			return true;
		}
		return false;
	}

	private function _killNote(daNote:Note):Void
	{
		if (daNote.horizontalLink) filterHorizontalNote(daNote, true);

		if (daNote.mustPress && !cpuControlled && (daNote.tooLate || !daNote.wasGoodHit)) {
			health -= daNote.missHealth * healthLoss;
			filterDupeNote(daNote);

			if (!endingSong) {
				if (daNote.missConsequence == 0) missNote(daNote);
			}
		}

		daNote.active = false;
		daNote.visible = false;

		deleteNote(daNote);
	}

	inline public function deleteNote(note:Note):Void
	{
		noteMap.remove(note.ID);
		note.kill();
		notes.remove(note, true);
		note.destroy();
	}

	inline function deleteNoteUnlessSus(note:Note):Void if (!note.isSustainNote) deleteNote(note);

	public function sortNotes():Void
	{
		notes.sort(function (Order:Int, Obj1:Note, Obj2:Note):Int {
			if (Obj1.zIndex == Obj2.zIndex) return FlxSort.byValues(FlxSort.DESCENDING, Obj1.distance, Obj2.distance);
			else return FlxSort.byValues(FlxSort.ASCENDING, Obj1.zIndex, Obj2.zIndex);
		}, FlxSort.ASCENDING);
	}

	public function sortUnspawn():Void
	{
		if (unspawnNotes != null) unspawnNotes.sort(function (Obj1:Note, Obj2:Note):Int {
			return FlxSort.byValues(FlxSort.ASCENDING, Obj1.entranceTime, Obj2.entranceTime);
		});
	}

	public function recalculateRating():Void
	{
		setOnLuas('score', score);
		setOnLuas('misses', missCount);
		setOnLuas('hits', hitCount);

		var ret:Dynamic = callOnLuas('onRecalculateRating', [], false);
		if (ret != FunkinLua.Function_Stop)	{
			_recalculateRating();
		}

		setOnLuas('rating', ratingPercent);
		setOnLuas('ratingName', ratingName);
		setOnLuas('ratingFC', ratingFC);
	}

	public function _recalculateRating():Void
	{
		if (ratingDenom < 1) {//Prevent divide by 0
			ratingName = '?';
		} else {
			// Rating Percent
			ratingPercent = Math.min(1, Math.max(0, ratingNumer / ratingDenom));

			// Rating Name
			if (ratingPercent >= 1) {
				ratingName = ratingStuff[ratingStuff.length-1][0]; //Uses last string
			} else {
				for (i in 0...ratingStuff.length-1) if (ratingPercent < ratingStuff[i][1]) {
						ratingName = ratingStuff[i][0];
						break;
				}
			}
		}

		// Rating FC
		ratingFC = "";
		if (sicks > 0) ratingFC = "SFC";
		if (goods > 0) ratingFC = "GFC";
		if (bads > 0 || shits > 0) ratingFC = "FC";
		if (missCount > 0 && missCount < 10) ratingFC = "SDCB";
		else if (missCount >= 10) ratingFC = "Clear";
	}

	/// Event Note Handling
	public function triggerEventNote(eventName:String, value1:String, value2:String) 
	{
		switch (eventName) {
			case 'Change Scroll Speed':
				if (songSpeedType == "constant")
					return;
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 1;
				if(Math.isNaN(val2)) val2 = 0;

				var newValue:Float = songData.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1) * val1;

				if (val2 <= 0) {
					songSpeed = newValue;
				} else {
					songSpeedTween = FlxTween.tween(this, {songSpeed: newValue}, val2, {ease: FlxEase.linear, onComplete:
						function (twn:FlxTween)
						{
							songSpeedTween = null;
						}
					});
				}

			case 'Set Property':
				FunkinLua.setVarDirectly(value1, value2, true);

			case 'Set Drain':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 0;
				if(Math.isNaN(val2)) val2 = 1;

				gmDrainMult = val1;
				gmDrainThreshold = val2 * 2; // Adjust to max health

			case 'Set Poison':
				var val1:Float = Std.parseFloat(value1);
				var val2:Float = Std.parseFloat(value2);
				if(Math.isNaN(val1)) val1 = 0;
				if(Math.isNaN(val2)) val2 = 1;

				gmPoisonMult = val1;
				gmPoisonThreshold = val2 * 2; // Adjust to max health

			case 'Screen Shake':
				var valuesArray:Array<String> = [value1, value2];
				var targetsArray:Array<FlxCamera> = [camGame, camHUD];
				for (i in 0...targetsArray.length) {
					var split:Array<String> = valuesArray[i].split(',');
					var duration:Float = 0;
					var intensity:Float = 0;
					if (split[0] != null) duration = Std.parseFloat(split[0].trim());
					if (split[1] != null) intensity = Std.parseFloat(split[1].trim());
					if (Math.isNaN(duration)) duration = 0;
					if (Math.isNaN(intensity)) intensity = 0;

					if (duration > 0 && intensity != 0) {
						targetsArray[i].shake(intensity, duration);
					}
				}
		}
		callOnLuas('onEvent', [eventName, value1, value2]);
	}

	// Lua
	public var luaArray:Array<FunkinLua> = [];
	// public var closeLuas:Array<FunkinLua> = [];
	private var luaDebugGroup:FlxTypedGroup<DebugLuaText>;

	public var modchartTweens:Map<String, FlxTween> = new Map<String, FlxTween>();
	public var modchartSprites:Map<String, ModchartSprite> = new Map<String, ModchartSprite>();
	public var modchartTimers:Map<String, FlxTimer> = new Map<String, FlxTimer>();
	public var modchartSounds:Map<String, FlxSound> = new Map<String, FlxSound>();
	public var modchartTexts:Map<String, ModchartText> = new Map<String, ModchartText>();
	public var modchartSaves:Map<String, FlxSave> = new Map<String, FlxSave>();
	public var modchartObjects:Map<String, FlxSprite> = new Map<String, FlxSprite>(); // Kept this way just in case more flxsprite storing is needed.
	public var noteMap:Map<Int, Note> = new Map<Int, Note>(); // For isNoteChild and stuff
	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();

	public function getLuaObject(tag:String, text:Bool=true):FlxSprite {
		if (modchartObjects.exists(tag)) return modchartObjects.get(tag);
		if (modchartSprites.exists(tag)) return modchartSprites.get(tag);
		if (text && modchartTexts.exists(tag)) return modchartTexts.get(tag);
		return null;
	}

	public function callOnLuas(event:String, args:Array<Dynamic>, ignoreStops = true, ?exclusions:Array<String>):Dynamic 
	{
		var returnVal:Dynamic = FunkinLua.Function_Continue;
		//trace('calling $event');
		#if LUA_ALLOWED
		if (exclusions == null) exclusions = [];
		for (script in luaArray) {
			if(exclusions.contains(script.scriptName))
				continue;

			var ret:Dynamic = script.call(event, args);
			if(ret == FunkinLua.Function_StopLua && !ignoreStops)
				break;
			
			if(ret != FunkinLua.Function_Continue)
				returnVal = ret;
		}
		#end
		return returnVal;
	}

	public function setOnLuas(variable:String, arg:Dynamic) 
	{
		#if LUA_ALLOWED
		for (script in luaArray) {
			script.set(variable, arg);
		}
		#end
	}

	public function addTextToDebug(text:String, color:FlxColor) 
	{
		#if LUA_ALLOWED
		luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += 20;
		});

		if(luaDebugGroup.members.length > 34) {
			var blah = luaDebugGroup.members[34];
			blah.destroy();
			luaDebugGroup.remove(blah);
		}
		luaDebugGroup.insert(0, new DebugLuaText(text, luaDebugGroup, color));
		#end
	}

	#if LUA_ALLOWED
	/**
	 * Initializes a Lua instance with variables that depend on this state
	 * @param lua FunkinLua instance to setup
	 */
	public function initLua(lua:FunkinLua)
	{
		// songData
		lua.set('bpm', songData.bpm);
		lua.set('scrollSpeed', songData.speed);
		lua.set('songLength', insts != null ? insts.length : 0);
		lua.set('songName', songName);
		lua.set('songFileName', songData.song);
		// Character shit
		lua.set('boyfriendName', songData.player1);
		lua.set('dadName', songData.player2);
		lua.set('gfName', songData.gfVersion);

		// Gameplay settings
		lua.set('healthGainMult', healthGain);
		lua.set('healthLossMult', healthLoss);
		lua.set('instakillOnMiss', instakillOnMiss);
		lua.set('botPlay', cpuControlled);
		lua.set('practice', practiceMode);

		// Timing
		lua.set('curSection', curSection);
		lua.set('curBeat', curBeat);
		lua.set('curStep', curStep);
		lua.set('curSectionStep', curSectionStep);
		lua.set('curBeatStep', curBeatStep);
		lua.set('curDecSection', curDecSection);
		lua.set('curDecBeat', curDecBeat);
		lua.set('curDecStep', curDecStep);

		if (0 <= curSection && curSection < songData.notes.length) {
			lua.set('mustHitSection', songData.notes[curSection].mustHitSection);
			lua.set('altAnim', songData.notes[curSection].altAnim);
			lua.set('gfSection', songData.notes[curSection].gfSection);
		}

		lua.set('curBpm', Conductor.bpm);
		lua.set('crochet', Conductor.crochet);
		lua.set('stepCrochet', Conductor.stepCrochet);

		// State
		lua.set('score', score);
		lua.set('misses', missCount);
		lua.set('hits', hitCount);

		lua.set('rating', 0);
		lua.set('ratingName', '');
		lua.set('ratingFC', '');

		lua.set('startedCountdown', startedCountdown);

		// StrumLineNotes
		if (strumLineNotes != null) {
			for (i in 0...Note.TOTAL) {
				lua.set('defaultPlayerStrumX' + i, playerStrums.members[i].x);
				lua.set('defaultPlayerStrumY' + i, playerStrums.members[i].y);
				lua.set('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
				lua.set('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
			}
		} else {
			for (i in 0...Note.TOTAL) {
				lua.set('defaultPlayerStrumX' + i, 0);
				lua.set('defaultPlayerStrumY' + i, 0);
				lua.set('defaultOpponentStrumX' + i, 0);
				lua.set('defaultOpponentStrumY' + i, 0);
			}			
		}
	}

	public function setupLuaGlobal()
	{
		// "GLOBAL" SCRIPTS
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('scripts/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('scripts/'));
		if (Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/scripts/'));

		for (mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/scripts/'));
		#end

		for (folder in foldersToCheck)
		{
			if(Paths.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
	}

	public function setupLuaStage()
	{
		// STAGE SCRIPTS
		#if MODS_ALLOWED
		var doPush:Bool = false;
		var luaFile:String = 'stages/' + songData.stage + '.lua';
		if(Paths.exists(Paths.modFolders(luaFile))) {
			luaFile = Paths.modFolders(luaFile);
			doPush = true;
		} else {
			luaFile = Paths.getPreloadPath(luaFile);
			if(Paths.exists(luaFile)) {
				doPush = true;
			}
		}

		if(doPush) 
			luaArray.push(new FunkinLua(luaFile));
		#end
	}

	public function setupLuaSong()
	{
		var filesPushed:Array<String> = [];
		var foldersToCheck:Array<String> = [Paths.getPreloadPath('data/' + Paths.formatToSongPath(songName) + '/')];

		#if MODS_ALLOWED
		foldersToCheck.insert(0, Paths.mods('data/' + Paths.formatToSongPath(songName) + '/'));
		if(Paths.currentModDirectory != null && Paths.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Paths.currentModDirectory + '/data/' + Paths.formatToSongPath(songName) + '/'));

		for(mod in Paths.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/data/' + Paths.formatToSongPath(songName) + '/' ));// using push instead of insert because these should run after everything else
		#end

		for (folder in foldersToCheck)
		{
			if(Paths.exists(folder))
			{
				for (file in FileSystem.readDirectory(folder))
				{
					if(file.endsWith('.lua') && !filesPushed.contains(file))
					{
						luaArray.push(new FunkinLua(folder + file));
						filesPushed.push(file);
					}
				}
			}
		}
	}
	#end

	public static var instance(default, null):SongPlayState;

	// Game Loop

	/// Initialization Sequence
	override public function create()
	{
		#if mobile
		barMode = BarMode.ACCEPT;
		#end
		Paths.clearStoredMemory();

		instance = this;

		setupControl(); // trace('init control');
		initPlayState(); // trace('init state');
		setupCamera(); // trace('init camera');
		setupStage(); // trace('init stage');
		setupLua(); // trace('init lua');
		setupCharacters(); // trace('init characters');
		generateSong(); // trace('init song data');
		setupHUD(); // trace('init hud');
		startPlayState(); // trace('trying to start state');
		finalizePlayState(); // trace('finalizing initialization');

		callOnLuas('onCreatePost', []);
		precacheAssets();
		super.create();
	}

	private function setupControl()
	{
		var uncontrollable = false;
		var bindScheme:Array<String> = null;
		if (Note.TOTAL < NoteList.bindschemeLength) bindScheme = ClientPrefs.bindSchemes[Note.TOTAL];
		notePressCheckers = [for (_ in 0...Note.TOTAL) null];
		noteCheckers = [for (_ in 0...Note.TOTAL) null];
		noteReleaseCheckers = [for (_ in 0...Note.TOTAL) null];
		if (bindScheme == null) uncontrollable = true;
		else {
			keysArray = [for (str in bindScheme) ClientPrefs.keyBinds.get(str)];
			for (i in 0...Note.TOTAL) {
				// Verify all keys are mapped
				var key:Array<FlxKey> = keysArray[i];
				if (key == null || (key[0] == NONE && key[1] == NONE)) uncontrollable = true;

				// I have no proof of this working with controller mode. Just hope that it does.
				// Retrieve FlxAction checkers
				var j:Int = (NoteList.buttonEnums[bindScheme[i].substr(5)] : Int); // This should never be null
				// trace('$i is ${bindScheme[i]} which is $j');
				notePressCheckers[i] = controls.noteCheckerP(j);
				noteCheckers[i] = controls.noteCheckerQ(j);
				noteReleaseCheckers[i] = controls.noteCheckerR(j);
			}
		}
		if (uncontrollable) trace('Warning: Chart is unplayable given the current control settings.');

		#if mobile
		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
			FlxG.stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		}
		#else
		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		#end
	}

	//// Set up all the variables needed for the state
	private function initPlayState()
	{
		// Load Settings
		healthGain = ClientPrefs.getGameplaySetting('healthgain', 1);
		healthLoss = ClientPrefs.getGameplaySetting('healthloss', 1);
		instakillOnMiss = ClientPrefs.getGameplaySetting('instakill', false);
		practiceMode = ClientPrefs.getGameplaySetting('practice', false);
		cpuControlled = ClientPrefs.getGameplaySetting('botplay', false);

		prefGhostTapping = ClientPrefs.ghostTapping;
		prefWrongNoteMiss = ClientPrefs.wrongNoteMiss;

		// Load songData (if not loaded already) and update corresponding states
		if (songData == null) {
			if (Song.curPlaying != null) loadSong(Song.curPlaying, Song.curSongName); // old behavior
			else loadSong(Song.loadFromJson('tutorial'), 'tutorial');
		}
		Song.curPlaying = songData;
		Song.curSongName = songName;

		Conductor.mapBPMChanges(songData);
		Conductor.changeBPM(songData.bpm);
		Conductor.safeZoneOffset = (ClientPrefs.safeFrames / 60) * 1000;

		popupLinger = Math.min(0.2, Conductor.stepCrochet);

		ratingsData = [
			new Rating('sick', 1, 350, true),
			new Rating('good', 0.7, 200, false),
			new Rating('bad', 0.4, 100, false),
			new Rating('shit', 0, 0, false)
		];
	}

	private function setupCamera()
	{
		// Camera Stuff
		camGame = new FlxCamera();
		camHUD = new FlxCamera();
		camOther = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		camOther.bgColor.alpha = 0;

		FlxG.cameras.reset(camGame);
		FlxG.cameras.add(camHUD);
		FlxG.cameras.add(camOther);

		FlxCamera.defaultCameras = [camGame];
		CustomFadeTransition.nextCamera = camOther;
		//FlxG.cameras.setDefaultDrawTarget(camGame, true);

		persistentUpdate = true;
		persistentDraw = true;
	}

	private function setupStage() // Only loads stageData by default.
	{
		// Grab StageData
		stageData = StageData.getStageFile(songData.stage);
		if (stageData == null) { //Stage couldn't be found, create a dummy stage for preventing a crash
			stageData = StageData.FALLBACK;
		}

		isPixelStage = stageData.isPixelStage;
	}

	private function setupLua() 
	{
		#if LUA_ALLOWED 
		luaDebugGroup = new FlxTypedGroup<DebugLuaText>();
		luaDebugGroup.cameras = [camOther];
		add(luaDebugGroup);

		setupLuaGlobal();
		setupLuaStage();
		setupLuaSong();
		#end
	}

	private function setupCharacters() {} // Does nothing by default.
	private function generateSong()
	{
		songSpeedType = ClientPrefs.getGameplaySetting('scrolltype', 'multiplicative');

		switch(songSpeedType)
		{
			case "multiplicative":
				songSpeed = songData.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		Conductor.changeBPM(songData.bpm);

		insts = new FlxSound().loadEmbedded(Paths.inst(songData.song));
		if (songData.needsVoices)
			vocals = new FlxSound().loadEmbedded(Paths.voices(songData.song));
		else
			vocals = new FlxSound();

		FlxG.sound.list.add(insts);
		FlxG.sound.list.add(vocals);

		// Song duration in a float, useful for the time left feature
		songLength = insts.length;
		setOnLuas('songLength', songLength);

		// Load Notes + Events
		var noteData:Array<SwagSection> = songData.notes;
		var eventsData:Array<Dynamic> = songData.events;

		var songName:String = Paths.formatToSongPath(songName);
		#if MODS_ALLOWED
		if (Paths.exists(Paths.modsJson(songName + '/events')) || Paths.exists(Paths.json(songName + '/events')))
		#else
		if (Paths.exists(Paths.json(songName + '/events')))
		#end
			eventsData = eventsData.concat(Song.loadFromJson('events', songName).events);

		var noteTypeMap:Map<String, Bool> = new Map();
		var eventPushedMap:Map<String, Bool> = new Map();

		Note.resetCache();
		NoteSplash.resetCache();
		var wholeSongSetting:NoteSetting = songData.noteSettings;
		for (section in noteData)
		{
			if (section.changeBPM) {
				Conductor.changeBPM(section.bpm);
			}
			var setting:NoteSetting = Note.overrideNoteSetting(wholeSongSetting, section.noteSettings);

			for (songNotes in section.sectionNotes)
			{
				var daStrumTime:Float = songNotes[0];
				var daNoteData:Int = Std.int(songNotes[1] % Note.TOTAL);

				var gottaHitNote:Bool = section.mustHitSection;
				if (songNotes[1] >= Note.TOTAL) gottaHitNote = !section.mustHitSection;

				var oldNote:Note = unspawnNotes.length > 0 ? unspawnNotes[Std.int(unspawnNotes.length - 1)] : null;

				var swagType:String = '';
				if (Std.isOfType(songNotes[3], String)) swagType = songNotes[3];
				else if (Std.isOfType(songNotes[3], Int)) swagType = editors.ChartingState.noteTypeList[songNotes[3]]; //Backward compatibility + compatibility with Week 7 charts

				var swagNote:Note = new Note(daStrumTime, daNoteData, oldNote, swagType);
				swagNote.ID = unspawnNotes.length;
				noteMap.set(swagNote.ID, swagNote);
				swagNote.mustPress = gottaHitNote;
				swagNote.sustainLength = songNotes[2];
				Note.applyNoteSetting(swagNote, setting, swagType);
				if (section.altAnim) Note.setAnimSuffix(swagNote, '-alt', false);

				swagNote.scrollFactor.set();

				var susLength:Float = swagNote.sustainLength;

				susLength = susLength / Conductor.stepCrochet;
				unspawnNotes.push(swagNote);

				var ceilSus:Int = Math.ceil(susLength - FlxMath.EPSILON);

				if (ceilSus > 0) {
					for (susNote in 0...ceilSus + 1)
					{
						oldNote = unspawnNotes[Std.int(unspawnNotes.length - 1)];

						var sustainNote:Note = new Note(
							susNote == ceilSus ? daStrumTime + swagNote.sustainLength : daStrumTime + Conductor.stepCrochet * susNote, 
							daNoteData, oldNote, true, swagType);
						sustainNote.ID = unspawnNotes.length;
						noteMap.set(sustainNote.ID, sustainNote);
						if (susNote != ceilSus) sustainNote.sustainLength = Conductor.stepCrochet;
						sustainNote.mustPress = gottaHitNote;
						Note.applyNoteSetting(sustainNote, setting, swagType);
						if (section.altAnim) Note.setAnimSuffix(sustainNote, '-alt', false);
						sustainNote.scrollFactor.set();

						swagNote.tail.push(sustainNote);
						unspawnNotes.push(sustainNote);
					}
				}

				noteTypeMap.set(swagNote.noteType, true);
			}
		}

		Conductor.changeBPM(songData.bpm);

		// Load Event Notes
		for (event in eventsData)
		{
			for (i in 0...event[1].length)
			{
				var newEventNote:Array<Dynamic> = [event[0], event[1][i][0], event[1][i][1], event[1][i][2]];
				var subEvent:EventNote = {
					strumTime: newEventNote[0] + ClientPrefs.noteOffset,
					event: newEventNote[1],
					value1: newEventNote[2],
					value2: newEventNote[3]
				};
				subEvent.strumTime -= eventNoteEarlyTrigger(subEvent);
				eventNotes.push(subEvent);
				eventPushed(subEvent);
				eventPushedMap.set(subEvent.event, true);
			}
		}

		// Load Custom Note/Event Lua
		#if LUA_ALLOWED
		for (notetype in noteTypeMap.keys())
		{
			#if MODS_ALLOWED
			var luaToLoad:String = Paths.modFolders('custom_notetypes/' + notetype + '.lua');
			if(Paths.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			else
			{
				luaToLoad = Paths.getPreloadPath('custom_notetypes/' + notetype + '.lua');
				if(Paths.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
			}
			#else
			var luaToLoad:String = Paths.getPreloadPath('custom_notetypes/' + notetype + '.lua');
			if(Paths.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			#end
		}

		for (event in eventPushedMap.keys())
		{
			#if MODS_ALLOWED
			var luaToLoad:String = Paths.modFolders('custom_events/' + event + '.lua');
			if(Paths.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			else
			{
				luaToLoad = Paths.getPreloadPath('custom_events/' + event + '.lua');
				if(Paths.exists(luaToLoad))
				{
					luaArray.push(new FunkinLua(luaToLoad));
				}
			}
			#else
			var luaToLoad:String = Paths.getPreloadPath('custom_events/' + event + '.lua');
			if(Paths.exists(luaToLoad))
			{
				luaArray.push(new FunkinLua(luaToLoad));
			}
			#end
		}
		#end

		sortUnspawn();
		eventNotes.sort(function (Obj1:EventNote, Obj2:EventNote):Int { return FlxSort.byValues(FlxSort.ASCENDING, Obj1.strumTime, Obj2.strumTime); });
		generatedMusic = true;
	}

	private function setupHUD()
	{
		strumLine = new FlxSprite(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, 50).makeGraphic(FlxG.width, 10);
		if(ClientPrefs.downScroll) strumLine.y = FlxG.height - 150;
		strumLine.scrollFactor.set();
		strumLine.cameras = [camHUD];

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		strumLineNotes.cameras = [camHUD];
		add(strumLineNotes);

		strumsByData = [for (i in 0 ... Note.TOTAL * 2) new FlxTypedGroup<StrumNote>()];

		opponentStrums = new FlxTypedGroup<StrumNote>();
		playerStrums = new FlxTypedGroup<StrumNote>();

		generateStaticArrows(0);
		generateStaticArrows(1);
		for (i in 0...playerStrums.length) {
			setOnLuas('defaultPlayerStrumX' + i, playerStrums.members[i].x);
			setOnLuas('defaultPlayerStrumY' + i, playerStrums.members[i].y);
		}
		for (i in 0...opponentStrums.length) {
			setOnLuas('defaultOpponentStrumX' + i, opponentStrums.members[i].x);
			setOnLuas('defaultOpponentStrumY' + i, opponentStrums.members[i].y);
		}
		bindStrum();

		grpStrumHint = new FlxTypedGroup<FlxText>();
		grpStrumHint.cameras = [camHUD];
		add(grpStrumHint);

		grpNoteSplashes = new FlxTypedGroup<NoteSplash>();
		grpNoteSplashes.cameras = [camHUD];
		add(grpNoteSplashes);

		var splash:NoteSplash = new NoteSplash(100, 100, 0);
		grpNoteSplashes.add(splash);
		splash.alpha = 0.0;

		notes = new FlxTypedGroup<Note>();
		notes.cameras = [camHUD];
		add(notes);

		comboGroup = new FlxTypedGroup<FlxSprite>();
		comboGroup.cameras = [camHUD];
		comboGroup.visible = !ClientPrefs.hideHud;
		add(comboGroup);

		noteOverlay = new FlxTypedGroup<FlxSprite>();
		noteOverlay.cameras = [camHUD];
		noteOverlay.visible = !ClientPrefs.hideHud;
		add(noteOverlay);
	}

	//// Handle the various ways a song is started (e.g. hard coded intros)
	//// Starts Directly by default.
	private function startPlayState() 
	{
		#if mobile
		if (ClientPrefs.middleScroll) barMode = BarMode.GAME_LEFT;
		else barMode = BarMode.GAME_CENTER;
		if (bar != null) { // This may be called before or after setupBar is called.
			remove(bar);
			bar.destroy();
			bar = new TouchBar(barMode, controls);
			bar.cameras = [camBar];
			add(bar);
		}
		#end 

		startedCountdown = true;
		setOnLuas('startedCountdown', true);
		callOnLuas('onCountdownStarted', []);
	}

	private function finalizePlayState() 
	{
		recalculateRating();

		if (ClientPrefs.hitsoundVolume > 0) precacheList.set('hitsound', 'sound');
		precacheList.set('missnote1', 'sound');
		precacheList.set('missnote2', 'sound');
		precacheList.set('missnote3', 'sound');

		// Combo, ratings, etc
		for (rating in ratingsData) precacheList.set(pixelWrap(rating.image), 'image');
		for (digit in 0...10) precacheList.set(pixelWrap('num$digit'), 'image');
		precacheList.set(pixelWrap('combo'), 'image');

		if (PauseSubState.songName != null) {
			precacheList.set(PauseSubState.songName, 'music');
		} else if(ClientPrefs.pauseMusic != 'None') {
			precacheList.set(Paths.formatToSongPath(ClientPrefs.pauseMusic), 'music');
		}
	}

	private function precacheAssets()
	{
		for (key => type in precacheList) {
			switch(type)
			{
				case 'image':
					Paths.image(key);
				case 'sound':
					Paths.sound(key);
				case 'music':
					Paths.music(key);
			}
		}
	}

	/// Update Sequence
	override function update(elapsed:Float)
	{
		callOnLuas('onUpdate', [elapsed]);

		// Which one should go first?
		super.update(elapsed);
		updateTime(elapsed); // trace('update time');

		checkInput(); // trace('update controls');
		updateStage(elapsed); // trace('update stage');
		updatePlayState(elapsed); // trace('update state');

		updateHUD(elapsed); // trace('update hud');
		updateNotes(); // trace('update notes');
		checkEventNote(); // trace('update event');

		updateLua(); // trace('update lua');

		callOnLuas('onUpdatePost', [elapsed]);
	}

	//// Directly updates songPosition by default
	private function updateTime(elapsed:Float)
	{
		if (startedSong) Conductor.songPosition += FlxG.elapsed * 1000;
		else startSong(0);
	}

	private function updateStage(elapsed:Float) {}
	private function updateHUD(elapsed:Float)
	{
		// Show Control thing
		if (responsive) {
			for (strums in strumsByData) strums.forEach(function (daStrum:StrumNote) {
				if (daStrum.showControl > 0) {
					var str:String = daStrum.getControlName();
					var size:Int = Math.ceil(str.length > 4 ? daStrum.height * 0.2 : daStrum.height * 0.3);

					var hint:FlxText = new FlxText(daStrum.x, daStrum.y + daStrum.height * 0.6, daStrum.width, str);
					hint.setFormat(size, CENTER, OUTLINE, FlxColor.BLACK);
					hint.borderSize = size * 0.1;
					grpStrumHint.add(hint);

					daStrum.hintThing = hint;
					FlxTween.tween(hint, { alpha: 0 }, daStrum.showControl * 0.2, { 
						startDelay: daStrum.showControl * 0.8,
						ease: FlxEase.quadOut,
						onComplete: function (twn:FlxTween) {
							hint.kill();
							grpStrumHint.remove(hint, true);
							hint.destroy();
							daStrum.hintThing = null;
						}
						});

					daStrum.showControl = 0;
				}
			});
		}
	}

	private function updatePlayState(elapsed:Float)
	{
		if (health > 2) health = 2;
		else if (health > gmPoisonThreshold) health -= FlxG.elapsed * (2 / 100) * gmPoisonMult;
	}

	private function updateNotes()
	{
		while (unspawnNotes.length > 0 && unspawnNotes[0].entranceTime - Conductor.songPosition < 0) {
			var dunceNote:Note = unspawnNotes[0];
			if (!dunceNote.spawned) { // A somewhat cheap way to prevent a note from ever spawning
				notes.insert(0, dunceNote);

				dunceNote.spawned = true;
				callOnLuas('onSpawnNote', [notes.members.indexOf(dunceNote), dunceNote.noteData, dunceNote.noteType, dunceNote.isSustainNote, dunceNote.ID]);
			}

			unspawnNotes.shift();
		}

		notes.forEachAlive(function(daNote:Note) {
			if (daNote.strum == null) bindStrum(daNote);

			var strumX:Float = daNote.strum.x;
			var strumY:Float = daNote.strum.y;
			var strumOffsetX:Float = daNote.strum.width / 2;
			var strumOffsetY:Float = daNote.strum.height / 2;
			var strumAngle:Float = daNote.strum.angle;
			var strumDirection:Float = daNote.strum.direction;
			var strumAlpha:Float = daNote.strum.alpha;
			var strumScroll:Bool = daNote.strum.downScroll;

			var timeOffset = Conductor.songPosition - daNote.strumTime;
			strumX += daNote.offsetX;
			strumY += daNote.offsetY;
			strumAlpha *= daNote.multAlpha;

			daNote.distance = (0.45 * -timeOffset * daNote.scroll);
			if (daNote.isSustainNote) {
				if (daNote.isSustainNoteEnd) {
					// This aligns the cap with the sustain notes, but may have inaccurate timing (depending on scroll speed)
					// daNote.distance -= (0.45 * sustainOffset * Conductor.stepCrochet * daNote.scroll) - daNote.height / 2;
					// This aligns the cap with the ending time, but leaves gaps or intersections.
					// daNote.distance -= (0.45 * (sustainOffset-1) * Conductor.stepCrochet * daNote.scroll) + daNote.height / 2;
					// This aligns the cap with the ending time of the previous note, but definitely leaves intersections to be clipped.
					daNote.distance -= (0.45 * sustainOffset * Conductor.stepCrochet * daNote.scroll) + daNote.height / 2;
				} else {
					// Assuming the sustain piece is (0.45 * stepCrochet * scroll) long

					// This aligns the piece by the center of the sprite
					// daNote.distance -= (0.45 * (sustainOffset-0.5) * Conductor.stepCrochet * daNote.scroll);
					// This aligns the piece by the bottom of the sprite
					daNote.distance -= (0.45 * sustainOffset * Conductor.stepCrochet * daNote.scroll) - daNote.height / 2;
				}
			} 

			var angleDir = strumDirection * Math.PI / 180;
			if (strumScroll) angleDir += Math.PI;
			var sinAD:Float = Math.sin(angleDir);
			var cosAD:Float = Math.cos(angleDir);

			if (daNote.copyAngleDirection) {
				daNote.angle = daNote.offsetAngle + strumDirection - 90;
				if (daNote.isSustainNote && strumScroll) daNote.angle += 180;
				if (daNote.copyAngle) daNote.angle += strumAngle;
			}

			if (daNote.copyAlpha) {
				daNote.alpha = strumAlpha;
				if (daNote.strum.hidePostStrum && daNote.distance < 0 && !(daNote.isSustainNote && daNote.strum.sustainReduce)) daNote.alpha = 0;
			}

			var normal:Float = strumScroll ? -daNote.offsetNormal : daNote.offsetNormal;
			var distance:Float = daNote.distance + daNote.offsetDistance;

			if (daNote.copyX) {
				daNote.x = strumX
					+ strumOffsetX - daNote.width / 2 // translate by center
					+ sinAD * normal + cosAD * distance;
			}

			if (daNote.copyY)
			{
				daNote.y = strumY 
					+ strumOffsetY - daNote.height / 2 // translate by center
					- cosAD * normal + sinAD * distance;
			}

			if (daNote.canEverBeHit && daNote.strumTime <= Conductor.songPosition) {
				if (daNote.mustPress) {
					if (cpuControlled) {
						if (daNote.hitConsequence != 0) {
							hitNote(daNote);
						} else {
							goodNote(daNote);
							deleteNoteUnlessSus(daNote);
						}

						if (!daNote.isSustainNote) return;
					}
				} else {
					if (!daNote.hitByOpponent && !(daNote.ignoreNote)) {
						opponentHitNote(daNote);

						if (!daNote.isSustainNote) return;
					}
				}
			}

			if (daNote.strum.sustainReduce && daNote.isSustainNote &&
				((daNote.mustPress ? cpuControlled || sustainActivated(daNote)
				: !daNote.ignoreNote) || daNote.strum.hidePostStrum)
			) {
				// Distance Based Calculation
				// var distance = daNote.distance + daNote.offsetDistance;
				if (distance < daNote.height * 0.5) {
					var clipRate:Float = 0.5 - distance / daNote.height;
					daNote.clipBottom = clipRate;
				}
			} else if (!daNote.strum.sustainReduce && daNote.wasGoodHit && daNote.isSustainNote) {
				deleteNote(daNote);
				return;
			}

			// Try to clip away sustain notes (assumes scroll of the whole sustain chain is the same)
			if (daNote.isSustainNoteEnd) {
				var cutHeight:Float = daNote.height; // distance to clip off from sus notes
				var pNote:Note = daNote.prevNote;
				if (pNote != null && pNote.isSustainNote) { // for non-whole-step sustain endings
					cutHeight += (pNote.sustainLength - (daNote.strumTime - pNote.strumTime)) * 0.45 * pNote.scroll;
				}
				while (pNote != null && pNote.isSustainNote) {
					if (cutHeight > pNote.susHeight) {
						pNote.clipTop = 1;
						cutHeight -= pNote.susHeight;
					} else if (cutHeight <= FlxMath.EPSILON) {
						if (pNote.clipTop <= FlxMath.EPSILON) break;
						pNote.clipTop = 0;
					} else {
						pNote.clipTop = cutHeight / pNote.susHeight;							
						cutHeight = 0;
					}
					pNote = pNote.prevNote;
				}

				if (cutHeight > FlxMath.EPSILON) { // cut the end sprite for the remaining pixels
					daNote.clipBottom = Math.max(daNote.clipBottom, cutHeight / daNote.height);				
				}
			}

			// Kill extremely late notes and cause misses
			var noteKillOffset:Float = noteKillOffset;
			if (Math.abs(daNote.scroll) < 1) noteKillOffset /= Math.abs(daNote.scroll);
			if (timeOffset > noteKillOffset) killNote(daNote);
		});
	}

	private function checkEventNote() 
	{
		while (eventNotes.length > 0) {
			var leStrumTime:Float = eventNotes[0].strumTime;
			if (Conductor.songPosition < leStrumTime) {
				break;
			}

			var value1:String = '';
			if(eventNotes[0].value1 != null)
				value1 = eventNotes[0].value1;

			var value2:String = '';
			if(eventNotes[0].value2 != null)
				value2 = eventNotes[0].value2;

			triggerEventNote(eventNotes[0].event, value1, value2);
			eventNotes.shift();
		}
	}

	private function updateLua() 
	{
		setOnLuas('curDecStep', curDecStep);
		setOnLuas('curDecBeat', curDecBeat);
		setOnLuas('curDecSection', curDecSection);
		setOnLuas('botPlay', cpuControlled);

		if (FunkinLua.somethingClosed) {
			var newArray = [];
			for (lua in luaArray) {
				if (lua.closed) {
					lua.call('onDestroy', []);
					lua.stop();
				} 
				else newArray.push(lua);
			}
			luaArray = newArray;
			FunkinLua.somethingClosed = false;
		}
	}

	/// Destructor Sequence
	override function destroy():Void
	{
		stopSong();
		if (vocals != null) vocals.destroy();

		for (lua in luaArray) {
			lua.call('onDestroy', []);
			lua.stop();
		}
		luaArray = [];

		#if hscript
		FunkinLua.haxeInterp = null;
		#end

		#if mobile
		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
			FlxG.stage.removeEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		}
		#else
		if(!ClientPrefs.controllerMode)
		{
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyPress);
			FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyRelease);
		}
		#end

		super.destroy();
	}

	/// Song playback related functions
	function startSong(startTime:Float):Void
	{
		startedSong = true;

		insts.volume = 1;
		vocals.volume = 1;
		insts.onComplete = endSong;

		setSongTime(startTime, !paused);

		callOnLuas('onSongStart', []);
	}

	public function setSongTime(time:Float, play:Bool = true)
	{
		if (time < 0) time = 0;

		insts.pause();
		vocals.pause();

		insts.time = time;
		vocals.time = Math.min(vocals.length, time);
		Conductor.songPosition = time;
		if (play) {
			insts.play();
			vocals.play(); 
		}
	}

	public function resyncSound(sound:FlxSound, newVal:Float)
	{
		var pos:Float = Math.min(sound.length, Conductor.songPosition - Conductor.offset);
		if (Math.abs(sound.time - pos) > 20) {
			sound.time = newVal;
			Conductor.songPosition = newVal;
		}
	}

	function stopSong():Void
	{
		insts.stop();
		vocals.stop();
	}

	public function endSong():Bool
	{
		var ret:Dynamic = callOnLuas('onEndSong', [], false);
		if (ret != FunkinLua.Function_Stop) {
			_endSong();
			return true;
		}
		return false;
	}

	function _endSong():Void
	{
		endingSong = true;
	}

	function eventNoteEarlyTrigger(event:EventNote):Float return callOnLuas('eventEarlyTrigger', [event.event]);
	function eventPushed(event:EventNote):Void {} // Post-processing of Events. Used in hard-code only

	private function generateStaticArrows(player:Int):Void
	{
		for (i in 0...Note.TOTAL)
		{
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if(!ClientPrefs.opponentStrums) targetAlpha = 0;
				else if(ClientPrefs.middleScroll) targetAlpha = 0.35;
			}

			var babyArrow:StrumNote = new StrumNote(ClientPrefs.middleScroll ? STRUM_X_MIDDLESCROLL : STRUM_X, strumLine.y, i, player);
			babyArrow.downScroll = ClientPrefs.downScroll;
			babyArrow.alpha = targetAlpha;

			if (player == 1) {
				babyArrow.showControl = ClientPrefs.strumHint;
				strumsByData[i].add(babyArrow);

				playerStrums.add(babyArrow);
			} else {
				if (ClientPrefs.middleScroll) {
					babyArrow.x += 310;
					if (i >= Std.int(Note.TOTAL / 2)) { //Up and Right
						babyArrow.x += FlxG.width / 2 + 25;
					}
				}
				opponentStrums.add(babyArrow);
			}

			strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
	}

	/**
	 * Assigns the corresponding strum for a given note (or if none is supplied, all unspawn notes)
	 * Must be called after generateStaticArrows.
	 */
	private function bindStrum(note:Note = null):Void
	{
		if (note != null) note.strum = (note.mustPress ? playerStrums : opponentStrums).members[note.noteData];
		else {
			for (note in unspawnNotes) note.strum = (note.mustPress ? playerStrums : opponentStrums).members[note.noteData];
		}
	}

	public function popUpScore(note:Note, rating:Rating, showComboNum:Bool = false)
	{
		if (note != null && rating.noteSplash && !note.noteSplashDisabled) spawnNoteSplashOnNote(note);
		if (!(showRating || showComboNum)) return;

		var placement:String = Std.string(combo);

		var coolText:FlxText = new FlxText(0, 0, 0, placement, 32);
		coolText.screenCenter();
		coolText.x = FlxG.width * 0.35;
		// Only .x is ever used

		var popUpGroup:FlxSpriteGroup = new FlxSpriteGroup();
		if (ClientPrefs.lowQuality) {
			comboGroup.forEachAlive(spr -> FlxTween.completeTweensOf(spr));
		}
		comboGroup.add(popUpGroup);

		if (showRating) {
			var ratingSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelWrap(rating.image)));
			ratingSpr.cameras = [camHUD];
			ratingSpr.screenCenter();
			ratingSpr.x = coolText.x - 40;
			ratingSpr.x += ClientPrefs.comboOffset[0];
			ratingSpr.y -= 60;
			ratingSpr.y -= ClientPrefs.comboOffset[1];
			ratingSpr.velocity.x -= FlxG.random.int(0, 10);
			ratingSpr.velocity.y -= FlxG.random.int(140, 175);
			ratingSpr.acceleration.y = 550;

			if (isPixelStage) {
				ratingSpr.setGraphicSize(Std.int(ratingSpr.width * PIXEL_ZOOM * 0.85));
			} else {
				ratingSpr.setGraphicSize(Std.int(ratingSpr.width * 0.7));
				ratingSpr.antialiasing = ClientPrefs.globalAntialiasing;
			}
			ratingSpr.updateHitbox();

			popUpGroup.add(ratingSpr);
		}

		if (showComboNum) {
			// individual digits
			var seperatedScore:Array<Int> = [];

			if (combo >= 1000) seperatedScore.push(Math.floor(combo / 1000) % 10);
			seperatedScore.push(Math.floor(combo / 100) % 10);
			seperatedScore.push(Math.floor(combo / 10) % 10);
			seperatedScore.push(combo % 10);

			var daLoop:Int = 0;
			for (i in seperatedScore) {
				var numScore:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelWrap('num$i')));
				numScore.cameras = [camHUD];
				numScore.screenCenter();
				numScore.x = coolText.x + (43 * daLoop) - 90;
				numScore.x += ClientPrefs.comboOffset[2];
				numScore.y += 80;
				numScore.y -= ClientPrefs.comboOffset[3];
				numScore.velocity.x = FlxG.random.float(-5, 5);
				numScore.velocity.y -= FlxG.random.int(140, 160);
				numScore.acceleration.y = FlxG.random.int(200, 300);


				if (isPixelStage) {
					numScore.setGraphicSize(Std.int(numScore.width * PIXEL_ZOOM));
				} else {
					numScore.antialiasing = ClientPrefs.globalAntialiasing;
					numScore.setGraphicSize(Std.int(numScore.width * 0.5));
				}
				numScore.updateHitbox();

				popUpGroup.add(numScore);

				daLoop++;
			}

			if (showCombo) {
				// "combo" sprite
				var comboSpr:FlxSprite = new FlxSprite().loadGraphic(Paths.image(pixelWrap('combo')));
				comboSpr.cameras = [camHUD];
				comboSpr.screenCenter();
				comboSpr.x = coolText.x + (43 * daLoop) - 40;
				comboSpr.x += ClientPrefs.comboOffset[2];
				comboSpr.y += 80;
				comboSpr.y -= ClientPrefs.comboOffset[3];
				comboSpr.velocity.x = FlxG.random.float(-5, 5);
				comboSpr.velocity.y -= FlxG.random.int(140, 160);
				comboSpr.acceleration.y = FlxG.random.int(200, 300);

				if (isPixelStage) {
					comboSpr.setGraphicSize(Std.int(comboSpr.width * PIXEL_ZOOM * 0.75));
				} else {
					comboSpr.setGraphicSize(Std.int(comboSpr.width * 0.5));
					comboSpr.antialiasing = ClientPrefs.globalAntialiasing;
				}
				comboSpr.updateHitbox();

				popUpGroup.add(comboSpr);
			}
		}

		FlxTween.tween(popUpGroup, {alpha: 0}, popupLinger, {
			startDelay: Conductor.crochet * 0.001,
			onComplete: function(tween:FlxTween) {
				popUpGroup.kill();
				comboGroup.remove(popUpGroup, true); 
				popUpGroup.destroy();
			}
		});
	}

	function strumPlayAnim(note:Note, time:Float = 0) {
		var spr:StrumNote = note.strum;

		if (spr != null) {
			spr.playAnim('confirm', true);
			spr.resetAnim = time;
		}
	}

	function spawnNoteSplashOnNote(note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			var strum:StrumNote = note.strum;
			if(strum != null) {
				spawnNoteSplash(strum.x + strum.width / 2, strum.y + strum.height / 2, note.noteData, note);
			}
		}
	}

	public function spawnNoteSplash(x:Float, y:Float, data:Int, ?note:Note = null) {
		var skin:String = 'noteSplashes';
		if (songData.splashSkin != null && songData.splashSkin.length > 0) skin = songData.splashSkin;

		var arrowHSV = ClientPrefs.arrowHSV[Note.SCHEME[data]];
		var hue:Float = arrowHSV[0] / 360;
		var sat:Float = arrowHSV[1] / 100;
		var brt:Float = arrowHSV[2] / 100;

		if (note != null) {
			if (note.noteSplashTexture != null && note.noteSplashTexture.length > 0) skin = note.noteSplashTexture;
			hue = note.noteSplashHue;
			sat = note.noteSplashSat;
			brt = note.noteSplashBrt;
		}

		var splash:NoteSplash = grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, skin, hue, sat, brt);
		grpNoteSplashes.add(splash);
	}

	inline function pixelWrap(str:String):String return isPixelStage ? 'pixelUI/$str-pixel' : str;
}