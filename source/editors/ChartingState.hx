package editors;

#if desktop
import Discord.DiscordClient;
#end
import Conductor.BPMChangeEvent;
import Section.SwagSection;
import Song.SwagSong;
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxObject;
import flixel.group.FlxSpriteGroup;
import flixel.input.keyboard.FlxKey;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import flixel.util.FlxColor;
import haxe.Json;
import haxe.format.JsonParser;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
import openfl.utils.Assets as OpenFlAssets;
import lime.media.AudioBuffer;
import haxe.io.Bytes;
import flash.geom.Rectangle;
import flixel.util.FlxSort;
#if sys
import sys.io.File;
import sys.FileSystem;
import flash.media.Sound;
#end

using StringTools;

@:access(flixel.system.FlxSound._sound)
@:access(openfl.media.Sound.__buffer)

class ChartingState extends SongBeatState
{
	public static var noteTypeList:Array<String> = //Used for backwards compatibility with 0.1 - 0.3.2 charts, though, you should add your hardcoded custom note types here too.
	[
		'',
		'Alt Animation',
		'Hey!',
		'Hurt Note',
		'GF Sing',
		'No Animation', 
		'Adlib', // New ones
		'Fuzzy',
		'Flick',
		'Avoid',
		'Union',
		'Score',
		'Ghost'
	];
	private var noteTypeIntMap:Map<Int, String> = new Map<Int, String>();
	private var noteTypeMap:Map<String, Null<Int>> = new Map<String, Null<Int>>();
	private var didAThing = false;
	public var ignoreWarnings = false;
	var undos = [];
	var redos = [];
	var eventStuff:Array<Dynamic> =
	[
		['', "Nothing. Yep, that's right."],
		['Dadbattle Spotlight', "Used in Dad Battle,\nValue 1: 0/1 = ON/OFF,\n2 = Target Dad\n3 = Target BF"],
		['Hey!', "Plays the \"Hey!\" animation from Bopeebo,\nValue 1: BF = Only Boyfriend, GF = Only Girlfriend,\nSomething else = Both.\nValue 2: Custom animation duration,\nleave it blank for 0.6s"],
		['Set GF Speed', "Sets GF head bopping speed,\nValue 1: 1 = Normal speed,\n2 = 1/2 speed, 4 = 1/4 speed etc.\nUsed on Fresh during the beatbox parts.\n\nWarning: Value must be integer!"],
		['Philly Glow', "Exclusive to Week 3\nValue 1: 0/1/2 = OFF/ON/Reset Gradient\n \nNo, i won't add it to other weeks."],
		['Kill Henchmen', "For Mom's songs, don't use this please, i love them :("],
		['Add Camera Zoom', "Used on MILF on that one \"hard\" part\nValue 1: Camera zoom add (Default: 0.015)\nValue 2: UI zoom add (Default: 0.03)\nLeave the values blank if you want to use Default."],
		['BG Freaks Expression', "Should be used only in \"school\" Stage!"],
		['Trigger BG Ghouls', "Should be used only in \"schoolEvil\" Stage!"],
		['Play Animation', "Plays an animation on a Character,\nonce the animation is completed,\nthe animation changes to Idle\n\nValue 1: Animation to play.\nValue 2: Character (Dad, BF, GF)"],
		['Camera Follow Pos', "Value 1: X\nValue 2: Y\n\nThe camera won't change the follow point\nafter using this, for getting it back\nto normal, leave both values blank."],
		['Alt Idle Animation', "Sets a specified suffix after the idle animation name.\nYou can use this to trigger 'idle-alt' if you set\nValue 2 to -alt\n\nValue 1: Character to set (Dad, BF or GF)\nValue 2: New suffix (Leave it blank to disable)"],
		['Screen Shake', "Value 1: Camera shake\nValue 2: HUD shake\n\nEvery value works as the following example: \"1, 0.05\".\nThe first number (1) is the duration.\nThe second number (0.05) is the intensity."],
		['Change Character', "Value 1: Character to change (Dad, BF, GF)\nValue 2: New character's name"],
		['Change Scroll Speed', "Value 1: Scroll Speed Multiplier (1 is default)\nValue 2: Time it takes to change fully in seconds."],
		['Set Property', "Value 1: Variable name\nValue 2: New value"],
		['Set Drain', "Set draining of health when opponent hits a note.\n\nValue 1: Multiplier (relative to hit health, default: 0)\nValue 2: Threshold (relative to max health, default: 1)"],
		['Set Poison', "Set poisoning of health as time passes.\n\nValue 1: Multiplier (% health per second, default: 0)\nValue 2: Threshold (relative to max health, default: 1)"],
		['Display Box', "Display a text box on the opponent side.\n\nValue 1: \\-escaped text\nValue 2: Display duration (in number of steps, default: 16)"]
	];

	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	public static var goToPlayState:Bool = false;
	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	// public static var curSection:Int = 0;
	public static var savedSection:Int = -1;
	private static var lastSong:String = '';
	var prevLengthInSteps:Int = 16;
	var prevNextLengthInSteps:Int = 16;

	var titleTxt:FlxText;
	var bpmTxt:FlxText;

	var camPos:FlxObject;
	var strumLine:FlxSprite;
	var quant:AttachedSprite;
	var strumLineNotes:FlxTypedGroup<StrumNote>;
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;

	var highlight:FlxSprite;

	public static final UI_X:Float = 660;
	public inline function GRID_COLS():Int 
	{
		return Note.TOTAL * 2 + 1;
	}
	public inline function GRID_ROWS():Int 
	{
		return sectionLengthInSteps() + sectionLengthInSteps(1);
	}
	static final MAX_GRID_SIZE:Int = 40;
	public static var GRID_SIZE:Int = MAX_GRID_SIZE;
	public static var CAM_OFFSET:Int = MAX_GRID_SIZE * 9;
	public static var PERMUTE(default, set):Array<Int> = [3, 1, 2, 0];
	public static function set_PERMUTE(a:Array<Int>) {
		PERMUTE = a;
		PERMUTE_STRING = a.join(', ');
		return PERMUTE;
	}
	private static var PERMUTE_STRING:String = null;

	var dummyArrow:FlxSprite;

	var curRenderedSustains:FlxTypedGroup<FlxSprite>;
	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedNoteType:FlxTypedGroup<FlxText>;

	var nextRenderedSustains:FlxTypedGroup<FlxSprite>;
	var nextRenderedNotes:FlxTypedGroup<Note>;

	var gridBG:FlxSprite;
	var nextGridBG:FlxSprite;
	var gridHeight:Float = 0;
	var gridBlack:FlxSprite;
	var gridMult:Int = 2;

	var daquantspot = 0;
	var curEventSelected:Int = 0;
	var curUndoIndex = 0;
	var curRedoIndex = 0;
	// var songData:SwagSong;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic> = null;

	var tempBpm:Float = 0;

	var vocals:FlxSound = null;

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	var value1InputText:FlxUIInputText;
	var value2InputText:FlxUIInputText;
	var curSong:String;
	var curSongFile:String;

	var zoomTxt:FlxText;

	var zoomList:Array<Float> = [
		0.25,
		0.5,
		1,
		2,
		3,
		4,
		6,
		8,
		12,
		16,
		24
	];
	var curZoom:Int = 2;

	private var blockPressWhileTypingOn:Array<FlxUIInputText> = [];
	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];
	private var blockPressWhileScrolling:Array<FlxUIDropDownMenuCustom> = [];

	var waveformSprite:FlxSprite;
	var gridLayer:FlxTypedGroup<FlxSprite>;

	public static var quantization:Int = 16;
	public static var curQuant = 3;

	public var quantizations:Array<Int> = [
		4,
		8,
		12,
		16,
		20,
		24,
		32,
		48,
		64,
		96,
		192
	];

	var text:String = "";
	public static var vortex:Bool = false;
	public var mouseQuant:Bool = false;
	override function create()
	{
		camGame = new FlxCamera(); // Hack to disable camera resetting. Not sure why that breaks things

		Note.resetCache();

		// Load Song
		if (songData == null) { // If songData not loaded already, load whatever is in PlayState.SONG
			if (Song.curPlaying != null) loadSong(Song.curPlaying, Song.curSongName);
			else {
				CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
				loadSong(Song.FALLBACK, 'Test');
			}
		}
		if (songData.notes.length == 0) addSection(); // Prevent crashing

		// Load Section Number
		if (savedSection != -1) {
			curSection = savedSection;
			savedSection = -1;
		}
		if (curSection >= songData.notes.length) curSection = songData.notes.length - 1;

		// Paths.clearMemory();

		#if desktop
		// Updating Discord Rich Presence
		DiscordClient.changePresence("Chart Editor", StringTools.replace(songName, '-', ' '));
		#end

		vortex = FlxG.save.data.chart_vortex;
		ignoreWarnings = FlxG.save.data.ignoreWarnings;
		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = 0xFF222222;
		add(bg);

		// gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * GRID_COLS());
		// gridFakeBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * GRID_COLS());
		gridLayer = new FlxTypedGroup<FlxSprite>();
		add(gridLayer);

		waveformSprite = new FlxSprite(GRID_SIZE, 0).makeGraphic(FlxG.width, FlxG.height, 0x00FFFFFF);
		add(waveformSprite);

		var eventIcon:FlxSprite = new FlxSprite(0, 0).loadGraphic(Paths.image('eventArrow'));
		leftIcon = new HealthIcon('bf');
		rightIcon = new HealthIcon('dad');
		eventIcon.scrollFactor.set(1, 1);
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		eventIcon.setGraphicSize(30, 30);
		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		eventIcon.updateHitbox();
		leftIcon.updateHitbox();
		rightIcon.updateHitbox();

		eventIcon.setPosition((GRID_SIZE - 30) / 2, -(MAX_GRID_SIZE + 30) / 2);
		leftIcon.setPosition(GRID_SIZE * (1 + Note.TOTAL * 0.5) - 45 / 2, -(MAX_GRID_SIZE + 45) / 2);
		rightIcon.setPosition(GRID_SIZE * (1 + Note.TOTAL * 1.5) - 45 / 2, -(MAX_GRID_SIZE + 45) / 2);

		add(eventIcon);
		add(leftIcon);
		add(rightIcon);

		curRenderedSustains = new FlxTypedGroup<FlxSprite>();
		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedNoteType = new FlxTypedGroup<FlxText>();

		nextRenderedSustains = new FlxTypedGroup<FlxSprite>();
		nextRenderedNotes = new FlxTypedGroup<Note>();

		FlxG.mouse.visible = true;
		//FlxG.save.bind('funkin', 'ninjamuffin99');

		tempBpm = songData.bpm;

		addSection();

		// sections = songData.notes;

		curSong = Paths.formatToSongPath(songName);
		curSongFile = Paths.formatToSongPath(songData.song);
		loadSongAudio();
		reloadGridLayer();
		Conductor.changeBPM(songData.bpm);
		Conductor.mapBPMChanges(songData);

		titleTxt = new FlxText(1000, 25, 0, songName + CoolUtil.getDifficultyFilePath(PlayState.storyDifficulty), 16);
		titleTxt.scrollFactor.set();
		add(titleTxt);

		bpmTxt = new FlxText(1000, 60, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(GRID_SIZE * GRID_COLS()), 4);
		add(strumLine);

		quant = new AttachedSprite('chart_quant','chart_quant');
		quant.animation.addByPrefix('q','chart_quant',0,false);
		quant.animation.play('q', true, false, 0);
		quant.sprTracker = strumLine;
		quant.xAdd = -32;
		quant.yAdd = 8;
		add(quant);

		strumLineNotes = new FlxTypedGroup<StrumNote>();
		for (i in 0...(Note.TOTAL * 2)){
			var note:StrumNote = new StrumNote(GRID_SIZE * (i+1), strumLine.y, i % Note.TOTAL, 0);
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.playAnim('static', true);
			strumLineNotes.add(note);
			note.scrollFactor.set(1, 1);
		}
		add(strumLineNotes);

		camPos = new FlxObject(0, 0, 1, 1);
		camPos.setPosition(strumLine.x + CAM_OFFSET, strumLine.y);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		var tabs = [
			{name: "Song", label: 'Song'},
			{name: "Section", label: 'Section'},
			{name: "Note", label: 'Note'},
			{name: "Events", label: 'Events'},
			{name: "Charting", label: 'Charting'},
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(300, 400);
		UI_box.x = UI_X;
		UI_box.y = 25;
		UI_box.scrollFactor.set();

		text =
		"W/S or Mouse Wheel - Change Conductor's strum time
		\nA/D - Go to the previous/next section
		\nLeft/Right - Change Snap
		\nUp/Down - Change Conductor's Strum Time with Snapping
		\nHold Shift to move 4x faster
		\nHold Control and click on an arrow to select it
		\nZ/X - Zoom in/out
		\n
		\nEsc - Test your chart inside Chart Editor
		\nEnter - Play your chart
		\nQ/E - Decrease/Increase Note Sustain Length
		\nSpace - Stop/Resume song";

		var tipTextArray:Array<String> = text.split('\n');
		for (i in 0...tipTextArray.length) {
			var tipText:FlxText = new FlxText(UI_box.x, UI_box.y + UI_box.height + 8, 0, tipTextArray[i], 16);
			tipText.y += i * 12;
			tipText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.WHITE, LEFT/*, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK*/);
			//tipText.borderSize = 2;
			tipText.scrollFactor.set();
			add(tipText);
		}
		add(UI_box);

		addSongUI();
		addSectionUI();
		addNoteUI();
		addEventsUI();
		addChartingUI();
		updateHeads();
		updateWaveform();
		//UI_box.selected_tab = 4;

		add(curRenderedSustains);
		add(curRenderedNotes);
		add(curRenderedNoteType);
		add(nextRenderedSustains);
		add(nextRenderedNotes);

		if(lastSong != curSong) {
			changeSection();
		}
		lastSong = curSong;

		zoomTxt = new FlxText(10, 10, 0, "Zoom: 1 / 1", 16);
		zoomTxt.scrollFactor.set();
		add(zoomTxt);

		updateGrid();
		super.create();
	}

	var check_mute_inst:FlxUICheckBox = null;
	var check_vortex:FlxUICheckBox = null;
	var check_warnings:FlxUICheckBox = null;
	var playSoundBf:FlxUICheckBox = null;
	var playSoundDad:FlxUICheckBox = null;
	var UI_songTitle:FlxUIInputText;
	var noteSkinInputText:FlxUIInputText;
	var noteSplashesInputText:FlxUIInputText;
	var keySchemeInputText:FlxUIInputText;
	var permuteSchemeInputText:FlxUIInputText;
	var stageDropDown:FlxUIDropDownMenuCustom;
	function addSongUI():Void
	{
		UI_songTitle = new FlxUIInputText(10, 10, 70, songData.song, 8);
		blockPressWhileTypingOn.push(UI_songTitle);

		var check_voices = new FlxUICheckBox(90, UI_songTitle.y, null, null, "Has voice track", 100);
		check_voices.checked = songData.needsVoices;
		check_voices.callback = function() {
			songData.needsVoices = check_voices.checked;
		};

		var saveButton:FlxButton = new FlxButton(200, 8, "Save", saveLevel);
		saveButton.color = FlxColor.GREEN;
		saveButton.label.color = FlxColor.WHITE;

		var reloadSong:FlxButton = new FlxButton(saveButton.x, saveButton.y + 30, "Reload Audio", function()
		{
			curSong = curSongFile = Paths.formatToSongPath(UI_songTitle.text); // TODO: Add option to separate audio name?
			loadSongAudio();
			updateWaveform();
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function () {
				loadJson(curSong.toLowerCase(), CoolUtil.getDifficultyFilePath(PlayState.storyDifficulty));
			}, null, ignoreWarnings));
		});

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'Load Autosave', function()
		{
			songData = Song.parseJSONshit(FlxG.save.data.autosave);
			Note.updateScheme(songData.keyScheme);

			MusicBeatState.resetState();
		});

		var clear_events:FlxButton = new FlxButton(320, 310, 'Clear events', function()
			{
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, clearEvents, null,ignoreWarnings));
			});
		clear_events.color = FlxColor.RED;
		clear_events.label.color = FlxColor.WHITE;

		var clear_notes:FlxButton = new FlxButton(320, clear_events.y + 30, 'Clear notes', function()
			{
				openSubState(new Prompt('This action will clear current progress.\n\nProceed?', 0, function () {
					for (sec in 0...songData.notes.length) {
						songData.notes[sec].sectionNotes = [];
					}
					updateGrid();
				}, null, ignoreWarnings));
			});
		clear_notes.color = FlxColor.RED;
		clear_notes.label.color = FlxColor.WHITE;

		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 70, 1, 1, 1, 400, 3);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';
		blockPressWhileTypingOnStepper.push(stepperBPM);

		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, stepperBPM.y + 35, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = songData.speed;
		stepperSpeed.name = 'song_speed';
		blockPressWhileTypingOnStepper.push(stepperSpeed);

		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('characters/'), Paths.mods(Paths.currentModDirectory + '/characters/'), Paths.getPreloadPath('characters/')];
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/characters/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('characters/')];
		#end

		var tempMap:Map<String, Bool> = new Map<String, Bool>();
		var characters:Array<String> = CoolUtil.coolTextFile(Paths.txt('characterList'));
		for (i in 0...characters.length) {
			tempMap.set(characters[i], true);
		}

		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(Paths.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var charToCheck:String = file.substr(0, file.length - 5);
						if(!charToCheck.endsWith('-dead') && !tempMap.exists(charToCheck)) {
							tempMap.set(charToCheck, true);
							characters.push(charToCheck);
						}
					}
				}
			}
		}
		#end

		var player1DropDown = new FlxUIDropDownMenuCustom(10, stepperSpeed.y + 45, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			songData.player1 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player1DropDown.selectedLabel = songData.player1;
		blockPressWhileScrolling.push(player1DropDown);

		var gfVersionDropDown = new FlxUIDropDownMenuCustom(player1DropDown.x, player1DropDown.y + 40, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			songData.gfVersion = characters[Std.parseInt(character)];
			updateHeads();
		});
		gfVersionDropDown.selectedLabel = songData.gfVersion;
		blockPressWhileScrolling.push(gfVersionDropDown);

		var player2DropDown = new FlxUIDropDownMenuCustom(player1DropDown.x, gfVersionDropDown.y + 40, FlxUIDropDownMenuCustom.makeStrIdLabelArray(characters, true), function(character:String)
		{
			songData.player2 = characters[Std.parseInt(character)];
			updateHeads();
		});
		player2DropDown.selectedLabel = songData.player2;
		blockPressWhileScrolling.push(player2DropDown);

		#if MODS_ALLOWED
		var directories:Array<String> = [Paths.mods('stages/'), Paths.mods(Paths.currentModDirectory + '/stages/'), Paths.getPreloadPath('stages/')];
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/stages/'));
		#else
		var directories:Array<String> = [Paths.getPreloadPath('stages/')];
		#end

		tempMap.clear();
		var stageFile:Array<String> = CoolUtil.coolTextFile(Paths.txt('stageList'));
		var stages:Array<String> = [];
		for (i in 0...stageFile.length) { //Prevent duplicates
			var stageToCheck:String = stageFile[i];
			if(!tempMap.exists(stageToCheck)) {
				stages.push(stageToCheck);
			}
			tempMap.set(stageToCheck, true);
		}
		#if MODS_ALLOWED
		for (i in 0...directories.length) {
			var directory:String = directories[i];
			if(Paths.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.json')) {
						var stageToCheck:String = file.substr(0, file.length - 5);
						if(!tempMap.exists(stageToCheck)) {
							tempMap.set(stageToCheck, true);
							stages.push(stageToCheck);
						}
					}
				}
			}
		}
		#end

		if(stages.length < 1) stages.push('stage');

		stageDropDown = new FlxUIDropDownMenuCustom(player1DropDown.x + 140, player1DropDown.y, FlxUIDropDownMenuCustom.makeStrIdLabelArray(stages, true), function(character:String)
		{
			songData.stage = stages[Std.parseInt(character)];
		});
		stageDropDown.selectedLabel = songData.stage;
		blockPressWhileScrolling.push(stageDropDown);

		var skin = songData.arrowSkin;
		if(skin == null) skin = '';

		noteSkinInputText = new FlxUIInputText(player2DropDown.x, player2DropDown.y + 50, 130, skin, 8);
		blockPressWhileTypingOn.push(noteSkinInputText);

		noteSplashesInputText = new FlxUIInputText(noteSkinInputText.x, noteSkinInputText.y + 35, 130, songData.splashSkin, 8);
		blockPressWhileTypingOn.push(noteSplashesInputText);

		var reloadNotesButton:FlxButton = new FlxButton(noteSplashesInputText.x, noteSplashesInputText.y + 35, 'Change Notes', function() {
			songData.arrowSkin = noteSkinInputText.text;
			updateGrid();
		});

		var scheme = songData.keyScheme.join(', ');
		keySchemeInputText = new FlxUIInputText(noteSkinInputText.x + 140, noteSkinInputText.y, 130, scheme, 8);
		blockPressWhileTypingOn.push(keySchemeInputText);

		var reloadSchemeButton:FlxButton = new FlxButton(keySchemeInputText.x, keySchemeInputText.y + 35, 'Apply Scheme', function() {
			var keyScheme:Array<String> = ~/ *, */g.split(keySchemeInputText.text.trim());
			openSubState(new Prompt('This action may be irreversible.\n\nProceed?', 0, function () {
				var aggressiveUpdate = keyScheme.length != Note.TOTAL;
				if (aggressiveUpdate) {
					for (section in songData.notes) { // For each section, filter and remap noteData.
						var noteArray:Array<Array<Dynamic>> = [];
						for (i in 0...section.sectionNotes.length) {
							var note:Array<Dynamic> = section.sectionNotes[i].copy();
							if (note[1] % Note.TOTAL < keyScheme.length) { // Filter
								if (note[1] >= Note.TOTAL) note[1] += keyScheme.length - Note.TOTAL; // Remap
								noteArray.push(note);
							}
						}
						section.sectionNotes = noteArray;
					}
				}
				songData.keyScheme = keyScheme;
				Note.updateScheme(keyScheme);
				permuteSchemeInputText.text = PERMUTE_STRING;

				MusicBeatState.resetState();
			}, null, ignoreWarnings || keyScheme.length >= Note.TOTAL));
		});

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);

		tab_group_song.add(check_voices);
		tab_group_song.add(clear_events);
		tab_group_song.add(clear_notes);
		tab_group_song.add(saveButton);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(noteSkinInputText);
		tab_group_song.add(noteSplashesInputText);
		tab_group_song.add(reloadNotesButton);
		tab_group_song.add(keySchemeInputText);
		tab_group_song.add(reloadSchemeButton);
		tab_group_song.add(new FlxText(stepperBPM.x, stepperBPM.y - 15, 0, 'Song BPM:'));
		tab_group_song.add(new FlxText(stepperSpeed.x, stepperSpeed.y - 15, 0, 'Song Speed:'));
		tab_group_song.add(new FlxText(player2DropDown.x, player2DropDown.y - 15, 0, 'Opponent:'));
		tab_group_song.add(new FlxText(gfVersionDropDown.x, gfVersionDropDown.y - 15, 0, 'Girlfriend:'));
		tab_group_song.add(new FlxText(player1DropDown.x, player1DropDown.y - 15, 0, 'Boyfriend:'));
		tab_group_song.add(new FlxText(stageDropDown.x, stageDropDown.y - 15, 0, 'Stage:'));
		tab_group_song.add(new FlxText(noteSkinInputText.x, noteSkinInputText.y - 15, 0, 'Note Texture:'));
		tab_group_song.add(new FlxText(noteSplashesInputText.x, noteSplashesInputText.y - 15, 0, 'Note Splashes Texture:'));
		tab_group_song.add(new FlxText(keySchemeInputText.x, keySchemeInputText.y - 15, 0, 'Key Scheme:'));
		tab_group_song.add(player2DropDown);
		tab_group_song.add(gfVersionDropDown);
		tab_group_song.add(player1DropDown);
		tab_group_song.add(stageDropDown);

		UI_box.addGroup(tab_group_song);

		FlxG.camera.follow(camPos);
	}

	var stepperLength:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_gfSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;

	var check_applyToLeft:FlxUICheckBox; // Affects the section manip buttons only
	// var check_applyToEvents:FlxUICheckBox; // Affects the section events

	var strumCopied:Float = 0;
	var notesCopied:Array<Dynamic> = [];

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		check_mustHitSection = new FlxUICheckBox(10, 15, null, null, "Must-hit Section", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = songData.notes[curSection].mustHitSection;

		check_gfSection = new FlxUICheckBox(10, check_mustHitSection.y + 22, null, null, "GF Section", 100);
		check_gfSection.name = 'check_gf';
		check_gfSection.checked = songData.notes[curSection].gfSection;

		check_altAnim = new FlxUICheckBox(check_gfSection.x + 120, check_gfSection.y, null, null, "Alt Animation", 100);
		check_altAnim.checked = songData.notes[curSection].altAnim;
		check_altAnim.name = 'check_altAnim';

		var stepUpdateButton:FlxButton = new FlxButton(10, check_altAnim.y + 22, "Update Length in Steps", function () 
		{
			if (songData.notes[curSection].lengthInSteps == Std.int(stepperLength.value)) return; 

			var endThing:Float = sectionStartTime(1);
			songData.notes[curSection].lengthInSteps = Std.int(stepperLength.value);
			var deltaStrum:Float = sectionStartTime(1) - endThing;

			for (i in curSection + 1...songData.notes.length) { // Update strumTime of all notes after
				if (songData.notes[i] != null) for (note in songData.notes[i].sectionNotes) {
					note[0] += deltaStrum;
				}
			}

			for (event in songData.events) {
				if (event[0] >= endThing) {
					event[0] += deltaStrum;
				}
			}

			recalculateBeat();
			reloadGridLayer();
		});
		stepUpdateButton.setGraphicSize(80, 30);
		stepUpdateButton.updateHitbox();

		stepperLength = new FlxUINumericStepper(100, stepUpdateButton.y + 6, 2, 0, 0, 999, 0);
		stepperLength.value = songData.notes[curSection].lengthInSteps;
		stepperLength.name = 'section_length';
		blockPressWhileTypingOnStepper.push(stepperLength);

		check_changeBPM = new FlxUICheckBox(100, stepperLength.y + 35, null, null, 'Change BPM', 100);
		check_changeBPM.checked = songData.notes[curSection].changeBPM;
		check_changeBPM.name = 'check_changeBPM';

		stepperSectionBPM = new FlxUINumericStepper(10, check_changeBPM.y, 1, Conductor.bpm, 0, 999, 1);
		if (check_changeBPM.checked) {
			stepperSectionBPM.value = songData.notes[curSection].bpm;
		} else {
			stepperSectionBPM.value = Conductor.bpm;
		}
		stepperSectionBPM.name = 'section_bpm';
		blockPressWhileTypingOnStepper.push(stepperSectionBPM);


		var copyButton:FlxButton = new FlxButton(10, check_changeBPM.y + 20, "Copy Section", function()
		{
			notesCopied = [];
			strumCopied = sectionStartTime();
			for (i in 0...songData.notes[curSection].sectionNotes.length)
			{
				var note:Array<Dynamic> = songData.notes[curSection].sectionNotes[i];

				// applyToLeft: Skip RHS
				if (check_applyToLeft.checked && note[1] >= Note.TOTAL) continue;

				notesCopied.push(note);
			}

			// applyToLeft: Skip Events
			if (check_applyToLeft.checked) return;

			var startThing:Float = sectionStartTime();
			var endThing:Float = sectionStartTime(1);
			for (event in songData.events)
			{
				var strumTime:Float = event[0];
				if(endThing > event[0] && event[0] >= startThing)
				{
					var copiedEventArray:Array<Dynamic> = [for (arr in (event[1]:Array<Dynamic>)) arr.copy()];
					notesCopied.push([strumTime, copiedEventArray]);
				}
			}
		});

		var pasteButton:FlxButton = new FlxButton(copyButton.x + 100, copyButton.y, "Paste Section", function()
		{
			if(notesCopied == null || notesCopied.length < 1) return;

			var deltaStrum:Float = sectionStartTime() - strumCopied;
			// trace('Time to add: ' + deltaStrum);

			for (note in notesCopied)
			{
				// applyToLeft: Skip RHS and Events
				if (check_applyToLeft.checked && (note[1] < 0 || note[1] >= Note.TOTAL)) continue;

				var newStrumTime:Float = note[0] + deltaStrum;
				if(note[1] < 0)
				{
					var copiedEventArray:Array<Dynamic> = [for (arr in (note[2]:Array<Dynamic>)) arr.copy()];
					songData.events.push([newStrumTime, copiedEventArray]);
				}
				else
				{
					var copiedNote:Array<Dynamic> = note.copy();
					copiedNote[0] = newStrumTime;
					songData.notes[curSection].sectionNotes.push(copiedNote);
				}
			}
			updateGrid();
		});

		var clearSectionButton:FlxButton = new FlxButton(pasteButton.x + 100, pasteButton.y, "Clear Section", function()
		{
			if (check_applyToLeft.checked) {
				// applyToLeft: Clear only LHS
				songData.notes[curSection].sectionNotes = songData.notes[curSection].sectionNotes.filter((note:Array<Dynamic>) -> !(note[1] < Note.TOTAL));
			} else {
				// Remove all notes in this section
				songData.notes[curSection].sectionNotes = [];

				var startThing:Float = sectionStartTime();
				var endThing:Float = sectionStartTime(1);

				// Filter events in this section
				songData.events = songData.events.filter((event:Array<Dynamic>) -> !(event != null && endThing > event[0] && event[0] >= startThing));
			}

			updateGrid();
			updateNoteUI();
		});
		clearSectionButton.color = FlxColor.RED;
		clearSectionButton.label.color = FlxColor.WHITE;

		var swapSection:FlxButton = new FlxButton(10, copyButton.y + 30, "Swap Section", function() // "Duet Notes" if check_applyToLeft
		{
			if (check_applyToLeft.checked) {
				// applyToLeft: Clone LHS to RHS
				var total = songData.notes[curSection].sectionNotes.length;

				for (i in 0...total) {
					var note:Array<Dynamic> = songData.notes[curSection].sectionNotes[i];
					if (note[1] < Note.TOTAL) {
						note = note.copy();
						note[1] += Note.TOTAL;
						songData.notes[curSection].sectionNotes.push(note);
					}
				}
			} else {
				for (i in 0...songData.notes[curSection].sectionNotes.length)
				{
					var note:Array<Dynamic> = songData.notes[curSection].sectionNotes[i];
					note[1] = (note[1] + Note.TOTAL) % (Note.TOTAL * 2);
					songData.notes[curSection].sectionNotes[i] = note;
				}
			}
			updateGrid();
		});

		var stepperCopy:FlxUINumericStepper = null;
		var copyLastButton:FlxButton = new FlxButton(10, swapSection.y + 60, "Copy last section", function()
		{
			var value:Int = Std.int(stepperCopy.value);
			if(value == 0) return;

			// Not sure if I understand this code correctly: If value > curSection, it copies from 0 to value?
			var daSec = FlxMath.maxInt(curSection, value);

			// Copy from (daSec - value) to daSec
			var oldTime:Float = sectionStartTime((daSec - value) - curSection);
			var oldEndTime:Float = sectionStartTime((daSec - value) + 1 - curSection);
			var newTime:Float = sectionStartTime(daSec - curSection);
			var deltaStrum:Float = newTime - oldTime;

			for (note in songData.notes[daSec - value].sectionNotes)
			{
				// applyToLeft: Skip RHS
				if (check_applyToLeft.checked && note[1] >= Note.TOTAL) continue;

				var copiedNote:Array<Dynamic> = note.copy();

				copiedNote[0] += deltaStrum;
				songData.notes[daSec].sectionNotes.push(copiedNote);
			}

			// applyToLeft: Skip Events
			if (check_applyToLeft.checked) {
				updateGrid();
				return;
			}

			for (event in songData.events)
			{
				var strumTime:Float = event[0];
				if(oldEndTime > event[0] && event[0] >= oldTime)
				{
					strumTime += deltaStrum;
					var copiedEventArray:Array<Dynamic> = [for (arr in (event[1]:Array<Dynamic>)) arr.copy()];
					songData.events.push([strumTime, copiedEventArray]);
				}
			}
			updateGrid();
		});
		copyLastButton.setGraphicSize(80, 30);
		copyLastButton.updateHitbox();
		
		stepperCopy = new FlxUINumericStepper(copyLastButton.x + 100, copyLastButton.y + 6, 1, 1, -999, 999, 0);
		blockPressWhileTypingOnStepper.push(stepperCopy);

		// New buttons
		var flipSection:FlxButton = new FlxButton(swapSection.x + 100, swapSection.y, "Flip Notes", function() // flip all Note.TOTAL notes
		{
			for (i in 0...songData.notes[curSection].sectionNotes.length)
			{
				var note:Array<Dynamic> = songData.notes[curSection].sectionNotes[i];

				// applyToLeft: Skip RHS
				if (check_applyToLeft.checked && note[1] >= Note.TOTAL) continue;

				if (note[1] >= Note.TOTAL) note[1] = Note.TOTAL * 2 - 1 - (note[1] - Note.TOTAL);
				else note[1] = Note.TOTAL - 1 - note[1];
			}
			updateGrid();
		});

		var permuteSection:FlxButton = new FlxButton(flipSection.x + 100, flipSection.y, "Permute Notes", function() // generalized permutation
		{
			// Parse permutation string
			if (PERMUTE_STRING != permuteSchemeInputText.text) {
				var strs:Array<String> = ~/ *, */g.split(permuteSchemeInputText.text.trim());
				if (strs.length != Note.TOTAL) { // Trim the permutation and give up
					permuteSchemeInputText.text = strs.slice(0, Note.TOTAL).join(', ');
					return;
				}
				var idxs:Array<Int> = [];
				for (i in 0...strs.length) {
					var idx:Null<Int> = Std.parseInt(strs[i]);
					if (idx == null || idx < 0 || Note.TOTAL <= idx) strs[i] = '?';
					else idxs.push((idx:Int));
				}
				if (idxs.length != Note.TOTAL) { // Some indices are invalid. Give up.
					permuteSchemeInputText.text = strs.join(', ');
					return;
				}
				PERMUTE	= idxs;
				permuteSchemeInputText.text = PERMUTE_STRING;
			}

			// Do the permutation
			for (i in 0...songData.notes[curSection].sectionNotes.length)
			{
				var note:Array<Dynamic> = songData.notes[curSection].sectionNotes[i];

				// applyToLeft: Skip RHS
				if (check_applyToLeft.checked && note[1] >= Note.TOTAL) continue;

				if (note[1] >= Note.TOTAL) note[1] = Note.TOTAL + PERMUTE[Std.int(note[1] - Note.TOTAL)];
				else note[1] = PERMUTE[Std.int(note[1])]; 
			}
			updateGrid();
		});

		var shiftSection:FlxButton = new FlxButton(10, swapSection.y + 30, "Shift Notes", function() // shift notes down by 1 grid
		{
			for (i in 0...songData.notes[curSection].sectionNotes.length)
			{
				var note:Array<Dynamic> = songData.notes[curSection].sectionNotes[i];

				// applyToLeft: Skip RHS
				if (check_applyToLeft.checked && note[1] >= Note.TOTAL) continue;

				note[0] += Conductor.stepCrochet;
			}
			updateGrid();
		});

		// applyToLeft button
		check_applyToLeft = new FlxUICheckBox(10, 350, null, null, "Operate on Left side only", 100,
			function() {
				if (check_applyToLeft.checked) swapSection.text = "Duet Notes";
				else swapSection.text = "Swap Section";
			}
		);

		// Mirror scheme
		var scheme:String = PERMUTE.join(', ');
		permuteSchemeInputText = new FlxUIInputText(130, 360, 100, scheme, 8);
		blockPressWhileTypingOn.push(permuteSchemeInputText);

		tab_group_section.add(stepperLength);
		tab_group_section.add(stepUpdateButton);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_gfSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(pasteButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(swapSection);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(copyLastButton);

		tab_group_section.add(flipSection);
		tab_group_section.add(permuteSection);
		tab_group_section.add(shiftSection);

		tab_group_section.add(check_applyToLeft);
		tab_group_section.add(permuteSchemeInputText);

		tab_group_section.add(new FlxText(permuteSchemeInputText.x, permuteSchemeInputText.y - 15, 0, 'Permutation:'));

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;
	var strumTimeInputText:FlxUIInputText; //I wanted to use a stepper but we can't scale these as far as i know :(
	var noteTypeDropDown:FlxUIDropDownMenuCustom;
	var noteTypeDropDownNew:FlxUIDropDownMenuCustom;
	var noteTypeInputText:FlxUIInputText;
	var currentType:Int = 0;

	function addNoteUI():Void
	{
		var tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		stepperSusLength = new FlxUINumericStepper(10, 25, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * 64);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';
		blockPressWhileTypingOnStepper.push(stepperSusLength);

		strumTimeInputText = new FlxUIInputText(10, 65, 180, "0");
		// tab_group_note.add(strumTimeInputText);
		blockPressWhileTypingOn.push(strumTimeInputText);

		var key:Int = 0;
		var displayNameList:Array<String> = [];
		while (key < noteTypeList.length) {
			displayNameList.push(noteTypeList[key]);
			noteTypeMap.set(noteTypeList[key], key);
			noteTypeIntMap.set(key, noteTypeList[key]);
			key++;
		}

		#if LUA_ALLOWED
		var directories:Array<String> = [];

		#if MODS_ALLOWED
		directories.push(Paths.mods('custom_notetypes/'));
		directories.push(Paths.mods(Paths.currentModDirectory + '/custom_notetypes/'));
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/custom_notetypes/'));
		#end

		for (i in 0...directories.length) {
			var directory:String =  directories[i];
			if(Paths.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file.endsWith('.lua')) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if(!noteTypeMap.exists(fileToCheck)) {
							displayNameList.push(fileToCheck);
							noteTypeMap.set(fileToCheck, key);
							noteTypeIntMap.set(key, fileToCheck);
							key++;
						}
					}
				}
			}
		}
		#end

		for (i in 1...displayNameList.length) {
			displayNameList[i] = i + '. ' + displayNameList[i];
		}

		noteTypeDropDown = new FlxUIDropDownMenuCustom(10, 105, FlxUIDropDownMenuCustom.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				curSelectedNote[3] = noteTypeIntMap.get(Std.parseInt(character));
				noteTypeInputText.text = '';
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(noteTypeDropDown);

		noteTypeDropDownNew = new FlxUIDropDownMenuCustom(10, 145, FlxUIDropDownMenuCustom.makeStrIdLabelArray(displayNameList, true), function(character:String)
		{
			currentType = Std.parseInt(character);
		});
		blockPressWhileScrolling.push(noteTypeDropDownNew);

		noteTypeInputText = new FlxUIInputText(noteTypeDropDown.x + 140, noteTypeDropDown.y + 2, 100, "");
		blockPressWhileTypingOn.push(noteTypeInputText);

		tab_group_note.add(new FlxText(stepperSusLength.x, stepperSusLength.y - 15, 0, 'Sustain length:'));
		tab_group_note.add(new FlxText(strumTimeInputText.x, strumTimeInputText.y - 15, 0, 'Strum time (in miliseconds):'));
		tab_group_note.add(new FlxText(noteTypeDropDown.x, noteTypeDropDown.y - 15, 0, 'Note type (for selected):'));
		tab_group_note.add(new FlxText(noteTypeDropDownNew.x, noteTypeDropDownNew.y - 15, 0, 'Note type (for new notes):').setFormat(8, FlxColor.YELLOW));
		tab_group_note.add(new FlxText(noteTypeInputText.x, noteTypeInputText.y - 2 - 15, 0, '(Custom note type, for Lua)'));
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(strumTimeInputText);
		tab_group_note.add(noteTypeDropDown);
		tab_group_note.add(noteTypeDropDownNew);
		tab_group_note.add(noteTypeInputText);

		UI_box.addGroup(tab_group_note);
	}

	var eventDropDown:FlxUIDropDownMenuCustom;
	var descText:FlxText;
	var selectedEventText:FlxText;
	function addEventsUI():Void
	{
		var tab_group_event = new FlxUI(null, UI_box);
		tab_group_event.name = 'Events';

		var loadEventJson:FlxButton = new FlxButton(320, 310, 'Load Events', function()
		{
			var file:String = Paths.json(curSong + '/events');
			if (#if MODS_ALLOWED Paths.exists(Paths.modsJson(curSong + '/events')) || #end Paths.exists(file))
			{
				clearEvents();
				var events:SwagSong = Song.loadFromJson('events', curSong);
				songData.events = events.events;
				changeSection(curSection);
			}
		});

		var saveEvents:FlxButton = new FlxButton(loadEventJson.x, loadEventJson.y + 30, 'Save Events', saveEvents);

		#if LUA_ALLOWED
		var eventPushedMap:Map<String, Bool> = new Map<String, Bool>();
		var directories:Array<String> = [];

		#if MODS_ALLOWED
		directories.push(Paths.mods('custom_events/'));
		directories.push(Paths.mods(Paths.currentModDirectory + '/custom_events/'));
		for (mod in Paths.getGlobalMods())
			directories.push(Paths.mods(mod + '/custom_events/'));
		#end

		for (i in 0...directories.length) {
			var directory:String =  directories[i];
			if(Paths.exists(directory)) {
				for (file in FileSystem.readDirectory(directory)) {
					var path = haxe.io.Path.join([directory, file]);
					if (!FileSystem.isDirectory(path) && file != 'readme.txt' && file.endsWith('.txt')) {
						var fileToCheck:String = file.substr(0, file.length - 4);
						if(!eventPushedMap.exists(fileToCheck)) {
							eventPushedMap.set(fileToCheck, true);
							eventStuff.push([fileToCheck, Paths.getText(path)]);
						}
					}
				}
			}
		}
		eventPushedMap.clear();
		eventPushedMap = null;
		#end

		descText = new FlxText(10, 200, 0, eventStuff[0][0]);

		var leEvents:Array<String> = [];
		for (i in 0...eventStuff.length) {
			leEvents.push(eventStuff[i][0]);
		}

		var text:FlxText = new FlxText(10, 30, 0, "Event:");
		tab_group_event.add(text);
		eventDropDown = new FlxUIDropDownMenuCustom(10, 45, FlxUIDropDownMenuCustom.makeStrIdLabelArray(leEvents, true), function(pressed:String) {
			var selectedEvent:Int = Std.parseInt(pressed);
			descText.text = eventStuff[selectedEvent][1];
				if (curSelectedNote != null &&  eventStuff != null) {
				if (curSelectedNote != null && curSelectedNote[2] == null){
				curSelectedNote[1][curEventSelected][0] = eventStuff[selectedEvent][0];

				}
				updateGrid();
			}
		});
		blockPressWhileScrolling.push(eventDropDown);

		var text:FlxText = new FlxText(10, 90, 0, "Value 1:");
		tab_group_event.add(text);
		value1InputText = new FlxUIInputText(10, 105, 100, "");
		blockPressWhileTypingOn.push(value1InputText);

		var text:FlxText = new FlxText(10, 130, 0, "Value 2:");
		tab_group_event.add(text);
		value2InputText = new FlxUIInputText(10, 145, 100, "");
		blockPressWhileTypingOn.push(value2InputText);

		// New event buttons
		var removeButton:FlxButton = new FlxButton(eventDropDown.x + eventDropDown.width + 10, eventDropDown.y, '-', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				if(curSelectedNote[1].length < 2)
				{
					songData.events.remove(curSelectedNote);
					curSelectedNote = null;
				}
				else
				{
					curSelectedNote[1].remove(curSelectedNote[1][curEventSelected]);
				}

				var eventsGroup:Array<Dynamic>;
				--curEventSelected;
				if(curEventSelected < 0) curEventSelected = 0;
				else if(curSelectedNote != null && curEventSelected >= (eventsGroup = curSelectedNote[1]).length) curEventSelected = eventsGroup.length - 1;

				changeEventSelected();
				updateGrid();
			}
		});
		removeButton.setGraphicSize(Std.int(removeButton.height), Std.int(removeButton.height));
		removeButton.updateHitbox();
		removeButton.color = FlxColor.RED;
		removeButton.label.color = FlxColor.WHITE;
		removeButton.label.size = 12;
		setAllLabelsOffset(removeButton, -30, 0);
		tab_group_event.add(removeButton);

		var addButton:FlxButton = new FlxButton(removeButton.x + removeButton.width + 10, removeButton.y, '+', function()
		{
			if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
			{
				var eventsGroup:Array<Dynamic> = curSelectedNote[1];
				eventsGroup.push(['', '', '']);

				changeEventSelected(1);
				updateGrid();
			}
		});
		addButton.setGraphicSize(Std.int(removeButton.width), Std.int(removeButton.height));
		addButton.updateHitbox();
		addButton.color = FlxColor.GREEN;
		addButton.label.color = FlxColor.WHITE;
		addButton.label.size = 12;
		setAllLabelsOffset(addButton, -30, 0);
		tab_group_event.add(addButton);

		var moveLeftButton:FlxButton = new FlxButton(addButton.x + addButton.width + 20, addButton.y, '<', function()
		{
			changeEventSelected(-1);
		});
		moveLeftButton.setGraphicSize(Std.int(addButton.width), Std.int(addButton.height));
		moveLeftButton.updateHitbox();
		moveLeftButton.label.size = 12;
		setAllLabelsOffset(moveLeftButton, -30, 0);
		tab_group_event.add(moveLeftButton);

		var moveRightButton:FlxButton = new FlxButton(moveLeftButton.x + moveLeftButton.width + 10, moveLeftButton.y, '>', function()
		{
			changeEventSelected(1);
		});
		moveRightButton.setGraphicSize(Std.int(moveLeftButton.width), Std.int(moveLeftButton.height));
		moveRightButton.updateHitbox();
		moveRightButton.label.size = 12;
		setAllLabelsOffset(moveRightButton, -30, 0);
		tab_group_event.add(moveRightButton);

		selectedEventText = new FlxText(addButton.x - 100, addButton.y + addButton.height + 6, (moveRightButton.x - addButton.x) + 186, 'Selected Event: None');
		selectedEventText.alignment = CENTER;
		tab_group_event.add(selectedEventText);

		tab_group_event.add(descText);
		tab_group_event.add(value1InputText);
		tab_group_event.add(value2InputText);
		tab_group_event.add(eventDropDown);

		tab_group_event.add(saveEvents);
		tab_group_event.add(loadEventJson);

		UI_box.addGroup(tab_group_event);
	}

	function changeEventSelected(change:Int = 0)
	{
		if(curSelectedNote != null && curSelectedNote[2] == null) //Is event note
		{
			curEventSelected += change;
			if(curEventSelected < 0) curEventSelected = Std.int(curSelectedNote[1].length) - 1;
			else if(curEventSelected >= curSelectedNote[1].length) curEventSelected = 0;
			selectedEventText.text = 'Selected Event: ' + (curEventSelected + 1) + ' / ' + curSelectedNote[1].length;
		}
		else
		{
			curEventSelected = 0;
			selectedEventText.text = 'Selected Event: None';
		}
		updateNoteUI();
	}

	function setAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
		{
			point.set(x, y);
		}
	}

	var metronome:FlxUICheckBox;
	var mouseScrollingQuant:FlxUICheckBox;
	var metronomeStepper:FlxUINumericStepper;
	var metronomeOffsetStepper:FlxUINumericStepper;
	var disableAutoScrolling:FlxUICheckBox;
	#if desktop
	var waveformUseInstrumental:FlxUICheckBox;
	var waveformUseVoices:FlxUICheckBox;
	#end
	var instVolume:FlxUINumericStepper;
	var voicesVolume:FlxUINumericStepper;
	function addChartingUI() {
		var tab_group_chart = new FlxUI(null, UI_box);
		tab_group_chart.name = 'Charting';

		#if desktop
		if (FlxG.save.data.chart_waveformInst == null) FlxG.save.data.chart_waveformInst = false;
		if (FlxG.save.data.chart_waveformVoices == null) FlxG.save.data.chart_waveformVoices = false;

		waveformUseInstrumental = new FlxUICheckBox(10, 90, null, null, "Waveform for Instrumental", 100);
		waveformUseInstrumental.checked = FlxG.save.data.chart_waveformInst;
		waveformUseInstrumental.callback = function()
		{
			waveformUseVoices.checked = false;
			FlxG.save.data.chart_waveformVoices = false;
			FlxG.save.data.chart_waveformInst = waveformUseInstrumental.checked;
			updateWaveform();
		};

		waveformUseVoices = new FlxUICheckBox(waveformUseInstrumental.x + 120, waveformUseInstrumental.y, null, null, "Waveform for Voices", 100);
		waveformUseVoices.checked = FlxG.save.data.chart_waveformVoices;
		waveformUseVoices.callback = function()
		{
			waveformUseInstrumental.checked = false;
			FlxG.save.data.chart_waveformInst = false;
			FlxG.save.data.chart_waveformVoices = waveformUseVoices.checked;
			updateWaveform();
		};
		#end

		check_mute_inst = new FlxUICheckBox(10, 310, null, null, "Mute Instrumental (in editor)", 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = function()
		{
			var vol:Float = 1;

			if (check_mute_inst.checked)
				vol = 0;

			FlxG.sound.music.volume = vol;
		};

		mouseScrollingQuant = new FlxUICheckBox(10, 200, null, null, "Mouse Scrolling Quantization", 100);
		if (FlxG.save.data.mouseScrollingQuant == null) FlxG.save.data.mouseScrollingQuant = false;
		mouseScrollingQuant.checked = FlxG.save.data.mouseScrollingQuant;

		mouseScrollingQuant.callback = function()
		{
			FlxG.save.data.mouseScrollingQuant = mouseScrollingQuant.checked;
			mouseQuant = FlxG.save.data.mouseScrollingQuant;
		};

		check_vortex = new FlxUICheckBox(10, 160, null, null, "Vortex Editor (BETA)", 100);
		if (FlxG.save.data.chart_vortex == null) FlxG.save.data.chart_vortex = false;
		check_vortex.checked = FlxG.save.data.chart_vortex;

		check_vortex.callback = function()
		{
			FlxG.save.data.chart_vortex = check_vortex.checked;
			vortex = FlxG.save.data.chart_vortex;
			reloadGridLayer();
		};

		check_warnings = new FlxUICheckBox(10, 120, null, null, "Ignore Progress Warnings", 100);
		if (FlxG.save.data.ignoreWarnings == null) FlxG.save.data.ignoreWarnings = false;
		check_warnings.checked = FlxG.save.data.ignoreWarnings;

		check_warnings.callback = function()
		{
			FlxG.save.data.ignoreWarnings = check_warnings.checked;
			ignoreWarnings = FlxG.save.data.ignoreWarnings;
		};

		var check_mute_vocals = new FlxUICheckBox(check_mute_inst.x + 120, check_mute_inst.y, null, null, "Mute Vocals (in editor)", 100);
		check_mute_vocals.checked = false;
		check_mute_vocals.callback = function()
		{
			if(vocals != null) {
				var vol:Float = 1;

				if (check_mute_vocals.checked)
					vol = 0;

				vocals.volume = vol;
			}
		};

		playSoundBf = new FlxUICheckBox(check_mute_inst.x, check_mute_vocals.y + 30, null, null, 'Play Sound (Boyfriend notes)', 100,
			function() {
				FlxG.save.data.chart_playSoundBf = playSoundBf.checked;
			}
		);
		if (FlxG.save.data.chart_playSoundBf == null) FlxG.save.data.chart_playSoundBf = false;
		playSoundBf.checked = FlxG.save.data.chart_playSoundBf;

		playSoundDad = new FlxUICheckBox(check_mute_inst.x + 120, playSoundBf.y, null, null, 'Play Sound (Opponent notes)', 100,
			function() {
				FlxG.save.data.chart_playSoundDad = playSoundDad.checked;
			}
		);
		if (FlxG.save.data.chart_playSoundDad == null) FlxG.save.data.chart_playSoundDad = false;
		playSoundDad.checked = FlxG.save.data.chart_playSoundDad;

		metronome = new FlxUICheckBox(10, 15, null, null, "Metronome Enabled", 100,
			function() {
				FlxG.save.data.chart_metronome = metronome.checked;
			}
		);
		if (FlxG.save.data.chart_metronome == null) FlxG.save.data.chart_metronome = false;
		metronome.checked = FlxG.save.data.chart_metronome;

		metronomeStepper = new FlxUINumericStepper(15, 55, 5, songData.bpm, 1, 1500, 1);
		metronomeOffsetStepper = new FlxUINumericStepper(metronomeStepper.x + 100, metronomeStepper.y, 25, 0, 0, 1000, 1);
		blockPressWhileTypingOnStepper.push(metronomeStepper);
		blockPressWhileTypingOnStepper.push(metronomeOffsetStepper);

		disableAutoScrolling = new FlxUICheckBox(metronome.x + 120, metronome.y, null, null, "Disable Autoscroll (Not Recommended)", 120,
			function() {
				FlxG.save.data.chart_noAutoScroll = disableAutoScrolling.checked;
			}
		);
		if (FlxG.save.data.chart_noAutoScroll == null) FlxG.save.data.chart_noAutoScroll = false;
		disableAutoScrolling.checked = FlxG.save.data.chart_noAutoScroll;

		instVolume = new FlxUINumericStepper(metronomeStepper.x, 270, 0.1, 1, 0, 1, 1);
		instVolume.value = FlxG.sound.music.volume;
		instVolume.name = 'inst_volume';
		blockPressWhileTypingOnStepper.push(instVolume);

		voicesVolume = new FlxUINumericStepper(instVolume.x + 100, instVolume.y, 0.1, 1, 0, 1, 1);
		voicesVolume.value = vocals.volume;
		voicesVolume.name = 'voices_volume';
		blockPressWhileTypingOnStepper.push(voicesVolume);

		tab_group_chart.add(new FlxText(metronomeStepper.x, metronomeStepper.y - 15, 0, 'BPM:'));
		tab_group_chart.add(new FlxText(metronomeOffsetStepper.x, metronomeOffsetStepper.y - 15, 0, 'Offset (ms):'));
		tab_group_chart.add(new FlxText(instVolume.x, instVolume.y - 15, 0, 'Inst Volume'));
		tab_group_chart.add(new FlxText(voicesVolume.x, voicesVolume.y - 15, 0, 'Voices Volume'));
		tab_group_chart.add(metronome);
		tab_group_chart.add(disableAutoScrolling);
		tab_group_chart.add(metronomeStepper);
		tab_group_chart.add(metronomeOffsetStepper);
		#if desktop
		tab_group_chart.add(waveformUseInstrumental);
		tab_group_chart.add(waveformUseVoices);
		#end
		tab_group_chart.add(instVolume);
		tab_group_chart.add(voicesVolume);
		tab_group_chart.add(check_mute_inst);
		tab_group_chart.add(check_mute_vocals);
		tab_group_chart.add(check_vortex);
		tab_group_chart.add(mouseScrollingQuant);
		tab_group_chart.add(check_warnings);
		tab_group_chart.add(playSoundBf);
		tab_group_chart.add(playSoundDad);
		UI_box.addGroup(tab_group_chart);
	}

	function loadSongAudio():Void
	{
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			// vocals.stop();
		}

		var file:Dynamic = Paths.voices(curSongFile);
		vocals = new FlxSound();
		if (Std.isOfType(file, Sound) || Paths.exists(file)) {
			vocals.loadEmbedded(file);
			FlxG.sound.list.add(vocals);
		}
		generateSong();
		FlxG.sound.music.pause();
		Conductor.songPosition = sectionStartTime();
		FlxG.sound.music.time = Conductor.songPosition;
	}

	function generateSong() {
		FlxG.sound.playMusic(Paths.inst(curSongFile), 0.6/*, false*/);
		if (instVolume != null) FlxG.sound.music.volume = instVolume.value;
		if (check_mute_inst != null && check_mute_inst.checked) FlxG.sound.music.volume = 0;

		FlxG.sound.music.onComplete = function()
		{
			FlxG.sound.music.pause();
			Conductor.songPosition = 0;
			if(vocals != null) {
				vocals.pause();
				vocals.time = 0;
			}
			changeSection();

			updateGrid();
			updateSectionUI();
			vocals.play();
		};
	}

	function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Must-hit Section':
					songData.notes[curSection].mustHitSection = check.checked;

					updateGrid();
					updateHeads();

				case 'GF Section':
					songData.notes[curSection].gfSection = check.checked;

					updateGrid();
					updateHeads();

				case 'Change BPM':
					songData.notes[curSection].changeBPM = check.checked;
					FlxG.log.add('changed bpm shit');
				case "Alt Animation":
					songData.notes[curSection].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			FlxG.log.add(wname);
			if (wname == 'section_length')
			{
				songData.notes[curSection].lengthInSteps = Std.int(nums.value);
				updateGrid();
			}
			else if (wname == 'song_speed')
			{
				songData.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				tempBpm = nums.value;
				Conductor.mapBPMChanges(songData);
				Conductor.changeBPM(nums.value);
			}
			else if (wname == 'note_susLength')
			{
				if(curSelectedNote != null && curSelectedNote[1] > -1) {
					curSelectedNote[2] = nums.value;
					updateGrid();
				} else {
					sender.value = 0;
				}
			}
			else if (wname == 'section_bpm')
			{
				if (check_changeBPM.checked) songData.notes[curSection].bpm = nums.value;
				updateGrid();
			}
			else if (wname == 'inst_volume')
			{
				FlxG.sound.music.volume = nums.value;
			}
			else if (wname == 'voices_volume')
			{
				vocals.volume = nums.value;
			}
		}
		else if(id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			if(sender == noteSplashesInputText) {
				songData.splashSkin = noteSplashesInputText.text;
			}
			else if(curSelectedNote != null)
			{
				if(sender == value1InputText) {
					curSelectedNote[1][curEventSelected][1] = value1InputText.text;
					updateGrid();
				}
				else if(sender == value2InputText) {
					curSelectedNote[1][curEventSelected][2] = value2InputText.text;
					updateGrid();
				}
				else if(sender == strumTimeInputText) {
					var value:Float = Std.parseFloat(strumTimeInputText.text);
					if(Math.isNaN(value)) value = 0;
					curSelectedNote[0] = value;
					updateGrid();
				}
				else if(sender == noteTypeInputText) {
					if (noteTypeInputText.text == '') {
						curSelectedNote[3] = '';
					} else {
						curSelectedNote[3] = '.' + noteTypeInputText.text;
						noteTypeDropDown.selectedLabel = '';
					}
					updateGrid();
				}
			}
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	inline function sectionStartTime(add:Int = 0):Float
	{
		return Song.songSectionStartTime(songData, curSection + add);
	}

	inline function sectionLengthInSteps(add:Int = 0):Int
	{
		return songData.notes[curSection + add] == null ? 0 : songData.notes[curSection + add].lengthInSteps;
	}

	var lastConductorPos:Float;
	var colorSine:Float = 0;
	var oldSection:Int = 0;
	override function update(elapsed:Float)
	{
		Conductor.songPosition = FlxG.sound.music.time;
		recalculateSteps();

		if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}

		Conductor.songPosition = FlxG.sound.music.time;

		strumLineUpdateY();
		for (i in 0...8){
			strumLineNotes.members[i].y = strumLine.y;
		}

		FlxG.mouse.visible = true;//cause reasons. trust me
		camPos.y = strumLine.y;

		if(!disableAutoScrolling.checked) {
			if (curSection == oldSection + 1)
			{
				if (songData.notes[curSection] == null)
					addSection();

				changeSection(curSection, false);
			} else if (curSection != oldSection) {
				changeSection(curSection, false);
			}
		}
		oldSection = curSection;

		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * sectionLengthInSteps()) * zoomList[curZoom])
		{
			dummyArrow.visible = true;
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.CONTROL)
				dummyArrow.y = FlxG.mouse.y;
			else{
				var alignStrum:Bool = FlxG.keys.pressed.SHIFT;
				var time:Float = getStrumTime(FlxG.mouse.y);
				var snap:Float = 16 / quantization * Conductor.stepCrochet; // For convenience we assume the quantization stuff always assumes 4/4 time

				if (alignStrum) { // align to strum
					var dTime:Float = FlxG.sound.music.time - sectionStartTime();

					time = Math.floor((time - dTime) / snap) * snap + dTime;
					if (time < 0) time += snap; // TODO: Epsilon
				} else { // align to section
					time = Math.floor(time / snap) * snap;
				}

				var y = getYfromStrum(time);
				dummyArrow.y = y;
			}
		} else {
			dummyArrow.visible = false;
		}

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEachAlive(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else if (FlxG.keys.pressed.ALT)
						{
							selectNote(note);
							curSelectedNote[3] = noteTypeIntMap.get(currentType);
							updateGrid();
						}
						else
						{
							//trace('tryin to delete note...');
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * sectionLengthInSteps()) * zoomList[curZoom])
				{
					FlxG.log.add('added note');
					addNote();
				}
			}
		}

		var blockInput:Bool = false;
		for (inputText in blockPressWhileTypingOn) {
			if(inputText.hasFocus) {
				FlxG.sound.muteKeys = [];
				FlxG.sound.volumeDownKeys = [];
				FlxG.sound.volumeUpKeys = [];
				blockInput = true;
				break;
			}
		}

		if(!blockInput) {
			for (stepper in blockPressWhileTypingOnStepper) {
				@:privateAccess
				var leText:Dynamic = stepper.text_field;
				var leText:FlxUIInputText = leText;
				if(leText.hasFocus) {
					FlxG.sound.muteKeys = [];
					FlxG.sound.volumeDownKeys = [];
					FlxG.sound.volumeUpKeys = [];
					blockInput = true;
					break;
				}
			}
		}

		if(!blockInput) {
			FlxG.sound.muteKeys = TitleState.muteKeys;
			FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
			FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
			for (dropDownMenu in blockPressWhileScrolling) {
				if(dropDownMenu.dropPanel.visible) {
					blockInput = true;
					break;
				}
			}
		}

		if (!blockInput)
		{
			if (FlxG.keys.justPressed.ESCAPE)
			{
				autosaveSong();
				savedSection = curSection;
				LoadingState.loadAndSwitchState(new editors.EditorPlayState(sectionStartTime()).loadSong(songData, songName));
			}
			if (FlxG.keys.justPressed.ENTER)
			{
				autosaveSong();
				FlxG.mouse.visible = false;
				FlxG.sound.music.stop();
				if(vocals != null) vocals.stop();

				//if(songData.stage == null) songData.stage = stageDropDown.selectedLabel;
				StageData.loadDirectory(songData);
				LoadingState.loadAndSwitchState(new PlayState().loadSong(songData, songName));
			}

			if(curSelectedNote != null && curSelectedNote[1] > -1) {
				if (FlxG.keys.justPressed.E)
				{
					changeNoteSustain(Conductor.stepCrochet);
				}
				if (FlxG.keys.justPressed.Q)
				{
					changeNoteSustain(-Conductor.stepCrochet);
				}
			}


			if (FlxG.keys.justPressed.BACKSPACE && FlxG.keys.pressed.CONTROL) {
				//if(onMasterEditor) {
					MusicBeatState.switchState(new editors.MasterEditorMenu());
					FlxG.sound.playMusic(Paths.music('freakyMenu'));
				//}
				FlxG.mouse.visible = false;
				return;
			}

			if(FlxG.keys.justPressed.Z && FlxG.keys.pressed.CONTROL) {
				undo();
			}			

			if(FlxG.keys.justPressed.Z && curZoom > 0 && !FlxG.keys.pressed.CONTROL) {
				--curZoom;
				updateZoom();
			}
			if(FlxG.keys.justPressed.X && curZoom < zoomList.length-1) {
				curZoom++;
				updateZoom();
			}

			if (FlxG.keys.justPressed.TAB)
			{
				if (FlxG.keys.pressed.SHIFT)
				{
					UI_box.selected_tab -= 1;
					if (UI_box.selected_tab < 0)
						UI_box.selected_tab = 2;
				}
				else
				{
					UI_box.selected_tab += 1;
					if (UI_box.selected_tab >= 3)
						UI_box.selected_tab = 0;
				}
			}

			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					if(vocals != null) vocals.pause();
				}
				else
				{
					if(vocals != null) {
						vocals.play();
						vocals.pause();
						vocals.time = FlxG.sound.music.time;
						vocals.play();
					}
					FlxG.sound.music.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				updateCurStep();

				if (!mouseQuant) {
					FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet*0.8);
				} else {
					var alignStrum:Bool = FlxG.keys.pressed.SHIFT;

					var time:Float = FlxG.sound.music.time;
					var snap:Float = 16 / quantization; // For convenience we assume the quantization stuff always assumes 4/4 time

					var dDecTime:Float;
					if (alignStrum) dDecTime = 0; // align to strum
					else { // align to section
						var dec:Float = curDecStep - (curStep - curSectionStep);
						dDecTime = CoolUtil.quantize(dec, snap) - dec;
					}

					if (FlxG.mouse.wheel > 0) {
						dDecTime -= snap;
					} else {
						dDecTime += snap;
					}
					var dtime:Float = dDecTime * Conductor.stepCrochet; // Convert dtime from steps to milliseconds
					time += dtime;

					if (vocals != null) {
						vocals.pause();
						vocals.time = time;
					}
				}

				if(vocals != null) {
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
			}

			//ARROW VORTEX SHIT NO DEADASS



			if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
			{
				FlxG.sound.music.pause();

				var holdingShift:Float = 1;
				if (FlxG.keys.pressed.CONTROL) holdingShift = 0.25;
				else if (FlxG.keys.pressed.SHIFT) holdingShift = 4;

				var daTime:Float = 700 * FlxG.elapsed * holdingShift;

				if (FlxG.keys.pressed.W)
				{
					FlxG.sound.music.time -= daTime;
				}
				else
					FlxG.sound.music.time += daTime;

				if(vocals != null) {
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
			}

			if (!vortex) {
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN  )
				{
					FlxG.sound.music.pause();
					updateCurStep();
					var alignStrum:Bool = FlxG.keys.pressed.SHIFT;

					var time:Float = FlxG.sound.music.time;
					var snap:Float = 16 / quantization; // For convenience we assume the quantization stuff always assumes 4/4 time

					var dDecTime:Float;
					if (alignStrum) dDecTime = 0; // align to strum
					else { // align to section
						var dec:Float = curDecStep - (curStep - curSectionStep);
						dDecTime = CoolUtil.quantize(dec, snap) - dec;
					}

					if (FlxG.keys.pressed.UP) {
						dDecTime -= snap;
					} else {
						dDecTime += snap;
					}
					var dtime:Float = dDecTime * Conductor.stepCrochet; // Convert dtime from steps to milliseconds
					time += dtime;
					FlxG.sound.music.time = time;
				}
			}

			var style = currentType;

			// What the fuck?
			// if (FlxG.keys.pressed.SHIFT){
			// 	style = 3;
			// }

			var conductorTime = Conductor.songPosition; //+ sectionStartTime();Conductor.songPosition / Conductor.stepCrochet;

			//AWW YOU MADE IT SEXY <3333 THX SHADMAR

			if(!blockInput){
				if(FlxG.keys.justPressed.RIGHT){
					curQuant++;
					if(curQuant>quantizations.length-1)
						curQuant = 0;

					quantization = quantizations[curQuant];
				}

				if(FlxG.keys.justPressed.LEFT){
					curQuant--;
					if(curQuant<0)
						curQuant = quantizations.length-1;

					quantization = quantizations[curQuant];
				}
				quant.animation.play('q', true, false, curQuant);
			}
			if(vortex && !blockInput){
				var controlArray:Array<Bool> = [FlxG.keys.justPressed.ONE, FlxG.keys.justPressed.TWO, FlxG.keys.justPressed.THREE, FlxG.keys.justPressed.FOUR,
											   FlxG.keys.justPressed.FIVE, FlxG.keys.justPressed.SIX, FlxG.keys.justPressed.SEVEN, FlxG.keys.justPressed.EIGHT];

				if(controlArray.contains(true))
				{
					for (i in 0...controlArray.length)
					{
						if(controlArray[i])
							doANoteThing(conductorTime, i, style);
					}
				}

				var feces:Float;
				if (FlxG.keys.justPressed.UP || FlxG.keys.justPressed.DOWN)
				{
					FlxG.sound.music.pause();


					updateCurStep();
					
					//FlxG.sound.music.time = (Math.round(curStep/quants[curQuant])*quants[curQuant]) * Conductor.stepCrochet;
					var alignStrum:Bool = FlxG.keys.pressed.SHIFT;

					var time:Float = FlxG.sound.music.time;
					var snap:Float = 16 / quantization; // For convenience we assume the quantization stuff always assumes 4/4 time

					var dDecTime:Float;
					if (alignStrum) dDecTime = 0; // align to strum
					else { // align to section
						var dec:Float = curDecStep - (curStep - curSectionStep);
						dDecTime = CoolUtil.quantize(dec, snap) - dec;
					}

					if (FlxG.keys.pressed.UP) {
						dDecTime -= snap;
					} else {
						dDecTime += snap;
					}
					var dtime:Float = dDecTime * Conductor.stepCrochet; // Convert dtime from steps to milliseconds
					time += dtime;

					FlxTween.tween(FlxG.sound.music, {time:time}, 0.1, {ease:FlxEase.circOut});
					if (vocals != null) {
						vocals.pause();
						vocals.time = time;
					}

					// I'm guessing this code makes dragging notes sustain possible?
					if (curSelectedNote != null)
					{
						var controlArray:Array<Bool> = [FlxG.keys.pressed.ONE, FlxG.keys.pressed.TWO, FlxG.keys.pressed.THREE, FlxG.keys.pressed.FOUR,
													   FlxG.keys.pressed.FIVE, FlxG.keys.pressed.SIX, FlxG.keys.pressed.SEVEN, FlxG.keys.pressed.EIGHT];

						if (controlArray.contains(true) && 0 <= curSelectedNote[1] && curSelectedNote[1] < controlArray.length &&
							controlArray[curSelectedNote[1]]) {
							curSelectedNote[2] = Math.max(0, curSelectedNote[2] + dtime);
							updateGrid();
							updateNoteUI();
						}
					}
				}
			}
			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftThing = 4;

			if (FlxG.keys.justPressed.D)
				changeSection(curSection + shiftThing);
			if (FlxG.keys.justPressed.A) {
				if(curSection <= 0) {
					changeSection(songData.notes.length-1);
				} else {
					changeSection(curSection - shiftThing);
				}
			}
		} else if (FlxG.keys.justPressed.ENTER) {
			for (i in 0...blockPressWhileTypingOn.length) {
				if (blockPressWhileTypingOn[i].hasFocus) {
					blockPressWhileTypingOn[i].hasFocus = false;
				}
			}
		}

		songData.bpm = tempBpm;

		strumLineNotes.visible = quant.visible = vortex;

		if(FlxG.sound.music.time < 0) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
		}
		else if(FlxG.sound.music.time > FlxG.sound.music.length) {
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		}
		Conductor.songPosition = FlxG.sound.music.time;

		strumLineUpdateY();
		camPos.y = strumLine.y;
		for (i in 0...8){
			strumLineNotes.members[i].y = strumLine.y;
			strumLineNotes.members[i].alpha = FlxG.sound.music.playing ? 1 : 0.35;
		}

		songData.song = UI_songTitle.text;

		bpmTxt.text = 
		Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2)) + " / " + Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2)) +
		"\nSection: " + curSection +
		"\n\nBeat: " + Std.string(curDecBeat).substring(0,4) +
		"\n\nStep: " + curStep +
		"\n\nBeat Snap: " + quantization + "th";

		var playedSound:Array<Bool> = [for (_ in 0...Note.TOTAL) false]; //Prevents ouchy GF sex sounds
		curRenderedNotes.forEachAlive(function(note:Note) {
			note.alpha = 1;
			if(curSelectedNote != null) {
				var noteDataToCheck:Int = note.noteData;
				if(noteDataToCheck > -1 && note.mustPress != songData.notes[curSection].mustHitSection) noteDataToCheck += Note.TOTAL;

				if (curSelectedNote[0] == note.strumTime && ((curSelectedNote[2] == null && noteDataToCheck < 0) || (curSelectedNote[2] != null && curSelectedNote[1] == noteDataToCheck)))
				{
					colorSine += elapsed;
					var colorVal:Float = 0.7 + Math.sin(Math.PI * colorSine) * 0.3;
					note.color = FlxColor.fromRGBFloat(colorVal, colorVal, colorVal, 0.999); //Alpha can't be 100% or the color won't be updated for some reason, guess i will die
				}
			}

			if(note.strumTime <= Conductor.songPosition) {
				note.alpha = 0.4;
				if(note.strumTime > lastConductorPos && FlxG.sound.music.playing && note.noteData > -1) {
					var data:Int = note.noteData % Note.TOTAL;
					var noteDataToCheck:Int = note.noteData;
					if(noteDataToCheck > -1 && note.mustPress != songData.notes[curSection].mustHitSection) noteDataToCheck += Note.TOTAL;
						strumLineNotes.members[noteDataToCheck].playAnim('confirm', true);
						strumLineNotes.members[noteDataToCheck].resetAnim = (note.sustainLength / 1000) + 0.15;
					if(!playedSound[data]) {
						if((playSoundBf.checked && note.mustPress) || (playSoundDad.checked && !note.mustPress)){
							var soundToPlay = 'hitsound';
							if(songData.player1 == 'gf') { //Easter egg
								soundToPlay = 'GF_' + Std.string((data % 4) + 1);
							}

							FlxG.sound.play(Paths.sound(soundToPlay)).pan = note.noteData < Note.TOTAL ? -0.6 : 0.6; //would be coolio
							playedSound[data] = true;
						}

						data = note.noteData;
						if(note.mustPress != songData.notes[curSection].mustHitSection)
						{
							data += Note.TOTAL;
						}
						// What's the use of this code? ^
					}
				}
			}
		});

		if(metronome.checked && lastConductorPos != Conductor.songPosition) {
			var metroInterval:Float = 60 / metronomeStepper.value;
			var metroStep:Int = Math.floor(((Conductor.songPosition + metronomeOffsetStepper.value) / metroInterval) / 1000);
			var lastMetroStep:Int = Math.floor(((lastConductorPos + metronomeOffsetStepper.value) / metroInterval) / 1000);
			if(metroStep != lastMetroStep) {
				FlxG.sound.play(Paths.sound('Metronome_Tick'));
				//trace('Ticked');
			}
		}
		lastConductorPos = Conductor.songPosition;

		super.update(elapsed);
	}

	function updateZoom() {
		var daZoom:Float = zoomList[curZoom];
		var zoomThing:String = '1 / ' + daZoom;
		if(daZoom < 1) zoomThing = Math.round(1 / daZoom) + ' / 1';
		zoomTxt.text = 'Zoom: ' + zoomThing;
		reloadGridLayer();
	}

	/*
	function loadAudioBuffer() {
		if(audioBuffers[0] != null) {
			audioBuffers[0].dispose();
		}
		audioBuffers[0] = null;
		#if MODS_ALLOWED
		if(Paths.exists(Paths.modFolders('songs/' + curSongFile + '/Inst.ogg'))) {
			audioBuffers[0] = AudioBuffer.fromFile(Paths.modFolders('songs/' + curSongFile + '/Inst.ogg'));
			//trace('Custom vocals found');
		}
		else { #end
			var leVocals:String = Paths.getPath(curSongFile + '/Inst.' + Paths.SOUND_EXT, SOUND, 'songs');
			if (Paths.exists(leVocals)) { //Vanilla inst
				audioBuffers[0] = AudioBuffer.fromFile('./' + leVocals.substr(6));
				//trace('Inst found');
			}
		#if MODS_ALLOWED
		}
		#end

		if(audioBuffers[1] != null) {
			audioBuffers[1].dispose();
		}
		audioBuffers[1] = null;
		#if MODS_ALLOWED
		if(Paths.exists(Paths.modFolders('songs/' + curSongFile + '/Voices.ogg'))) {
			audioBuffers[1] = AudioBuffer.fromFile(Paths.modFolders('songs/' + curSongFile + '/Voices.ogg'));
			//trace('Custom vocals found');
		} else { #end
			var leVocals:String = Paths.getPath(curSongFile + '/Voices.' + Paths.SOUND_EXT, SOUND, 'songs');
			if (Paths.exists(leVocals)) { //Vanilla voices
				audioBuffers[1] = AudioBuffer.fromFile('./' + leVocals.substr(6));
				//trace('Voices found, LETS FUCKING GOOOO');
			}
		#if MODS_ALLOWED
		}
		#end
	}
	*/

	function reloadGridLayer() {
		prevLengthInSteps = sectionLengthInSteps();
		prevNextLengthInSteps = sectionLengthInSteps(1);

		gridLayer.clear();
		gridHeight = GRID_SIZE * (prevLengthInSteps + prevNextLengthInSteps) * zoomList[curZoom];
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * GRID_COLS(), Std.int(gridHeight));
		gridLayer.add(gridBG);
		// gridFakeBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * GRID_COLS());
		// gridLayer.add(gridFakeBG);

		#if desktop
		if(FlxG.save.data.chart_waveformInst || FlxG.save.data.chart_waveformVoices) {
			updateWaveform();
		}
		#end

		// Next Section Mask
		var blackY:Int = Std.int(GRID_SIZE * prevLengthInSteps * zoomList[curZoom]);

		gridBlack = new FlxSprite(0, blackY).makeGraphic(Std.int(GRID_SIZE * GRID_COLS()), Std.int(gridHeight - blackY), FlxColor.BLACK);
		gridBlack.alpha = 0.4;
		gridLayer.add(gridBlack);

		// Event and Player Note separators
		var gridBlackLine:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE * (1 + Note.TOTAL) - 1)
			.makeGraphic(2, Std.int(gridHeight), FlxColor.BLACK);
		gridLayer.add(gridBlackLine);

		gridBlackLine = new FlxSprite(gridBG.x + GRID_SIZE - 1).makeGraphic(2, Std.int(gridHeight), FlxColor.BLACK);
		gridLayer.add(gridBlackLine);

		// Beat separator lines 
		final rPerSep = Conductor.stepsPerBeat;
		if (vortex) for (i in 1...Math.ceil(sectionLengthInSteps() / rPerSep)) {
			var beatsep1:FlxSprite = new FlxSprite(gridBG.x, GRID_SIZE * (rPerSep * zoomList[curZoom] * i) - 0.5)
				.makeGraphic(Std.int(gridBG.width), 1, 0x44FF0000);
			gridLayer.add(beatsep1);
		}

		// Column separators (for high EKs)
		final cPerSep = 4;
		for (i in 1...Math.ceil(Note.TOTAL / cPerSep)) {
			var notesep1:FlxSprite = new FlxSprite(gridBG.x + GRID_SIZE * (1 + cPerSep * i) - 0.5)
				.makeGraphic(1, Std.int(gridHeight), 0x44000000);
			gridLayer.add(notesep1);
			var notesep2:FlxSprite = new FlxSprite(notesep1.x + GRID_SIZE * Note.TOTAL)
				.makeGraphic(1, Std.int(gridHeight), 0x44000000);
			gridLayer.add(notesep2);
		}

		updateGrid();
	}

	function strumLineUpdateY()
	{
		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()));
	}

	var waveformPrinted:Bool = true;
	var wavData:Array<Array<Array<Float>>> = [[[0], [0]], [[0], [0]]];
	function updateWaveform() {
		#if desktop
		if(waveformPrinted) {
			waveformSprite.makeGraphic(Std.int(GRID_SIZE * Note.TOTAL * 2), Std.int(gridHeight), 0x00FFFFFF);
			waveformSprite.pixels.fillRect(new Rectangle(0, 0, gridBG.width, gridHeight), 0x00FFFFFF);
		}
		waveformPrinted = false;

		if(!FlxG.save.data.chart_waveformInst && !FlxG.save.data.chart_waveformVoices) {
			//trace('Epic fail on the waveform lol');
			return;
		}

		wavData[0][0] = [];
		wavData[0][1] = [];
		wavData[1][0] = [];
		wavData[1][1] = [];

		var steps:Int = sectionLengthInSteps() + sectionLengthInSteps(1);

		var st:Float = sectionStartTime();
		var et:Float = st + (Conductor.stepCrochet * steps);

		if (FlxG.save.data.chart_waveformInst) {
			var sound:FlxSound = FlxG.sound.music;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();

				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					Std.int(gridBG.height)
				);
			}
		}

		if (FlxG.save.data.chart_waveformVoices) {
			var sound:FlxSound = vocals;
			if (sound._sound != null && sound._sound.__buffer != null) {
				var bytes:Bytes = sound._sound.__buffer.data.toBytes();

				wavData = waveformData(
					sound._sound.__buffer,
					bytes,
					st,
					et,
					1,
					wavData,
					Std.int(gridBG.height)
				);
			}
		}

		// Draws
		var gSize:Int = Std.int(GRID_SIZE * Note.TOTAL * 2);
		var hSize:Int = Std.int(gSize / 2);

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var size:Float = 1;

		var leftLength:Int = (
			wavData[0][0].length > wavData[0][1].length ? wavData[0][0].length : wavData[0][1].length
		);

		var rightLength:Int = (
			wavData[1][0].length > wavData[1][1].length ? wavData[1][0].length : wavData[1][1].length
		);

		var length:Int = leftLength > rightLength ? leftLength : rightLength;

		var index:Int;
		for (i in 0...length) {
			index = i;

			lmin = FlxMath.bound(((index < wavData[0][0].length && index >= 0) ? wavData[0][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			lmax = FlxMath.bound(((index < wavData[0][1].length && index >= 0) ? wavData[0][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			rmin = FlxMath.bound(((index < wavData[1][0].length && index >= 0) ? wavData[1][0][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;
			rmax = FlxMath.bound(((index < wavData[1][1].length && index >= 0) ? wavData[1][1][index] : 0) * (gSize / 1.12), -hSize, hSize) / 2;

			waveformSprite.pixels.fillRect(new Rectangle(hSize - (lmin + rmin), i * size, (lmin + rmin) + (lmax + rmax), size), FlxColor.BLUE);
		}

		waveformPrinted = true;
		#end
	}

	function waveformData(buffer:AudioBuffer, bytes:Bytes, time:Float, endTime:Float, multiply:Float = 1, ?array:Array<Array<Array<Float>>>, ?steps:Float):Array<Array<Array<Float>>>
	{
		#if (lime_cffi && !macro)
		if (buffer == null || buffer.data == null) return [[[0], [0]], [[0], [0]]];

		var khz:Float = (buffer.sampleRate / 1000);
		var channels:Int = buffer.channels;

		var index:Int = Std.int(time * khz);

		var samples:Float = ((endTime - time) * khz);

		if (steps == null) steps = 1280;

		var samplesPerRow:Float = samples / steps;
		var samplesPerRowI:Int = Std.int(samplesPerRow);

		var gotIndex:Int = 0;

		var lmin:Float = 0;
		var lmax:Float = 0;

		var rmin:Float = 0;
		var rmax:Float = 0;

		var rows:Float = 0;

		var simpleSample:Bool = false;//samples > 17200;
		var v1:Bool = false;

		if (array == null) array = [[[0], [0]], [[0], [0]]];

		while (index < (bytes.length - 1)) {
			if (index >= 0) {
				var byte:Int = bytes.getUInt16(index * channels * 2);

				if (byte > 65535 / 2) byte -= 65535;

				var sample:Float = (byte / 65535);

				if (sample > 0) {
					if (sample > lmax) lmax = sample;
				} else if (sample < 0) {
					if (sample < lmin) lmin = sample;
				}

				if (channels >= 2) {
					byte = bytes.getUInt16((index * channels * 2) + 2);

					if (byte > 65535 / 2) byte -= 65535;

					sample = (byte / 65535);

					if (sample > 0) {
						if (sample > rmax) rmax = sample;
					} else if (sample < 0) {
						if (sample < rmin) rmin = sample;
					}
				}
			}

			while (simpleSample ? samplesPerRowI > 0 && (index % samplesPerRowI == 0) : rows >= samplesPerRow) {
				rows -= samplesPerRow;

				gotIndex++;

				var lRMin:Float = Math.abs(lmin) * multiply;
				var lRMax:Float = lmax * multiply;

				var rRMin:Float = Math.abs(rmin) * multiply;
				var rRMax:Float = rmax * multiply;

				if (gotIndex > array[0][0].length) array[0][0].push(lRMin);
					else array[0][0][gotIndex - 1] = array[0][0][gotIndex - 1] + lRMin;

				if (gotIndex > array[0][1].length) array[0][1].push(lRMax);
					else array[0][1][gotIndex - 1] = array[0][1][gotIndex - 1] + lRMax;

				if (channels >= 2) {
					if (gotIndex > array[1][0].length) array[1][0].push(rRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + rRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(rRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + rRMax;
				}
				else {
					if (gotIndex > array[1][0].length) array[1][0].push(lRMin);
						else array[1][0][gotIndex - 1] = array[1][0][gotIndex - 1] + lRMin;

					if (gotIndex > array[1][1].length) array[1][1].push(lRMax);
						else array[1][1][gotIndex - 1] = array[1][1][gotIndex - 1] + lRMax;
				}

				lmin = 0;
				lmax = 0;

				rmin = 0;
				rmax = 0;
			}

			index++;
			rows++;
			if(gotIndex > steps) break;
		}

		return array;
		#else
		return [[[0], [0]], [[0], [0]]];
		#end
	}

	function changeNoteSustain(dvalue:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += dvalue;
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	override function updateCurStep()
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		var shit:Float = (FlxG.sound.music.time - lastChange.songTime + FlxMath.EPSILON) / Conductor.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
	}

	function recalculateSteps(add:Float = 0):Int
	{
		var oldStep:Int = curStep;

		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		var shit:Float = (FlxG.sound.music.time - lastChange.songTime + FlxMath.EPSILON) / Conductor.stepCrochet;
		curDecStep = lastChange.stepTime + shit;
		curStep = lastChange.stepTime + Math.floor(shit);
		if (oldStep != curStep) recalculateBeat(oldStep);
		updateDecimals();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();
		Conductor.songPosition = FlxG.sound.music.time;

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
		}

		if(vocals != null) {
			vocals.pause();
			vocals.time = FlxG.sound.music.time;
		}
		// updateCurStep();

		updateGrid();
		updateSectionUI();
		updateWaveform();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		if (songData.notes[sec] != null)
		{
			curSection = sec;

			if (updateMusic)
			{
				FlxG.sound.music.pause();

				FlxG.sound.music.time = Song.songSectionStartTime(songData, sec);
				Conductor.songPosition = FlxG.sound.music.time;
				if(vocals != null) {
					vocals.pause();
					vocals.time = FlxG.sound.music.time;
				}
				// updateCurStep();
			}

			if (sectionLengthInSteps() != prevLengthInSteps || sectionLengthInSteps(1) != prevNextLengthInSteps)
				reloadGridLayer();
			else updateGrid();
			updateSectionUI();
		}
		else
		{
			changeSection();
		}
		updateWaveform();
	}

	function updateSectionUI():Void
	{
		var sec = songData.notes[curSection];

		stepperLength.value = sectionLengthInSteps();
		check_mustHitSection.checked = sec.mustHitSection;
		check_gfSection.checked = sec.gfSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;

		// Not section UI but section-dependent
		stepperSusLength.max = Conductor.stepCrochet * sec.lengthInSteps * 2;
		stepperSusLength.stepSize = Conductor.stepCrochet / 2;

		updateHeads();
	}

	function updateHeads():Void
	{
		var healthIconP1:String = loadHealthIconFromCharacter(songData.player1);
		var healthIconP2:String = loadHealthIconFromCharacter(songData.player2);

		if (songData.notes[curSection].mustHitSection)
		{
			leftIcon.changeIcon(healthIconP1);
			rightIcon.changeIcon(healthIconP2);
			if (songData.notes[curSection].gfSection) leftIcon.changeIcon('gf');
		}
		else
		{
			leftIcon.changeIcon(healthIconP2);
			rightIcon.changeIcon(healthIconP1);
			if (songData.notes[curSection].gfSection) leftIcon.changeIcon('gf');
		}
	}

	function loadHealthIconFromCharacter(char:String) {
		var characterPath:String = 'characters/' + char + '.json';
		#if MODS_ALLOWED
		var path:String = Paths.modFolders(characterPath);
		if (!Paths.exists(path)) {
			path = Paths.getPreloadPath(characterPath);
		}

		if (!Paths.exists(path))
		#else
		var path:String = Paths.getPreloadPath(characterPath);
		if (!Paths.exists(path))
		#end
		{
			path = Paths.getPreloadPath('characters/' + Character.DEFAULT_CHARACTER + '.json'); //If a character couldn't be found, change him to BF just to prevent a crash
		}

		var rawJson = Paths.getText(path);

		var json:Character.CharacterFile = cast Json.parse(rawJson);
		return json.healthicon;
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null) {
			if(curSelectedNote.length >= 3) {
				stepperSusLength.value = curSelectedNote[2];
				noteTypeInputText.text = '';

				var selectedNoteType:Null<Int> = null;
				if (curSelectedNote.length >= 4) {
					if (curSelectedNote[3].charAt(0) != '.') selectedNoteType = noteTypeMap.get(curSelectedNote[3]); // get with null key is UB?
					else noteTypeInputText.text = curSelectedNote[3].substr(1);
				}
				if (selectedNoteType == null || selectedNoteType <= 0) {
					noteTypeDropDown.selectedLabel = '';
				} else {
					noteTypeDropDown.selectedLabel = selectedNoteType + '. ' + curSelectedNote[3];
				}
			} else {
				eventDropDown.selectedLabel = curSelectedNote[1][curEventSelected][0];
				var selected:Int = Std.parseInt(eventDropDown.selectedId);
				if(selected > 0 && selected < eventStuff.length) {
					descText.text = eventStuff[selected][1];
				}
				value1InputText.text = curSelectedNote[1][curEventSelected][1];
				value2InputText.text = curSelectedNote[1][curEventSelected][2];
			}
			strumTimeInputText.text = '' + curSelectedNote[0];
		}
	}

	function updateGrid():Void
	{
		// trace('updateGrid called for $curSection');
		curRenderedNotes.clear();
		curRenderedSustains.clear();
		curRenderedNoteType.clear();
		nextRenderedNotes.clear();
		nextRenderedSustains.clear();

		if (songData.notes[curSection].changeBPM && songData.notes[curSection].bpm > 0)
		{
			Conductor.changeBPM(songData.notes[curSection].bpm);
			//trace('BPM of this section:');
		}
		else
		{
			// get last bpm
			var daBPM:Float = songData.bpm;
			for (i in 0...curSection)
				if (songData.notes[i].changeBPM)
					daBPM = songData.notes[i].bpm;
			Conductor.changeBPM(daBPM);
		}

		// CURRENT SECTION
		for (i in songData.notes[curSection].sectionNotes)
		{
			var note:Note = setupNoteData(i, false);
			curRenderedNotes.add(note);
			if (note.sustainLength > 0)
			{
				curRenderedSustains.add(setupSusNote(note));
			}

			if(i[3] != null && note.noteType != null && note.noteType.length > 0) {
				var theType:String = '';

				if (i[3].charAt(0) == '.') theType = 'x';
				else {
					var typeInt:Null<Int> = noteTypeMap.get(i[3]);
					if (typeInt != null) theType = '' + typeInt;
					else theType = '?';
				}

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, MAX_GRID_SIZE - 2, theType, 24);
				daText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
				var swagScale = GRID_SIZE / MAX_GRID_SIZE;
				daText.scale.x = daText.scale.y = swagScale;
				daText.updateHitbox();
				// daText.xAdd = -32 * swagScale;
				daText.yAdd = 6 * swagScale;
				daText.borderSize = 1;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
			}
			note.mustPress = songData.notes[curSection].mustHitSection;
			if(i[1] >= Note.TOTAL) note.mustPress = !note.mustPress;
		}

		// CURRENT EVENTS
		var startThing:Float = sectionStartTime();
		var endThing:Float = sectionStartTime(1);
		for (i in songData.events)
		{
			if(endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, false);
				curRenderedNotes.add(note);

				var text:String = 'Event: ' + note.eventName + ' (' + Math.floor(note.strumTime) + ' ms)' + '\nValue 1: ' + note.eventVal1 + '\nValue 2: ' + note.eventVal2;
				if(note.eventLength > 1) text = note.eventLength + ' Events:\n' + note.eventName;

				var daText:AttachedFlxText = new AttachedFlxText(0, 0, 400, text, 12);
				daText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.WHITE, RIGHT, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
				daText.xAdd = -410;
				daText.borderSize = 1;
				if(note.eventLength > 1) daText.yAdd += 8;
				curRenderedNoteType.add(daText);
				daText.sprTracker = note;
				//trace('test: ' + i[0], 'startThing: ' + startThing, 'endThing: ' + endThing);
			}
		}

		// NEXT SECTION
		if(curSection < songData.notes.length-1) {
			for (i in songData.notes[curSection+1].sectionNotes)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
				if (note.sustainLength > 0)
				{
					nextRenderedSustains.add(setupSusNote(note));
				}
			}
		}

		// NEXT EVENTS
		var startThing:Float = sectionStartTime(1);
		var endThing:Float = sectionStartTime(2);
		for (i in songData.events)
		{
			if(endThing > i[0] && i[0] >= startThing)
			{
				var note:Note = setupNoteData(i, true);
				note.alpha = 0.6;
				nextRenderedNotes.add(note);
			}
		}
	}

	function setupNoteData(i:Array<Dynamic>, isNextSection:Bool):Note
	{
		var daNoteInfo = i[1];
		var daStrumTime = i[0];
		var daSus:Null<Int> = i[2];
		var daType:String = '';
		if (daSus != null) { // Common Note
			if (Std.isOfType(i[3], String)) daType = i[3];
			else if (Std.isOfType(i[3], Int)) { //Convert old note type to new note type format
				daType = noteTypeIntMap.get(i[3]);
			}
		}

		var note:Note = new Note(daStrumTime, daNoteInfo % Note.TOTAL, null, null, true, daType);
		if(daSus != null) { //Common note
			note.sustainLength = daSus;
			note.noteType = daType;
		} else { //Event note
			note.loadGraphic(Paths.image('eventArrow'));
			note.eventName = getEventName(i[1]);
			note.eventLength = i[1].length;
			if(i[1].length < 2)
			{
				note.eventVal1 = i[1][0][1];
				note.eventVal2 = i[1][0][2];
			}
			note.noteData = -1;
			daNoteInfo = -1;
		}

		note.setGraphicSize(GRID_SIZE, GRID_SIZE);
		note.updateHitbox();
		note.x = Math.floor(daNoteInfo * GRID_SIZE) + GRID_SIZE;
		if(isNextSection && songData.notes[curSection].mustHitSection != songData.notes[curSection+1].mustHitSection) {
			if(daNoteInfo >= Note.TOTAL) {
				note.x -= GRID_SIZE * Note.TOTAL;
			} else if(daSus != null) {
				note.x += GRID_SIZE * Note.TOTAL;
			}
		}

		note.y = getYfromStrumNotes(daStrumTime - sectionStartTime());
		//if(isNextSection) note.y += gridBG.height;
		if(note.y < -150) note.y = -150;
		return note;
	}

	function getEventName(names:Array<Dynamic>):String
	{
		var retStr:String = '';
		var addedOne:Bool = false;
		for (i in 0...names.length)
		{
			if(addedOne) retStr += ', ';
			retStr += names[i][0];
			addedOne = true;
		}
		return retStr;
	}

	function setupSusNote(note:Note):FlxSprite {
		var height:Int = Math.floor(FlxMath.remapToRange(note.sustainLength, 0, Conductor.stepCrochet, 0, GRID_SIZE * zoomList[curZoom]) + (GRID_SIZE * zoomList[curZoom]) - GRID_SIZE / 2);
		var minHeight:Int = Std.int((GRID_SIZE * zoomList[curZoom] / 2) + GRID_SIZE / 2);
		if(height < minHeight) height = minHeight;
		if(height < 1) height = 1; //Prevents error of invalid height

		var thickness:Int = Std.int(Math.max(1, GRID_SIZE / 10));
		var spr:FlxSprite = new FlxSprite(note.x + (GRID_SIZE * 0.5) - thickness / 2, note.y + GRID_SIZE / 2).makeGraphic(thickness, height);
		return spr;
	}

	private function addSection(?lengthInSteps:Null<Int>):Void
	{
		if (lengthInSteps == null) lengthInSteps = prevLengthInSteps;
		var sec:SwagSection = Section.FALLBACK;
		sec.lengthInSteps = lengthInSteps;
		sec.bpm = songData.bpm;

		songData.notes.push(sec);

		// Update those outro parameters
		outroSection += 1;
		outroSectionLength = lengthInSteps;
		outroStep += outroSectionLength;
		outroBeatsPerSection = Math.ceil(lengthInSteps / Conductor.stepsPerBeat);
		outroBeat += outroBeatsPerSection;
	}

	function selectNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;

		if(noteDataToCheck > -1)
		{
			if(note.mustPress != songData.notes[curSection].mustHitSection) noteDataToCheck += Note.TOTAL;
			for (i in songData.notes[curSection].sectionNotes)
			{
				if (i != curSelectedNote && i.length > 2 && i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					curSelectedNote = i;
					break;
				}
			}
		}
		else
		{
			for (i in songData.events)
			{
				if(i != curSelectedNote && i[0] == note.strumTime)
				{
					curSelectedNote = i;
					curEventSelected = Std.int(curSelectedNote[1].length) - 1;
					changeEventSelected();
					break;
				}
			}
		}

		updateGrid();
		updateNoteUI();
	}

	function deleteNote(note:Note):Void
	{
		var noteDataToCheck:Int = note.noteData;
		if(noteDataToCheck > -1 && note.mustPress != songData.notes[curSection].mustHitSection) noteDataToCheck += Note.TOTAL;

		didAThing = true;
		if(note.noteData > -1) //Normal Notes
		{
			for (i in songData.notes[curSection].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] == noteDataToCheck)
				{
					if(i == curSelectedNote) curSelectedNote = null;
					//FlxG.log.add('FOUND EVIL NOTE');
					songData.notes[curSection].sectionNotes.remove(i);
					break;
				}
			}
		}
		else //Events
		{
			for (i in songData.events)
			{
				if(i[0] == note.strumTime)
				{
					if(i == curSelectedNote)
					{
						curSelectedNote = null;
						changeEventSelected();
					}
					//FlxG.log.add('FOUND EVIL EVENT');
					songData.events.remove(i);
					break;
				}
			}
		}

		updateGrid();
	}

	public function doANoteThing(cs, d, style){
		var delnote = false;
		if(strumLineNotes.members[d].overlaps(curRenderedNotes))
		{
			curRenderedNotes.forEachAlive(function(note:Note)
			{
				if (note.overlapsPoint(new FlxPoint(strumLineNotes.members[d].x + 1,strumLine.y+1)) && note.noteData == d % Note.TOTAL)
				{
						//trace('tryin to delete note...');
						if(!delnote) deleteNote(note);
						delnote = true;
				}
			});
		}

		if (!delnote){
			addNote(cs, d, style);
		}
	}
	function clearSong():Void
	{
		for (daSection in 0...songData.notes.length)
		{
			songData.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote(strum:Null<Float> = null, data:Null<Int> = null, type:Null<Int> = null):Void
	{
		//curUndoIndex++;
		//var newsong = songData.notes;
		// undos.push(newsong);
		didAThing = true;
		var noteStrum = getStrumTime(dummyArrow.y) + sectionStartTime();
		var noteData = Math.floor((FlxG.mouse.x - GRID_SIZE) / GRID_SIZE);
		var noteSus = 0;
		var daType = currentType;

		if (strum != null) noteStrum = strum;
		if (data != null) noteData = data;
		if (type != null) daType = type;

		if(noteData > -1) {
			songData.notes[curSection].sectionNotes.push([noteStrum, noteData, noteSus, noteTypeIntMap.get(daType)]);
			curSelectedNote = songData.notes[curSection].sectionNotes[songData.notes[curSection].sectionNotes.length - 1];
		} else {
			var event = eventStuff[Std.parseInt(eventDropDown.selectedId)][0];
			var text1 = value1InputText.text;
			var text2 = value2InputText.text;
			songData.events.push([noteStrum, [[event, text1, text2]]]);
			curSelectedNote = songData.events[songData.events.length - 1];
			curEventSelected = 0;
			changeEventSelected();
		}

		if (FlxG.keys.pressed.CONTROL && noteData > -1)
		{
			songData.notes[curSection].sectionNotes.push([noteStrum, (noteData + Note.TOTAL) % (Note.TOTAL * 2), noteSus, noteTypeIntMap.get(daType)]);
		}

		//trace(noteData + ', ' + noteStrum + ', ' + curSection);
		strumTimeInputText.text = '' + curSelectedNote[0];

		updateGrid();
		updateNoteUI();
	}
	// will figure this out l8r
	function redo(){
		//songData = redos[curRedoIndex];
	}
	function undo(){
		//redos.push(songData);
		undos.pop();
		//songData.notes = undos[undos.length - 1];
		///trace(songData.notes);
		//updateGrid();
	}
	function getStrumTime(yPos:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + GRID_SIZE * leZoom, 0, Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float, doZoomCalc:Bool = true):Float
	{
		var leZoom:Float = zoomList[curZoom];
		if(!doZoomCalc) leZoom = 1;
		return FlxMath.remapToRange(strumTime, 0, Conductor.stepCrochet, gridBG.y, gridBG.y + GRID_SIZE * leZoom);
	}
	
	function getYfromStrumNotes(strumTime:Float):Float
	{
		var value:Float = strumTime / Conductor.stepCrochet;
		return GRID_SIZE * zoomList[curZoom] * value + gridBG.y;
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in songData.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function loadJson(song:String, suffix:String):Void
	{
		songData = Song.loadFromJson(song + suffix, song);
		Note.updateScheme(songData.keyScheme);

		MusicBeatState.resetState();
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": songData
		});
		FlxG.save.flush();
	}

	function clearEvents() {
		songData.events = [];
		updateGrid();
	}

	private function saveLevel()
	{
		if (songData.events != null) songData.events.sort(sortByTime);
		var json = {
			"song": songData
		};

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), curSong + ".json");
		}
	}

	function sortByTime(Obj1:Array<Dynamic>, Obj2:Array<Dynamic>):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, Obj1[0], Obj2[0]);
	}

	private function saveEvents()
	{
		if (songData.events != null) songData.events.sort(sortByTime);
		var eventsSong:Dynamic = {
			events: songData.events
		};
		var json = {
			"song": eventsSong
		}

		var data:String = Json.stringify(json, "\t");

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), "events.json");
		}
	}

	function onSaveComplete(_):Void
	{
		didAThing = true;
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}
}

class AttachedFlxText extends FlxText
{
	public var sprTracker:FlxSprite;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;

	public function new(X:Float = 0, Y:Float = 0, FieldWidth:Float = 0, ?Text:String, Size:Int = 8, EmbeddedFont:Bool = true) {
		super(X, Y, FieldWidth, Text, Size, EmbeddedFont);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null) {
			setPosition(sprTracker.x + xAdd, sprTracker.y + yAdd);
			angle = sprTracker.angle;
			alpha = sprTracker.alpha;
		}
	}
}
