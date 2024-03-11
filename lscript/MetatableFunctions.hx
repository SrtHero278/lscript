package lscript;

import lscript.LScript;
import lscript.CustomConvert;

import llua.Lua;
import llua.LuaL;
import llua.State;

import cpp.RawPointer;
import cpp.Callable;

class MetatableFunctions {
	/**
	 * The metatable function that is called when lua tries to get an unknown variable.
	 */
	public static final callIndex = Callable.fromStaticFunction(_callIndex);
	/**
	 * The metatable function that is called when lua tries to set an unknown variable.
	 */
	public static final callNewIndex = Callable.fromStaticFunction(_callNewIndex);
	/**
	 * The metatable function that is called when lua calls a function with this metatable. (Most likely a haxe function)
	 */
	public static final callMetatableCall = Callable.fromStaticFunction(_callMetatableCall);
	/**
	 * The metatable function that is called when lua tries to get an enum value. (TODO: Fix enum values with parameters.)
	 */
	public static final callGarbageCollect = Callable.fromStaticFunction(_callGarbageCollect);
	/**
	 * The metatable function that is called when lua tries to get an enum value. (TODO: Fix enum values with parameters.)
	 */
	public static final callEnumIndex = Callable.fromStaticFunction(_callEnumIndex);

	//These functions are here because Callable seems like it wants an int return and whines when you do a non static function.
	static function _callIndex(state:StatePointer):Int {
		return metatableFunc(LScript.currentLua.luaState, 0);
	}
	static function _callNewIndex(state:StatePointer):Int {
		return metatableFunc(LScript.currentLua.luaState, 1);
	}
	static function _callMetatableCall(state:StatePointer):Int {
		return metatableFunc(LScript.currentLua.luaState, 2);
	}
	static function _callGarbageCollect(state:StatePointer):Int {
		return metatableFunc(LScript.currentLua.luaState, 3);
	}
	static function _callEnumIndex(state:StatePointer):Int {
		return metatableFunc(LScript.currentLua.luaState, 4);
	}

	static function metatableFunc(state:State, funcNum:Int) {
		final functions:Array<Dynamic> = [index, newIndex, metatableCall, garbageCollect, enumIndex];

		//Making the params for the function.
		final nparams:Int = Lua.gettop(state);
		final specialIndex:Int = -1;
		final parentIndex:Int = -1;
		final params:Array<Dynamic> = [for(i in 0...nparams) CustomConvert.fromLua(-nparams + i, RawPointer.addressOf(specialIndex), RawPointer.addressOf(parentIndex), i == 0)];

		if (funcNum == 2) {
			if (params[1] != LScript.currentLua.specialVars[parentIndex])
				params.insert(1, LScript.currentLua.specialVars[parentIndex]);

			final funcParams = [for (i in 2...params.length) params[i]];
			params.splice(2, params.length);
			params.push(funcParams);
		}

		//Calling the function. If it catches something, will send a lua error of what went wrong.
		var returned:Dynamic = null;
		try {
			returned = functions[funcNum](params[0], params[1], params[2]); //idk why im not using Reflect but this slightly more optimized so whatevs.
		} catch(e) {
			LuaL.error(state, "Lua Metatable Error: " + e.details());
			Lua.settop(state, 0);
			return 0;
		}
		Lua.settop(state, 0);

		if (returned != null) {
			CustomConvert.toLua(returned, funcNum < 2 ? specialIndex : -1);
			return 1;
		}
		return 0;
	}

	//These three functions are the actual functions that the metatable use.
	//Without these, object oriented lua wouldn't work at all.

	public static function index(object:Dynamic, property:Any, ?uselessValue:Any):Dynamic {
		if (object is Array && property is Int)
			return object[cast(property, Int)];

		var grabbedProperty:Dynamic = null;

		if (object != null && (grabbedProperty = Reflect.getProperty(object, cast(property, String))) != null)
			return grabbedProperty;
		return null;
	}
	public static function newIndex(object:Dynamic, property:Any, value:Dynamic) {
		if (object is Array && property is Int) {
			object[cast(property, Int)] = value;
			return null;
		}

		if (object != null)
			Reflect.setProperty(object, cast(property, String), value);
		return null;
	}
	public static function metatableCall(func:Dynamic, object:Dynamic, ?params:Array<Any>) {
		final funcParams = (params != null && params.length > 0) ? params : [];

		if (object != null && func != null && Reflect.isFunction(func))
			return Reflect.callMethod(object, func, funcParams);
		return null;
	}
	public static function garbageCollect(index:Int) {
		LScript.currentLua.avalibableIndexes.push(index);
		LScript.currentLua.specialVars.remove(index);
	}
	public static function enumIndex(object:Enum<Dynamic>, value:String, ?params:Array<Any>):EnumValue {
		final funcParams = (params != null && params.length > 0) ? params : [];
		var enumValue:EnumValue;

		enumValue = object.createByName(value, funcParams);
		if (object != null && enumValue != null)
			return enumValue;
		return null;
	}
}

/**
 * ignore this code block.
 * i was showing CrowPlexus how easy it would be to make a create function.
 * 
 * ```haxe
 * var script = new LScript("
 * --haha funny lua code
 * function create()
 *      FlxG.state:add(FlxSprite:new(640, 360, 'assets/images/piss.png'))
 * end
 * ");
 * script.setVar("FlxG", flixel.FlxG);
 * script.setVar("FlxSprite", flixel.FlxSprite);
 * script.execute();
 * script.callFunc("create");
 * ```
 */
