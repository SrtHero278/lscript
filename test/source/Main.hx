package;

class Main extends openfl.display.Sprite {
	public function new():Void {
		super();

		addChild(new flixel.FlxGame(1280, 720, TestState, 120, 120, true));
	}
}