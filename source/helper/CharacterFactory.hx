package helper;

import hardcoded.WindowCharacter.WindowNoteCharacter;
import hardcoded.WindowCharacter.WindowTextCharacter;
import hardcoded.ShootingPico;

/**
 * Static class for handling hard-coded characters
 */
class CharacterFactory
{
	public static function getCharacter(name:String, isPlayer:Bool, isGF:Bool):Character
	{
		var ch:Character;
		switch (name) {
			case 'pico-speaker':
				ch = new ShootingPico(0, 0);

			case 'debug-text':
				ch = new WindowTextCharacter(0, 0, 'square', isPlayer);
			
			case 'debug':
				ch = new WindowNoteCharacter(0, 0, 'square', isPlayer);

			default:
				if (isPlayer) {
					ch = new Boyfriend(0, 0, name).postprocess(Note.SCHEME);
				} else {
					ch = new Character(0, 0, name, false).postprocess(Note.SCHEME, !isGF);
				}
		}

		return ch;
	}
}