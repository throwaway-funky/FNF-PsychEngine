package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.util.FlxTimer;
import flixel.system.FlxSound;
import flash.media.Sound;

using StringTools;

/**
 * Loosley based on FlxTypeText lolol
 */
class Alphabet extends FlxSpriteGroup
{
	public var delay:Float = 0.05;
	public var paused:Bool = false;

	// for menu shit
	public var forceX:Float = Math.NEGATIVE_INFINITY;
	public var targetY:Float = 0;
	public var yMult:Float = 120;
	public var xAdd:Float = 0;
	public var yAdd:Float = 0;
	public var isMenuItem:Bool = false;
	public var textSize:Float = 1.0;

	public var text(default, null):String = "";

	// _finalText is always same as text
	// var _finalText:String = "";
	var yMulti:Float = 1;

	// EReg parsing rewrite
	var textStream:String = "";

	// Constants
	final LONG_TEXT_ADD:Float = -24; //text is over 2 rows long, make it go up a bit
	final LINE_HEIGHT:Float = 55;
	final FIXED_SPACE_WIDTH:Float = 40;
	final TYPED_SPACE_WIDTH:Float = 20;

	// custom shit
	// amp, backslash, question mark, apostrophy, comma, angry faic, period
	var lastSprite:AlphaCharacter;
	var xPosResetted:Bool = false;

	var splitWords:Array<String> = [];

	public var isBold:Bool = false;
	public var lettersArray:Array<AlphaCharacter> = [];

	public var finishedText:Bool = false;
	public var typed:Bool = false;

	public var typingSpeed:Float = 0.05;
	public function new(x:Float, y:Float, text:String = "", ?bold:Bool = false, typed:Bool = false, ?typingSpeed:Float = 0.05, ?textSize:Float = 1)
	{
		super(x, y);
		forceX = Math.NEGATIVE_INFINITY;
		this.textSize = textSize;

		// _finalText = text;
		this.text = text;
		this.typed = typed;
		isBold = bold;

		if (text != "")
		{
			if (typed)
			{
				startTypedText(typingSpeed);
			}
			else
			{
				addText();
			}
		} else {
			finishedText = true;
		}
	}

	public function changeText(newText:String, newTypingSpeed:Float = -1)
	{
		for (i in 0...lettersArray.length) {
			var letter = lettersArray[0];
			letter.destroy();
			remove(letter);
			lettersArray.remove(letter);
		}
		lettersArray = [];
		loopNum = 0;
		xPos = 0;
		curRow = 0;
		consecutiveSpaces = 0;
		xPosResetted = false;
		finishedText = false;
		lastSprite = null;

		var lastX = x;
		x = 0;
		// _finalText = newText;
		text = newText;
		if(newTypingSpeed != -1) {
			typingSpeed = newTypingSpeed;
		}

		if (text != "") {
			if (typed)
			{
				startTypedText(typingSpeed);
			} else {
				addText();
			}
		} else {
			finishedText = true;
		}
		x = lastX;
	}

	public function addText()
	{
		var xPos:Float = 0;
		textStream = text;
		while (AlphaCharacter.CHAR.match(textStream))
		{
			var character = AlphaCharacter.CHAR.matched(0);

			var spaceChar:Bool = (character == " " || (isBold && character == "_"));
			if (spaceChar)
			{
				consecutiveSpaces++;
			}

			var isNumber:Bool = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_NUMBER) != null;
			var isSymbol:Bool = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_SYMBOL) != null;
			var isSymbol2:Bool = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_SYMBOL2) != null;
			var isAlphabet:Bool = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_ALPHABET) != null;
			var charEscape:String = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_ESCAPE);

			if ((isAlphabet || isSymbol || isSymbol2 || isNumber || charEscape != null) && (!isBold || !spaceChar)) {
				if (lastSprite != null)
				{
					xPos = lastSprite.x + lastSprite.width;
				}

				if (consecutiveSpaces > 0)
				{
					xPos += FIXED_SPACE_WIDTH * consecutiveSpaces * textSize;
				}
				consecutiveSpaces = 0;

				// var letter:AlphaCharacter = new AlphaCharacter(30 * loopNum, 0, textSize);
				var letter:AlphaCharacter = new AlphaCharacter(xPos, 0, textSize);

				if (isBold)
				{
					if (charEscape != null) {
						trace("Bold Escape char is not supported yet. Skipping: " + charEscape);
					} else if (isNumber) letter.createBoldNumber(character);
					else if (isSymbol) letter.createBoldSymbol(character);
					else if (isSymbol2) {
						trace("Bold " + character + " is not supported yet. Skipping: " + character);
					} else letter.createBoldLetter(character);
				}
				else
				{
					if (charEscape != null) {
						letter.createExtra(charEscape);
					} else if (isNumber) letter.createNumber(character);
					else if (isSymbol || isSymbol2) letter.createSymbol(character);
					else letter.createLetter(character);
				}

				add(letter);
				lettersArray.push(letter);

				lastSprite = letter;
			}

			textStream = AlphaCharacter.CHAR.matchedRight();
		}

		if (textStream.length > 0) trace("Problem encountered while parsing text:\n" + textStream);
	}

	var loopNum:Int = 0;
	var xPos:Float = 0;
	public var curRow:Int = 0;
	var dialogueSound:FlxSound = null;
	private static var soundDialog:Sound = null;
	var consecutiveSpaces:Int = 0;
	public static function setDialogueSound(name:String = '')
	{
		if (name == null || name.trim() == '') name = 'dialogue';
		soundDialog = Paths.sound(name);
		if(soundDialog == null) soundDialog = Paths.sound('dialogue');
	}

	var typeTimer:FlxTimer = null;
	public function startTypedText(speed:Float):Void
	{
		textStream = text;

		if(soundDialog == null)
		{
			Alphabet.setDialogueSound();
		}

		if(speed <= 0) {
			while(!finishedText) { 
				timerCheck();
			}
			if(dialogueSound != null) dialogueSound.stop();
			dialogueSound = FlxG.sound.play(soundDialog);
		} else {
			typeTimer = new FlxTimer().start(0.1, function(tmr:FlxTimer) {
				typeTimer = new FlxTimer().start(speed, function(tmr:FlxTimer) {
					timerCheck(tmr);
				}, 0);
			});
		}
	}

	public function timerCheck(?tmr:FlxTimer = null) {
		var match:Bool = AlphaCharacter.CHAR.match(textStream);

		while (match && (AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_ESCAPE) == "n" 
			|| (xPos >= FlxG.width * 0.65 && AlphaCharacter.CHAR.matched(0) == ' ')))
		{
			yMulti += 1;
			xPosResetted = true;
			xPos = 0;
			curRow += 1;
			if(curRow == 2) y += LONG_TEXT_ADD;

			textStream = AlphaCharacter.CHAR.matchedRight();
			match = AlphaCharacter.CHAR.match(textStream);
		}

		if (!match) {
			if (textStream.length > 0) trace("Problem encountered while parsing text:\n" + textStream);
			if (tmr != null) {
				typeTimer = null;
				tmr.cancel();
				tmr.destroy();
			}
			finishedText = true;
			return;
		}
		var character = AlphaCharacter.CHAR.matched(0);

		if (character != null) {
			var spaceChar:Bool = (character == ' ' || (isBold && character == '_'));
			if (spaceChar)
			{
				consecutiveSpaces++;
			}

			var isNumber:Bool = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_NUMBER) != null;
			var isSymbol:Bool = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_SYMBOL) != null;
			var isSymbol2:Bool = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_SYMBOL2) != null;
			var isAlphabet:Bool = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_ALPHABET) != null;
			var charEscape:String = AlphaCharacter.CHAR.matched(AlphaCharacter.CAP_ESCAPE);

			if ((isAlphabet || isSymbol || isSymbol2 || isNumber || charEscape != null) && (!isBold || !spaceChar)) {
				if (lastSprite != null && !xPosResetted)
				{
					lastSprite.updateHitbox();
					xPos += lastSprite.width + 3;
					// if (isBold)
					// xPos -= 80;
				}
				else
				{
					xPosResetted = false;
				}

				if (consecutiveSpaces > 0)
				{
					xPos += TYPED_SPACE_WIDTH * consecutiveSpaces * textSize;
				}
				consecutiveSpaces = 0;

				// var letter:AlphaCharacter = new AlphaCharacter(30 * loopNum, 0, textSize);
				var letter:AlphaCharacter = new AlphaCharacter(xPos, LINE_HEIGHT * yMulti * textSize, textSize);
				letter.row = curRow;
				if (isBold)
				{
					if (charEscape != null) {
						trace("Bold Escape char is not supported yet. Skipping: " + charEscape);
					} else if (isNumber) letter.createBoldNumber(character);
					else if (isSymbol) letter.createBoldSymbol(character);
					else if (isSymbol2) {
						trace("Bold " + character + " is not supported yet. Skipping: " + character);
					} else letter.createBoldLetter(character);
				}
				else
				{
					if (charEscape != null) {
						letter.createExtra(charEscape);
					} else if (isNumber) letter.createNumber(character);
					else if (isSymbol || isSymbol2) letter.createSymbol(character);
					else letter.createLetter(character);
				}
				letter.x += 90;

				if(tmr != null) {
					if(dialogueSound != null) dialogueSound.stop();
					dialogueSound = FlxG.sound.play(soundDialog);
				}

				add(letter);

				lastSprite = letter;
			}
		}

		textStream = AlphaCharacter.CHAR.matchedRight();
		if(textStream.length <= 0) {
			if(tmr != null) {
				typeTimer = null;
				tmr.cancel();
				tmr.destroy();
			}
			finishedText = true;
			//CoolUtil.traceFrames(lastSprite.frames);
		}
	}

	override function update(elapsed:Float)
	{
		if (isMenuItem)
		{
			var scaledY = FlxMath.remapToRange(targetY, 0, 1, 0, 1.3);

			var lerpVal:Float = CoolUtil.boundTo(elapsed * 9.6, 0, 1);
			y = FlxMath.lerp(y, (scaledY * yMult) + (FlxG.height * 0.48) + yAdd, lerpVal);
			if(forceX != Math.NEGATIVE_INFINITY) {
				x = forceX;
			} else {
				x = FlxMath.lerp(x, (targetY * 20) + 90 + xAdd, lerpVal);
			}
		}

		super.update(elapsed);
	}

	public function killTheTimer() {
		if(typeTimer != null) {
			typeTimer.cancel();
			typeTimer.destroy();
		}
		typeTimer = null;
	}
}

class AlphaCharacter extends FlxSprite
{

	public static final CHAR:EReg = ~/^(?: |([a-zA-Z])|([0-9])|([()*+\-<>."'!?&])|([~#%@:;=$\[\]^_,\/\|])|\\([a-zA-Z]+|"|) ?)/g;
	public static final CAP_ALPHABET:Int = 1;
	public static final CAP_NUMBER:Int = 2;
	public static final CAP_SYMBOL:Int = 3;
	public static final CAP_SYMBOL2:Int = 4;
	public static final CAP_ESCAPE:Int = 5;

	public var row:Int = 0;

	private var textSize:Float = 1;

	public function new(x:Float, y:Float, textSize:Float)
	{
		super(x, y);
		var tex = Paths.getSparrowAtlas('alphabet');
		frames = tex;

		setGraphicSize(Std.int(width * textSize));
		updateHitbox();
		this.textSize = textSize;
		antialiasing = ClientPrefs.globalAntialiasing;
	}

	private function changeCharset(name:String):Void
	{
		var tex = Paths.getSparrowAtlas(name);
		frames = tex;
	}

	public function createBoldLetter(letter:String):Void
	{
		animation.addByPrefix(letter, letter.toUpperCase() + " bold", 24);
		animation.play(letter);
		updateHitbox();
	}

	public function createBoldNumber(letter:String):Void
	{
		animation.addByPrefix(letter, "bold" + letter, 24);
		animation.play(letter);
		updateHitbox();
	}

	public function createBoldSymbol(letter:String):Void
	{
		switch (letter)
		{
			case '.':
				animation.addByPrefix(letter, 'PERIOD bold', 24);
			case "'":
				animation.addByPrefix(letter, 'APOSTRAPHIE bold', 24);
			case '"':
				animation.addByPrefix(letter, 'END PARENTHESES bold', 24);
			case '?':
				animation.addByPrefix(letter, 'QUESTION MARK bold', 24);
			case '!':
				animation.addByPrefix(letter, 'EXCLAMATION POINT bold', 24);
			case '(':
				animation.addByPrefix(letter, 'bold (', 24);
			case ')':
				animation.addByPrefix(letter, 'bold )', 24);
			default:
				animation.addByPrefix(letter, 'bold ' + letter, 24);
		}
		animation.play(letter);
		updateHitbox();
		switch (letter)
		{
			case "'" | '"':
				y -= 20 * textSize;
			case '-':
				//x -= 35 - (90 * (1.0 - textSize));
				y += 20 * textSize;
			case '(':
				x -= 65 * textSize;
				y -= 5 * textSize;
				offset.x = -58 * textSize;
			case ')':
				x -= 20 / textSize;
				y -= 5 * textSize;
				offset.x = 12 * textSize;
			case '.':
				y += 45 * textSize;
				x += 5 * textSize;
				offset.x += 3 * textSize;
		}
	}

	public function createLetter(letter:String):Void
	{
		var letterCase:String = "lowercase";
		if (letter.toLowerCase() != letter)
		{
			letterCase = 'capital';
		}

		animation.addByPrefix(letter, letter + " " + letterCase, 24);
		animation.play(letter);
		updateHitbox();

		y = (110 - height);
		y += row * 60;
	}

	public function createNumber(letter:String):Void
	{
		animation.addByPrefix(letter, letter, 24);
		animation.play(letter);

		updateHitbox();

		y = (110 - height);
		y += row * 60;
	}

	public function createSymbol(letter:String):Void
	{
		switch (letter)
		{
			case '&':
				animation.addByPrefix(letter, 'amp', 24);
			case '#':
				animation.addByPrefix(letter, 'hashtag', 24);
			case '.':
				animation.addByPrefix(letter, 'period', 24);
			case "'":
				animation.addByPrefix(letter, 'apostraphie', 24); // wha?
				y -= 50;
			case '"':
				animation.addByPrefix(letter, 'end parentheses', 24); // im not sure i understand english anymore
				y -= 50;
			case '^':
				animation.addByPrefix(letter, '^', 24);
				y -= 50;
			case '?':
				animation.addByPrefix(letter, 'question mark', 24);
			case '!':
				animation.addByPrefix(letter, 'exclamation point', 24);
			case ',':
				animation.addByPrefix(letter, 'comma', 24);
			case '$':
				animation.addByPrefix(letter, 'dollarsign', 24);
			case '/':
				animation.addByPrefix(letter, 'forward slash', 24);
			default:
				animation.addByPrefix(letter, letter, 24);
		}
		animation.play(letter);

		updateHitbox();

		y = (110 - height);
		y += row * 60;
		switch (letter)
		{
			case "'" | '"' | '^':
				y -= 20;
			case '-' | '~':
				y -= 12;
			case '=' | '*':
				y -= 6;
			case '+':
				y -= 2;
			case ';':
				y += 4;
			case ',':
				y += 6;
		}
	}

	public function createExtra(letter:String):Void
	{
		switch (letter)
		{
			case 'n':
			case '':
				animation.addByPrefix(letter, '\\ copy', 24);
			case '"':
				animation.addByPrefix(letter, 'start parentheses', 24);
				y -= 50;
			case 'angryfaic':
				animation.addByPrefix(letter, 'angry faic', 24);
			case 'heart':
				animation.addByPrefix(letter, 'heart', 24);
			case 'mid': // alias
				animation.addByPrefix(letter, '|', 24);
			case 'leftarrow' | 'downarrow' | 'uparrow' | 'rightarrow':
				animation.addByPrefix(letter, letter.replace('arrow', ' arrow'), 24);
			case 'leftblackarrow' | 'downblackarrow' | 'upblackarrow' | 'rightblackarrow'
				| 'leftblackwhitearrow' | 'downblackwhitearrow' | 'upblackwhitearrow' | 'rightblackwhitearrow'
				| 'leftwhitearrow' | 'downwhitearrow' | 'upwhitearrow' | 'rightwhitearrow'
				| 'diamond' | 'brick' | 'oct':
				changeCharset('extra');
				animation.addByPrefix(letter, letter, 12);
			case 'bf' | 'mathbf' | 'textbf':
				changeCharset('extra');
				animation.addByPrefix(letter, 'mathbf', 12);
			default:
				trace("Unknown Escape Character: " + letter);
				animation.addByPrefix(letter, 'angry faic', 24);
		}
		animation.play(letter);

		updateHitbox();

		y = (110 - height);
		y += row * 60;
		switch (letter)
		{
			case '"':
				y -= 20;
			case 'leftarrow' | 'rightarrow' | 'diamond':
				y -= 2;
			case 'brick' | 'oct':
				y += 4;
			case 'downblackarrow' | 'rightblackarrow' | 'downblackwhitearrow' | 'rightblackwhitearrow'
				| 'downwhitearrow' | 'rightwhitearrow': // Apparently putting them in atlas doesn't work
				animation.curAnim.flipX = true;
				animation.curAnim.flipY = true;
		}
	}
}
