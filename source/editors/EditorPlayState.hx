package editors;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import SongPlayState;

class EditorPlayState extends SongPlayState
{
	// Song State
	var startOffset:Float = Conductor.crochet;
	var startPos:Float = 0;
	var timerToStart:Float = 0;

	// UI
	var scoreTxt:FlxText;
	var stepTxt:FlxText;
	var ratingTxt:FlxText;	

	// Overrides
	override public function new(startPos:Float)
	{
		this.startPos = startPos;
		super();
	}

	override private function initPlayState()
	{
		super.initPlayState();

		Conductor.songPosition = startPos - startOffset;
		timerToStart = startOffset;

		skipArrowStartTween = true;
		cpuControlled = false;
	}

	override private function finalizePlayState()
	{
		clearNotesBefore(startPos);

		super.finalizePlayState();
	}

	override private function setupStage()
	{
		super.setupStage();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.scrollFactor.set();
		bg.color = FlxColor.fromHSB(FlxG.random.int(0, 359), FlxG.random.float(0, 0.8), FlxG.random.float(0.3, 1));
		add(bg);
	}

	override private function setupHUD()
	{
		super.setupHUD();

		FlxG.mouse.visible = false;

		scoreTxt = new FlxText(0, FlxG.height - 70, FlxG.width, "Hits: 0 | Misses: 0", 20);
		scoreTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scoreTxt.scrollFactor.set();
		scoreTxt.borderSize = 1.25;
		scoreTxt.visible = !ClientPrefs.hideHud;
		scoreTxt.cameras = [camHUD];
		add(scoreTxt);
		if(ClientPrefs.downScroll) scoreTxt.y = 10;
		
		stepTxt = new FlxText(10, scoreTxt.y + 30, FlxG.width, "Section: 0 | Beat: 0 | Step: 0", 20);
		stepTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		stepTxt.scrollFactor.set();
		stepTxt.borderSize = 1.25;
		stepTxt.cameras = [camHUD];
		add(stepTxt);

		ratingTxt = new FlxText(10, scoreTxt.y + 60, FlxG.width, "Health: 0 | Rating: ?", 20);
		ratingTxt.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		ratingTxt.scrollFactor.set();
		ratingTxt.borderSize = 1.25;
		ratingTxt.cameras = [camHUD];
		add(ratingTxt);

		var tipText:FlxText = new FlxText(10, FlxG.height - 24, 0, 'Press ESC to Go Back to Chart Editor', 16);
		tipText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tipText.borderSize = 2;
		tipText.scrollFactor.set();
		tipText.cameras = [camHUD];
		add(tipText);
	}

	override private function updateTime(elapsed:Float)
	{
		if (startedSong) {
			Conductor.songPosition += elapsed * 1000;
		} else {
			timerToStart -= elapsed * 1000;
			Conductor.songPosition = startPos - timerToStart;
			if (timerToStart < 0) {
				startSong(startPos);
			}
		}
	}

	override private function checkInput()
	{
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.sound.music.pause();
			vocals.pause();
			
			_endSong();
		}

		if (responsive && generatedMusic) super.checkInput();	
	}

	override private function updateHUD(elapsed:Float)
	{
		scoreTxt.text = 'Hits: $hitCount | Misses: $missCount';
		stepTxt.text = 'Section: $curSection | Beat: $curBeat | Step: $curStep';
		ratingTxt.text = 'Health: ${Highscore.floorDecimal(health, 3)} | Rating: ${Highscore.floorDecimal(ratingPercent * 100, 2)}%';

		super.updateHUD(elapsed);
	}


	override private function _endSong():Void
	{
		LoadingState.loadAndSwitchState(new editors.ChartingState());
	}

	override private function _gameOver():Void { isDead = true; }
}