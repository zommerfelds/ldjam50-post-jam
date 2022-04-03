class App extends HerbalTeaApp {
	public static var instance:App;

	static function main() {
		instance = new App();
	}

	override function onload() {
		Card.init();

		final params = new js.html.URLSearchParams(js.Browser.window.location.search);
		switch (params.get("start")) {
			case "game":
				switchState(new PlayView());
			case "gameover":
				switchState(new GameOverView());
			default:
				switchState(new MenuView());
		}
	}

	// TODO: move this to HerbalTeaApp
	public static function loadHighScore():Int {
		return hxd.Save.load({highscore: 0}).highscore;
	}

	public static function writeHighScore(highscore:Int) {
		hxd.Save.save({highscore: highscore});
	}
}
