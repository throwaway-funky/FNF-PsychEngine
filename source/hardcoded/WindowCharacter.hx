package hardcoded;

import flixel.text.FlxText;
import flixel.FlxSprite;
import helper.NoteLoader;

/**
 * A hardcoded variant of Character that simply shows whatever animation it is asked to play.
 */
class WindowCharacter extends Character
{
	var displaySprite:FlxSprite;
	final padding:Float = 50;

	override public function new(x:Float, y:Float, img:String = 'square', isPlayer:Bool = false)
	{
		super(x, y, '.none', isPlayer);
		
		loadGraphic(Paths.image(img));

		flipX = false;
		healthIcon = isPlayer ? "displayer" : "display";
		positionArray = [-180, 200]; // Idk
		cameraPosition = [width * 0.2, height * 0.2]; // Idk
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0)
	{
		idling = false;
		singing = false;
		specialAnim = false;
		animName = AnimName;
	}

	// Must succeed.
	override public function tryPlayAnim(singAnim:String, suffix:String, force:Bool = false):Bool
	{
		playAnim(singAnim + suffix, force);
		return true;
	}

	override public function draw() {
		super.draw();

		if (displaySprite != null) displaySprite.draw();
	}
}

class WindowTextCharacter extends WindowCharacter
{
	override public function new(x:Float, y:Float, img:String = 'square', isPlayer:Bool = false)
	{
		super(x, y, img, isPlayer);

		var txt:FlxText = new FlxText(x, y, width - padding * 2, '', 20);
		displaySprite = txt;
	}

	override public function updateHitbox()
	{
		super.updateHitbox();

		displaySprite.scale.set(scale.x, scale.y);
		displaySprite.updateHitbox(); 
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0)
	{
		super.playAnim(AnimName, Force, Reversed, Frame);

		if (displaySprite != null) (cast displaySprite:FlxText).text = AnimName;
	}

	override public function update(elapsed:Float)
	{
		displaySprite.x = x + padding;
		displaySprite.y = y + padding;

		super.update(elapsed);
	}

	override public function destroy() {
		displaySprite.destroy();
		super.destroy();
	}
}

class WindowNoteCharacter extends WindowCharacter
{
	var noteStamp:FlxSprite;
	final stampSize:Int = 80;
	var noteArray:Array<String> = [];

	override public function new(x:Float, y:Float, img:String = 'square', isPlayer:Bool = false)
	{
		super(x, y, img, isPlayer);

		var txt:FlxText = new FlxText(x, y, width - padding * 2, '', 20);
		displaySprite = txt;

		noteStamp = new FlxSprite();
		noteStamp.frames = Paths.getSparrowAtlas('ADLIBNOTE_assets');
		NoteLoader.loadNoteAnimsByKeyScheme([for (i in 0...NoteEK.TOTAL_DEFINED) i], noteStamp, [' '], ['']);
		noteStamp.setGraphicSize(stampSize);
		noteStamp.updateHitbox();
	}

	override public function updateHitbox()
	{
		super.updateHitbox();

		displaySprite.scale.set(scale.x, scale.y);
		displaySprite.updateHitbox(); 

		noteStamp.setGraphicSize(Std.int(stampSize * scale.x));
		noteStamp.updateHitbox();
	}

	override public function playAnim(AnimName:String, Force:Bool = false, Reversed:Bool = false, Frame:Int = 0)
	{
		if (noteArray.length > 0) noteArray = [];
		super.playAnim(AnimName, Force, Reversed, Frame);

		if (displaySprite != null) (cast displaySprite:FlxText).text = 'Anim: ' + AnimName;
	}

	override public function playSingAnim(suffix:String, noteName:String, checkSet:Bool = true)
	{
		if (checkSet) {
			var ar:Array<Int> = noteAnimSet;
			ar.sort((a, b) -> a - b);

			noteArray = ar.map(x -> NoteList.keys[x].id);
			
			if (displaySprite != null) (cast displaySprite:FlxText).text = 'Sing: ' + (suffix != '' ? '(Suffix: $suffix)' : '');

			var singAnim:String = 'sing' + ar.map(x -> NoteList.keys[x].id).join('-');
			super.playAnim(singAnim + suffix, true);
		} else {
			noteArray = [noteName];
			
			if (displaySprite != null) (cast displaySprite:FlxText).text = 'Sing: ' + (suffix != '' ? '(Suffix: $suffix)' : '');

			var singAnim:String = 'sing' + noteName;
			super.playAnim(singAnim + suffix, true);
		}
	}

	override public function update(elapsed:Float)
	{
		displaySprite.x = x + padding;
		displaySprite.y = y + padding;

		super.update(elapsed);
	}

	override public function draw() {
		super.draw();

		// Like printing a text but probably a hundred times slower
		if (displaySprite != null && noteArray.length > 0) {
			var x2 = x + padding;
			var y2 = displaySprite.y + displaySprite.height + 15;
			for (noteName in noteArray) {
				if (x2 + stampSize - x > width - padding) {
					y2 += stampSize;
					x2 = x + padding;
				}
				if (y2 + stampSize - y > height - padding) {
					break; // Not sure what to do with this one
				}

				noteStamp.x = x2;
				noteStamp.y = y2;
				noteStamp.animation.play(noteName);
				noteStamp.draw();

				x2 += stampSize;
			}
		}
	}

	override public function miss(noteData:Int, suffix:String = '')
	{
		if (displaySprite != null) (cast displaySprite:FlxText).text = 'Miss: ' + (suffix != '' ? '(Suffix: $suffix)' : '');
		noteArray = [Note.NAME_SCHEME[noteData]];

		singTime = -1000;

		psaTrigger = false;
	}

	override public function destroy() {
		displaySprite.destroy();
		noteStamp.destroy();
		super.destroy();
	}
}