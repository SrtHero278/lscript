package lscript;

import lscript.*;

import llua.Lua;
import llua.LuaL;
import llua.State;

import cpp.Callable;

using StringTools;

/**
 * The class used for making lua scripts.
 * 
 * Base code written by YoshiCrafter29 (https://github.com/YoshiCrafter29)
 * Fixed and tweaked by Srt (https://github.com/SrtHero278)
 */
class LScript {
	public static var currentLua:LScript = null;

	public var luaState:State;
	public var tracePrefix:String = "testScript: ";
	public var parent(get, set):Dynamic;
	public var script(get, null):Dynamic;
	var toParse:String;

	/**
	 * The map containing the special vars so lua can utilize them by getting the location used in the `__special_id` field.
	 */
	public var specialVars:Map<Int, Dynamic> = [-1 => null];
	public var avalibableIndexes:Array<Int> = [];
	public var nextIndex:Int = 1;
	
	public function new(scriptCode:String) {
		luaState = LuaL.newstate();
		LuaL.openlibs(luaState);
		Lua.register_hxtrace_func(Callable.fromStaticFunction(scriptTrace));
		Lua.register_hxtrace_lib(luaState);

		Lua.newtable(luaState);
		final tableIndex = Lua.gettop(luaState); //The variable position of the table. Used for paring the metatable with this table.
		Lua.pushvalue(luaState, tableIndex);

		LuaL.newmetatable(luaState, "__scriptMetatable");
		final metatableIndex = Lua.gettop(luaState); //The variable position of the table. Used for setting the functions inside this metatable.
		Lua.pushvalue(luaState, metatableIndex);
		Lua.setglobal(luaState, "__scriptMetatable");

		Lua.pushstring(luaState, '__index'); //This is a function in the metatable that is called when you to get a var that doesn't exist.
		Lua.pushcfunction(luaState, MetatableFunctions.callIndex);
		Lua.settable(luaState, metatableIndex);
		
		Lua.pushstring(luaState, '__newindex'); //This is a function in the metatable that is called when you to set a var that was originally null.
		Lua.pushcfunction(luaState, MetatableFunctions.callNewIndex);
		Lua.settable(luaState, metatableIndex);
		
		Lua.pushstring(luaState, '__call'); //This is a function in the metatable that is called when you call a function inside the table.
		Lua.pushcfunction(luaState, MetatableFunctions.callMetatableCall);
		Lua.settable(luaState, metatableIndex);

		Lua.pushstring(luaState, '__gc'); //This is a function in the metatable that is called when you call a function inside the table.
		Lua.pushcfunction(luaState, MetatableFunctions.callGarbageCollect);
		Lua.settable(luaState, metatableIndex);

		Lua.setmetatable(luaState, tableIndex);

		LuaL.newmetatable(luaState, "__enumMetatable");
		final enumMetatableIndex = Lua.gettop(luaState); //The variable position of the table. Used for setting the functions inside this metatable.
		Lua.pushvalue(luaState, metatableIndex);

		Lua.pushstring(luaState, '__index'); //This is a function in the metatable that is called when you to get a var that doesn't exist.
		Lua.pushcfunction(luaState, MetatableFunctions.callEnumIndex);
		Lua.settable(luaState, enumMetatableIndex);

		specialVars[0] = {"import": ClassWorkarounds.importClass}

		Lua.newtable(luaState);
		final scriptTableIndex = Lua.gettop(luaState);
		Lua.pushvalue(luaState, scriptTableIndex);
		Lua.setglobal(luaState, "script");

		Lua.pushstring(luaState, '__special_id'); //This is a helper var in the table that is used by the conversion functions to detect a special var.
		Lua.pushinteger(luaState, 0);
		Lua.settable(luaState, scriptTableIndex);

		LuaL.getmetatable(luaState, "__scriptMetatable");
		Lua.setmetatable(luaState, scriptTableIndex);

		//Adding a suffix to the end of the lua file to attach a metatable to the global vars. (So you cant have to do `script.parent.this`)
		toParse = scriptCode + '\n\nsetmetatable(_G, {
			__newindex = function (notUsed, name, value)
				__scriptMetatable.__newindex(script.parent, name, value)
			end,
			__index = function (notUsed, name)
				return __scriptMetatable.__index(script.parent, name)
			end
		})';
	}

	public function execute() {
		final lastLua:LScript = currentLua;
		currentLua = this;

		if (LuaL.dostring(luaState, toParse) != 0)
			parseError(Lua.tostring(luaState, -1));

		currentLua = lastLua;
	}

	public dynamic function parseError(err:String) {
		trace("Lua code was unable to be parsed.\n" + err);
	}

	static inline function scriptTrace(s:String):Int {
		Sys.println(currentLua.tracePrefix + CustomConvert.fromLua(-2));
		return 0;
	}

	public function getVar(name:String):Dynamic {
		var toReturn:Dynamic = null;

		final lastLua:LScript = currentLua;
		currentLua = this;

		Lua.getglobal(luaState, name);
		toReturn = CustomConvert.fromLua(-1);
		Lua.pop(luaState, 1);

		currentLua = lastLua;

		return toReturn;
	}

	public function setVar(name:String, newValue:Dynamic) {
		final lastLua:LScript = currentLua;
		currentLua = this;

		CustomConvert.toLua(newValue);
		Lua.setglobal(luaState, name);
		
		currentLua = lastLua;
	}

	public function callFunc(name:String, ?param:Dynamic, ?param2:Dynamic, ?param3:Dynamic,
		?param4:Dynamic, ?param5:Dynamic, ?param6:Dynamic, ?param7:Dynamic, ?param8:Dynamic,
		?param9:Dynamic, ?param10:Dynamic):Dynamic {
		final lastLua:LScript = currentLua;
		currentLua = this;

		Lua.settop(luaState, 0);
		Lua.getglobal(luaState, name); //Finds the function from the script.

		if (!Lua.isfunction(luaState, -1))
			return null;

		//Pushes the parameters of the script.
		//To save a bunch of lines, I wrote an inline function that adds the function's parameter to the state

		var nparams:cpp.UInt8 = 0;

		inline function addParam(param:Dynamic)
		{
			if (param != null)
			{
				++nparams;
				CustomConvert.toLua(param);
			}
		}

		addParam(param);
		addParam(param2);
		addParam(param3);
		addParam(param4);
		addParam(param5);
		addParam(param6);
		addParam(param7);
		addParam(param8);
		addParam(param9);
		addParam(param10);
		
		//Calls the function of the script. If it does not return 0, will trace what went wrong.
		if (Lua.pcall(luaState, nparams, 1, 0) != 0) {
			Sys.println(tracePrefix + 'Function("$name") Error: ${Lua.tostring(luaState, -1)}');
			return null;
		}

		//Grabs and returns the result of the function.
		final v = CustomConvert.fromLua(Lua.gettop(luaState));
		Lua.settop(luaState, 0);
		currentLua = lastLua;
		return v;
	}

	inline function get_script() {
		return specialVars[0];
	}

	inline function get_parent() {
		return specialVars[0].parent;
	}
	inline function set_parent(newParent:Dynamic) {
		return specialVars[0].parent = newParent;
	}
}
