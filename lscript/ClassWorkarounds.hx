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
		//Making the params for the function.
		final nparams:Int = Lua.gettop(LScript.currentLua.luaState);
		final params:Array<Dynamic> = [for(i in 0...nparams) CustomConvert.fromLua(-nparams + i)];
		
		final funcParams = [for (i in 1...params.length) params[i]];
		params.splice(1, params.length);
		params.push(funcParams);
		Sys.println(params);

		//Calling the function.
		var returned:Dynamic = null;
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
		final luaState = LScript.currentLua.luaState;

		final importedClass = Type.resolveClass(path);
		final importedEnum = Type.resolveEnum(path);
		final trimmedName = (varName != null) ? varName : path.substr(path.lastIndexOf(".") + 1, path.length);
		if (importedClass != null) {
			final tableIndex = CustomConvert.addToMetatable(importedClass, -1);
			
			Lua.pushstring(luaState, "new"); //This implements the work around function to create the class instance.
			Lua.pushcfunction(luaState, workaroundCallable);
			Lua.rawset(luaState, tableIndex);

			Lua.setglobal(luaState, trimmedName);
		} else if (importedEnum != null) {
			final tableIndex = CustomConvert.addToMetatable(importedEnum, -1);
			
			LuaL.getmetatable(luaState, "__enumMetatable");
			Lua.setmetatable(luaState, tableIndex);
			
			Lua.setglobal(luaState, trimmedName);
		} else {
			Sys.println('${LScript.currentLua.tracePrefix}Lua Import Error: Unable to find class from path "$path".');
		}
	}
}