package;

import flixel.FlxSprite;

using StringTools;

class HealthIcon extends FlxSprite
{
	public var sprTracker:FlxSprite;
	private var isOldIcon:Bool = false;
	private var isPlayer:Bool = false;
	private var char:String = '';

	public function new(char:String = 'bf', isPlayer:Bool = false)
	{
		super();
		isOldIcon = (char == 'bf-old');
		this.isPlayer = isPlayer;
		changeIcon(char);
		scrollFactor.set();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (sprTracker != null)
			setPosition(sprTracker.x + sprTracker.width + 10, sprTracker.y - 30);
	}

	public function swapOldIcon() {
		if(isOldIcon = !isOldIcon) changeIcon('bf-old');
		else changeIcon('bf');
	}

	private var iconOffsets:Array<Float> = [0, 0];
	static inline final iconWidth:Int = 150; // Seems like it is, so why not?
	public function changeIcon(char:String) {
		if(this.char != char) {
			var name:String = 'icons/' + char;
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-' + char; //Older versions of psych engine's support
			if(!Paths.fileExists('images/' + name + '.png', IMAGE)) name = 'icons/icon-face'; //Prevents crash from missing icon
			var file:Dynamic = Paths.image(name);

			loadGraphic(file); //Load stupidly first for getting the file size
			var frames:Int = Math.floor(width / iconWidth);

			loadGraphic(file, true, iconWidth, Math.floor(height)); //Then load it fr
			iconOffsets[0] = (width - iconWidth) / 2;
			iconOffsets[1] = (width - iconWidth) / 2;
			updateHitbox();

			if (frames == 3) 
				animation.add(char, [0, 1, 2], 0, false, isPlayer);
			else if (frames == 2)
				animation.add(char, [0, 1, 0], 0, false, isPlayer);
			else
				animation.add(char, [0, 0, 0], 0, false, isPlayer);

			animation.play(char);
			this.char = char;

			antialiasing = ClientPrefs.globalAntialiasing;
			if(char.endsWith('-pixel')) {
				antialiasing = false;
			}
		}
	}

	// override function updateHitbox()
	// {
	// 	super.updateHitbox();
	// 	offset.x = iconOffsets[0];
	// 	offset.y = iconOffsets[1];
	// }

	inline public function getCharacter():String {
		return char;
	}
}
