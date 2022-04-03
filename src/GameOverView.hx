import haxe.Timer;

class GameOverView extends GameState {
	override function init() {
		final centeringFlow = new h2d.Flow(this);
		centeringFlow.backgroundTile = h2d.Tile.fromColor(0x333333);
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
		centeringFlow.addSpacing(Gui.scaleAsInt(500));

		// TODO: add some stats

		makeCard();

		new Gui.TextButton(centeringFlow, "Try again", () -> {
			App.instance.switchState(new PlayView());
		}, Gui.Colors.BLUE, 0.8);

		centeringFlow.addSpacing(Gui.scaleAsInt(100));
	}

	function makeCard() {
		final card = new Card(Debt, this, this);
		card.obj.x = -Gui.scale(200);
		card.obj.y = Gui.scale(300);
		card.obj.rotation = Math.random() * Math.PI * 2;
		card.homePos.x += Gui.scale(200) * (Math.random() - 0.5);
		card.homePos.y += Gui.scale(200) * (Math.random() - 0.5);
		card.homeRotation = Math.random() * Math.PI * 2;
		card.returnToHomePos().ease(motion.easing.Cubic.easeOut);

		Timer.delay(makeCard, 2000);
	}
}
