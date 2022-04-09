class MenuView extends GameState {
	override function init() {
		final centeringFlow = new h2d.Flow(this);
		centeringFlow.backgroundTile = h2d.Tile.fromColor(0x082036);
		centeringFlow.fillWidth = true;
		centeringFlow.fillHeight = true;
		centeringFlow.horizontalAlign = Middle;
		centeringFlow.verticalAlign = Middle;
		centeringFlow.maxWidth = width;
		centeringFlow.layout = Vertical;
		centeringFlow.verticalSpacing = Gui.scaleAsInt(50);

		new Gui.Text("Debt Train", centeringFlow);

		centeringFlow.addSpacing(Gui.scaleAsInt(100));

		new Gui.TextButton(centeringFlow, "Toggle fullscreen", () -> {
			HerbalTeaApp.toggleFullScreen();
			centeringFlow.reflow();
		}, Gui.Colors.BLUE, 0.8);
		new Gui.TextButton(centeringFlow, "Start game!", () -> {
			App.instance.switchState(new IntroView());
		}, Gui.Colors.BLUE, 0.8);

		centeringFlow.addSpacing(Gui.scaleAsInt(100));

		new Gui.Text("Game by Christian Zommerfelds", centeringFlow, 0.5);
		new Gui.Text("Ludum Dare 50, post jam edition", centeringFlow, 0.5);
		new Gui.Text("Version: " + hxd.Res.version.entry.getText(), centeringFlow, 0.5);
	}
}
