import motion.Actuate;
import h2d.col.Point;

enum CardType {
	Track;
	Station;
	Money;
}

class Card {
	public function new(type, obj) {
		this.type = type;
		this.obj = obj;
	}

	public final type:CardType;
	public final obj:h2d.Object;
}

class PlayView extends GameState {
	static final LAYER_MAP = 0;
	static final LAYER_UI = 1;

	final points = [];
	final tracks = [];
	final houses = [];

	final drawGr = new h2d.Graphics();
	final fpsText = new Gui.Text("", null, 0.5);

	final handCards = [];

	final tileCardTrack = hxd.Res.card_track.toTile();
	final tileCardMoney = hxd.Res.card_money.toTile();
	final tileCardStation = hxd.Res.card_station.toTile();

	final CARD_WIDTH = 21;
	final CARD_HEIGHT = 31;

	override function init() {
		// Set up fixed camera for UI elements.
		final uiCamera = new h2d.Camera(this);
		uiCamera.layerVisible = (layer) -> layer == LAYER_UI;
		interactiveCamera = uiCamera;

		// Set up moving camera for map.
		camera.anchorX = 0.5;
		camera.anchorY = 0.5;
		camera.clipViewport = true;
		camera.layerVisible = (layer) -> layer == LAYER_MAP;

		addEventListener(onMapEvent);

		final rand = new hxd.Rand(/* seed= */ 10);

		points.push(new Point(-100, -700));
		points.push(new Point(1000, 500));
		points.push(new Point(800, 2000));

		for (i in -10...10) {
			for (j in -10...10) {
				houses.push(new Point((i + rand.rand()) * 700, (j + rand.rand()) * 700));
			}
		}

		tracks.push({start: 0, end: 1});
		tracks.push({start: 1, end: 2});

		addChild(drawGr);

		tileCardTrack.setCenterRatio();
		tileCardMoney.setCenterRatio();
		tileCardStation.setCenterRatio();

		handCards.push(makeCard(Track));
		handCards.push(makeCard(Money));
		handCards.push(makeCard(Track));
		handCards.push(makeCard(Station));
		handCards.push(makeCard(Station));
		arrangeHand();

		if (new js.html.URLSearchParams(js.Browser.window.location.search).get("fps") != null) {
			addChildAt(fpsText, LAYER_UI);
		}
	}

	function makeCard(type:CardType) {
		final obj = new h2d.Bitmap(switch (type) {
			case Track: tileCardTrack;
			case Station: tileCardStation;
			case Money: tileCardMoney;
		});
		obj.scale(Gui.scale(5));
		obj.x = width / 2;
		obj.y = height / 2;

		final interactive = new h2d.Interactive(CARD_WIDTH, CARD_HEIGHT, obj);
		interactive.x = -CARD_WIDTH / 2;
		interactive.y = -CARD_HEIGHT / 2;
		interactive.onClick = (e) -> {
			trace("Touched " + type);
		};

		final card = new Card(type, obj);

		addChildAt(obj, LAYER_UI);

		return card;
	}

	function arrangeHand() {
		var i = 0;
		for (card in handCards) {
			Actuate.tween(card.obj, 3, {
				x: width * 0.5 + Math.min(width * 0.75, handCards.length * Gui.scale(60)) * (i / (handCards.length - 1) - 0.5),
				y: height - Gui.scale(50),
				rotation: (i / (handCards.length - 1) - 0.5) * Math.PI * 0.2,
			}).onUpdate(() -> posUpdated(card.obj));
			i++;
		}
	}

	function posUpdated(obj:h2d.Object) {
		// Tween is not smart enough to call the setter.
		obj.x = obj.x;
	}

	function onMapEvent(event:hxd.Event) {
		event.propagate = false;

		if (event.kind == EPush) {
			final pt = new Point(event.relX, event.relY);
			camera.screenToCamera(pt);
			// clickedLevel = map.findIndex(arch -> arch.pos.sub(new Point(0, -Gui.scale() * 30)).distance(pt) < Gui.scale() * 60);

			var closestPoint = null;
			for (track in tracks) {
				final closestPointTrack = Utils.projectToLineSegment(pt, points[track.start], points[track.end]);
				if (closestPoint == null || closestPointTrack.distance(pt) < closestPoint.distance(pt)) {
					closestPoint = closestPointTrack;
				}
			}
			final addingTrack = (closestPoint.distance(pt) < 100);
			if (addingTrack) {
				points.push(closestPoint);
				points.push(pt);
				tracks.push({start: points.length - 2, end: points.length - 1});
			}

			final startDragPos = new Point(event.relX, event.relY);
			var lastDragPos = startDragPos.clone();

			// Using startCapture ensures we still get events when going over other interactives.
			startCapture(event -> {
				final pt = new Point(event.relX, event.relY);
				camera.screenToCamera(pt);

				if (addingTrack) {
					points[points.length - 1] = pt.clone();
				} else {
					// Moving camera
					camera.x += lastDragPos.x - event.relX;
					camera.y += lastDragPos.y - event.relY;
				}

				/*if (clickedLevel != -1 && startDragPos.distance(new Point(event.relX, event.relY)) > Gui.scale() * 30) {
					// If we scroll too far, drop a level click action.
					clickedLevel = -1;
				}*/

				lastDragPos = new Point(event.relX, event.relY);
			});
		} else if (event.kind == ERelease) {
			stopCapture();
			/*if (clickedLevel != -1) {
				// click!
			}*/
		}
	}

	override function update(dt:Float) {
		drawMap();

		fpsText.text = "FPS: " + Math.round(hxd.Timer.fps());
	}

	function drawMap() {
		drawGr.clear();
		drawGr.beginFill(0x509450);
		drawGr.drawRect(-10000, -10000, 20000, 20000);

		drawGr.beginFill(0x382c26);
		for (point in points) {
			drawGr.drawCircle(point.x, point.y, 35);
		}

		drawGr.endFill();
		drawGr.lineStyle(15, 0x662d0e);

		for (track in tracks) {
			final start = points[track.start];
			final end = points[track.end];
			final dir = end.sub(start).normalized();
			final offset = dir.multiply(30);
			offset.rotate(0.5 * Math.PI);

			var pos = start.add(dir.multiply(25));
			while (pos.distance(start) + 25 < end.distance(start)) {
				final plankLeft = pos.add(offset.multiply(1.5));
				final plankRight = pos.sub(offset.multiply(1.5));
				drawGr.moveTo(plankLeft.x, plankLeft.y);
				drawGr.lineTo(plankRight.x, plankRight.y);
				pos = pos.add(dir.multiply(25));
			}
		}

		drawGr.lineStyle(10, 0x000000);
		for (track in tracks) {
			final start = points[track.start];
			final end = points[track.end];
			final dir = end.sub(start).normalized();
			final offset = dir.multiply(30);
			offset.rotate(0.5 * Math.PI);

			final rail1Start = start.add(offset);
			final rail1End = end.add(offset);
			drawGr.moveTo(rail1Start.x, rail1Start.y);
			drawGr.lineTo(rail1End.x, rail1End.y);
			final rail2Start = start.sub(offset);
			final rail2End = end.sub(offset);
			drawGr.moveTo(rail2Start.x, rail2Start.y);
			drawGr.lineTo(rail2End.x, rail2End.y);
		}

		drawGr.beginFill(0xc79f1a);
		drawGr.lineStyle();
		for (house in houses) {
			final w = 140;
			final h = 200;
			drawGr.drawRect(house.x - w / 2, house.y - h / 2, w, h);
		}
	}
}
