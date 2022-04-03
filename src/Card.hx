import h2d.col.Point;
import Utils.*;

enum CardType {
	Track;
	Station;
	Money;
	Debt;
	Backside;
}

class Card {
	static final CARD_WIDTH = 21;
	static final CARD_HEIGHT = 31;

	public static var CARD_TILES = null;
	public static final NORMAL_CARD_SCALE = 5;
	public static final FULLSCREEN_CARD_SCALE = 20;

	static public function init() {
		CARD_TILES = [
			Track => hxd.Res.card_track.toTile(),
			Money => hxd.Res.card_money.toTile(),
			Station => hxd.Res.card_station.toTile(),
			Debt => hxd.Res.card_debt.toTile(),
			Backside => hxd.Res.card_back.toTile(),
		];
		for (tile in CARD_TILES) {
			tile.setCenterRatio();
		}
	}

	public final type:CardType;
	public final obj:h2d.Object;
	public var homePos = new Point();
	public var homeRotation = 0.0;
	public var homeScale = NORMAL_CARD_SCALE; // Gui.scale will be applied on top
	public var canMove = true;
	public var onRelease = (card:Card, pt:Point) -> {
		card.returnToHomePos();
	};

	public function new(type:CardType, parent:h2d.Object, scene:h2d.Scene, pos = null) {
		this.type = type;

		obj = new h2d.Bitmap(CARD_TILES[type]);
		obj.x = scene.width / 2;
		obj.y = scene.height / 2;
		obj.scale(Gui.scale(NORMAL_CARD_SCALE));
		if (pos == null) {
			parent.addChild(obj);
		} else {
			parent.addChildAt(obj, pos);
		}

		final interactive = new h2d.Interactive(CARD_WIDTH, CARD_HEIGHT, obj);
		interactive.x = -CARD_WIDTH / 2;
		interactive.y = -CARD_HEIGHT / 2;
		interactive.onPush = (e) -> {
			if (!canMove)
				return;
			scene.startCapture((e) -> {
				final pt = scene.localToGlobal(new Point(e.relX, e.relY));
				tween(obj, 0, {
					x: pt.x,
					y: pt.y,
					rotation: 0,
				});
			});
		};
		interactive.onRelease = (e) -> {
			scene.stopCapture();
			if (!canMove)
				return;
			onRelease(this, interactive.localToGlobal(new Point(e.relX, e.relY)));
		}

		homePos = toPoint(obj);
		homeRotation = obj.rotation;
	}

	public function returnToHomePos(time = 1.0) {
		tween(obj, time, {
			x: homePos.x,
			y: homePos.y,
			rotation: homeRotation,
			scaleX: Gui.scale(homeScale),
			scaleY: Gui.scale(homeScale),
		});
	}
}
