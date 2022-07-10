package helper;

import flixel.FlxSprite;
import flixel.input.keyboard.FlxKey;

enum abstract NoteEK(Int) from Int to Int {
	var L1;	var D1;	var U1;	var R1;
	var L2;	var D2;	var U2;	var R2;

	var W1; var W2; var W3; var W4;
	var S1;	var S2;	var S3;	var S4;
	var N1;	var N2;	var N3;	var N4;
	var E1; var E2; var E3; var E4;

	var TOTAL_DEFINED;
}

enum abstract NoteNameEK(String) to String {
	var L1;	var D1;	var U1;	var R1;
	var L2;	var D2;	var U2;	var R2;

	var W1; var W2; var W3; var W4;
	var S1;	var S2;	var S3;	var S4;
	var N1;	var N2;	var N3;	var N4;
	var E1; var E2; var E3; var E4;

	var DEFAULT;
}

enum abstract ButtonEK(Int) from Int to Int {
	var LS1; var LS2; var LS3; var LS4;
	var RS1; var RS2; var RS3; var RS4;

	var LC1; var LC2; var LC3; var LC4;
	var RC1; var RC2; var RC3; var RC4;
	var LA1; var LA2; var LA3; var LA4;
	var RA1; var RA2; var RA3; var RA4;

	var CEN; // var LSP; var RSP;

	var TOTAL_DEFINED;
}

enum abstract ButtonNameEK(String) to String {
	var LS1; var LS2; var LS3; var LS4;
	var RS1; var RS2; var RS3; var RS4;

	var LC1; var LC2; var LC3; var LC4;
	var RC1; var RC2; var RC3; var RC4;
	var LA1; var LA2; var LA3; var LA4;
	var RA1; var RA2; var RA3; var RA4;

	var CEN; //var LSP; var RSP;
}

private typedef Key = {
	id:NoteNameEK,
	names:Array<NoteNameEK>,
	pixelIds:Array<Int> // column to use for key given n columns: [1, 4, 5, 8, 9, 24]
};

// How pixel notes loading works:
// There are 6 presets on how the columns should be interpreted, depending on the number of columns.
// "1": Same texture for all notes
// "4": Regular 4K, others fallback to a close enough arrow
// "5": Regular 5K (4 arrows + center), others fallback just like 4K. Center is "N_"
// "8": All 8 defined shapes (4 arrows + 4 special shapes), all variations are in the same color.
// "9": Regular 9K (8 arrows + center), others fallback just like 4K. Center is "N_"
// "24": All 24 defined notes.

private typedef IStr = {
	i:Int, 
	str:String
};

/**
 * Static structure for lists related to notes
 */
class NoteList
{
	public static final keys:Map<NoteEK, Key> = [
		L1 => { id: L1, names: [L1, DEFAULT], pixelIds: [0, 0, 0, 0, 0, 0]},
		D1 => { id: D1, names: [D1, DEFAULT], pixelIds: [0, 1, 1, 1, 1, 1]},
		U1 => { id: U1, names: [U1, DEFAULT], pixelIds: [0, 2, 2, 2, 2, 2]},
		R1 => { id: R1, names: [R1, DEFAULT], pixelIds: [0, 3, 3, 3, 3, 3]},
		L2 => { id: L2, names: [L2, L1, DEFAULT], pixelIds: [0, 0, 0, 0, 4, 4]},
		D2 => { id: D2, names: [D2, D1, DEFAULT], pixelIds: [0, 1, 1, 1, 5, 5]},
		U2 => { id: U2, names: [U2, U1, DEFAULT], pixelIds: [0, 2, 2, 2, 6, 6]},
		R2 => { id: R2, names: [R2, R1, DEFAULT], pixelIds: [0, 3, 3, 3, 7, 7]},
		W1 => { id: W1, names: [W1, L1, DEFAULT]	, pixelIds: [0, 0, 0, 4, 0, 8]},
		W2 => { id: W2, names: [W2, W1, L1, DEFAULT], pixelIds: [0, 0, 0, 4, 0, 9]},
		W3 => { id: W3, names: [W3, W1, L1, DEFAULT], pixelIds: [0, 0, 0, 4, 0, 10]},
		W4 => { id: W4, names: [W4, W1, L1, DEFAULT], pixelIds: [0, 0, 0, 4, 0, 11]},
		S1 => { id: S1, names: [S1, D1, DEFAULT]	, pixelIds: [0, 1, 1, 5, 1, 12]},
		S2 => { id: S2, names: [S2, S1, D1, DEFAULT], pixelIds: [0, 1, 1, 5, 1, 13]},
		S3 => { id: S3, names: [S3, S1, D1, DEFAULT], pixelIds: [0, 1, 1, 5, 1, 14]},
		S4 => { id: S4, names: [S4, S1, D1, DEFAULT], pixelIds: [0, 1, 1, 5, 1, 15]},
		N1 => { id: N1, names: [N1, U1, DEFAULT]	, pixelIds: [0, 2, 4, 6, 9, 16]},
		N2 => { id: N2, names: [N2, N1, U1, DEFAULT], pixelIds: [0, 2, 4, 6, 9, 17]},
		N3 => { id: N3, names: [N3, N1, U1, DEFAULT], pixelIds: [0, 2, 4, 6, 9, 18]},
		N4 => { id: N4, names: [N4, N1, U1, DEFAULT], pixelIds: [0, 2, 4, 6, 9, 19]},
		E1 => { id: E1, names: [E1, R1, DEFAULT]	, pixelIds: [0, 3, 3, 7, 3, 20]},
		E2 => { id: E2, names: [E2, E1, R1, DEFAULT], pixelIds: [0, 3, 3, 7, 3, 21]},
		E3 => { id: E3, names: [E3, E1, R1, DEFAULT], pixelIds: [0, 3, 3, 7, 3, 22]},
		E4 => { id: E4, names: [E4, E1, R1, DEFAULT], pixelIds: [0, 3, 3, 7, 3, 23]},
	];
	public static final keyEnums:Map<String, NoteEK> = [
		L1 => L1, D1 => D1, U1 => U1, R1 => R1,
		L2 => L2, D2 => D2, U2 => U2, R2 => R2,
		W1 => W1, W2 => W2, W3 => W3, W4 => W4,
		S1 => S1, S2 => S2, S3 => S3, S4 => S4,
		N1 => N1, N2 => N2, N3 => N3, N4 => N4,
		E1 => E1, E2 => E2, E3 => E3, E4 => E4
	];
	public static final buttons:Map<ButtonEK, ButtonNameEK> = [
		LS1 => LS1, LS2 => LS2, LS3 => LS3, LS4 => LS4,
		RS1 => RS1, RS2 => RS2, RS3 => RS3, RS4 => RS4,
		LC1 => LC1, LC2 => LC2, LC3 => LC3, LC4 => LC4,
		RC1 => RC1, RC2 => RC2, RC3 => RC3, RC4 => RC4,
		LA1 => LA1, LA2 => LA2, LA3 => LA3, LA4 => LA4,
		RA1 => RA1, RA2 => RA2, RA3 => RA3, RA4 => RA4,
		CEN => CEN//, LSP => LSP, RSP => RSP
	];
	public static final buttonEnums:Map<String, ButtonEK> = [
		LS1 => LS1, LS2 => LS2, LS3 => LS3, LS4 => LS4,
		RS1 => RS1, RS2 => RS2, RS3 => RS3, RS4 => RS4,
		LC1 => LC1, LC2 => LC2, LC3 => LC3, LC4 => LC4,
		RC1 => RC1, RC2 => RC2, RC3 => RC3, RC4 => RC4,
		LA1 => LA1, LA2 => LA2, LA3 => LA3, LA4 => LA4,
		RA1 => RA1, RA2 => RA2, RA3 => RA3, RA4 => RA4,
		CEN => CEN//, LSP => LSP, RSP => RSP
	];
	public static final keybindWASD:Map<ButtonNameEK, Array<FlxKey>> = [
		LS1 => [A, LEFT], LS2 => [S, DOWN], LS3 => [W, UP], LS4 => [D, RIGHT],
		RS1 => [J, NONE], RS2 => [K, NONE], RS3 => [I, NONE], RS4 => [L, NONE],

		LA1 => [CAPSLOCK, NONE], LA2 => [Q, NONE], LA3 => [E, NONE], LA4 => [F, NONE],
		RA1 => [H, NONE], RA2 => [U, NONE], RA3 => [O, NONE], RA4 => [SEMICOLON, NONE],

		LC1 => [Z, NONE], LC2 => [X, NONE], LC3 => [C, NONE], LC4 => [V, NONE],
		RC1 => [N, NONE], RC2 => [M, NONE], RC3 => [COMMA, NONE], RC4 => [PERIOD, NONE],

		CEN => [SPACE, NONE]//, LSP => [SHIFT, NONE], RSP => [ENTER, NONE] 
		// TODO: Observe how indie cross detects LSHIFT and RSHIFT (if they would ever release the source code...)
	];
	public static final keybindDFJK:Map<ButtonNameEK, Array<FlxKey>> = [
		LS1 => [A, NONE], LS2 => [S, NONE], LS3 => [D, NONE], LS4 => [F, NONE],
		RS1 => [J, NONE], RS2 => [K, NONE], RS3 => [L, NONE], RS4 => [SEMICOLON, NONE],

		LA1 => [Q, NONE], LA2 => [W, NONE], LA3 => [E, NONE], LA4 => [R, NONE],
		RA1 => [U, NONE], RA2 => [I, NONE], RA3 => [O, NONE], RA4 => [P, NONE],

		LC1 => [X, NONE], LC2 => [C, NONE], LC3 => [V, NONE], LC4 => [B, NONE],
		RC1 => [N, NONE], RC2 => [M, NONE], RC3 => [COMMA, NONE], RC4 => [PERIOD, NONE],

		CEN => [SPACE, NONE]//, LSP => [SHIFT, NONE], RSP => [ENTER, NONE]
	];
	public static final bindschemeWASD:Array<Array<ButtonNameEK>> = [
		[],
		[CEN],
		[LS1, LS4],
		[LS1, LS2, LS4],
		[LS1, LS2, LS3, LS4],
		[LS1, LS2, LS3, LS4, LA4], // This is the point where Arrow Keys become useless
		[LS1, LS2, LS4, RS1, RS3, RS4],
		[LS1, LS2, LS4, CEN, RS1, RS3, RS4],
		[LS1, LS2, LS3, LS4, RS1, RS2, RS3, RS4],
		[LS1, LS2, LS3, LS4, CEN, RS1, RS2, RS3, RS4],
		[LA1, LS1, LS2, LS3, LS4, RS1, RS2, RS3, RS4, RA4], // + pinky
		[LA1, LS1, LS2, LS3, LS4, CEN, RS1, RS2, RS3, RS4, RA4],
		[LA1, LS1, LS2, LS3, LS4, LC4, RC1, RS1, RS2, RS3, RS4, RA4], // + thumb		
		[LA1, LS1, LS2, LS3, LS4, LC4, CEN, RC1, RS1, RS2, RS3, RS4, RA4],
		[LA1, LA2, LS1, LS2, LS3, LS4, LC4, RC1, RS1, RS2, RS3, RS4, RA3, RA4], // + ring
		[LA1, LA2, LS1, LS2, LS3, LS4, LC4, CEN, RC1, RS1, RS2, RS3, RS4, RA3, RA4], 
		[LA1, LA2, LA3, LS1, LS2, LS3, LS4, LC4, RC1, RS1, RS2, RS3, RS4, RA2, RA3, RA4], // + index (or middle)
		[LA1, LA2, LA3, LS1, LS2, LS3, LS4, LC4, CEN, RC1, RS1, RS2, RS3, RS4, RA2, RA3, RA4],
		[LA1, LA2, LA3, LS1, LS2, LS3, LS4, LC3, LC4, RC1, RC2, RS1, RS2, RS3, RS4, RA2, RA3, RA4], // + thumb (or index)
		[LA1, LA2, LA3, LS1, LS2, LS3, LS4, LC3, LC4, CEN, RC1, RC2, RS1, RS2, RS3, RS4, RA2, RA3, RA4],
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC3, LC4, RC1, RC2, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], // + index
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC3, LC4, CEN, RC1, RC2, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4],
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC2, LC3, LC4, RC1, RC2, RC3, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], // + thumb (?)
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC2, LC3, LC4, CEN, RC1, RC2, RC3, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], 
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC1, LC2, LC3, LC4, RC1, RC2, RC3, RC4, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], 
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC1, LC2, LC3, LC4, CEN, RC1, RC2, RC3, RC4, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], // technically?
	];
	public static final bindschemeDFJK:Array<Array<ButtonNameEK>> = [
		[],
		[CEN],
		[LS4, RS1],
		[LS4, CEN, RS1],
		[LS3, LS4, RS1, RS2],
		[LS3, LS4, CEN, RS1, RS2],
		[LS2, LS3, LS4, RS1, RS2, RS3],
		[LS2, LS3, LS4, CEN, RS1, RS2, RS3],
		[LS1, LS2, LS3, LS4, RS1, RS2, RS3, RS4],
		[LS1, LS2, LS3, LS4, CEN, RS1, RS2, RS3, RS4],
		[LS1, LS2, LS3, LS4, LC4, RC1, RS1, RS2, RS3, RS4], // + thumb
		[LS1, LS2, LS3, LS4, LC4, CEN, RC1, RS1, RS2, RS3, RS4], // This is the point when DFJK stops making sense (no reasoning for the schemes below)
		[LA1, LS1, LS2, LS3, LS4, LC4, RC1, RS1, RS2, RS3, RS4, RA4],
		[LA1, LS1, LS2, LS3, LS4, LC4, CEN, RC1, RS1, RS2, RS3, RS4, RA4],
		[LA1, LS1, LS2, LS3, LS4, LC3, LC4, RC1, RC2, RS1, RS2, RS3, RS4, RA4], 
		[LA1, LS1, LS2, LS3, LS4, LC3, LC4, CEN, RC1, RC2, RS1, RS2, RS3, RS4, RA4], 
		[LA1, LA2, LS1, LS2, LS3, LS4, LC3, LC4, RC1, RC2, RS1, RS2, RS3, RS4, RA3, RA4], 
		[LA1, LA2, LS1, LS2, LS3, LS4, LC3, LC4, CEN, RC1, RC2, RS1, RS2, RS3, RS4, RA3, RA4], 
		[LA1, LA2, LS1, LS2, LS3, LS4, LC2, LC3, LC4, RC1, RC2, RC3, RS1, RS2, RS3, RS4, RA3, RA4], 
		[LA1, LA2, LS1, LS2, LS3, LS4, LC2, LC3, LC4, CEN, RC1, RC2, RC3, RS1, RS2, RS3, RS4, RA3, RA4], 
		[LA1, LA2, LA3, LS1, LS2, LS3, LS4, LC2, LC3, LC4, RC1, RC2, RC3, RS1, RS2, RS3, RS4, RA2, RA3, RA4], 
		[LA1, LA2, LA3, LS1, LS2, LS3, LS4, LC2, LC3, LC4, CEN, RC1, RC2, RC3, RS1, RS2, RS3, RS4, RA2, RA3, RA4], 
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC2, LC3, LC4, RC1, RC2, RC3, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], 
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC2, LC3, LC4, CEN, RC1, RC2, RC3, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], 
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC1, LC2, LC3, LC4, RC1, RC2, RC3, RC4, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], 
		[LA1, LA2, LA3, LA4, LS1, LS2, LS3, LS4, LC1, LC2, LC3, LC4, CEN, RC1, RC2, RC3, RC4, RS1, RS2, RS3, RS4, RA1, RA2, RA3, RA4], // technically?
	];
	public static final keyLength:Int = NoteEK.TOTAL_DEFINED;
	public static final buttonLength:Int = ButtonEK.TOTAL_DEFINED;
	public static final bindschemeLength:Int = 26;
}

/**
 * Static class for handling advanced note-related animation loading
 */
class NoteLoader
{
	// helper regexes.
	static final digitEReg:EReg = ~/\d+(\.\w+)?$/;

	static final strumEReg:EReg = ~/^arrow(LEFT|DOWN|UP|RIGHT)/;
	static final splashEReg:EReg = ~/^note splash (purple|blue|green|red) (\d)/;

	static final colorEReg:EReg = ~/^(purple|blue|green|red)/i;
	static final directionEReg:EReg = ~/^(left|down|up|right)/i;

	static final prupleEndHoldEReg:EReg = ~/^pruple end hold/;

	/**
	 * Performs Binary Search on sorted IStr array.
	 * @return Int the index of the matched string, or -1 if not found.
	 */
	static function bsearch (want:String, have:Array<IStr>):Int
	{
		var L:Int = 0;
		var R:Int = have.length - 1;
		while (L <= R) {
			var M:Int = L + R >> 1;
			var c:Int = Reflect.compare(want, have[M].str);
			if (c > 0) L = M + 1;
			else if (c < 0) R = M - 1;
			else return M;
		}

		return -1;
	}

	/**
	 * Extracts an array of index-string pair of the loaded frames.
	 */
	inline static function loadFrames (sprite:FlxSprite):Array<IStr>
		return [for (i in 0...sprite.frames.frames.length) { i:i, str:sprite.frames.frames[i].name }];

	/**
	 * Sorts an Array<IStr> by string.
	 */
	inline static function sortFrames (x:Array<IStr>)
		x.sort(function(a, b) return Reflect.compare(a.str, b.str));

	/**
	 * Given an Array<IStr> sorted by string, find the prefixes and their boundaries.
	 * Prefix is determined by trailing numbers, so it may be inaccurate. 
	 */
	inline static function findPrefixBoundaries (x:Array<IStr>)
	{
		var borders:Array<IStr> = [];
		var lastPx:String = '';
		for (j in 0...x.length) {
			digitEReg.match(x[j].str);
			var curPx:String = digitEReg.matchedLeft();
			if (curPx != lastPx) borders.push({ i:j, str:curPx });
			lastPx = curPx;
		}

		return borders;
	}

	inline static function _directionNoteName (s:String) 
	{
		return s.charAt(0).toUpperCase() + "1";
	}

	inline static function _colorNoteName (s:String) 
	{
		// I'm not sure how much speedup comparing only the first letter does but well
		return switch(s.charAt(0)) { 
					case 'p': "L1";
					case 'b': "D1";
					case 'g': "U1";
					case 'r': "R1";
					default: ""; // shouldn't happen
		};
	}

	/**
	 * Given an Array<IStr>, reformat each frame name with a new convention (strum)
	 */
	inline static function strumReformatFrames (frameISs:Array<IStr>)
	{
		for (frameIS in frameISs) {
			if (strumEReg.match(frameIS.str)) { // Remap "arrowLEFT" etc
				var noteName = _directionNoteName(strumEReg.matched(1));
				frameIS.str = noteName + " arrow" + strumEReg.matchedRight();
				continue;
			}

			if (directionEReg.match(frameIS.str)) { // Remap colors to new note names
				var noteName = _directionNoteName(directionEReg.matched(1));
				frameIS.str = noteName + directionEReg.matchedRight(); // Strum names probably do not need padding.
			}
		}
	}

	/**
	 * Given an Array<IStr>, reformat each frame name with a new convention (note)
	 */
	inline static function noteReformatFrames (frameISs:Array<IStr>)
	{
		for (frameIS in frameISs) {
			if (prupleEndHoldEReg.match(frameIS.str)) { // Ugh
				frameIS.str = "L1 hold end" + prupleEndHoldEReg.matchedRight();
				continue;
			}

			if (colorEReg.match(frameIS.str)) { // Remap colors to new note names
				var noteName = _colorNoteName(colorEReg.matched(1));

				// Add padding if the remainder starts with a number. 
				// This is a consequence of the note names being named that way but idc
				var a = colorEReg.matchedPos();
				var ch:Null<Int> = frameIS.str.charCodeAt(a.pos + a.len);
				if (48 <= ch && ch < 58) noteName += " ";
				frameIS.str = noteName + colorEReg.matchedRight();
			}
		}
	}

	/**
	 * Given an Array<IStr>, reformat each frame name with a new convention (splash)
	 */
	inline static function splashReformatFrames (frameISs:Array<IStr>)
	{
		for (frameIS in frameISs) {
			if (splashEReg.match(frameIS.str)) { // Remap colors to new note names
				var noteName = _colorNoteName(splashEReg.matched(1));

				frameIS.str = noteName + "splash" + splashEReg.matched(2) + " " + splashEReg.matchedRight();
			}
		}
	}

	/**
	 * Hard replace: copy the offset and animation of a name to another.
	 */
	inline static function charHardReplace (char:Character, from:String, to:String)
	{
		var offset = char.animOffsets.get(from);
		var anim = char.animation.getByName(from);

		char.addOffset(to, offset[0], offset[1]);
		char.animation.add(to, anim.frames, anim.frameRate, anim.looped, anim.flipX, anim.flipY);
	}

	/**
	 * Soft replace: Perform hardreplace only if possible.
	 */
	inline static function charSoftReplace (char:Character, from:String, to:String)
		if (char.animOffsets.exists(from) && !char.animOffsets.exists(to)) charHardReplace(char, from, to);

	/**
	 * Loads (pixel) animations of given a Note object, a Key Scheme, 
	 * the number of columns recorded, a set frame name suffixes and their corresponding row number.
	 * Expects the Note object to have frames loaded already.
	 *
	 * @param scheme	Array of Key Enums for each key.
	 * @param note		(Assumed Note) object to load animations for
	 * @param column_n	Number of columns recorded.
	 * @param pTerms	Array of suffixes to be appended to the key name as the animation name.
	 * @param pRowIss	Array of array of (row) indices to be applied for each animation.
	 */
	public static function loadPixelNoteAnimsByKeyScheme (scheme:Array<NoteEK>, note:FlxSprite, column_n:Int, pTerms:Array<String>, pRowIss:Array<Array<Int>>)
	{
		final columnPresets:Array<Int> = [1, 4, 5, 8, 9, 24, 2147483647];
		var preset_i:Int = -1;
		while (column_n >= columnPresets[preset_i + 1]) preset_i += 1; // Linear search to find the closest column preset to apply
		if (preset_i == -1) {
			trace('No columns found. Halting. Crashes may be expected.');
			return;
		}

		// For each key:
		for (id in scheme) {
			var key:Key = NoteList.keys[id];
			var key_k:Int = key.pixelIds[preset_i];

			for (n in 0...pTerms.length) if (pTerms[n] != null) {
				note.animation.add(key.id + pTerms[n], [for (pRowI in pRowIss[n]) column_n * pRowI + key_k]);
			}
		}
	}

	/**
	 * Loads (pixel) animations of given a StrumNote object, a Key Scheme, 
	 * the number of columns recorded, a set frame name suffixes and their corresponding row number.
	 * Expects the Note object to have frames loaded already.
	 *
	 * @param id		NoteEK to render.
	 * @param note		(Assumed StrumNote) object to load animations for
	 * @param column_n	Number of columns recorded.
	 * @param pTerms	Array of suffixes to be appended to the key name as the animation name.
	 * @param pRowIss	Array of array of (row) indices to be applied for each animation.
	 */
	public static function loadPixelStrumNoteAnimsByKey (id:NoteEK, note:FlxSprite, column_n:Int, pTerms:Array<String>, pRowIss:Array<Array<Int>>)
	{
		final columnPresets:Array<Int> = [1, 4, 5, 8, 9, 24, 2147483647];
		var preset_i:Int = -1;
		while (column_n >= columnPresets[preset_i + 1]) preset_i += 1; // Linear search to find the closest column preset to apply
		if (preset_i == -1) {
			trace('No columns found. Halting. Crashes may be expected.');
			return;
		}

		var key:Key = NoteList.keys[id];
		var key_k:Int = key.pixelIds[preset_i];

		for (n in 0...pTerms.length) if (pTerms[n] != null) {
			note.animation.add(pTerms[n], [for (pRowI in pRowIss[n]) column_n * pRowI + key_k], 24, false);
		}
	}

	/**
	 * Loads animations of given a Note object, a Key Scheme and a set frame name suffixes.
	 * Expects the Note object to have frames loaded already.
	 *
	 * @param scheme	Array of Key Enums for each key.
	 * @param note		(Assumed Note) object to load animations for
	 * @param qTerms	Array of suffixes to be appended to the key name for searching.
	 * @param pTerms	Array of suffixes to be appended to the key name as the animation name.
	 */
	public static function loadNoteAnimsByKeyScheme (scheme:Array<NoteEK>, note:FlxSprite, qTerms:Array<String>, pTerms:Array<String>)
	{
		// Get an index-string pair of the loaded frames
		var frameISs:Array<IStr> = loadFrames(note);
		noteReformatFrames(frameISs);
		sortFrames(frameISs);
		
		// Get the unique prefixes of the frames
		var borders:Array<IStr> = findPrefixBoundaries(frameISs);

		// For each suffix
		for (n in 0...pTerms.length) { 
			// Get the frame indices for each key
			for (id in scheme) {
				var key:Key = NoteList.keys[id];
				var key_k:Int = -1;
				for (name in key.names) {
					key_k = bsearch(name + qTerms[n], borders);
					if (key_k != -1) break;
				}

				if (key_k == -1) {
					trace('Key ${key.id} sprite not found. Skipping. Crashes may be expected.');
					continue;
				}

				#if debug
				trace('Key ${key.id} using animation ${borders[key_k].str}');
				#end

				var border_L:Int = borders[key_k].i;
				var border_R:Int = key_k == borders.length - 1 ? frameISs.length : borders[key_k + 1].i;
				var indices:Array<Int> = [for (j in border_L...border_R) frameISs[j].i];
				// trace('indices: for ${key.id + pTerms[n]} $indices');
				note.animation.add(key.id + pTerms[n], indices);
			}
		}
	}

	/**
	 * Loads animations of given a NoteSplash object, a Key Scheme and a set frame name suffixes.
	 * Expects the Note object to have frames loaded already.
	 *
	 * This code is identical to loadNoteAnimsByKeyScheme, with only the type, reformat function and animation settings changed.
	 *
	 * @param scheme	Array of Key Enums for each key.
	 * @param note		(Assumed NoteSplash) object to load animations for
	 * @param qTerms	Array of suffixes to be appended to the key name for searching.
	 * @param pTerms	Array of suffixes to be appended to the key name as the animation name.
	 */
	public static function loadSplashAnimsByKeyScheme (scheme:Array<NoteEK>, note:FlxSprite, qTerms:Array<String>, pTerms:Array<String>)
	{
		// Get an index-string pair of the loaded frames
		var frameISs:Array<IStr> = loadFrames(note);
		splashReformatFrames(frameISs);
		sortFrames(frameISs);
		
		// Get the unique prefixes of the frames
		var borders:Array<IStr> = findPrefixBoundaries(frameISs);

		// For each suffix
		for (n in 0...pTerms.length) { 
			// Get the frame indices for each key
			for (id in scheme) {
				var key:Key = NoteList.keys[id];
				var key_k:Int = -1;
				for (name in key.names) {
					key_k = bsearch(name + qTerms[n], borders);
					if (key_k != -1) break;
				}

				if (key_k == -1) {
					trace('Key ${key.id} sprite not found. Skipping. Crashes may be expected.');
					continue;
				}

				#if debug
				trace('Key ${key.id} using animation ${borders[key_k].str}');
				#end

				var border_L:Int = borders[key_k].i;
				var border_R:Int = key_k == borders.length - 1 ? frameISs.length : borders[key_k + 1].i;
				var indices:Array<Int> = [for (j in border_L...border_R) frameISs[j].i];
				// trace('indices: for ${key.id + pTerms[n]} $indices');
				note.animation.add(key.id + pTerms[n], indices, 24, false);
			}
		}
	}

	/**
	 * Loads animations of given a StrumNote object, a Key and a set frame name suffixes.
	 * Expects the StrumNote object to have frames loaded already.
	 *
	 * @param id		NoteEK to render.
	 * @param note		(Assumed StrumNote) object to load animations for
	 * @param qTerms	Array of suffixes to be appended to the key name for searching.
	 * @param pTerms	Array of names to be used as the animation name.
	 */
	public static function loadStrumNoteAnimsByKey (id:NoteEK, note:FlxSprite, qTerms:Array<String>, pTerms:Array<String>)
	{
		// Get an index-string pair of the loaded frames
		var frameISs:Array<IStr> = loadFrames(note);
		strumReformatFrames(frameISs);
		sortFrames(frameISs);
		
		// Get the unique prefixes of the frames
		var borders:Array<IStr> = findPrefixBoundaries(frameISs);

		// For each suffix
		var key:Key = NoteList.keys[id];
		for (n in 0...pTerms.length) { 
			// Get the frame indices for the key.
			var key_k:Int = -1;
			for (name in key.names) {
				key_k = bsearch(name + qTerms[n], borders);
				if (key_k != -1) break;
			}

			if (key_k == -1) {
				trace('Strum Key ${key.id} ${pTerms[n]} sprite not found. Skipping. Crashes may be expected.');
				continue;
			}

			#if debug
			trace('Strum Key ${key.id} ${pTerms[n]} using animation ${borders[key_k].str}');
			#end

			var border_L:Int = borders[key_k].i;
			var border_R:Int = key_k == borders.length - 1 ? frameISs.length : borders[key_k + 1].i;
			var indices:Array<Int> = [for (j in border_L...border_R) frameISs[j].i];
			// trace('indices: for ${pTerms[n]} $indices');
			note.animation.add(pTerms[n], indices, 24, false);
		}
	}

	/**
	 * Given a Character object and a Key Scheme, post-process the character by adding missing animations.
	 *
	 * @param scheme	Array of Key Enums for each key.
	 * @param char		Character object to postprocess
	 */
	public static function postprocessCharacter (scheme:Array<NoteEK>, char:Character, warn:Bool = true)
	{
		// Substitution of old names to new names
		final sublist:Array<String> = ['singLEFT', 'singDOWN', 'singUP', 'singRIGHT', 'singLEFTmiss', 'singDOWNmiss', 'singUPmiss', 'singRIGHTmiss'];
		final replist:Array<String> = ['singL1', 'singD1', 'singU1', 'singR1', 'singL1miss', 'singD1miss', 'singU1miss', 'singR1miss'];

		for (i in 0...sublist.length) charSoftReplace(char, sublist[i], replist[i]);

		// For each key in scheme, find a suitable replacement if animation doesn't already exist.
		// Speed is probably less of a problem here
		for (id in scheme) {
			var key:Key = NoteList.keys[id];
			
			// Search for 'singL1', etc
			var keyName:String = null;
			for (name in key.names) if (char.animOffsets.exists('sing' + name)) {
				keyName = name;
				break;
			}

			if (keyName == null) {
				if (warn) {
					trace('Animation sing${key.id} not found. Skipping. Crashes may be expected.');
				}
			} else if (keyName != key.id) charHardReplace(char, 'sing' + keyName, 'sing' + key.id);

			// Search for 'singL1miss', etc
			keyName = null;
			for (name in key.names) if (char.animOffsets.exists('sing' + name + 'miss')) {
				keyName = name;
				char.hasMissAnimations = true; // Existing code assumes this is true when *any* miss animation exists. idk why.
				break;
			}

			if (keyName != null && keyName != key.id) charHardReplace(char, 'sing' + keyName + 'miss', 'sing' + key.id + 'miss');

			// Since note animation suffices are dynamic now, it is hard to take care of them here.
			// Either include a separate function for those, or leave them unsupported. 
		}
	}
}