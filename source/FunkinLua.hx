#if LUA_ALLOWED
import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Convert;
#end

import animateatlas.AtlasFrameMaker;
import flixel.FlxG;
import flixel.addons.effects.FlxTrail;
import flixel.input.keyboard.FlxKey;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.text.FlxText;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.util.FlxTimer;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.util.FlxColor;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import openfl.Lib;
import openfl.display.BlendMode;
import openfl.filters.BitmapFilter;
import openfl.utils.Assets;
import flixel.math.FlxMath;
import flixel.util.FlxSave;
import flixel.addons.transition.FlxTransitionableState;
import flixel.system.FlxAssets.FlxShader;

import Type.ValueType;
import Controls;
import DialogueBoxPsych;
import Song;
import helper.NoteLoader.NoteList;

#if sys
import sys.io.File;
import sys.FileSystem;
#end

#if hscript
import hscript.Interp;
import hscript.Parser;
#end

#if desktop
import Discord;
#end

using StringTools;

@:allow(EditorLua)
class FunkinLua {
	public static var Function_Stop:Dynamic = 1;
	public static var Function_Continue:Dynamic = 0;
	public static var Function_StopLua:Dynamic = 2;

	public static var COLOR_INFO:FlxColor = 0x0088FF;

	// public var errorHandler:String->Void;
	#if LUA_ALLOWED
	public var lua:State = null;
	#end
	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var inPlayState:Bool = false;
	public var closed:Bool = false;
	public static var somethingClosed:Bool = false;

	#if hscript
	public static var haxeInterp:Interp = null;
	#end

	public function new(script:String) {
		#if LUA_ALLOWED
		lua = LuaL.newstate();
		LuaL.openlibs(lua);
		Lua.init_callbacks(lua);

		//trace('Lua version: ' + Lua.version());
		//trace("LuaJIT version: " + Lua.versionJIT());

		//LuaL.dostring(lua, CLENSE);
		try{
			var result:Dynamic = LuaL.dofile(lua, script);
			var resultStr:String = Lua.tostring(lua, result);
			if(resultStr != null && result != 0) {
				trace('Error on lua script! ' + resultStr);
				#if windows
				lime.app.Application.current.window.alert(resultStr, 'Error on lua script!');
				#else
				luaTrace('Error loading lua script: "$script"\n' + resultStr, true, false, FlxColor.RED);
				#end
				lua = null;
				return;
			}
		}catch(e:Dynamic){
			trace(e);
			return;
		}
		scriptName = script;
		trace('lua file loaded succesfully:' + script);

		// inPlayState
		inPlayState = SongPlayState.instance == PlayState.instance;
		set('inPlayState', inPlayState);

		// Lua shit
		set('Function_StopLua', Function_StopLua);
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', false);

		set('version', MainMenuState.psychEngineVersion.trim());


		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// Song/Week shit
		set('difficulty', PlayState.storyDifficulty);
		set('difficultyString', CoolUtil.difficultyString());

		// These are given default values to be overridden by the states
		set('isStoryMode', false);
		set('weekRaw', -1);
		set('week', '');
		set('seenCutscene', false);
		set('cameraX', 0);
		set('cameraY', 0);

		set('inGameOver', false);

		// Default character positions woooo
		set('defaultBoyfriendX', 0);
		set('defaultBoyfriendY', 0);
		set('defaultOpponentX', 0);
		set('defaultOpponentY', 0);
		set('defaultGirlfriendX', 0);
		set('defaultGirlfriendY', 0);

		// Some settings, no jokes
		set('downscroll', ClientPrefs.downScroll);
		set('middlescroll', ClientPrefs.middleScroll);
		set('framerate', ClientPrefs.framerate);
		set('ghostTapping', ClientPrefs.ghostTapping);
		set('wrongNoteMiss', ClientPrefs.wrongNoteMiss);
		set('showMissPress', ClientPrefs.showMissPress);
		set('hideHud', ClientPrefs.hideHud);
		set('timeBarType', ClientPrefs.timeBarType);
		set('scoreZoom', ClientPrefs.scoreZoom);
		set('cameraZoomOnBeat', ClientPrefs.camZooms);
		set('flashingLights', ClientPrefs.flashing);
		set('noteOffset', ClientPrefs.noteOffset);
		set('healthBarAlpha', ClientPrefs.healthBarAlpha);
		set('noResetButton', ClientPrefs.noReset);
		set('lowQuality', ClientPrefs.lowQuality);
		set('scriptName', scriptName);

		#if windows
		set('buildTarget', 'windows');
		#elseif linux
		set('buildTarget', 'linux');
		#elseif mac
		set('buildTarget', 'mac');
		#elseif html5
		set('buildTarget', 'browser');
		#elseif android
		set('buildTarget', 'android');
		#else
		set('buildTarget', 'unknown');
		#end

		// Let the state do the rest of the variable filling
		SongPlayState.instance.initLua(this);

		Lua_helper.add_callback(lua, "getRunningScripts", function(){
			var runningScripts:Array<String> = [];
			for (idx in 0...SongPlayState.instance.luaArray.length)
				runningScripts.push(SongPlayState.instance.luaArray[idx].scriptName);


			return runningScripts;
		});

		Lua_helper.add_callback(lua, "callOnLuas", function(?funcName:String, ?args:Array<Dynamic>, ignoreStops=false, ignoreSelf=true, ?exclusions:Array<String>) {
			if(funcName==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #1 to 'callOnLuas' (string expected, got nil)");
				#end
				return;
			}
			if(args==null)args = [];

			if(exclusions==null)exclusions=[];

			Lua.getglobal(lua, 'scriptName');
			var daScriptName = Lua.tostring(lua, -1);
			Lua.pop(lua, 1);
			if(ignoreSelf && !exclusions.contains(daScriptName))exclusions.push(daScriptName);
			SongPlayState.instance.callOnLuas(funcName, args, ignoreStops, exclusions);
		});

		Lua_helper.add_callback(lua, "callScript", function(?luaFile:String, ?funcName:String, ?args:Array<Dynamic>) {
			if(luaFile==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #1 to 'callScript' (string expected, got nil)");
				#end
				return;
			}
			if(funcName==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #2 to 'callScript' (string expected, got nil)");
				#end
				return;
			}
			if(args==null){
				args = [];
			}
			var cervix = luaFile + ".lua";
			if(luaFile.endsWith(".lua"))cervix=luaFile;
			var doPush = false;
			#if MODS_ALLOWED
			if(Paths.exists(Paths.modFolders(cervix)))
			{
				cervix = Paths.modFolders(cervix);
				doPush = true;
			}
			else if(Paths.exists(cervix))
			{
				doPush = true;
			}
			else {
				cervix = Paths.getPreloadPath(cervix);
				if(Paths.exists(cervix)) {
					doPush = true;
				}
			}
			#else
			cervix = Paths.getPreloadPath(cervix);
			if(Paths.exists(cervix)) {
				doPush = true;
			}
			#end
			if(doPush)
			{
				for (luaInstance in SongPlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
					{
						luaInstance.call(funcName, args);

						return;
					}

				}
			}
			Lua.pushnil(lua);

		});

		Lua_helper.add_callback(lua, "getGlobalFromScript", function(?luaFile:String, ?global:String) { // returns the global from a script
			if(luaFile==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #1 to 'getGlobalFromScript' (string expected, got nil)");
				#end
				return;
			}
			if(global==null){
				#if (linc_luajit >= "0.0.6")
				LuaL.error(lua, "bad argument #2 to 'getGlobalFromScript' (string expected, got nil)");
				#end
				return;
			}
			var cervix = luaFile + ".lua";
			if(luaFile.endsWith(".lua"))cervix=luaFile;
			var doPush = false;
			#if MODS_ALLOWED
			if(Paths.exists(Paths.modFolders(cervix)))
			{
				cervix = Paths.modFolders(cervix);
				doPush = true;
			}
			else if(Paths.exists(cervix))
			{
				doPush = true;
			}
			else {
				cervix = Paths.getPreloadPath(cervix);
				if(Paths.exists(cervix)) {
					doPush = true;
				}
			}
			#else
			cervix = Paths.getPreloadPath(cervix);
			if(Paths.exists(cervix)) {
				doPush = true;
			}
			#end
			if(doPush)
			{
				for (luaInstance in SongPlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
					{
						Lua.getglobal(luaInstance.lua, global);
						if(Lua.isnumber(luaInstance.lua,-1)){
							Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
						}else if(Lua.isstring(luaInstance.lua,-1)){
							Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
						}else if(Lua.isboolean(luaInstance.lua,-1)){
							Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
						}else{
							Lua.pushnil(lua);
						}
						// TODO: table

						Lua.pop(luaInstance.lua,1); // remove the global

						return;
					}

				}
			}
			Lua.pushnil(lua);
		});
		Lua_helper.add_callback(lua, "setGlobalFromScript", function(luaFile:String, global:String, val:Dynamic) { // returns the global from a script
			var cervix = luaFile + ".lua";
			if(luaFile.endsWith(".lua"))cervix=luaFile;
			var doPush = false;
			#if MODS_ALLOWED
			if(Paths.exists(Paths.modFolders(cervix)))
			{
				cervix = Paths.modFolders(cervix);
				doPush = true;
			}
			else if(Paths.exists(cervix))
			{
				doPush = true;
			}
			else {
				cervix = Paths.getPreloadPath(cervix);
				if(Paths.exists(cervix)) {
					doPush = true;
				}
			}
			#else
			cervix = Paths.getPreloadPath(cervix);
			if(Paths.exists(cervix)) {
				doPush = true;
			}
			#end
			if(doPush)
			{
				for (luaInstance in SongPlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
					{
						luaInstance.set(global, val);
					}

				}
			}
			Lua.pushnil(lua);
		});
		/*Lua_helper.add_callback(lua, "getGlobals", function(luaFile:String) { // returns a copy of the specified file's globals
			var cervix = luaFile + ".lua";
			if(luaFile.endsWith(".lua"))cervix=luaFile;
			var doPush = false;
			#if MODS_ALLOWED
			if(Paths.exists(Paths.modFolders(cervix)))
			{
				cervix = Paths.modFolders(cervix);
				doPush = true;
			}
			else if(Paths.exists(cervix))
			{
				doPush = true;
			}
			else {
				cervix = Paths.getPreloadPath(cervix);
				if(Paths.exists(cervix)) {
					doPush = true;
				}
			}
			#else
			cervix = Paths.getPreloadPath(cervix);
			if(Paths.exists(cervix)) {
				doPush = true;
			}
			#end
			if(doPush)
			{
				for (luaInstance in SongPlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
					{
						Lua.newtable(lua);
						var tableIdx = Lua.gettop(lua);

						Lua.pushvalue(luaInstance.lua, Lua.LUA_GLOBALSINDEX);
						Lua.pushnil(luaInstance.lua);
						while(Lua.next(luaInstance.lua, -2) != 0) {
							// key = -2
							// value = -1

							var pop:Int = 0;

							// Manual conversion
							// first we convert the key
							if(Lua.isnumber(luaInstance.lua,-2)){
								Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -2));
								pop++;
							}else if(Lua.isstring(luaInstance.lua,-2)){
								Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -2));
								pop++;
							}else if(Lua.isboolean(luaInstance.lua,-2)){
								Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -2));
								pop++;
							}
							// TODO: table


							// then the value
							if(Lua.isnumber(luaInstance.lua,-1)){
								Lua.pushnumber(lua, Lua.tonumber(luaInstance.lua, -1));
								pop++;
							}else if(Lua.isstring(luaInstance.lua,-1)){
								Lua.pushstring(lua, Lua.tostring(luaInstance.lua, -1));
								pop++;
							}else if(Lua.isboolean(luaInstance.lua,-1)){
								Lua.pushboolean(lua, Lua.toboolean(luaInstance.lua, -1));
								pop++;
							}
							// TODO: table

							if(pop==2)Lua.rawset(lua, tableIdx); // then set it
							Lua.pop(luaInstance.lua, 1); // for the loop
						}
						Lua.pop(luaInstance.lua,1); // end the loop entirely
						Lua.pushvalue(lua, tableIdx); // push the table onto the stack so it gets returned

						return;
					}

				}
			}
			Lua.pushnil(lua);
		});*/
		Lua_helper.add_callback(lua, "isRunning", function(luaFile:String) {
			var cervix = luaFile + ".lua";
			if(luaFile.endsWith(".lua"))cervix=luaFile;
			var doPush = false;
			#if MODS_ALLOWED
			if(Paths.exists(Paths.modFolders(cervix)))
			{
				cervix = Paths.modFolders(cervix);
				doPush = true;
			}
			else if(Paths.exists(cervix))
			{
				doPush = true;
			}
			else {
				cervix = Paths.getPreloadPath(cervix);
				if(Paths.exists(cervix)) {
					doPush = true;
				}
			}
			#else
			cervix = Paths.getPreloadPath(cervix);
			if(Paths.exists(cervix)) {
				doPush = true;
			}
			#end

			if(doPush)
			{
				for (luaInstance in SongPlayState.instance.luaArray)
				{
					if(luaInstance.scriptName == cervix)
						return true;

				}
			}
			return false;
		});


		Lua_helper.add_callback(lua, "addLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) { //would be dope asf.
			var cervix = luaFile + ".lua";
			if(luaFile.endsWith(".lua"))cervix=luaFile;
			var doPush = false;
			#if MODS_ALLOWED
			if(Paths.exists(Paths.modFolders(cervix)))
			{
				cervix = Paths.modFolders(cervix);
				doPush = true;
			}
			else if(Paths.exists(cervix))
			{
				doPush = true;
			}
			else {
				cervix = Paths.getPreloadPath(cervix);
				if(Paths.exists(cervix)) {
					doPush = true;
				}
			}
			#else
			cervix = Paths.getPreloadPath(cervix);
			if(Paths.exists(cervix)) {
				doPush = true;
			}
			#end

			if(doPush)
			{
				if(!ignoreAlreadyRunning)
				{
					for (luaInstance in SongPlayState.instance.luaArray)
					{
						if(luaInstance.scriptName == cervix)
						{
							luaTrace('The script "' + cervix + '" is already running!');
							return;
						}
					}
				}
				SongPlayState.instance.luaArray.push(new FunkinLua(cervix));
				return;
			}
			luaTrace("Script doesn't exist!", false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "removeLuaScript", function(luaFile:String, ?ignoreAlreadyRunning:Bool = false) { //would be dope asf.
			var cervix = luaFile + ".lua";
			if(luaFile.endsWith(".lua"))cervix=luaFile;
			var doPush = false;
			#if MODS_ALLOWED
			if(Paths.exists(Paths.modFolders(cervix))) {
				cervix = Paths.modFolders(cervix);
				doPush = true;
			}
			else if(Paths.exists(cervix))
			{
				doPush = true;
			}
			else {
				cervix = Paths.getPreloadPath(cervix);
				if(Paths.exists(cervix)) {
					doPush = true;
				}
			}
			#else
			cervix = Paths.getPreloadPath(cervix);
			if(Paths.exists(cervix)) {
				doPush = true;
			}
			#end

			if(doPush)
			{
				if(!ignoreAlreadyRunning)
				{
					for (luaInstance in SongPlayState.instance.luaArray)
					{
						if(luaInstance.scriptName == cervix)
						{
							//luaTrace('The script "' + cervix + '" is already running!');

							SongPlayState.instance.luaArray.remove(luaInstance);
							return;
						}
					}
				}
				return;
			}
			luaTrace("Script doesn't exist!", false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "runHaxeCode", function(codeToRun:String) {
			#if hscript
			initHaxeInterp();

			try {
				var myFunction:Dynamic = haxeInterp.expr(new Parser().parseString(codeToRun));
				myFunction();
			}
			catch (e:Dynamic) {
				switch(e)
				{
					case 'Null Function Pointer', 'SReturn':
						//nothing
					default:
						luaTrace(scriptName + ":" + lastCalledFunction + " - " + e, false, false, FlxColor.RED);
				}
			}
			#end
		});

		Lua_helper.add_callback(lua, "addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			#if hscript
			initHaxeInterp();

			try {
				var str:String = '';
				if(libPackage.length > 0)
					str = libPackage + '.';

				haxeInterp.variables.set(libName, Type.resolveClass(str + libName));
			}
			catch (e:Dynamic) {
				luaTrace(scriptName + ":" + lastCalledFunction + " - " + e, false, false, FlxColor.RED);
			}
			#end
		});

		Lua_helper.add_callback(lua, "loadSong", function(?name:String = null, ?difficultyNum:Int = -1) {
			if(name == null || name.length < 1)
				name = PlayState.instance.songName;
			if (difficultyNum == -1)
				difficultyNum = PlayState.storyDifficulty;

			var poop = Highscore.formatSong(name, difficultyNum);
			var playSong:SwagSong = Song.loadFromJson(poop, name);
			PlayState.storyDifficulty = difficultyNum;
			SongPlayState.instance.persistentUpdate = false;
			LoadingState.loadAndSwitchState(new PlayState().loadSong(playSong, name));

			SongPlayState.instance.insts.pause();
			SongPlayState.instance.insts.volume = 0;
			if(SongPlayState.instance.vocals != null)
			{
				SongPlayState.instance.vocals.pause();
				SongPlayState.instance.vocals.volume = 0;
			}
		});

		// Direct callback to the sortUnspawn function. Use if scrollspeeds are modified.
		Lua_helper.add_callback(lua, "sortUnspawn", function() {
			SongPlayState.instance.sortUnspawn();
			return true;
		});

		Lua_helper.add_callback(lua, "loadGraphic", function(variable:String, image:String, ?gridX:Int, ?gridY:Int) {
			var gX = gridX==null?0:gridX;
			var gY = gridY==null?0:gridY;
			var animated = gX!=0 || gY!=0;

			var spr:FlxSprite = getVarDirectly(variable);

			if(spr != null && image != null && image.length > 0)
			{
				spr.loadGraphic(Paths.image(image), animated, gX, gY);
			}
		});
		Lua_helper.add_callback(lua, "loadFrames", function(variable:String, image:String, spriteType:String = "sparrow") {
			var spr:FlxSprite = getVarDirectly(variable);

			if(spr != null && image != null && image.length > 0)
			{
				loadFrames(spr, image, spriteType);
			}
		});

		Lua_helper.add_callback(lua, "getProperty", function(variable:String) {
			@:privateAccess
			return getVar(getInstance(), variable);
		});
		Lua_helper.add_callback(lua, "setProperty", function(variable:String, value:Dynamic) {
			@:privateAccess
			return setVar(getInstance(), variable, value);
		});
		Lua_helper.add_callback(lua, "getPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic) {
			@:privateAccess
			var realObject:Dynamic = getVarDirectly(obj, true);

			if (Std.isOfType(realObject, FlxTypedGroup) || Std.isOfType(realObject, FlxTypedSpriteGroup)) {
				return getGroupStuff(realObject.members[index], variable);
			}

			var leArray:Dynamic = realObject[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					return leArray[variable];
				}
				return getGroupStuff(leArray, variable);
			}
			luaTrace("Object #" + index + " from group: " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return null;
		});
		Lua_helper.add_callback(lua, "setPropertyFromGroup", function(obj:String, index:Int, variable:Dynamic, value:Dynamic) {
			@:privateAccess
			var realObject:Dynamic = getVarDirectly(obj, true);

			if (Std.isOfType(realObject, FlxTypedGroup) || Std.isOfType(realObject, FlxTypedSpriteGroup)) {
				setGroupStuff(realObject.members[index], variable, value);
				return;
			}

			var leArray:Dynamic = realObject[index];
			if(leArray != null) {
				if(Type.typeof(variable) == ValueType.TInt) {
					leArray[variable] = value;
					return;
				}
				setGroupStuff(leArray, variable, value);
			}
		});
		Lua_helper.add_callback(lua, "removeFromGroup", function(obj:String, index:Int, dontDestroy:Bool = false) {
			if(Std.isOfType(Reflect.getProperty(getInstance(), obj), FlxTypedGroup)) {
				var sex = Reflect.getProperty(getInstance(), obj).members[index];
				if(!dontDestroy)
					sex.kill();
				Reflect.getProperty(getInstance(), obj).remove(sex, true);
				if(!dontDestroy)
					sex.destroy();
				return;
			}
			Reflect.getProperty(getInstance(), obj).remove(Reflect.getProperty(getInstance(), obj)[index]);
		});
		Lua_helper.add_callback(lua, "getPropertyFromClass", function(classVar:String, variable:String) {
			var thing:Dynamic = Type.resolveClass(classVar);
			@:privateAccess
			return getVar(thing, variable);
		});
		Lua_helper.add_callback(lua, "setPropertyFromClass", function(classVar:String, variable:String, value:Dynamic) {
			var thing:Dynamic = Type.resolveClass(classVar);
			@:privateAccess
			return setVar(thing, variable, value);
		});
		Lua_helper.add_callback(lua, "getPropertyFromObject", function(tag:String, variable:String) {
			var spr:FlxSprite = SongPlayState.instance.getLuaObject(tag);
			@:privateAccess
			return getVar(spr, variable);
		});
		Lua_helper.add_callback(lua, "setPropertyFromObject", function(tag:String, variable:String, value:Dynamic) {
			var spr:FlxSprite = SongPlayState.instance.getLuaObject(tag);
			@:privateAccess
			return setVar(spr, variable, value);
		});

		//shitass stuff for epic coders like me B)  *image of obama giving himself a medal*
		Lua_helper.add_callback(lua, "getObjectOrder", function(obj:String) {
			var leObj:FlxBasic = getVarDirectly(obj);

			if(leObj != null)
			{
				return getInstance().members.indexOf(leObj);
			}
			luaTrace("Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return -1;
		});
		Lua_helper.add_callback(lua, "setObjectOrder", function(obj:String, position:Int) {
			var leObj:FlxBasic = getVarDirectly(obj);

			if(leObj != null) {
				getInstance().remove(leObj, true);
				getInstance().insert(position, leObj);
				return;
			}
			luaTrace("Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
		});

		// gay ass tweens
		Lua_helper.add_callback(lua, "doTweenX", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {x: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.add_callback(lua, "doTweenY", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {y: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.add_callback(lua, "doTweenAngle", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {angle: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.add_callback(lua, "doTweenAlpha", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {alpha: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.add_callback(lua, "doTweenZoom", function(tag:String, vars:String, value:Dynamic, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(penisExam, {zoom: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});
		Lua_helper.add_callback(lua, "doTweenColor", function(tag:String, vars:String, targetColor:String, duration:Float, ease:String) {
			var penisExam:Dynamic = tweenShit(tag, vars);
			if(penisExam != null) {
				var color:Int = Std.parseInt(targetColor);
				if(!targetColor.startsWith('0x')) color = Std.parseInt('0xff' + targetColor);

				var curColor:FlxColor = penisExam.color;
				curColor.alphaFloat = penisExam.alpha;
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.color(penisExam, duration, curColor, color, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.modchartTweens.remove(tag);
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
					}
				}));
			} else {
				luaTrace('Couldnt find object: ' + vars, false, false, FlxColor.RED);
			}
		});

		//Tween shit, but for strums
		Lua_helper.add_callback(lua, "noteTweenX", function(tag:String, noteTag:Dynamic, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			var testicle:StrumNote = SongPlayState.instance.getStrumByTag(noteTag);

			if(testicle != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {x: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.add_callback(lua, "noteTweenY", function(tag:String, noteTag:Dynamic, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			var testicle:StrumNote = SongPlayState.instance.getStrumByTag(noteTag);

			if(testicle != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {y: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.add_callback(lua, "noteTweenAngle", function(tag:String, noteTag:Dynamic, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			var testicle:StrumNote = SongPlayState.instance.getStrumByTag(noteTag);

			if(testicle != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {angle: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.add_callback(lua, "noteTweenDirection", function(tag:String, noteTag:Dynamic, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			var testicle:StrumNote = SongPlayState.instance.getStrumByTag(noteTag);

			if(testicle != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {direction: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.add_callback(lua, "noteTweenAlpha", function(tag:String, noteTag:Dynamic, value:Dynamic, duration:Float, ease:String) {
			cancelTween(tag);
			var testicle:StrumNote = SongPlayState.instance.getStrumByTag(noteTag);

			if(testicle != null) {
				SongPlayState.instance.modchartTweens.set(tag, FlxTween.tween(testicle, {alpha: value}, duration, {ease: getFlxEaseByString(ease),
					onComplete: function(twn:FlxTween) {
						SongPlayState.instance.callOnLuas('onTweenCompleted', [tag]);
						SongPlayState.instance.modchartTweens.remove(tag);
					}
				}));
			}
		});
		Lua_helper.add_callback(lua, "cancelTween", function(tag:String) {
			cancelTween(tag);
		});

		Lua_helper.add_callback(lua, "runTimer", function(tag:String, time:Float = 1, loops:Int = 1) {
			cancelTimer(tag);
			SongPlayState.instance.modchartTimers.set(tag, new FlxTimer().start(time, function(tmr:FlxTimer) {
				if(tmr.finished) {
					SongPlayState.instance.modchartTimers.remove(tag);
				}
				SongPlayState.instance.callOnLuas('onTimerCompleted', [tag, tmr.loops, tmr.loopsLeft]);
				//trace('Timer Completed: ' + tag);
			}, loops));
		});
		Lua_helper.add_callback(lua, "cancelTimer", function(tag:String) {
			cancelTimer(tag);
		});

		// Strum Stuff
		Lua_helper.add_callback(lua, "makeLuaStrum", function(tag:String, noteData:Int, player:Int, x:Float = 0, y:Float = 0) {
			tag = tag.replace('.', '');
			if (SongPlayState.instance.modchartObjects.exists(tag)) {
				luaTrace('Tag name $tag already used.', false, false, FlxColor.RED);
				return false;
			}
			var stm:StrumNote = new ModchartStrum(x, y, noteData, player);

			stm.downScroll = ClientPrefs.downScroll;
			stm.alpha = player < 1 ? ClientPrefs.opponentStrums ? ClientPrefs.middleScroll ? 0.35 : 1 : 0 : 1;
			stm.showControl = player == 1 ? ClientPrefs.strumHint : 0;
			stm.playAnim('static');

			SongPlayState.instance.modchartObjects.set(tag, stm);
			return true;
		});
		Lua_helper.add_callback(lua, "addLuaStrum", function(tag:String) {
			var thing:Dynamic = SongPlayState.instance.modchartObjects.get(tag);
			if (thing != null && Std.isOfType(thing, ModchartStrum)) {
				var stm:ModchartStrum = cast thing;
				if (!stm.wasAdded) {
					SongPlayState.instance.strumsByData[stm.noteData].add(stm);
					SongPlayState.instance.strumLineNotes.add(stm);
					stm.wasAdded = true;
				}
				return true;
			} else {
				luaTrace('$tag is not a LuaStrum.', false, false, FlxColor.RED);
				return false;
			}
		});
		/// Don't do this when there are some notes bound to the strum. No checking is done.
		Lua_helper.add_callback(lua, "removeLuaStrum", function(tag:String, destroy:Bool = true) {
			var thing:Dynamic = SongPlayState.instance.modchartObjects.get(tag);
			if (thing != null && Std.isOfType(thing, ModchartStrum)) {
				var stm:ModchartStrum = cast thing;

				if (destroy) stm.kill();

				if (stm.wasAdded) {
					SongPlayState.instance.strumsByData[stm.noteData].remove(stm, true);
					SongPlayState.instance.strumLineNotes.remove(stm, true);
					stm.wasAdded = false;
				}

				if (destroy) {
					stm.destroy();
					SongPlayState.instance.modchartObjects.remove(tag);
				}

				return true;
			} else {
				luaTrace('$tag is not a LuaStrum.', false, false, FlxColor.RED);
				return false;
			}
		});
		Lua_helper.add_callback(lua, "bindStrum", function(noteID:Int, tag:String) {
			var thing:Dynamic = SongPlayState.instance.modchartObjects.get(tag);
			var thung:Dynamic = SongPlayState.instance.noteMap.get(noteID);
			if (thing != null && (thing == null || Std.isOfType(thing, StrumNote)) && Std.isOfType(thung, Note)) {
				var stm:StrumNote = cast thing;
				var note:Note = cast thung;

				note.strum = stm;

				return true;
			} else {
				luaTrace('Bind Failed.', false, false, FlxColor.RED);
				return false;
			}
		});

		// Character Stuff
		Lua_helper.add_callback(lua, "loadLuaCharacter", function(tag:String, name:String, player:Bool, x:Float = 0, y:Float = 0) {
			tag = tag.replace('.', '');
			if (SongPlayState.instance.modchartObjects.exists(tag)) {
				luaTrace('Tag name $tag already used.', false, false, FlxColor.RED);
				return false;
			}
			var cha:ModchartCharacter = new ModchartCharacter(0, 0, name);
			cha.postprocess(Note.SCHEME);

			@:privateAccess
			PlayState.instance.startCharacterPos(cha);
			cha.x += x;
			cha.y += y;
			@:privateAccess
			PlayState.instance.startCharacterLua(cha.curCharacter);
			if (player) {
				PlayState.instance.boyfriendGroup.add(cha);
			} else {
				PlayState.instance.dadGroup.add(cha);
			}
			cha.playerSide = player;
			cha.alpha = 0.00001;

			SongPlayState.instance.modchartObjects.set(tag, cha);
			return true;
		});
		Lua_helper.add_callback(lua, "activateLuaCharacter", function(tag:String) {
			var thing:Dynamic = SongPlayState.instance.modchartObjects.get(tag);
			if (thing != null && Std.isOfType(thing, ModchartCharacter)) {
				var cha:ModchartCharacter = cast thing;
				if (!cha.wasAdded) {
					if (cha.playerSide) {
						PlayState.instance.activeBFs.push(cha);
					} else {
						PlayState.instance.activeDads.push(cha);
					}
					cha.alpha = 1;
					cha.wasAdded = true;
				}
				return true;
			} else {
				luaTrace('$tag is not a LuaCharacter.', false, false, FlxColor.RED);
				return false;
			}
		});
		Lua_helper.add_callback(lua, "deactivateLuaCharacter", function(tag:String, destroy:Bool = true) {
			var thing:Dynamic = SongPlayState.instance.modchartObjects.get(tag);
			if (thing != null && Std.isOfType(thing, ModchartCharacter)) {
				var cha:ModchartCharacter = cast thing;

				if (destroy) cha.kill();

				if (cha.wasAdded) {
					if (cha.playerSide) {
						PlayState.instance.activeBFs.remove(cha);
						if (destroy) PlayState.instance.boyfriendGroup.remove(cha);
					} else {
						PlayState.instance.activeDads.remove(cha);
						if (destroy) PlayState.instance.dadGroup.remove(cha);
					}
					cha.alpha = 0.00001;
					cha.wasAdded = false;
				}

				if (destroy) {
					cha.destroy();
					SongPlayState.instance.modchartObjects.remove(tag);
				}

				return true;
			} else {
				luaTrace('$tag is not a LuaCharacter.', false, false, FlxColor.RED);
				return false;
			}
		});

		/*Lua_helper.add_callback(lua, "getPropertyAdvanced", function(varsStr:String) {
			var variables:Array<String> = varsStr.replace(' ', '').split(',');
			var leClass:Class<Dynamic> = Type.resolveClass(variables[0]);
			if(variables.length > 2) {
				var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
				if(variables.length > 3) {
					for (i in 2...variables.length-1) {
						curProp = Reflect.getProperty(curProp, variables[i]);
					}
				}
				return Reflect.getProperty(curProp, variables[variables.length-1]);
			} else if(variables.length == 2) {
				return Reflect.getProperty(leClass, variables[variables.length-1]);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "setPropertyAdvanced", function(varsStr:String, value:Dynamic) {
			var variables:Array<String> = varsStr.replace(' ', '').split(',');
			var leClass:Class<Dynamic> = Type.resolveClass(variables[0]);
			if(variables.length > 2) {
				var curProp:Dynamic = Reflect.getProperty(leClass, variables[1]);
				if(variables.length > 3) {
					for (i in 2...variables.length-1) {
						curProp = Reflect.getProperty(curProp, variables[i]);
					}
				}
				return Reflect.setProperty(curProp, variables[variables.length-1], value);
			} else if(variables.length == 2) {
				return Reflect.setProperty(leClass, variables[variables.length-1], value);
			}
		});*/

		//stupid bietch ass functions
		Lua_helper.add_callback(lua, "addScore", function(value:Int = 0) {
			SongPlayState.instance.score += value;
			SongPlayState.instance.recalculateRating();
		});
		Lua_helper.add_callback(lua, "addMisses", function(value:Int = 0) {
			SongPlayState.instance.missCount += value;
			SongPlayState.instance.recalculateRating();
		});
		Lua_helper.add_callback(lua, "addHits", function(value:Int = 0) {
			SongPlayState.instance.hitCount += value;
			SongPlayState.instance.recalculateRating();
		});
		Lua_helper.add_callback(lua, "setScore", function(value:Int = 0) {
			SongPlayState.instance.score = value;
			SongPlayState.instance.recalculateRating();
		});
		Lua_helper.add_callback(lua, "setMisses", function(value:Int = 0) {
			SongPlayState.instance.missCount = value;
			SongPlayState.instance.recalculateRating();
		});
		Lua_helper.add_callback(lua, "setHits", function(value:Int = 0) {
			SongPlayState.instance.hitCount = value;
			SongPlayState.instance.recalculateRating();
		});
		Lua_helper.add_callback(lua, "getScore", function() {
			return SongPlayState.instance.score;
		});
		Lua_helper.add_callback(lua, "getMisses", function() {
			return SongPlayState.instance.missCount;
		});
		Lua_helper.add_callback(lua, "getHits", function() {
			return SongPlayState.instance.hitCount;
		});

		Lua_helper.add_callback(lua, "callHitNote", function(value:Int = 0, byID:Bool = false) {
			if (byID && SongPlayState.instance.noteMap.exists(value)) {
				var note:Note = cast SongPlayState.instance.noteMap.get(value);
				SongPlayState.instance.hitNote(note);
			} else if (!byID && 0 <= value && value < SongPlayState.instance.notes.length) {
				SongPlayState.instance.hitNote(SongPlayState.instance.notes.members[value]);
			} else {
				luaTrace('Note #$value doesn\'t exist!', false, false, FlxColor.RED);
			}
		});

		Lua_helper.add_callback(lua, "setHealth", function(value:Float = 0) {
			SongPlayState.instance.health = value;
		});
		Lua_helper.add_callback(lua, "addHealth", function(value:Float = 0) {
			SongPlayState.instance.health += value;
		});
		Lua_helper.add_callback(lua, "getHealth", function() {
			return SongPlayState.instance.health;
		});

		Lua_helper.add_callback(lua, "getColorFromHex", function(color:String) {
			if(!color.startsWith('0x')) color = '0xff' + color;
			return Std.parseInt(color);
		});

		Lua_helper.add_callback(lua, "mouseClicked", function(button:String) {
			var boobs = FlxG.mouse.justPressed;
			switch(button){
				case 'middle':
					boobs = FlxG.mouse.justPressedMiddle;
				case 'right':
					boobs = FlxG.mouse.justPressedRight;
			}


			return boobs;
		});
		Lua_helper.add_callback(lua, "mousePressed", function(button:String) {
			var boobs = FlxG.mouse.pressed;
			switch(button){
				case 'middle':
					boobs = FlxG.mouse.pressedMiddle;
				case 'right':
					boobs = FlxG.mouse.pressedRight;
			}
			return boobs;
		});
		Lua_helper.add_callback(lua, "mouseReleased", function(button:String) {
			var boobs = FlxG.mouse.justReleased;
			switch(button){
				case 'middle':
					boobs = FlxG.mouse.justReleasedMiddle;
				case 'right':
					boobs = FlxG.mouse.justReleasedRight;
			}
			return boobs;
		});

		Lua_helper.add_callback(lua, "keyboardJustPressed", function(name:String) {
			return Reflect.getProperty(FlxG.keys.justPressed, name);
		});
		Lua_helper.add_callback(lua, "keyboardPressed", function(name:String) {
			return Reflect.getProperty(FlxG.keys.pressed, name);
		});
		Lua_helper.add_callback(lua, "keyboardReleased", function(name:String) {
			return Reflect.getProperty(FlxG.keys.justReleased, name);
		});

		Lua_helper.add_callback(lua, "anyGamepadJustPressed", function(name:String) {
			return FlxG.gamepads.anyJustPressed(name);
		});
		Lua_helper.add_callback(lua, "anyGamepadPressed", function(name:String) {
			return FlxG.gamepads.anyPressed(name);
		});
		Lua_helper.add_callback(lua, "anyGamepadReleased", function(name:String) {
			return FlxG.gamepads.anyJustReleased(name);
		});

		Lua_helper.add_callback(lua, "gamepadAnalogX", function(id:Int, ?leftStick:Bool = true) {
			return FlxG.gamepads.getByID(id).getXAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadAnalogY", function(id:Int, ?leftStick:Bool = true) {
			return FlxG.gamepads.getByID(id).getYAxis(leftStick ? LEFT_ANALOG_STICK : RIGHT_ANALOG_STICK);
		});
		Lua_helper.add_callback(lua, "gamepadJustPressed", function(id:Int, name:String) {
			return Reflect.getProperty(FlxG.gamepads.getByID(id).justPressed, name);
		});
		Lua_helper.add_callback(lua, "gamepadPressed", function(id:Int, name:String) {
			return Reflect.getProperty(FlxG.gamepads.getByID(id).pressed, name);
		});
		Lua_helper.add_callback(lua, "gamepadReleased", function(id:Int, name:String) {
			return Reflect.getProperty(FlxG.gamepads.getByID(id).justReleased, name);
		});

		var bindScheme:Array<String> = ClientPrefs.bindSchemes[4];
		var schemeID:Array<Int> = [for (i in 0...4) (NoteList.buttonEnums[bindScheme[i].substr(5)] : Int)];
		Lua_helper.add_callback(lua, "keyJustPressed", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = SongPlayState.instance.getControlNoteCheckerP(schemeID[0]);
				case 'down': key = SongPlayState.instance.getControlNoteCheckerP(schemeID[1]);
				case 'up': key = SongPlayState.instance.getControlNoteCheckerP(schemeID[2]);
				case 'right': key = SongPlayState.instance.getControlNoteCheckerP(schemeID[3]);
				case 'accept': key = SongPlayState.instance.getControl('ACCEPT');
				case 'back': key = SongPlayState.instance.getControl('BACK');
				case 'pause': key = SongPlayState.instance.getControl('PAUSE');
				case 'reset': key = SongPlayState.instance.getControl('RESET');
				case 'space': key = FlxG.keys.justPressed.SPACE;//an extra key for convinience
				case var name:
					if (name.startsWith('key')) {
						var id:Null<Int> = Std.parseInt(name.substr(3));
						if (id != null && 0 <= id && id < Note.TOTAL) key = SongPlayState.instance.getNoteCheckerP((id : Int));
					}
			}
			return key;
		});
		Lua_helper.add_callback(lua, "keyPressed", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = SongPlayState.instance.getControlNoteCheckerQ(schemeID[0]);
				case 'down': key = SongPlayState.instance.getControlNoteCheckerQ(schemeID[1]);
				case 'up': key = SongPlayState.instance.getControlNoteCheckerQ(schemeID[2]);
				case 'right': key = SongPlayState.instance.getControlNoteCheckerQ(schemeID[3]);
				case 'space': key = FlxG.keys.pressed.SPACE;//an extra key for convinience
				case var name:
					if (name.startsWith('key')) {
						var id:Null<Int> = Std.parseInt(name.substr(3));
						if (id != null && 0 <= id && id < Note.TOTAL) key = SongPlayState.instance.getNoteCheckerQ((id : Int));
					}
			}
			return key;
		});
		Lua_helper.add_callback(lua, "keyReleased", function(name:String) {
			var key:Bool = false;
			switch(name) {
				case 'left': key = SongPlayState.instance.getControlNoteCheckerR(schemeID[0]);
				case 'down': key = SongPlayState.instance.getControlNoteCheckerR(schemeID[1]);
				case 'up': key = SongPlayState.instance.getControlNoteCheckerR(schemeID[2]);
				case 'right': key = SongPlayState.instance.getControlNoteCheckerR(schemeID[3]);
				case 'space': key = FlxG.keys.justReleased.SPACE;//an extra key for convinience
				case var name:
					if (name.startsWith('key')) {
						var id:Null<Int> = Std.parseInt(name.substr(3));
						if (id != null && 0 <= id && id < Note.TOTAL) key = SongPlayState.instance.getNoteCheckerR((id : Int));
					}
			}
			return key;
		});
		Lua_helper.add_callback(lua, "addCharacterToList", function(name:String, type:String) {
			var charType:Int = 0;
			switch(type.toLowerCase()) {
				case 'dad': charType = 1;
				case 'gf' | 'girlfriend': charType = 2;
			}
			PlayState.instance.addCharacterToList(name, charType);
		});
		Lua_helper.add_callback(lua, "precacheImage", function(name:String) {
			Paths.returnGraphic(name);
		});
		Lua_helper.add_callback(lua, "precacheSound", function(name:String) {
			CoolUtil.precacheSound(name);
		});
		Lua_helper.add_callback(lua, "precacheMusic", function(name:String) {
			CoolUtil.precacheMusic(name);
		});
		Lua_helper.add_callback(lua, "triggerEvent", function(name:String, arg1:Dynamic, arg2:Dynamic) {
			var value1:String = arg1;
			var value2:String = arg2;
			SongPlayState.instance.triggerEventNote(name, value1, value2);
			//trace('Triggered event: ' + name + ', ' + value1 + ', ' + value2);
			return true;
		});

		Lua_helper.add_callback(lua, "startCountdown", function() {
			PlayState.instance.startCountdown();
			return true;
		});
		Lua_helper.add_callback(lua, "endSong", function() {
			SongPlayState.instance.clearAllNotes();
			SongPlayState.instance.endSong();
			return true;
		});
		Lua_helper.add_callback(lua, "restartSong", function(skipTransition:Bool = false) {
			SongPlayState.instance.persistentUpdate = false;
			PauseSubState.restartSong(skipTransition);
			return true;
		});
		Lua_helper.add_callback(lua, "exitSong", function(skipTransition:Bool = false) {
			if(skipTransition)
			{
				FlxTransitionableState.skipNextTransIn = true;
				FlxTransitionableState.skipNextTransOut = true;
			}

			PlayState.cancelMusicFadeTween();
			CustomFadeTransition.nextCamera = SongPlayState.instance.camOther;
			if(FlxTransitionableState.skipNextTransIn)
				CustomFadeTransition.nextCamera = null;

			if(PlayState.isStoryMode)
				MusicBeatState.switchState(new StoryMenuState());
			else
				MusicBeatState.switchState(new FreeplayState());

			FlxG.sound.playMusic(Paths.music('freakyMenu'));
			PlayState.changedDifficulty = false;
			PlayState.chartingMode = false;
			PlayState.instance.transitioning = true;
			WeekData.loadTheFirstEnabledMod();
			return true;
		});
		Lua_helper.add_callback(lua, "getSongPosition", function() {
			return Conductor.songPosition;
		});

		Lua_helper.add_callback(lua, "getCharacterX", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.x;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.x;
				default:
					return PlayState.instance.boyfriendGroup.x;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterX", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.x = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.x = value;
				default:
					PlayState.instance.boyfriendGroup.x = value;
			}
		});
		Lua_helper.add_callback(lua, "getCharacterY", function(type:String) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					return PlayState.instance.dadGroup.y;
				case 'gf' | 'girlfriend':
					return PlayState.instance.gfGroup.y;
				default:
					return PlayState.instance.boyfriendGroup.y;
			}
		});
		Lua_helper.add_callback(lua, "setCharacterY", function(type:String, value:Float) {
			switch(type.toLowerCase()) {
				case 'dad' | 'opponent':
					PlayState.instance.dadGroup.y = value;
				case 'gf' | 'girlfriend':
					PlayState.instance.gfGroup.y = value;
				default:
					PlayState.instance.boyfriendGroup.y = value;
			}
		});
		Lua_helper.add_callback(lua, "cameraSetTarget", function(target:String) {
			var isDad:Bool = false;
			if(target == 'dad') {
				isDad = true;
			}
			PlayState.instance.moveCamera(isDad);
			return isDad;
		});
		Lua_helper.add_callback(lua, "cameraShake", function(camera:String, intensity:Float, duration:Float) {
			cameraFromString(camera).shake(intensity, duration);
		});

		Lua_helper.add_callback(lua, "cameraFlash", function(camera:String, color:String, duration:Float,forced:Bool) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			cameraFromString(camera).flash(colorNum, duration,null,forced);
		});
		Lua_helper.add_callback(lua, "cameraFade", function(camera:String, color:String, duration:Float,forced:Bool) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			cameraFromString(camera).fade(colorNum, duration,false,null,forced);
		});
		Lua_helper.add_callback(lua, "setRatingPercent", function(value:Float) {
			SongPlayState.instance.ratingPercent = value;
		});
		Lua_helper.add_callback(lua, "setRatingName", function(value:String) {
			SongPlayState.instance.ratingName = value;
		});
		Lua_helper.add_callback(lua, "setRatingFC", function(value:String) {
			SongPlayState.instance.ratingFC = value;
		});
		Lua_helper.add_callback(lua, "getMouseX", function(camera:String) {
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		Lua_helper.add_callback(lua, "getMouseY", function(camera:String) {
			var cam:FlxCamera = cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});

		Lua_helper.add_callback(lua, "getMidpointX", function(variable:String) {
			var obj:FlxSprite = getVarDirectly(variable);
			if (obj != null) return obj.getMidpoint().x;

			return 0;
		});
		Lua_helper.add_callback(lua, "getMidpointY", function(variable:String) {
			var obj:FlxSprite = getVarDirectly(variable);
			if (obj != null) return obj.getMidpoint().y;

			return 0;
		});
		Lua_helper.add_callback(lua, "getGraphicMidpointX", function(variable:String) {
			var obj:FlxSprite = getVarDirectly(variable);
			if (obj != null) return obj.getGraphicMidpoint().x;

			return 0;
		});
		Lua_helper.add_callback(lua, "getGraphicMidpointY", function(variable:String) {
			var obj:FlxSprite = getVarDirectly(variable);
			if (obj != null) return obj.getGraphicMidpoint().y;

			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionX", function(variable:String) {
			var obj:FlxSprite = getVarDirectly(variable);
			if (obj != null) return obj.getScreenPosition().x;

			return 0;
		});
		Lua_helper.add_callback(lua, "getScreenPositionY", function(variable:String) {
			var obj:FlxSprite = getVarDirectly(variable);
			if (obj != null) return obj.getScreenPosition().y;

			return 0;
		});
		Lua_helper.add_callback(lua, "characterDance", function(character:String, index:Int = 0) {
			var cha = switch(character.toLowerCase()) {
				case 'dad':
					if (0 <= index && index < PlayState.instance.activeDads.length) PlayState.instance.activeDads[index];
					else null;
				case 'gf' | 'girlfriend':
					PlayState.instance.gf;
				default:
					if (0 <= index && index < PlayState.instance.activeBFs.length) PlayState.instance.activeBFs[index];
					else null;
			}
			if (cha != null) {
				cha.dance();
			}
		});
		Lua_helper.add_callback(lua, "characterSing", function(character:String, index:Int = 0, noteData:Int = 0,
			suffix:String = '', force:Bool = false) {
			var cha = switch(character.toLowerCase()) {
				case 'dad':
					if (0 <= index && index < PlayState.instance.activeDads.length) PlayState.instance.activeDads[index];
					else null;
				case 'gf' | 'girlfriend':
					PlayState.instance.gf;
				default:
					if (0 <= index && index < PlayState.instance.activeBFs.length) PlayState.instance.activeBFs[index];
					else null;
			}
			if (cha != null) {
				if (force) cha.singTime = -1000;
				cha.sing(noteData, suffix, -1, -1, -1, null);
			}
		});
		Lua_helper.add_callback(lua, "boyfriendMiss", function(index:Int = 0, noteData:Int = 0, suffix:String = '') {
			if (0 <= index && index < PlayState.instance.activeBFs.length) {
				PlayState.instance.activeBFs[index].miss(noteData, suffix);
			}
		});

		Lua_helper.add_callback(lua, "makeLuaSprite", function(tag:String, image:String, x:Float, y:Float) {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);
			if(image != null && image.length > 0)
			{
				leSprite.loadGraphic(Paths.image(image));
			}
			leSprite.antialiasing = ClientPrefs.globalAntialiasing;
			SongPlayState.instance.modchartSprites.set(tag, leSprite);
			leSprite.active = true;
		});
		Lua_helper.add_callback(lua, "makeAnimatedLuaSprite", function(tag:String, image:String, x:Float, y:Float, ?spriteType:String = "sparrow") {
			tag = tag.replace('.', '');
			resetSpriteTag(tag);
			var leSprite:ModchartSprite = new ModchartSprite(x, y);

			loadFrames(leSprite, image, spriteType);
			leSprite.antialiasing = ClientPrefs.globalAntialiasing;
			SongPlayState.instance.modchartSprites.set(tag, leSprite);
		});

		Lua_helper.add_callback(lua, "makeGraphic", function(obj:String, width:Int, height:Int, color:String) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

			var spr:FlxSprite = SongPlayState.instance.getLuaObject(obj,false);
			if(spr!=null) {
				SongPlayState.instance.getLuaObject(obj,false).makeGraphic(width, height, colorNum);
				return;
			}

			var object:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(object != null) {
				object.makeGraphic(width, height, colorNum);
			}
		});
		Lua_helper.add_callback(lua, "addAnimationByPrefix", function(obj:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			if(SongPlayState.instance.getLuaObject(obj,false)!=null) {
				var cock:FlxSprite = SongPlayState.instance.getLuaObject(obj,false);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			var cock:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(cock != null) {
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		Lua_helper.add_callback(lua, "addAnimation", function(obj:String, name:String, frames:Array<Int>, framerate:Int = 24, loop:Bool = true) {
			if(SongPlayState.instance.getLuaObject(obj,false)!=null) {
				var cock:FlxSprite = SongPlayState.instance.getLuaObject(obj,false);
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
				return;
			}

			var cock:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(cock != null) {
				cock.animation.add(name, frames, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});

		Lua_helper.add_callback(lua, "addAnimationByIndices", function(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			var strIndices:Array<String> = indices.trim().split(',');
			var die:Array<Int> = [];
			for (i in 0...strIndices.length) {
				die.push(Std.parseInt(strIndices[i]));
			}

			if(SongPlayState.instance.getLuaObject(obj, false)!=null) {
				var pussy:FlxSprite = SongPlayState.instance.getLuaObject(obj,false);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
				return true;
			}

			var pussy:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(pussy != null) {
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "playAnim", function(obj:String, name:String, forced:Bool = false, ?reverse:Bool = false, ?startFrame:Int = 0) {
			if (SongPlayState.instance.getLuaObject(obj, false) != null) {
				var luaObj:FlxSprite = PlayState.instance.getLuaObject(obj,false);
				if(luaObj.animation.getByName(name) != null)
				{
					luaObj.animation.play(name, forced, reverse, startFrame);
					if(Std.isOfType(luaObj, ModchartSprite))
					{
						//convert luaObj to ModchartSprite
						var obj:Dynamic = luaObj;
						var luaObj:ModchartSprite = obj;

						var daOffset = luaObj.animOffsets.get(name);
						if (luaObj.animOffsets.exists(name))
						{
							luaObj.offset.set(daOffset[0], daOffset[1]);
						}
						else
							luaObj.offset.set(0, 0);
					}
				}
				return true;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(spr != null) {
				if(spr.animation.getByName(name) != null)
				{
					if(Std.isOfType(spr, Character))
					{
						//convert spr to Character
						var obj:Dynamic = spr;
						var spr:Character = obj;
						spr.playAnim(name, forced, reverse, startFrame);
					}
					else
						spr.animation.play(name, forced, reverse, startFrame);
				}
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "addOffset", function(obj:String, anim:String, x:Float, y:Float) {
			if (SongPlayState.instance.modchartSprites.exists(obj)) {
				SongPlayState.instance.modchartSprites.get(obj).animOffsets.set(anim, [x, y]);
				return true;
			}

			var char:Character = Reflect.getProperty(getInstance(), obj);
			if(char != null) {
				char.addOffset(anim, x, y);
				return true;
			}
			return false;
		});

		Lua_helper.add_callback(lua, "setScrollFactor", function(obj:String, scrollX:Float, scrollY:Float) {
			if(SongPlayState.instance.getLuaObject(obj,false)!=null) {
				SongPlayState.instance.getLuaObject(obj,false).scrollFactor.set(scrollX, scrollY);
				return;
			}

			var object:FlxObject = Reflect.getProperty(getInstance(), obj);
			if(object != null) {
				object.scrollFactor.set(scrollX, scrollY);
			}
		});
		Lua_helper.add_callback(lua, "addLuaSprite", function(tag:String, front:Bool = false) {
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = SongPlayState.instance.modchartSprites.get(tag);
				if(!shit.wasAdded) {
					if(!inPlayState || front)
					{
						getInstance().add(shit);
					}
					else
					{
						if(PlayState.instance.isDead)
						{
							GameOverSubstate.instance.insert(GameOverSubstate.instance.members.indexOf(GameOverSubstate.instance.boyfriend), shit);
						}
						else
						{
							var position:Int = Std.int(
								Math.min(Math.min(
									PlayState.instance.members.indexOf(PlayState.instance.gfGroup),
									PlayState.instance.members.indexOf(PlayState.instance.boyfriendGroup)),
									PlayState.instance.members.indexOf(PlayState.instance.dadGroup))
									);
							PlayState.instance.insert(position, shit);
						}
					}
					shit.wasAdded = true;
					//trace('added a thing: ' + tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "setGraphicSize", function(obj:String, x:Int, y:Int = 0, updateHitbox:Bool = true) {
			if(SongPlayState.instance.getLuaObject(obj)!=null) {
				var shit:FlxSprite = SongPlayState.instance.getLuaObject(obj);
				shit.setGraphicSize(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			var poop:FlxSprite = getVarDirectly(obj);

			if(poop != null) {
				poop.setGraphicSize(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			luaTrace('Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "scaleObject", function(obj:String, x:Float, y:Float, updateHitbox:Bool = true) {
			if(SongPlayState.instance.getLuaObject(obj)!=null) {
				var shit:FlxSprite = SongPlayState.instance.getLuaObject(obj);
				shit.scale.set(x, y);
				if(updateHitbox) shit.updateHitbox();
				return;
			}

			var poop:FlxSprite = getVarDirectly(obj);

			if(poop != null) {
				poop.scale.set(x, y);
				if(updateHitbox) poop.updateHitbox();
				return;
			}
			luaTrace('Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "updateHitbox", function(obj:String) {
			if(SongPlayState.instance.getLuaObject(obj)!=null) {
				var shit:FlxSprite = SongPlayState.instance.getLuaObject(obj);
				shit.updateHitbox();
				return;
			}

			var poop:FlxSprite = getVarDirectly(obj);
			if(poop != null) {
				poop.updateHitbox();
				return;
			}
			luaTrace('Couldnt find object: ' + obj, false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "updateHitboxFromGroup", function(group:String, index:Int) {
			if(Std.isOfType(Reflect.getProperty(getInstance(), group), FlxTypedGroup)) {
				Reflect.getProperty(getInstance(), group).members[index].updateHitbox();
				return;
			}
			Reflect.getProperty(getInstance(), group)[index].updateHitbox();
		});

		Lua_helper.add_callback(lua, "isNoteChild", function(parentID:Int, childID:Int) {
			var parent:Note = cast SongPlayState.instance.noteMap.get(parentID);
			var child:Note = cast SongPlayState.instance.noteMap.get(childID);
			if (parent!=null && child!=null)
				return parent.tail.contains(child);

			luaTrace('${parentID} or ${childID} is not a valid note ID', false, false, FlxColor.RED);
			return false;
		});

		Lua_helper.add_callback(lua, "removeLuaSprite", function(tag:String, destroy:Bool = true) {
			if(!SongPlayState.instance.modchartSprites.exists(tag)) {
				return;
			}

			var pee:ModchartSprite = SongPlayState.instance.modchartSprites.get(tag);
			if(destroy) {
				pee.kill();
			}

			if(pee.wasAdded) {
				getInstance().remove(pee, true);
				pee.wasAdded = false;
			}

			if(destroy) {
				pee.destroy();
				SongPlayState.instance.modchartSprites.remove(tag);
			}
		});

		Lua_helper.add_callback(lua, "luaSpriteExists", function(tag:String) {
			return SongPlayState.instance.modchartSprites.exists(tag);
		});
		Lua_helper.add_callback(lua, "luaTextExists", function(tag:String) {
			return SongPlayState.instance.modchartTexts.exists(tag);
		});
		Lua_helper.add_callback(lua, "luaSoundExists", function(tag:String) {
			return SongPlayState.instance.modchartSounds.exists(tag);
		});

		Lua_helper.add_callback(lua, "setHealthBarIcon", function(leftIcon:String, rightIcon:String) {
			if (leftIcon == '') leftIcon = PlayState.instance.boyfriend.healthIcon;
			if (rightIcon == '') rightIcon = PlayState.instance.dad.healthIcon;
			if (PlayState.instance.iconP1.getCharacter() != leftIcon) PlayState.instance.iconP1.changeIcon(leftIcon);
			if (PlayState.instance.iconP2.getCharacter() != rightIcon) PlayState.instance.iconP2.changeIcon(rightIcon);
		});
		Lua_helper.add_callback(lua, "setHealthBarColors", function(leftHex:String, rightHex:String) {
			var left:FlxColor = Std.parseInt(leftHex);
			if(!leftHex.startsWith('0x')) left = Std.parseInt('0xff' + leftHex);
			var right:FlxColor = Std.parseInt(rightHex);
			if(!rightHex.startsWith('0x')) right = Std.parseInt('0xff' + rightHex);

			PlayState.instance.healthBar.createFilledBar(left, right);
			PlayState.instance.healthBar.updateBar();
		});
		Lua_helper.add_callback(lua, "setTimeBarColors", function(leftHex:String, rightHex:String) {
			var left:FlxColor = Std.parseInt(leftHex);
			if(!leftHex.startsWith('0x')) left = Std.parseInt('0xff' + leftHex);
			var right:FlxColor = Std.parseInt(rightHex);
			if(!rightHex.startsWith('0x')) right = Std.parseInt('0xff' + rightHex);

			PlayState.instance.timeBar.createFilledBar(right, left);
			PlayState.instance.timeBar.updateBar();
		});

		Lua_helper.add_callback(lua, "setObjectCamera", function(obj:String, camera:String = '') {
			/*if(SongPlayState.instance.modchartSprites.exists(obj)) {
				SongPlayState.instance.modchartSprites.get(obj).cameras = [cameraFromString(camera)];
				return true;
			}
			else if(SongPlayState.instance.modchartTexts.exists(obj)) {
				SongPlayState.instance.modchartTexts.get(obj).cameras = [cameraFromString(camera)];
				return true;
			}*/
			var real = SongPlayState.instance.getLuaObject(obj);
			if(real!=null){
				real.cameras = [cameraFromString(camera)];
				return true;
			}

			var object:FlxBasic = getVarDirectly(obj);

			if(object != null) {
				object.cameras = [cameraFromString(camera)];
				return true;
			}
			luaTrace("Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		Lua_helper.add_callback(lua, "setBlendMode", function(obj:String, blend:String = '') {
			var real = SongPlayState.instance.getLuaObject(obj);
			if(real!=null) {
				real.blend = blendModeFromString(blend);
				return true;
			}

			var spr:FlxSprite = getVarDirectly(obj);

			if(spr != null) {
				spr.blend = blendModeFromString(blend);
				return true;
			}
			luaTrace("Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
			return false;
		});
		Lua_helper.add_callback(lua, "screenCenter", function(obj:String, pos:String = 'xy') {
			var spr:FlxSprite = getVarDirectly(obj);

			if(spr != null)
			{
				switch(pos.trim().toLowerCase())
				{
					case 'x':
						spr.screenCenter(X);
						return;
					case 'y':
						spr.screenCenter(Y);
						return;
					default:
						spr.screenCenter(XY);
						return;
				}
			}
			luaTrace("Object " + obj + " doesn't exist!", false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "objectsOverlap", function(obj1:String, obj2:String) {
			var namesArray:Array<String> = [obj1, obj2];
			var objectsArray:Array<FlxSprite> = [];
			for (i in 0...namesArray.length)
			{
				var real = SongPlayState.instance.getLuaObject(namesArray[i]);
				if(real!=null) {
					objectsArray.push(real);
				} else {
					objectsArray.push(Reflect.getProperty(getInstance(), namesArray[i]));
				}
			}

			if(!objectsArray.contains(null) && FlxG.overlap(objectsArray[0], objectsArray[1]))
			{
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "getPixelColor", function(obj:String, x:Int, y:Int) {
			var spr:FlxSprite = getVarDirectly(obj);

			if(spr != null)
			{
				if(spr.framePixels != null) spr.framePixels.getPixel32(x, y);
				return spr.pixels.getPixel32(x, y);
			}
			return 0;
		});
		Lua_helper.add_callback(lua, "getRandomInt", function(min:Int, max:Int = FlxMath.MAX_VALUE_INT, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Int> = [];
			for (i in 0...excludeArray.length)
			{
				toExclude.push(Std.parseInt(excludeArray[i].trim()));
			}
			return FlxG.random.int(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "getRandomFloat", function(min:Float, max:Float = 1, exclude:String = '') {
			var excludeArray:Array<String> = exclude.split(',');
			var toExclude:Array<Float> = [];
			for (i in 0...excludeArray.length)
			{
				toExclude.push(Std.parseFloat(excludeArray[i].trim()));
			}
			return FlxG.random.float(min, max, toExclude);
		});
		Lua_helper.add_callback(lua, "getRandomBool", function(chance:Float = 50) {
			return FlxG.random.bool(chance);
		});
		Lua_helper.add_callback(lua, "startDialogue", function(dialogueFile:String, music:String = null) {
			var path:String;
			#if MODS_ALLOWED
			path = Paths.modsJson(Paths.formatToSongPath(Song.curSongName) + '/' + dialogueFile);
			if(!Paths.exists(path))
			#end
				path = Paths.json(Paths.formatToSongPath(Song.curSongName) + '/' + dialogueFile);

			luaTrace('Trying to load dialogue: ' + path);

			if(Paths.exists(path))
			{
				var shit:DialogueFile = DialogueBoxPsych.parseDialogue(path);
				if(shit.dialogue.length > 0) {
					PlayState.instance.startDialogue(shit, music);
					luaTrace('Successfully loaded dialogue', false, false, FlxColor.GREEN);
					return true;
				} else {
					luaTrace('Your dialogue file is badly formatted!', false, false, FlxColor.RED);
				}
			} else {
				luaTrace('Dialogue file not found', false, false, FlxColor.RED);
				PlayState.instance.startAndEnd();
			}
			return false;
		});
		Lua_helper.add_callback(lua, "startVideo", function(videoFile:String) {
			#if VIDEOS_ALLOWED
			if(Paths.exists(Paths.video(videoFile))) {
				PlayState.instance.startVideo(videoFile);
				return true;
			} else {
				luaTrace('Video file not found: ' + videoFile, false, false, FlxColor.RED);
			}
			return false;

			#else
			PlayState.instance.startAndEnd();
			return true;
			#end
		});

		Lua_helper.add_callback(lua, "playMusic", function(sound:String, volume:Float = 1, loop:Bool = false) {
			FlxG.sound.playMusic(Paths.music(sound), volume, loop);
		});
		Lua_helper.add_callback(lua, "playSound", function(sound:String, volume:Float = 1, ?tag:String = null) {
			if(tag != null && tag.length > 0) {
				tag = tag.replace('.', '');
				if(SongPlayState.instance.modchartSounds.exists(tag)) {
					SongPlayState.instance.modchartSounds.get(tag).stop();
				}
				SongPlayState.instance.modchartSounds.set(tag, FlxG.sound.play(Paths.sound(sound), volume, false, function() {
					SongPlayState.instance.modchartSounds.remove(tag);
					SongPlayState.instance.callOnLuas('onSoundFinished', [tag]);
				}));
				return;
			}
			FlxG.sound.play(Paths.sound(sound), volume);
		});
		Lua_helper.add_callback(lua, "stopSound", function(tag:String) {
			if(tag != null && tag.length > 1 && SongPlayState.instance.modchartSounds.exists(tag)) {
				SongPlayState.instance.modchartSounds.get(tag).stop();
				SongPlayState.instance.modchartSounds.remove(tag);
			}
		});
		Lua_helper.add_callback(lua, "pauseSound", function(tag:String) {
			if(tag != null && tag.length > 1 && SongPlayState.instance.modchartSounds.exists(tag)) {
				SongPlayState.instance.modchartSounds.get(tag).pause();
			}
		});
		Lua_helper.add_callback(lua, "resumeSound", function(tag:String) {
			if(tag != null && tag.length > 1 && SongPlayState.instance.modchartSounds.exists(tag)) {
				SongPlayState.instance.modchartSounds.get(tag).play();
			}
		});
		Lua_helper.add_callback(lua, "soundFadeIn", function(tag:String, duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			} else if(SongPlayState.instance.modchartSounds.exists(tag)) {
				SongPlayState.instance.modchartSounds.get(tag).fadeIn(duration, fromValue, toValue);
			}

		});
		Lua_helper.add_callback(lua, "soundFadeOut", function(tag:String, duration:Float, toValue:Float = 0) {
			if(tag == null || tag.length < 1) {
				FlxG.sound.music.fadeOut(duration, toValue);
			} else if(SongPlayState.instance.modchartSounds.exists(tag)) {
				SongPlayState.instance.modchartSounds.get(tag).fadeOut(duration, toValue);
			}
		});
		Lua_helper.add_callback(lua, "soundFadeCancel", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music.fadeTween != null) {
					FlxG.sound.music.fadeTween.cancel();
				}
			} else if(SongPlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = SongPlayState.instance.modchartSounds.get(tag);
				if(theSound.fadeTween != null) {
					theSound.fadeTween.cancel();
					SongPlayState.instance.modchartSounds.remove(tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "getSoundVolume", function(tag:String) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					return FlxG.sound.music.volume;
				}
			} else if(SongPlayState.instance.modchartSounds.exists(tag)) {
				return SongPlayState.instance.modchartSounds.get(tag).volume;
			}
			return 0;
		});
		Lua_helper.add_callback(lua, "setSoundVolume", function(tag:String, value:Float) {
			if(tag == null || tag.length < 1) {
				if(FlxG.sound.music != null) {
					FlxG.sound.music.volume = value;
				}
			} else if(SongPlayState.instance.modchartSounds.exists(tag)) {
				SongPlayState.instance.modchartSounds.get(tag).volume = value;
			}
		});
		Lua_helper.add_callback(lua, "getSoundTime", function(tag:String) {
			if(tag != null && tag.length > 0 && SongPlayState.instance.modchartSounds.exists(tag)) {
				return SongPlayState.instance.modchartSounds.get(tag).time;
			}
			return 0;
		});
		Lua_helper.add_callback(lua, "setSoundTime", function(tag:String, value:Float) {
			if(tag != null && tag.length > 0 && SongPlayState.instance.modchartSounds.exists(tag)) {
				var theSound:FlxSound = SongPlayState.instance.modchartSounds.get(tag);
				if(theSound != null) {
					var wasResumed:Bool = theSound.playing;
					theSound.pause();
					theSound.time = value;
					if(wasResumed) theSound.play();
				}
			}
		});

		Lua_helper.add_callback(lua, "debugPrint", function(text1:Dynamic = '', text2:Dynamic = '', text3:Dynamic = '', text4:Dynamic = '', text5:Dynamic = '') {
			if (text1 == null) text1 = '';
			if (text2 == null) text2 = '';
			if (text3 == null) text3 = '';
			if (text4 == null) text4 = '';
			if (text5 == null) text5 = '';
			luaTrace('' + text1 + text2 + text3 + text4 + text5, true, false);
		});

		Lua_helper.add_callback(lua, "close", function() {
			closed = true;
			somethingClosed = true;
			return closed;
		});

		Lua_helper.add_callback(lua, "changePresence", function(details:String, state:Null<String>, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float) {
			#if desktop
			DiscordClient.changePresence(details, state, smallImageKey, hasStartTimestamp, endTimestamp);
			#end
		});


		// LUA TEXTS
		Lua_helper.add_callback(lua, "makeLuaText", function(tag:String, text:String, width:Int, x:Float, y:Float) {
			tag = tag.replace('.', '');
			resetTextTag(tag);
			var leText:ModchartText = new ModchartText(x, y, text, width);
			SongPlayState.instance.modchartTexts.set(tag, leText);
		});

		Lua_helper.add_callback(lua, "setTextString", function(tag:String, text:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.text = text;
			}
		});
		Lua_helper.add_callback(lua, "setTextSize", function(tag:String, size:Int) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.size = size;
			}
		});
		Lua_helper.add_callback(lua, "setTextWidth", function(tag:String, width:Float) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.fieldWidth = width;
			}
		});
		Lua_helper.add_callback(lua, "setTextBorder", function(tag:String, size:Int, color:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

				obj.borderSize = size;
				obj.borderColor = colorNum;
			}
		});
		Lua_helper.add_callback(lua, "setTextColor", function(tag:String, color:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

				obj.color = colorNum;
			}
		});
		Lua_helper.add_callback(lua, "setTextFont", function(tag:String, newFont:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.font = Paths.font(newFont);
			}
		});
		Lua_helper.add_callback(lua, "setTextItalic", function(tag:String, italic:Bool) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.italic = italic;
			}
		});
		Lua_helper.add_callback(lua, "setTextAlignment", function(tag:String, alignment:String = 'left') {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				obj.alignment = LEFT;
				switch(alignment.trim().toLowerCase())
				{
					case 'right':
						obj.alignment = RIGHT;
					case 'center':
						obj.alignment = CENTER;
				}
			}
		});

		Lua_helper.add_callback(lua, "getTextString", function(tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				return obj.text;
			}
			return null;
		});
		Lua_helper.add_callback(lua, "getTextSize", function(tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				return obj.size;
			}
			return -1;
		});
		Lua_helper.add_callback(lua, "getTextFont", function(tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				return obj.font;
			}
			return null;
		});
		Lua_helper.add_callback(lua, "getTextWidth", function(tag:String) {
			var obj:FlxText = getTextObject(tag);
			if(obj != null)
			{
				return obj.fieldWidth;
			}
			return 0;
		});

		Lua_helper.add_callback(lua, "addLuaText", function(tag:String) {
			if(SongPlayState.instance.modchartTexts.exists(tag)) {
				var shit:ModchartText = SongPlayState.instance.modchartTexts.get(tag);
				if(!shit.wasAdded) {
					getInstance().add(shit);
					shit.wasAdded = true;
					//trace('added a thing: ' + tag);
				}
			}
		});
		Lua_helper.add_callback(lua, "removeLuaText", function(tag:String, destroy:Bool = true) {
			if(!SongPlayState.instance.modchartTexts.exists(tag)) {
				return;
			}

			var pee:ModchartText = SongPlayState.instance.modchartTexts.get(tag);
			if(destroy) {
				pee.kill();
			}

			if(pee.wasAdded) {
				getInstance().remove(pee, true);
				pee.wasAdded = false;
			}

			if(destroy) {
				pee.destroy();
				SongPlayState.instance.modchartTexts.remove(tag);
			}
		});

		Lua_helper.add_callback(lua, "initSaveData", function(name:String, ?folder:String = 'psychenginemods') {
			if(!SongPlayState.instance.modchartSaves.exists(name))
			{
				var save:FlxSave = new FlxSave();
				save.bind(name, folder);
				SongPlayState.instance.modchartSaves.set(name, save);
				return;
			}
			luaTrace('Save file already initialized: ' + name);
		});
		Lua_helper.add_callback(lua, "flushSaveData", function(name:String) {
			if(SongPlayState.instance.modchartSaves.exists(name))
			{
				SongPlayState.instance.modchartSaves.get(name).flush();
				return;
			}
			luaTrace('Save file not initialized: ' + name, false, false, FlxColor.RED);
		});
		Lua_helper.add_callback(lua, "getDataFromSave", function(name:String, field:String, ?defaultValue:Dynamic = null) {
			if(SongPlayState.instance.modchartSaves.exists(name))
			{
				var retVal:Dynamic = Reflect.field(SongPlayState.instance.modchartSaves.get(name).data, field);
				return retVal;
			}
			luaTrace('Save file not initialized: ' + name, false, false, FlxColor.RED);
			return defaultValue;
		});
		Lua_helper.add_callback(lua, "setDataFromSave", function(name:String, field:String, value:Dynamic) {
			if(SongPlayState.instance.modchartSaves.exists(name))
			{
				Reflect.setField(SongPlayState.instance.modchartSaves.get(name).data, field, value);
				return;
			}
			luaTrace('Save file not initialized: ' + name, false, false, FlxColor.RED);
		});

		Lua_helper.add_callback(lua, "checkFileExists", function(filename:String, ?absolute:Bool = false) {
			#if MODS_ALLOWED
			if(absolute)
			{
				return Paths.exists(filename);
			}

			var path:String = Paths.modFolders(filename);
			if(Paths.exists(path))
			{
				return true;
			}
			return Paths.exists(Paths.getPath('assets/$filename', TEXT));
			#else
			if(absolute)
			{
				return Paths.exists(filename);
			}
			return Paths.exists(Paths.getPath('assets/$filename', TEXT));
			#end
		});
		#if sys
		Lua_helper.add_callback(lua, "saveFile", function(path:String, content:String, ?absolute:Bool = false) {
			try {
				if(!absolute)
					File.saveContent(Paths.mods(path), content);
				else
					File.saveContent(path, content);

				return true;
			} catch (e:Dynamic) {
				luaTrace("Error trying to save " + path + ": " + e, false, false, FlxColor.RED);
			}
			return false;
		});
		Lua_helper.add_callback(lua, "deleteFile", function(path:String, ?ignoreModFolders:Bool = false) {
			try {
				#if MODS_ALLOWED
				if(!ignoreModFolders)
				{
					var lePath:String = Paths.modFolders(path);
					if(Paths.exists(lePath))
					{
						FileSystem.deleteFile(lePath);
						return true;
					}
				}
				#end

				var lePath:String = Paths.getPath(path, TEXT);
				if(Assets.exists(lePath))
				{
					FileSystem.deleteFile(lePath);
					return true;
				}
			} catch (e:Dynamic) {
				luaTrace("Error trying to delete " + path + ": " + e, false, false, FlxColor.RED);
			}
			return false;
		});
		#end
		Lua_helper.add_callback(lua, "getTextFromFile", function(path:String, ?ignoreModFolders:Bool = false) {
			return Paths.getTextFromFile(path, ignoreModFolders);
		});

		// DEPRECATED, DONT MESS WITH THESE SHITS, ITS JUST THERE FOR BACKWARD COMPATIBILITY
		Lua_helper.add_callback(lua, "objectPlayAnimation", function(obj:String, name:String, forced:Bool = false, ?startFrame:Int = 0) {
			luaTrace("objectPlayAnimation is deprecated! Use playAnim instead", false, true);
			if(PlayState.instance.getLuaObject(obj,false) != null) {
				PlayState.instance.getLuaObject(obj,false).animation.play(name, forced, false, startFrame);
				return true;
			}

			var spr:FlxSprite = Reflect.getProperty(getInstance(), obj);
			if(spr != null) {
				spr.animation.play(name, forced, false, startFrame);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "characterPlayAnim", function(character:String, anim:String, ?forced:Bool = false) {
			luaTrace("characterPlayAnim is deprecated! Use playAnim instead", false, true);
			switch(character.toLowerCase()) {
				case 'dad':
					if(PlayState.instance.dad.animOffsets.exists(anim))
						PlayState.instance.dad.playAnim(anim, forced);
				case 'gf' | 'girlfriend':
					if(PlayState.instance.gf != null && PlayState.instance.gf.animOffsets.exists(anim))
						PlayState.instance.gf.playAnim(anim, forced);
				default:
					if(PlayState.instance.boyfriend.animOffsets.exists(anim))
						PlayState.instance.boyfriend.playAnim(anim, forced);
			}
		});
		Lua_helper.add_callback(lua, "luaSpriteMakeGraphic", function(tag:String, width:Int, height:Int, color:String) {
			luaTrace("luaSpriteMakeGraphic is deprecated! Use makeGraphic instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				var colorNum:Int = Std.parseInt(color);
				if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);

				SongPlayState.instance.modchartSprites.get(tag).makeGraphic(width, height, colorNum);
			}
		});
		Lua_helper.add_callback(lua, "luaSpriteAddAnimationByPrefix", function(tag:String, name:String, prefix:String, framerate:Int = 24, loop:Bool = true) {
			luaTrace("luaSpriteAddAnimationByPrefix is deprecated! Use addAnimationByPrefix instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				var cock:ModchartSprite = SongPlayState.instance.modchartSprites.get(tag);
				cock.animation.addByPrefix(name, prefix, framerate, loop);
				if(cock.animation.curAnim == null) {
					cock.animation.play(name, true);
				}
			}
		});
		Lua_helper.add_callback(lua, "luaSpriteAddAnimationByIndices", function(tag:String, name:String, prefix:String, indices:String, framerate:Int = 24) {
			luaTrace("luaSpriteAddAnimationByIndices is deprecated! Use addAnimationByIndices instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				var strIndices:Array<String> = indices.trim().split(',');
				var die:Array<Int> = [];
				for (i in 0...strIndices.length) {
					die.push(Std.parseInt(strIndices[i]));
				}
				var pussy:ModchartSprite = SongPlayState.instance.modchartSprites.get(tag);
				pussy.animation.addByIndices(name, prefix, die, '', framerate, false);
				if(pussy.animation.curAnim == null) {
					pussy.animation.play(name, true);
				}
			}
		});
		Lua_helper.add_callback(lua, "luaSpritePlayAnimation", function(tag:String, name:String, forced:Bool = false) {
			luaTrace("luaSpritePlayAnimation is deprecated! Use playAnim instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				SongPlayState.instance.modchartSprites.get(tag).animation.play(name, forced);
			}
		});
		Lua_helper.add_callback(lua, "setLuaSpriteCamera", function(tag:String, camera:String = '') {
			luaTrace("setLuaSpriteCamera is deprecated! Use setObjectCamera instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				SongPlayState.instance.modchartSprites.get(tag).cameras = [cameraFromString(camera)];
				return true;
			}
			luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});
		Lua_helper.add_callback(lua, "setLuaSpriteScrollFactor", function(tag:String, scrollX:Float, scrollY:Float) {
			luaTrace("setLuaSpriteScrollFactor is deprecated! Use setScrollFactor instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				SongPlayState.instance.modchartSprites.get(tag).scrollFactor.set(scrollX, scrollY);
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "scaleLuaSprite", function(tag:String, x:Float, y:Float) {
			luaTrace("scaleLuaSprite is deprecated! Use scaleObject instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				var shit:ModchartSprite = SongPlayState.instance.modchartSprites.get(tag);
				shit.scale.set(x, y);
				shit.updateHitbox();
				return true;
			}
			return false;
		});
		Lua_helper.add_callback(lua, "getPropertyLuaSprite", function(tag:String, variable:String) {
			luaTrace("getPropertyLuaSprite is deprecated! Use getProperty instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				var killMe:Array<String> = variable.split('.');
				if(killMe.length > 1) {
					var coverMeInPiss:Dynamic = Reflect.getProperty(SongPlayState.instance.modchartSprites.get(tag), killMe[0]);
					for (i in 1...killMe.length-1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
				}
				return Reflect.getProperty(SongPlayState.instance.modchartSprites.get(tag), variable);
			}
			return null;
		});
		Lua_helper.add_callback(lua, "setPropertyLuaSprite", function(tag:String, variable:String, value:Dynamic) {
			luaTrace("setPropertyLuaSprite is deprecated! Use setProperty instead", false, true);
			if(SongPlayState.instance.modchartSprites.exists(tag)) {
				var killMe:Array<String> = variable.split('.');
				if(killMe.length > 1) {
					var coverMeInPiss:Dynamic = Reflect.getProperty(SongPlayState.instance.modchartSprites.get(tag), killMe[0]);
					for (i in 1...killMe.length-1) {
						coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
					}
					Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
					return true;
				}
				Reflect.setProperty(SongPlayState.instance.modchartSprites.get(tag), variable, value);
				return true;
			}
			luaTrace("Lua sprite with tag: " + tag + " doesn't exist!");
			return false;
		});
		Lua_helper.add_callback(lua, "musicFadeIn", function(duration:Float, fromValue:Float = 0, toValue:Float = 1) {
			FlxG.sound.music.fadeIn(duration, fromValue, toValue);
			luaTrace('musicFadeIn is deprecated! Use soundFadeIn instead.', false, true);

		});
		Lua_helper.add_callback(lua, "musicFadeOut", function(duration:Float, toValue:Float = 0) {
			FlxG.sound.music.fadeOut(duration, toValue);
			luaTrace('musicFadeOut is deprecated! Use soundFadeOut instead.', false, true);
		});

		// Other stuff
		Lua_helper.add_callback(lua, "stringStartsWith", function(str:String, start:String) {
			return str.startsWith(start);
		});
		Lua_helper.add_callback(lua, "stringEndsWith", function(str:String, end:String) {
			return str.endsWith(end);
		});

		// Disabling some non-playstate stuff
		if (!inPlayState) {
			final disabledCallbacks:Array<String> = [
				'loadSong', 'restartSong', 'exitSong', // Song Manipulation
				'addCharacterToList', 'characterPlayAnim', 
				'characterDance', 'characterSing', 'characterMiss',
				'loadLuaCharacter', 'activateLuaCharacter', 'deactivateLuaCharacter',
				'getCharacterX', 'setCharacterX', 'getCharacterY', 'setCharacterY', // Character Manipulation
				'setHealthBarColors', 'setTimeBarColors', // PlayState Bar Manipulation
				'cameraSetTarget', // Camera-Character Interaction
				'startCountdown'
				];

			for (dC in disabledCallbacks) {
				Lua_helper.add_callback(lua, dC, function(text1:Dynamic = '', text2:Dynamic = '', text3:Dynamic = '', text4:Dynamic = '', text5:Dynamic = '') {
					if (text1 == null) text1 = '';
					if (text2 == null) text2 = '';
					if (text3 == null) text3 = '';
					if (text4 == null) text4 = '';
					if (text5 == null) text5 = '';
					var str = '' + text1 + text2 + text3 + text4 + text5;
					luaTrace('Unsupported $dC called with $str. Ignored.', true, false, COLOR_INFO);
				});
				// function(...things:Dynamic) {
				// 	luaTrace('Unsupported $dC called with ${things.toString()}. Ignored.', true, false, COLOR_INFO);
				// });
			}

			// Special replacements:
			for (sC in ['startDialogue', 'startVideo']) {
				Lua_helper.add_callback(lua, sC, function(text1:Dynamic = '', text2:Dynamic = '', text3:Dynamic = '', text4:Dynamic = '', text5:Dynamic = '') {
					if (text1 == null) text1 = '';
					if (text2 == null) text2 = '';
					if (text3 == null) text3 = '';
					if (text4 == null) text4 = '';
					if (text5 == null) text5 = '';
					var str = '' + text1 + text2 + text3 + text4 + text5;
					luaTrace('Unsupported $sC called with $str. Ignored.', true, false, COLOR_INFO);
					if (SongPlayState.instance.endingSong) {
						SongPlayState.instance.endSong();
					}
				});

				// function(...things:Dynamic) {
				// 	luaTrace('Unsupported $sC called with ${things.toString()}. Ignored.', COLOR_INFO);
				// 	if (SongPlayState.instance.endingSong) {
				// 		SongPlayState.instance.endSong();
				// 	}
				// });
			}
		}

		call('onCreate', []);
		#end
	}

	#if hscript
	public function initHaxeInterp()
	{
		if(haxeInterp == null)
		{
			haxeInterp = new Interp();
			haxeInterp.variables.set('FlxG', FlxG);
			haxeInterp.variables.set('FlxSprite', FlxSprite);
			haxeInterp.variables.set('FlxCamera', FlxCamera);
			haxeInterp.variables.set('FlxTween', FlxTween);
			haxeInterp.variables.set('FlxEase', FlxEase);
			haxeInterp.variables.set('SongPlayState', SongPlayState);
			haxeInterp.variables.set('instance', SongPlayState.instance);
			if (inPlayState) {
				haxeInterp.variables.set('PlayState', PlayState);
				haxeInterp.variables.set('game', PlayState.instance);
			}
			haxeInterp.variables.set('Paths', Paths);
			haxeInterp.variables.set('Conductor', Conductor);
			haxeInterp.variables.set('ClientPrefs', ClientPrefs);
			haxeInterp.variables.set('Character', Character);
			haxeInterp.variables.set('Alphabet', Alphabet);
			haxeInterp.variables.set('StringTools', StringTools);

			haxeInterp.variables.set('setVar', function(name:String, value:Dynamic) {
				SongPlayState.instance.variables.set(name, value);
			});
			haxeInterp.variables.set('getVar', function(name:String) {
				return SongPlayState.instance.variables.get(name);
			});
		}
	}
	#end

	static var tokenEReg:EReg = ~/^(?:([_a-z][_a-z0-9]*)\.?|\[(-?\d+)\]|\[("(?:[^"]|\\.)*"|'(?:[^']|\\.)*')\])/i;
	static var tagEReg:EReg = ~/^([^.\[]*)\.?/i;
	inline static final TOKEN_PROP = 1;
	inline static final TOKEN_ARRAY = 2;
	inline static final TOKEN_MAP = 3;
	public static function getVar(instance:Dynamic, variable:String):Any
	{
		var match:Bool = tokenEReg.match(variable);

		while (match) {
			variable = tokenEReg.matchedRight();
			var prop:String = tokenEReg.matched(TOKEN_PROP);
			var idx:String = tokenEReg.matched(TOKEN_ARRAY);
			var key:String = tokenEReg.matched(TOKEN_MAP);
			if (variable != null && variable.length > 0) { // Intermediate
				if (prop != null) {
					instance = Reflect.getProperty(instance, prop);
				} else if (idx != null) {
					var i:Int = Std.parseInt(idx);
					instance = instance[i];
				} else if (key != null) { // Add safety checks here?
					key = key.substr(1, key.length - 2);
					instance = instance.get(key);
				} else return null;
			} else { // Last
				if (prop != null) {
					return Reflect.getProperty(instance, prop);
				} else if (idx != null) {
					var i:Int = Std.parseInt(idx);
					return instance[i];
				} else if (key != null) {
					key = key.substr(1, key.length - 2);
					return instance.get(key);
				} else return null;
			}

			match = tokenEReg.match(variable);
		}

		return null;
	}

	public static function setVar(instance:Dynamic, variable:String, value:Dynamic):Bool
	{
		var match:Bool = tokenEReg.match(variable);

		while (match) {
			var prop:String = tokenEReg.matched(TOKEN_PROP);
			var idx:String = tokenEReg.matched(TOKEN_ARRAY);
			var key:String = tokenEReg.matched(TOKEN_MAP);
			variable = tokenEReg.matchedRight();
			if (variable != null && variable.length > 0) { // Intermediate
				if (prop != null) {
					instance = Reflect.getProperty(instance, prop);
				} else if (idx != null) {
					var i:Int = Std.parseInt(idx);
					instance = instance[i];
				} else if (key != null) { // Add safety checks here?
					key = key.substr(1, key.length - 2);
					instance = instance.get(key);
				} else return false;
			} else { // Last
				if (prop != null) {
					Reflect.setProperty(instance, prop, value);
					return true;
				} else if (idx != null) { // Is there a way to do arrayAccess checks?
					var i:Int = Std.parseInt(idx);
					instance[i] = value;
					return true;
				} else if (key != null) { // Add safety checks here?
					key = key.substr(1, key.length - 2);
					instance.set(key, value);
					return true;
				} else return false;
			}

			match = tokenEReg.match(variable);
		}

		return false;
	}

	public static function getVarDirectly(full:String, checkText:Bool = false):Any
	{
		var match:Bool = tagEReg.match(full);

		if (match) {
			var instance:Dynamic = getObjectDirectly(tagEReg.matched(1), checkText);
			var variable = tagEReg.matchedRight();

			if (variable != null && variable.length > 0) {
				return getVar(instance, variable);
			} else return instance;
		} else return null;
	}

	public static function setVarDirectly(full:String, value:Dynamic, checkText:Bool = false):Bool
	{
		var match:Bool = tagEReg.match(full);

		if (match) {
			var instance:Dynamic = getObjectDirectly(tagEReg.matched(1), checkText);
			var variable = tagEReg.matchedRight();

			if (variable != null && variable.length > 0) {
				return setVar(instance, variable, value);
			} else {
				Reflect.setProperty(getInstance(), full, value);
				return true;
			}
		} else return false;
	}

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
	{
		var shit:Array<String> = variable.split('[');
		if(shit.length > 1)
		{
			var blah:Dynamic = Reflect.getProperty(instance, shit[0]);
			for (i in 1...shit.length)
			{
				var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
				if(i >= shit.length-1) //Last array
					blah[leNum] = value;
				else //Anything else
					blah = blah[leNum];
			}
			return blah;
		}
		/*if(Std.isOfType(instance, Map))
			instance.set(variable,value);
		else*/

		Reflect.setProperty(instance, variable, value);
		return true;
	}
	public static function getVarInArray(instance:Dynamic, variable:String):Any
	{
		var shit:Array<String> = variable.split('[');
		if(shit.length > 1)
		{
			var blah:Dynamic = Reflect.getProperty(instance, shit[0]);
			for (i in 1...shit.length)
			{
				var leNum:Dynamic = shit[i].substr(0, shit[i].length - 1);
				blah = blah[leNum];
			}
			return blah;
		}

		return Reflect.getProperty(instance, variable);
	}

	inline static function getTextObject(name:String):FlxText
	{
		return SongPlayState.instance.modchartTexts.exists(name) ? SongPlayState.instance.modchartTexts.get(name) : Reflect.getProperty(SongPlayState.instance, name);
	}

	public static function getGroupStuff(leArray:Dynamic, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			switch(Type.typeof(coverMeInPiss)){
				case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
					return coverMeInPiss.get(killMe[killMe.length-1]);
				default:
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			};
		}
		switch(Type.typeof(leArray)){
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				return leArray.get(variable);
			default:
				return Reflect.getProperty(leArray, variable);
		};
	}

	public static function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().trim())
		{
			case "texture" | "textureatlas" | "tex":
				spr.frames = AtlasFrameMaker.construct(image);

			case "texture_noaa" | "textureatlas_noaa" | "tex_noaa":
				spr.frames = AtlasFrameMaker.construct(image, null, true);

			case "packer" | "packeratlas" | "pac":
				spr.frames = Paths.getPackerAtlas(image);

			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	public static function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			return;
		}
		Reflect.setProperty(leArray, variable, value);
	}

	function resetTextTag(tag:String) {
		if(!SongPlayState.instance.modchartTexts.exists(tag)) {
			return;
		}

		var pee:ModchartText = SongPlayState.instance.modchartTexts.get(tag);
		pee.kill();
		if(pee.wasAdded) {
			SongPlayState.instance.remove(pee, true);
		}
		pee.destroy();
		SongPlayState.instance.modchartTexts.remove(tag);
	}

	function resetSpriteTag(tag:String) {
		if(!SongPlayState.instance.modchartSprites.exists(tag)) {
			return;
		}

		var pee:ModchartSprite = SongPlayState.instance.modchartSprites.get(tag);
		pee.kill();
		if(pee.wasAdded) {
			SongPlayState.instance.remove(pee, true);
		}
		pee.destroy();
		SongPlayState.instance.modchartSprites.remove(tag);
	}

	function cancelTween(tag:String) {
		if(SongPlayState.instance.modchartTweens.exists(tag)) {
			SongPlayState.instance.modchartTweens.get(tag).cancel();
			SongPlayState.instance.modchartTweens.get(tag).destroy();
			SongPlayState.instance.modchartTweens.remove(tag);
		}
	}

	function tweenShit(tag:String, vars:String) {
		cancelTween(tag);
		return getVarDirectly(vars);
	}

	function cancelTimer(tag:String) {
		if(SongPlayState.instance.modchartTimers.exists(tag)) {
			var theTimer:FlxTimer = SongPlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			SongPlayState.instance.modchartTimers.remove(tag);
		}
	}

	//Better optimized than using some getProperty shit or idk
	function getFlxEaseByString(?ease:String = '') {
		switch(ease.toLowerCase().trim()) {
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepInOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
		}
		return FlxEase.linear;
	}

	function blendModeFromString(blend:String):BlendMode {
		switch(blend.toLowerCase().trim()) {
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
		}
		return NORMAL;
	}

	function cameraFromString(cam:String):FlxCamera {
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud': return SongPlayState.instance.camHUD;
			case 'camother' | 'other': return SongPlayState.instance.camOther;
		}
		return SongPlayState.instance.camGame;
	}

	public function luaTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		#if LUA_ALLOWED
		if(ignoreCheck || getBool('luaDebugMode')) {
			if(deprecated && !getBool('luaDeprecatedWarnings')) {
				return;
			}
			SongPlayState.instance.addTextToDebug(text, color);
			trace(text);
		}
		#end
	}

	function getErrorMessage() {
		#if LUA_ALLOWED
		var v:String = Lua.tostring(lua, -1);
		if(!isErrorAllowed(v)) v = null;
		return v;
		#end
	}

	var lastCalledFunction:String = '';
	public function call(func:String, args:Array<Dynamic>): Dynamic{
		//trace('call to $func with $args');
		#if LUA_ALLOWED
		if(closed) return Function_Continue;

		lastCalledFunction = func;
		try {
			if(lua == null) return Function_Continue;

			Lua.getglobal(lua, func);

			for(arg in args) {
				Convert.toLua(lua, arg);
			}

			var result:Null<Int> = Lua.pcall(lua, args.length, 1, 0);
			var error:Dynamic = getErrorMessage();
			if(!resultIsAllowed(lua, result))
			{
				Lua.pop(lua, 1);
				if(error != null) luaTrace("ERROR (" + func + "): " + error, false, false, FlxColor.RED);
			}
			else
			{
				var conv:Dynamic = Convert.fromLua(lua, result);
				Lua.pop(lua, 1);
				if(conv == null) conv = Function_Continue;
				return conv;
			}
			return Function_Continue;
		}
		catch (e:Dynamic) {
			trace(e);
		}
		#end
		return Function_Continue;
	}

	public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true):Dynamic
	{
		var coverMeInPiss:Dynamic = SongPlayState.instance.getLuaObject(objectName, checkForTextsToo);
		if (coverMeInPiss == null) coverMeInPiss = Reflect.getProperty(getInstance(), objectName);

		return coverMeInPiss;
	}


	#if LUA_ALLOWED
	function resultIsAllowed(leLua:State, leResult:Null<Int>) { //Makes it ignore warnings
		return Lua.type(leLua, leResult) >= Lua.LUA_TNIL;
	}

	function isErrorAllowed(error:String) {
		switch(error)
		{
			case 'attempt to call a nil value' | 'C++ exception':
				return false;
		}
		return true;
	}
	#end

	public function set(variable:String, data:Dynamic) {
		#if LUA_ALLOWED
		if(lua == null) {
			return;
		}

		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	#if LUA_ALLOWED
	public function getBool(variable:String) {
		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) {
			return false;
		}
		return (result == 'true');
	}
	#end

	public function stop() {
		#if LUA_ALLOWED
		if(lua == null) {
			return;
		}

		Lua.close(lua);
		lua = null;
		#end
	}

	public static inline function getInstance()
	{
		return (PlayState.instance == SongPlayState.instance) && PlayState.instance.isDead ? GameOverSubstate.instance : SongPlayState.instance;
	}
}

class ModchartCharacter extends Character
{
	public var wasAdded:Bool = false;
	public var playerSide:Bool = false;
}

class ModchartStrum extends StrumNote
{
	public var wasAdded:Bool = false;
}

class ModchartSprite extends FlxSprite
{
	public var wasAdded:Bool = false;
	public var animOffsets:Map<String, Array<Float>> = new Map<String, Array<Float>>();
	//public var isInFront:Bool = false;

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super(x, y);
		antialiasing = ClientPrefs.globalAntialiasing;
	}
}

class ModchartText extends FlxText
{
	public var wasAdded:Bool = false;
	public function new(x:Float, y:Float, text:String, width:Float)
	{
		super(x, y, width, text, 16);
		setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		cameras = [PlayState.instance.camHUD];
		scrollFactor.set();
		borderSize = 2;
	}
}

class DebugLuaText extends FlxText
{
	private var disableTime:Float = 6;
	public var parentGroup:FlxTypedGroup<DebugLuaText>;
	public function new(text:String, parentGroup:FlxTypedGroup<DebugLuaText>, color:FlxColor) {
		this.parentGroup = parentGroup;
		super(10, 10, 0, text, 16);
		setFormat(Paths.font("vcr.ttf"), 20, color, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		scrollFactor.set();
		borderSize = 1;
	}

	override function update(elapsed:Float) {
		super.update(elapsed);
		disableTime -= elapsed;
		if(disableTime < 0) disableTime = 0;
		if(disableTime < 1) alpha = disableTime;
	}

}
