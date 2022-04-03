class GameOverView extends GameState {
	override function init() {
		final centeringFlow = new h2d.Flow(this);
		centeringFlow.backgroundTile = h2d.Tile.fromColor(0x852a30);
		centeringFlow.fillWidth = true;
		centeringFlow.fillHeight = true;
		centeringFlow.horizontalAlign = Middle;
		centeringFlow.verticalAlign = Middle;
		centeringFlow.maxWidth = width;
		centeringFlow.layout = Vertical;
		centeringFlow.verticalSpacing = Gui.scaleAsInt(50);

		new Gui.Text("Game Over", centeringFlow);
		centeringFlow.addSpacing(Gui.scaleAsInt(50));

		new Gui.Text("Bankruptcy was inevitable!", centeringFlow, 0.7);
		centeringFlow.addSpacing(Gui.scaleAsInt(100));

		// TODO: add some stats

		new Gui.TextButton(centeringFlow, "Try again", () -> {
			App.instance.switchState(new PlayView());
		}, Gui.Colors.BLUE, 0.8);

		centeringFlow.addSpacing(Gui.scaleAsInt(100));
	}
}
