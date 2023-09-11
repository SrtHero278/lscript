package;

import lscript.LScript;

class TestState extends flixel.FlxState {
    var script:LScript;

    override public function create() {
        super.create();
        
        script = new LScript(openfl.Assets.getText("assets/test.lua"));
        script.parent = this;
        script.setVar("FlxG", flixel.FlxG);
        script.setVar("FlxSprite", flixel.FlxSprite);
        script.execute();
        script.callFunc("create");
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);
        script.callFunc("update", [elapsed]);
    }
}