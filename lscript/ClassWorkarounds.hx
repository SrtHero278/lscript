package lscript;

import lscript.LScript;
import lscript.CustomConvert;

import llua.Lua;
import llua.LuaL;
import llua.State;

import cpp.Callable;

class ClassWorkarounds {
	/**
	 * A function made to workaround class constructor functions not appering in class fields.
	 */
	public static final workaroundCallable:Callable<llua.State.StatePointer->Int> = Callable.fromStaticFunction(instanceWorkAround);

	static function instanceWorkAround(state:StatePointer):Int {
		var returnVars = [];
				
		//Making the params for the function.
		var nparams:Int = Lua.gettop(LScript.currentLua.luaState);
		var params:Array<Dynamic> = [for(i in 0...nparams) CustomConvert.fromLua(-nparams + i)];

		var funcParams = [for (i in 1...params.length) params[i]];
		params.splice(1, params.length);
		params.push(funcParams);

		//Calling the function.
		var returned = null;
		try {
			returned = Type.createInstance(params[0], params[1]);
		} catch(e) {
			LuaL.error(LScript.currentLua.luaState, "Lua Instance Creation Error: " + e.details());
			Lua.settop(LScript.currentLua.luaState, 0);
			return 0;
		}
		Lua.settop(LScript.currentLua.luaState, 0);

		if (returned != null) {
			CustomConvert.toLua(returned);
			return 1;
		}
		return 0;
	}

	/**
	 * The function utilized for adding classes to lua.
	 * @param path                  The path to the class.
	 * @param varName               [OPTIONAL] The name to set the class to.
	 */
	public static function importClass(path:String, ?varName:String) {
		var luaState = LScript.currentLua.luaState;
		var specialVars = LScript.currentLua.specialVars;

		var importedClass = Type.resolveClass(path);
		var importedEnum = Type.resolveEnum(path);
		if (importedClass != null) {
			var location = specialVars.indexOf(importedClass);
			if (location < 0) {
				location = specialVars.length;
				specialVars.push(importedClass);
			}

			var trimmedName = (varName != null) ? varName : path.substr(path.lastIndexOf(".") + 1, path.length);

			Lua.newtable(luaState);
			var tableIndex = Lua.gettop(luaState); //The variable position of the table. Used for paring the metatable with this table and attaching variables.
			Lua.pushvalue(luaState, tableIndex);
			Lua.setglobal(luaState, trimmedName);

			Lua.pushstring(luaState, '__special_id'); //This is a helper var in the table that is used by the conversion functions to detect a special var.
			Lua.pushinteger(luaState, location);
			Lua.settable(luaState, tableIndex);

			Lua.pushstring(luaState, "new"); //This implements the work around function to create the class instance.
			Lua.pushcfunction(luaState, workaroundCallable);
			Lua.rawset(luaState, tableIndex);

			LuaL.getmetatable(luaState, "__scriptMetatable");
			Lua.setmetatable(luaState, tableIndex);
		} else if (importedEnum != null) {
			var location = specialVars.indexOf(importedEnum);
			if (location < 0) {
				location = specialVars.length;
				specialVars.push(importedEnum);
			}

			var trimmedName = (varName != null) ? varName : path.substr(path.lastIndexOf(".") + 1, path.length);

			Lua.newtable(luaState);
			var tableIndex = Lua.gettop(luaState); //The variable position of the table. Used for paring the metatable with this table.
			Lua.pushvalue(luaState, tableIndex);
			Lua.setglobal(luaState, trimmedName);

			Lua.pushstring(luaState, '__special_id'); //This is a helper var in the table that is used by the conversion functions to detect a class.
			Lua.pushinteger(luaState, location);
			Lua.settable(luaState, tableIndex);

			LuaL.getmetatable(luaState, "__enumMetatable");
			Lua.setmetatable(luaState, tableIndex);
		} else {
			Sys.println('${LScript.currentLua.tracePrefix}Lua Import Error: Unable to find class from path "$path".');
		}
	}
}