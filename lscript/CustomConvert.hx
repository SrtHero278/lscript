package lscript;

import lscript.LScript;
import lscript.ClassWorkarounds;

import llua.Lua;
import llua.LuaL;
import llua.State;
import llua.Macro.*;

class CustomConvert {
	/**
	 * Converts a lua variable to haxe. Used for lua function returns.
	 * @param stackPos The position of the lua variable.
	 * @param inTable Default to false. This var is included because functions break in tables.
	 */
	 public static function fromLua(stackPos:Int):Dynamic {
		var ret:Any = null;
		var curLua = LScript.currentLua; // Mainly for the local function support but makes some lines shorter and nicer.
		var luaState = curLua.luaState;

		switch(Lua.type(luaState, stackPos)) {
			case Lua.LUA_TNIL:
				ret = null;
			case Lua.LUA_TBOOLEAN:
				ret = Lua.toboolean(luaState, stackPos);
			case Lua.LUA_TNUMBER:
				ret = Lua.tonumber(luaState, stackPos);
			case Lua.LUA_TSTRING:
				ret = Lua.tostring(luaState, stackPos);
			case Lua.LUA_TTABLE:
				ret = toHaxeObj(stackPos);
			case Lua.LUA_TFUNCTION:
				if (Lua.tocfunction(luaState, stackPos) != ClassWorkarounds.workaroundCallable) {
					Lua.pushvalue(luaState, stackPos);
					var ref = LuaL.ref(luaState, Lua.LUA_REGISTRYINDEX);

					function callLocalLuaFunc(params:Array<Dynamic>) {
						var lastLua:LScript = LScript.currentLua;
						LScript.currentLua = curLua;

						Lua.settop(luaState, 0);
						Lua.rawgeti(luaState, Lua.LUA_REGISTRYINDEX, ref);
				
						if (!Lua.isfunction(luaState, -1))
							return null;

						//Pushes the parameters of the script.
						var nparams:Int = 0;
						if (params != null && params.length > 0) {
							nparams = params.length;
							for (val in params)
								CustomConvert.toLua(val);
						}
						
						//Calls the function of the script. If it does not return 0, will trace what went wrong.
						if (Lua.pcall(luaState, nparams, 1, 0) != 0) {
							trace(curLua.tracePrefix + 'Function(LOCAL) Error: ${Lua.tostring(luaState, -1)}');
							return null;
						}

						//Grabs and returns the result of the function.
						var v = CustomConvert.fromLua(Lua.gettop(luaState));
						Lua.settop(luaState, 0);
						LScript.currentLua = lastLua;
						return v;
					}

					ret = Reflect.makeVarArgs(callLocalLuaFunc);
				}
			case idk:
				ret = null;
				trace('Return value not supported: ${Std.string(idk)} - $stackPos');
		}

		//This is to check if the object has a special field and converts it back if so.
		if (ret is Dynamic && Reflect.hasField(ret, "__special_id")) //Special Var.
			return curLua.specialVars[Reflect.field(ret, "__special_id")];
		return ret;
	}

	/**
	 * Converts any value into a lua variable.
	 * Automatically calls `Lua.push[var-type]` so all you need to do is call `Lua.setglobal` or `Lua.settable`.
	 * @param val                The value to convert.
	 */
	public static function toLua(val:Any) {
		var varType = Type.typeof(val);
		var curLua = LScript.currentLua;
		var luaState = curLua.luaState;

		switch (varType) {
			case Type.ValueType.TNull:
				Lua.pushnil(luaState);
			case Type.ValueType.TBool:
				Lua.pushboolean(luaState, val);
			case Type.ValueType.TInt:
				Lua.pushinteger(luaState, cast(val, Int));
			case Type.ValueType.TFloat:
				Lua.pushnumber(luaState, val);
			case Type.ValueType.TClass(String):
				Lua.pushstring(luaState, cast(val, String));
			case Type.ValueType.TClass(Array):
				var location = curLua.specialVars.indexOf(val);
				if (location < 0) {
					location = curLua.specialVars.length;
					curLua.specialVars.push(val);
				}

				Lua.newtable(luaState);
				var tableIndex = Lua.gettop(luaState); //The variable position of the table. Used for paring the metatable with this table and attaching variables.

				Lua.pushstring(luaState, '__special_id'); //This is a helper var in the table that is used by the conversion functions to detect a special var.
				Lua.pushinteger(luaState, location);
				Lua.settable(luaState, tableIndex);

				LuaL.getmetatable(luaState, "__scriptMetatable");
				Lua.setmetatable(luaState, tableIndex);
			case Type.ValueType.TObject:
				var location = curLua.specialVars.indexOf(val);
				if (location < 0) {
					location = curLua.specialVars.length;
					curLua.specialVars.push(val);
				}
	
				Lua.newtable(luaState);
				var tableIndex = Lua.gettop(luaState); //The variable position of the table. Used for paring the metatable with this table and attaching variables.
	
				Lua.pushstring(luaState, '__special_id'); //This is a helper var in the table that is used by the conversion functions to detect a special var.
				Lua.pushinteger(luaState, location);
				Lua.settable(luaState, tableIndex);

				//Idk why it thinks static classes are objects but ok.
				var className:String = Type.getClassName(val); //I should find a better way to check if its a class.
				if (className != null) {
					Lua.pushstring(luaState, "new"); //This implements the work around function to create the class instance.
					Lua.pushcfunction(luaState, ClassWorkarounds.workaroundCallable);
					Lua.rawset(luaState, tableIndex);
				}
	
				LuaL.getmetatable(luaState, "__scriptMetatable");
				Lua.setmetatable(luaState, tableIndex);

				return true;
			default: //Didn't fit any of the var types. Assuming it's an instance/pointer, creating table, and attaching table to metatable.
				var location = curLua.specialVars.indexOf(val);
				if (location < 0) {
					location = curLua.specialVars.length;
					curLua.specialVars.push(val);
				}

				Lua.newtable(luaState);
				var tableIndex = Lua.gettop(luaState); //The variable position of the table. Used for paring the metatable with this table and attaching variables.

				Lua.pushstring(luaState, '__special_id'); //This is a helper var in the table that is used by the conversion functions to detect a special var.
				Lua.pushinteger(luaState, location);
				Lua.settable(luaState, tableIndex);

				LuaL.getmetatable(luaState, "__scriptMetatable");
				Lua.setmetatable(luaState, tableIndex);

				return false;
		}

		return true;
	}

	public static function toHaxeObj(i:Int):Any {
		var luaState = LScript.currentLua.luaState;
		var count = 0;
		var array = true;

		loopTable(luaState, i, {
			if(array) {
				if(Lua.type(luaState, -2) != Lua.LUA_TNUMBER) array = false;
				else {
					var index = Lua.tonumber(luaState, -2);
					if(index < 0 || Std.int(index) != index) array = false;
				}
			}
			count++;
		});

		return
		if(count == 0) {
			{};
		} else if(array) {
			var v = [];
			loopTable(luaState, i, {
				var index = Std.int(Lua.tonumber(luaState, -2)) - 1;
				v[index] = fromLua(-1);
			});
			cast v;
		} else {
			var v:haxe.DynamicAccess<Any> = {};
			loopTable(luaState, i, {
				switch Lua.type(luaState, -2) {
					case t if(t == Lua.LUA_TSTRING): v.set(Lua.tostring(luaState, -2), fromLua(-1));
					case t if(t == Lua.LUA_TNUMBER): v.set(Std.string(Lua.tonumber(luaState, -2)), fromLua(-1));
				}
			});
			cast v;
		}
	}
}