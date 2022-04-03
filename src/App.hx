class App extends HerbalTeaApp {
	public static var instance:App;

	public var musicChannel:hxd.snd.Channel;

	static function main() {
		instance = new App();
	}

	override function onload() {
		Card.init();

		musicChannel = hxd.Res.song.play(/* loop= */ true, /* volume= */ 0.5);
		musicChannel.pause = true;

		final params = new js.html.URLSearchParams(js.Browser.window.location.search);
		switch (params.get("start")) {
			case "game":
				switchState(new PlayView());
			case "gameover":
				switchState(new GameOverView(/* cardsDrawn= */ 0));
			case "intro":
				switchState(new IntroView());
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
