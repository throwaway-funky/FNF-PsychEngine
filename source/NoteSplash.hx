package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import helper.NoteLoader;

class NoteSplash extends FlxSprite
{
	public var colorSwap:ColorSwap = null;
	private var idleAnim:String;
	private var textureLoaded:String = null;

	private static var textureCache:Map<String, FlxSprite> = [];
	public static function resetCache() textureCache.clear();

	public function new(x:Float = 0, y:Float = 0, ?note:Int = 0) {
		super(x, y);

		var skin:String = 'noteSplashes';
		if(Song.curPlaying.splashSkin != null && Song.curPlaying.splashSkin.length > 0) skin = Song.curPlaying.splashSkin;

		loadAnims(skin);

		colorSwap = new ColorSwap();
		shader = colorSwap.shader;

		setupNoteSplash(x, y, note);
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	public function setupNoteSplash(x:Float, y:Float, note:Int = 0, texture:String = null, hueColor:Float = 0, satColor:Float = 0, brtColor:Float = 0) {
		if(texture == null) {
			texture = 'noteSplashes';
			if(Song.curPlaying.splashSkin != null && Song.curPlaying.splashSkin.length > 0) texture = Song.curPlaying.splashSkin;
		}

		if(textureLoaded != texture) {
			loadAnims(texture);
		}
		colorSwap.hue = hueColor;
		colorSwap.saturation = satColor;
		colorSwap.brightness = brtColor;
		offset.set(10, 10);

		var animNum:Int = FlxG.random.int(1, 2);
		animation.play(Note.NAME_SCHEME[note] + '-' + animNum, true);
		if(animation.curAnim != null)animation.curAnim.frameRate = 24 + FlxG.random.int(-2, 2);

		setGraphicSize(Std.int(width * Note.swagScaleVariable));
		updateHitbox();
		setPosition(x - width / 2, y - height / 2);
		alpha = 0.6;
	}

	function loadAnims(skin:String) {
		if (textureCache.exists(skin)) {
			loadGraphicFromSprite(textureCache.get(skin));
		} else {
			frames = Paths.getSparrowAtlas(skin);
			NoteLoader.loadSplashAnimsByKeyScheme(Note.SCHEME, this, ['splash1 ', 'splash2 '], ['-1', '-2']);

			textureCache.set(skin, clone());
		}
	}

	override function update(elapsed:Float) {
		if(animation.curAnim != null)if(animation.curAnim.finished) kill();

		super.update(elapsed);
	}
}