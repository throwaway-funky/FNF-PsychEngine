package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxTween;
import Note;
import helper.NoteLoader;

using StringTools;

class StrumNote extends FlxSprite
{
	private var colorSwap:ColorSwap;
	public var resetAnim:Float = 0;
	public var noteData(default, null):Int = 0;
	public var direction:Float = 90;
	public var downScroll:Bool = false;
	public var sustainReduce:Bool = true;
	public var hidePostStrum:Bool = false;

	public var showControl:Float = 0;
	public var hintThing:FlxSprite;

	private var player:Int;

	public var texture(default, set):String = null;
	private function set_texture(value:String):String {
		if (texture != value) {
			texture = value;
			reloadNote();
		}
		return value;
	}

	public function new(x:Float, y:Float, leData:Int, player:Int) {
		colorSwap = new ColorSwap();
		shader = colorSwap.shader;
		this.player = player;
		this.noteData = leData;
		super(x, y);

		var skin:String = 'NOTE_assets';
		if (Song.curPlaying.arrowSkin != null && Song.curPlaying.arrowSkin.length > 1) skin = Song.curPlaying.arrowSkin;
		texture = skin; //Load texture and anims

		scrollFactor.set();
	}

	public function reloadNote()
	{
		var lastAnim:String = null;
		if (animation.curAnim != null) lastAnim = animation.curAnim.name;

		if (SongPlayState.isPixelStage) {
			var column_n:Int = 4;

			// new() part in Note
			loadGraphic(Paths.image('pixelUI/' + texture));
			height = height / 5;
			column_n = Std.int(width / height); // A less wild assumption here
			width = width / column_n;
			loadGraphic(Paths.image('pixelUI/' + texture), true, Math.floor(width), Math.floor(height));

			antialiasing = false;
			setGraphicSize(Std.int(width * SongPlayState.PIXEL_ZOOM * Note.swagScaleVariable));

			// loadPixelAnims() part in Note
			NoteLoader.loadPixelStrumNoteAnimsByKey(Note.SCHEME[noteData], this, column_n, ['static', 'pressed', 'confirm'], [[0], [1, 2], [3, 4]]);
			animation.getByName('pressed').frameRate = 12;
		} else {
			frames = Paths.getSparrowAtlas(texture);

			antialiasing = ClientPrefs.globalAntialiasing;
			setGraphicSize(Std.int(width * Note.swagScaleConstant * Note.swagScaleVariable));

			NoteLoader.loadStrumNoteAnimsByKey(Note.SCHEME[noteData], this, [' arrow', ' press', ' confirm'], ['static', 'pressed', 'confirm']);		
		}
		updateHitbox();

		if (lastAnim != null) {
			playAnim(lastAnim, true);
		}
	}

	public function postAddedToGroup() {
		playAnim('static');
		x += Note.swagWidthSpacing * noteData - Note.swagOffsetStrum;
		x += 50;
		x += ((FlxG.width / 2) * player);
		ID = noteData;
	}

	override function update(elapsed:Float) {
		if(resetAnim > 0) {
			resetAnim -= elapsed;
			if(resetAnim <= 0) {
				playAnim('static');
				resetAnim = 0;
			}
		}
		//if(animation.curAnim != null){ //my bad i was upset
		if(animation.curAnim.name == 'confirm' && !SongPlayState.isPixelStage) {
			centerOrigin();
		//}
		}

		super.update(elapsed);
	}

	public function getControlName():String
	{
		if (SongPlayState.instance != null) {
			var key:FlxKey = SongPlayState.instance.getKeyByNote(noteData);
			if (key != NONE) return InputFormatter.getKeyName(key);
		} else { // Left here just in case
			var keys:Array<FlxKey> = ClientPrefs.keyBinds[ClientPrefs.bindSchemes[Note.TOTAL][noteData]];
			for (key in keys) if (key != NONE) return InputFormatter.getKeyName(key);
		}
		return '';
	}

	public function playAnim(anim:String, ?force:Bool = false) {
		animation.play(anim, force);
		centerOffsets();
		centerOrigin();
		if(animation.curAnim == null || animation.curAnim.name == 'static') {
			colorSwap.hue = 0;
			colorSwap.saturation = 0;
			colorSwap.brightness = 0;
		} else {
			var arrowHSV = ClientPrefs.arrowHSV[Note.SCHEME[noteData]];
			colorSwap.hue = arrowHSV[0] / 360;
			colorSwap.saturation = arrowHSV[1] / 100;
			colorSwap.brightness = arrowHSV[2] / 100;

			if(animation.curAnim.name == 'confirm' && !SongPlayState.isPixelStage) {
				centerOrigin();
			}
		}
	}

	override public function destroy()
	{
		if (hintThing != null) FlxTween.completeTweensOf(hintThing);
		super.destroy();
	}
}
