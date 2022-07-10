package options;

#if desktop
import Discord.DiscordClient;
#end
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import flixel.FlxSubState;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxSave;
import haxe.Json;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import flixel.graphics.FlxGraphic;
import Controls;
import helper.NoteLoader.NoteList;

using StringTools;

private enum OptionType
{
	NONE;
	CALL(func:Void->Void);
	CONTROL(name:String);
	NOTES(num:Int);
	NOTE(index:Int);
}

class ControlsSubState extends MusicBeatSubstate {
	private static var curSelected:Int = -1;
	private static var curAlt:Int = 0;
	private static var curKey:Int = 4;
	private static var curKeyID:Int = 0;
	private static var curKeyScheme:Int = 0;

	private static var defaultKey:String = 'Reset UI to Default Keys';
	private static var defaultWASD:String = 'Set Notes to WASD';
	private static var defaultDFJK:String = 'Set Notes to DFJK';

	var optionShit:Array<Array<Any>> = [
		['< NOTES (4 key) >', NOTES(curKey)],
		[''],
		['UI'],
		['Left', CONTROL('ui_left')],
		['Down', CONTROL('ui_down')],
		['Up', CONTROL('ui_up')],
		['Right', CONTROL('ui_right')],
		[''],
		['Reset', CONTROL('reset')],
		['Accept', CONTROL('accept')],
		['Back', CONTROL('back')],
		['Pause', CONTROL('pause')],
		[''],
		['VOLUME'],
		['Mute', CONTROL('volume_mute')],
		['Up', CONTROL('volume_up')],
		['Down', CONTROL('volume_down')],
		[''],
		['DEBUG'],
		['Key 1', CONTROL('debug_1')],
		['Key 2', CONTROL('debug_2')]
	];

	private var grpOptions:FlxTypedGroup<Alphabet>;
	private var grpInputs:Array<AttachedText> = [];
	private var grpInputsAlt:Array<AttachedText> = [];
	var rebindingKey:Bool = false;
	var rebindingScheme:Bool = false;
	var nextAccept:Int = 5;

	public function new() {
		super();

		var bg:FlxSprite = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xFFea71fd;
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		add(bg);

		grpOptions = new FlxTypedGroup<Alphabet>();
		add(grpOptions);

		optionShit = optionShit.concat([
			[''],
			[defaultKey, CALL(function () {
				for (key => value in ClientPrefs.defaultKeys) {
					if (!key.startsWith('note')) ClientPrefs.keyBinds[key] = value.copy(); // Copy only non-note keys
				}
				reloadKeys();
				changeSelection();
			})],
			[defaultWASD, CALL(function () {
				for (buttonName => value in NoteList.keybindWASD) {
					ClientPrefs.keyBinds['note_' + buttonName] = value.copy();
				}
				ClientPrefs.bindSchemes = [for (scheme in NoteList.bindschemeWASD) [for (str in scheme) 'note_' + str]];
				reloadKeys();
				changeSelection();
			})],
			[defaultDFJK, CALL(function () {
				for (buttonName => value in NoteList.keybindDFJK) {
					ClientPrefs.keyBinds['note_' + buttonName] = value.copy();
				}
				ClientPrefs.bindSchemes = [for (scheme in NoteList.bindschemeDFJK) [for (str in scheme) 'note_' + str]];
				reloadKeys();
				changeSelection();
			})]
		]);

		var i:Int = 0;
		while (i < optionShit.length) {
			if (optionShit[i].length < 2) optionShit[i].push(OptionType.NONE);
			else switch (optionShit[i][1] : OptionType) {
				case NOTES(n):
					for (j in 0...n)
						optionShit.insert(i + j + 1, ['Key ${j+1}', NOTE(j)]);
						// optionShit.insert(i + j + 1, ['Key ${j+1} (${ClientPrefs.bindSchemes[n][j].substr(5)})', NOTE(j)]);
					i += n;
				default:
			}
			i += 1;
		}

		for (i in 0...optionShit.length) {
			var first:String = (optionShit[i][0] : String);
			var second:OptionType = (optionShit[i][1] : OptionType);
			var isBold:Bool = switch (second) {
				case NONE: false;
				case NOTES(_): false;
				default: true;
			};
			var isCentered:Bool = switch (second) {
				case NOTE(_): false;
				case CONTROL(_): false;
				default: true;
			};

			var optionText:Alphabet = new Alphabet(0, (10 * i), optionShit[i][0], isBold, false);
			optionText.isMenuItem = true;
			if(isCentered) {
				optionText.screenCenter(X);
				optionText.forceX = optionText.x;
				optionText.yAdd = -55;
			} else {
				optionText.forceX = 200;
			}
			optionText.yMult = 60;
			optionText.targetY = i;
			grpOptions.add(optionText);

			if(!isCentered) {
				addBindTexts(optionText, i);
				if(curSelected < 0) curSelected = i;
			}
		}

		changeSelection();
	}

	var leaving:Bool = false;
	var bindingTime:Float = 0;
	override function update(elapsed:Float) {
		if(!rebindingKey && !rebindingScheme) {
			if (controls.UI_UP_P) {
				changeSelection(-1);
			}
			if (controls.UI_DOWN_P) {
				changeSelection(1);
			}
			if (controls.UI_LEFT_P || controls.UI_RIGHT_P) {
				switch (optionShit[curSelected][1] : OptionType) {
					case CONTROL(_):
						changeAlt(controls.UI_RIGHT_P, false);
					case NOTE(_):
						changeAlt(controls.UI_RIGHT_P, true);
					case NOTES(n):
						changeNotes(controls.UI_RIGHT_P);
					default:
				}
			}

			if (controls.BACK) {
				ClientPrefs.reloadControls();
				close();
				FlxG.sound.play(Paths.sound('cancelMenu'));
			}

			if(controls.ACCEPT && nextAccept <= 0) {
				switch (optionShit[curSelected][1] : OptionType) {
					case CALL(func):
						func();
						FlxG.sound.play(Paths.sound('confirmMenu'));
					case CONTROL(_) | NOTE(_) if (curAlt != 2): // Rebind Key
						bindingTime = 0;
						rebindingKey = true;
						if (curAlt == 1) {
							grpInputsAlt[getInputTextNum()].alpha = 0;
						} else {
							grpInputs[getInputTextNum()].alpha = 0;
						}
						FlxG.sound.play(Paths.sound('scrollMenu'));
					case NOTE(index) if (curAlt == 2): // Rebind Scheme
						rebindingScheme = true;
						curKeyID = index;
						curKeyScheme = (NoteList.buttonEnums[ClientPrefs.bindSchemes[curKey][index].substr(5)] : Int);
						changeScheme(0);
						FlxG.sound.play(Paths.sound('scrollMenu'));						
					default:
				}
			}
		} else if (rebindingKey) {
			var controlName:String = getControlName(curSelected);
			var keyPressed:FlxKey = FlxG.keys.firstJustPressed();
			if (controlName != null && keyPressed != NONE) {
				var keysArray:Array<FlxKey> = ClientPrefs.keyBinds.get(controlName);
				keysArray[curAlt] = keyPressed;

				var opposite:Int = 1 - curAlt;
				if(keysArray[opposite] == keysArray[curAlt]) {
					keysArray[opposite] = NONE;
				}
				ClientPrefs.keyBinds.set(controlName, keysArray);

				reloadKeys();
				FlxG.sound.play(Paths.sound('confirmMenu'));
				rebindingKey = false;
			}

			bindingTime += elapsed;
			if(bindingTime > 5) { // cancel
				if (curAlt == 1) {
					grpInputsAlt[curSelected].alpha = 1;
				} else {
					grpInputs[curSelected].alpha = 1;
				}
				FlxG.sound.play(Paths.sound('scrollMenu'));
				rebindingKey = false;
				bindingTime = 0;
			}
		} else if (rebindingScheme) {
			if (controls.UI_UP_P) changeScheme(-8);
			if (controls.UI_DOWN_P) changeScheme(8);
			if (controls.UI_LEFT_P) changeScheme(-1);
			if (controls.UI_RIGHT_P) changeScheme(1);
			if (controls.ACCEPT) {
				ClientPrefs.bindSchemes[curKey][curKeyID] = 'note_' + NoteList.buttons[curKeyScheme];
				grpOptions.members[curSelected].changeText('Key ${curKeyID+1}');
				rebindingScheme = false;
			}
		}

		if(nextAccept > 0) {
			nextAccept -= 1;
		}
		super.update(elapsed);
	}

	function getInputTextNum() {
		var num:Int = 0;
		for (i in 0...curSelected) {
			if(bindCheck(i)) {
				num++;
			}
		}
		return num;
	}

	@:access(grpOptions.length) // I'll just cheat here idc
	function changeNotes(right:Bool) {
		var newKey:Int = curKey + (right ? 1 : -1);
		if (newKey == NoteList.bindschemeLength) newKey = 1;
		else if (newKey == 0) newKey = NoteList.bindschemeLength - 1;
		optionShit[curSelected] = ['< NOTES ($newKey key) >', NOTES(newKey)];
		grpOptions.members[curSelected].changeText('< NOTES ($newKey key) >');

		optionShit.splice(curSelected + 1, curKey);
		var toKill:Array<Alphabet> = grpOptions.members.splice(curSelected + 1, curKey);
		for (option in toKill) {
			option.kill();
			option.destroy();
			remove(option);
		}
		grpOptions.length -= curKey;

		for (i in 0...newKey) {
			var pos:Int = curSelected + i + 1;

			optionShit.insert(pos, ['Key ${i+1}', NOTE(i)]);
			// optionShit.insert(pos, ['Key ${i+1} (${ClientPrefs.bindSchemes[n][i].substr(5)})', NOTE(i)]);

			var optionText:Alphabet = new Alphabet(0, (10 * pos), optionShit[pos][0], true, false);
			optionText.isMenuItem = true;
			optionText.forceX = 200;
			optionText.yMult = 60;
			optionText.targetY = pos;
			grpOptions.insert(pos, optionText);
		}

		curKey = newKey;
		reloadKeys();
	}

	function changeScheme(change:Int = 0) {
		curKeyScheme += change;
		while (curKeyScheme < 0)
			curKeyScheme += NoteList.buttonLength;
		while (curKeyScheme >= NoteList.buttonLength)
			curKeyScheme -= NoteList.buttonLength;

		var buttonName:String = NoteList.buttons[curKeyScheme];
		var item:Alphabet = grpOptions.members[curSelected];
		var keys:Array<FlxKey> = ClientPrefs.keyBinds.get('note_' + buttonName);
		for (i in 0...grpInputs.length) {
			if (grpInputs[i].sprTracker == item) {
				grpInputs[i].changeText(InputFormatter.getKeyName(keys[0]));
				break;
			}
		}
		for (i in 0...grpInputsAlt.length) {
			if (grpInputsAlt[i].sprTracker == item) {
				grpInputsAlt[i].changeText(InputFormatter.getKeyName(keys[1]));
				break;
			}
		}
		item.changeText('< $buttonName >');
	}
	
	function changeSelection(change:Int = 0) {
		do {
			curSelected += change;
			if (curSelected < 0)
				curSelected = optionShit.length - 1;
			if (curSelected >= optionShit.length)
				curSelected = 0;
		} while(unselectableCheck(curSelected));

		if (curAlt == 2 && !(optionShit[curSelected][1] : OptionType).match(NOTE(_))) curAlt = 0;

		var bullShit:Int = 0;

		for (i in 0...grpInputs.length) {
			grpInputs[i].alpha = 0.6;
		}
		for (i in 0...grpInputsAlt.length) {
			grpInputsAlt[i].alpha = 0.6;
		}

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			if(!unselectableCheck(bullShit-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
					if(curAlt == 1) {
						for (i in 0...grpInputsAlt.length) {
							if(grpInputsAlt[i].sprTracker == item) {
								grpInputsAlt[i].alpha = 1;
								break;
							}
						}
					} else {
						for (i in 0...grpInputs.length) {
							if(grpInputs[i].sprTracker == item) {
								grpInputs[i].alpha = 1;
								break;
							}
						}
					}
				}
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	function changeAlt(right:Bool, extra:Bool) {
		var total = extra ? 3 : 2;
		curAlt = curAlt + (right ? 1 : total - 1);
		if (curAlt >= total) curAlt -= total;

		for (i in 0...grpInputs.length) {
			if(grpInputs[i].sprTracker == grpOptions.members[curSelected]) {
				grpInputs[i].alpha = 0.6;
				if(curAlt == 0) {
					grpInputs[i].alpha = 1;
				}
				break;
			}
		}
		for (i in 0...grpInputsAlt.length) {
			if(grpInputsAlt[i].sprTracker == grpOptions.members[curSelected]) {
				grpInputsAlt[i].alpha = 0.6;
				if(curAlt == 1) {
					grpInputsAlt[i].alpha = 1;
				}
				break;
			}
		}
		FlxG.sound.play(Paths.sound('scrollMenu'));
	}

	private function unselectableCheck(num:Int):Bool {
		return (optionShit[num][1] : OptionType).match(NONE);
	}

	private function bindCheck(num:Int):Bool {
		return (optionShit[num][1] : OptionType).match(NOTE(_) | CONTROL(_));
	}

	private function getControlName(num:Int):String {
		return switch (optionShit[num][1] : OptionType) {
			case NOTE(index): ClientPrefs.bindSchemes[curKey][index];
			case CONTROL(str): str;
			default: null;
		};
	}

	private function addBindTexts(optionText:Alphabet, num:Int) {
		var controlName:String = getControlName(num);

		var keys:Array<FlxKey> = ClientPrefs.keyBinds.get(controlName);
		var text1 = new AttachedText(InputFormatter.getKeyName(keys[0]), 400, -55);
		text1.setPosition(optionText.x + 400, optionText.y - 55);
		text1.sprTracker = optionText;
		grpInputs.push(text1);
		add(text1);

		var text2 = new AttachedText(InputFormatter.getKeyName(keys[1]), 650, -55);
		text2.setPosition(optionText.x + 650, optionText.y - 55);
		text2.sprTracker = optionText;
		grpInputsAlt.push(text2);
		add(text2);
	}

	function reloadKeys() {
		while(grpInputs.length > 0) {
			var item:AttachedText = grpInputs[0];
			item.kill();
			grpInputs.remove(item);
			item.destroy();
		}
		while(grpInputsAlt.length > 0) {
			var item:AttachedText = grpInputsAlt[0];
			item.kill();
			grpInputsAlt.remove(item);
			item.destroy();
		}

		// trace('Reloaded keys: ' + ClientPrefs.keyBinds);
		trace(grpOptions.length);
		trace(optionShit.length);
		for (i in 0...grpOptions.length) {
			// trace('$i: ${optionShit[i]} ${grpOptions.members[i].text}');
			if (bindCheck(i)) {
				addBindTexts(grpOptions.members[i], i);
			}
		}

		var bullShit:Int = 0;
		for (i in 0...grpInputs.length) {
			grpInputs[i].alpha = 0.6;
		}
		for (i in 0...grpInputsAlt.length) {
			grpInputsAlt[i].alpha = 0.6;
		}

		for (item in grpOptions.members) {
			item.targetY = bullShit - curSelected;
			bullShit++;

			if(!unselectableCheck(bullShit-1)) {
				item.alpha = 0.6;
				if (item.targetY == 0) {
					item.alpha = 1;
					if(curAlt == 1) {
						for (i in 0...grpInputsAlt.length) {
							if(grpInputsAlt[i].sprTracker == item) {
								grpInputsAlt[i].alpha = 1;
							}
						}
					} else {
						for (i in 0...grpInputs.length) {
							if(grpInputs[i].sprTracker == item) {
								grpInputs[i].alpha = 1;
							}
						}
					}
				}
			}
		}
	}
}