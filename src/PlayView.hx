import motion.Actuate;
import h2d.col.Point;
import RenderUtils.*;

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
	final stations = [];
	var trackUnderConstruction:{
		start:Point,
		end:Point,
		cost:Int,
		paid:Int,
		cards:Array<Card>,
	} = null;

	final drawGr = new h2d.Graphics();
	final fpsText = new Gui.Text("", null, 0.5);
	final constructionCardPlaceholders:Array<h2d.Bitmap> = [];
	var clickedPt = null;

	final handCards:Array<Card> = [];

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

		setUpGameModel();

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

		for (i in 0...5) {
			final placeholder = new h2d.Bitmap(tileCardTrack, this);
			placeholder.scale(Gui.scale(2));
			placeholder.alpha = 0.5;
			placeholder.visible = false;
			constructionCardPlaceholders.push(placeholder);
		}
	}

	function setUpGameModel() {
		final rand = new hxd.Rand(/* seed= */ 10);

		points.push(new Point(-400, -700));
		points.push(new Point(400, 700));
		// points.push(new Point(800, 2000));

		for (i in -10...10) {
			for (j in -10...10) {
				houses.push(new Point((i + rand.rand()) * 1000, (j + rand.rand()) * 1000));
			}
		}

		tracks.push({start: 0, end: 1});
		// tracks.push({start: 1, end: 2});

		stations.push(points[0].multiply(0.1).add(points[1].multiply(0.9)));
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

		final card = new Card(type, obj);

		final interactive = new h2d.Interactive(CARD_WIDTH, CARD_HEIGHT, obj);
		interactive.x = -CARD_WIDTH / 2;
		interactive.y = -CARD_HEIGHT / 2;
		interactive.onPush = (e) -> {
			startCapture((e) -> {
				Actuate.tween(obj, 0, {
					x: e.relX,
					y: e.relY,
					rotation: 0,
				}).onComplete(() -> posUpdated(obj));
			});
		};
		interactive.onRelease = (e) -> {
			var pt = new Point(e.relX, e.relY);
			pt = interactive.localToGlobal(pt);
			camera.screenToCamera(pt);

			switch (card.type) {
				case Track:
					if (trackUnderConstruction != null && trackUnderConstruction.paid < trackUnderConstruction.cost) {
						final placeholder = constructionCardPlaceholders[trackUnderConstruction.paid];
						if (Utils.toPoint(placeholder).distance(pt) < 450) {
							trace("Building track!");
							handCards.remove(card);

							trackUnderConstruction.cards.push(card);

							// Move to map layer.
							obj.remove();
							addChild(obj);

							var cardPos = Utils.toPoint(card.obj);
							camera.screenToCamera(cardPos);
							card.obj.x = cardPos.x;
							card.obj.y = cardPos.y;

							trackUnderConstruction.paid++;

							Actuate.tween(card.obj, 1.0, {
								x: placeholder.x,
								y: placeholder.y,
								scaleX: placeholder.scaleX,
								scaleY: placeholder.scaleY,
							}).onUpdate(() -> posUpdated(card.obj)).onComplete(() -> {
								if (trackUnderConstruction.paid == trackUnderConstruction.cost) {
									points.push(trackUnderConstruction.start);
									points.push(trackUnderConstruction.end);
									tracks.push({start: points.length - 2, end: points.length - 1});
									for (card in trackUnderConstruction.cards) {
										card.obj.remove();
									}
									trackUnderConstruction = null;
								}
							});
						}
					}
				case Station:
				default:
			}
			arrangeHand();

			stopCapture();
		};

		addChildAt(obj, LAYER_UI);

		return card;
	}

	function arrangeHand() {
		var i = 0;
		for (card in handCards) {
			Actuate.tween(card.obj, 1.0, {
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
			clickedPt = new Point(event.relX, event.relY);
			final pt = clickedPt.clone();
			camera.screenToCamera(pt);

			var closestPoint = null;
			for (track in tracks) {
				final closestPointTrack = Utils.projectToLineSegment(pt, points[track.start], points[track.end]);
				if (closestPoint == null || closestPointTrack.distance(pt) < closestPoint.distance(pt)) {
					closestPoint = closestPointTrack;
				}
			}
			// For now you can't stop a construction in progress.
			final addingTrack = (closestPoint.distance(pt) < 100 && (trackUnderConstruction == null || trackUnderConstruction.paid == 0));
			if (addingTrack) {
				trackUnderConstruction = {
					start: closestPoint,
					end: pt,
					cost: 1,
					paid: 0,
					cards: [],
				};
			}

			final startDragPos = new Point(event.relX, event.relY);
			var lastDragPos = startDragPos.clone();

			// Using startCapture ensures we still get events when going over other interactives.
			startCapture(event -> {
				final pt = new Point(event.relX, event.relY);
				camera.screenToCamera(pt);

				if (addingTrack) {
					final newCost = Math.ceil(trackUnderConstruction.start.distance(pt) / 700);
					if (newCost <= 5) {
						trackUnderConstruction.end = pt.clone();
						trackUnderConstruction.cost = newCost;
					}

					// points[points.length - 1] = pt.clone();
				} else {
					// Moving camera
					camera.x += lastDragPos.x - event.relX;
					camera.y += lastDragPos.y - event.relY;
				}

				if (clickedPt != null && startDragPos.distance(new Point(event.relX, event.relY)) > Gui.scale() * 30) {
					// If we scroll too far, don't consider this a click.
					clickedPt = null;
				}

				lastDragPos = new Point(event.relX, event.relY);
			});
		} else if (event.kind == ERelease) {
			stopCapture();
			if (clickedPt != null && trackUnderConstruction.paid == 0) {
				trackUnderConstruction = null;
			}
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

		drawGr.beginFill(0xc79f1a);
		drawGr.lineStyle();
		for (house in houses) {
			final w = 140;
			final h = 200;
			drawGr.drawRect(house.x - w / 2, house.y - h / 2, w, h);
		}

		drawGr.beginFill(0x382c26);
		for (point in points) {
			drawGr.drawCircle(point.x, point.y, 35);
		}
		if (trackUnderConstruction != null) {
			drawGr.drawCircle(trackUnderConstruction.start.x, trackUnderConstruction.start.y, 35);
			drawGr.drawCircle(trackUnderConstruction.end.x, trackUnderConstruction.end.y, 35);
		}

		drawGr.endFill();
		drawGr.lineStyle(15, 0x662d0e);
		for (track in tracks) {
			drawRailroadTies(drawGr, points[track.start], points[track.end]);
		}
		if (trackUnderConstruction != null) {
			drawGr.lineStyle(15, 0x662d0e, 0.4);
			drawRailroadTies(drawGr, trackUnderConstruction.start, trackUnderConstruction.end);
		}

		drawGr.lineStyle(10, 0x000000);
		for (track in tracks) {
			drawRails(drawGr, points[track.start], points[track.end]);
		}
		for (placeholder in constructionCardPlaceholders) {
			placeholder.visible = false;
		}
		if (trackUnderConstruction != null) {
			drawGr.lineStyle(10, 0x000000, 0.4);
			drawRails(drawGr, trackUnderConstruction.start, trackUnderConstruction.end);

			drawGr.beginFill(0x706362);
			drawGr.lineStyle();

			final offsetY = 80;
			final triangleSize = 30;
			final placeholderWidth = constructionCardPlaceholders[0].getBounds().width;
			final w = (placeholderWidth + Gui.scale(10)) * trackUnderConstruction.cost + Gui.scale(10);
			final h = constructionCardPlaceholders[0].getBounds().height + Gui.scale(20);
			final popup = trackUnderConstruction.start.add(trackUnderConstruction.end).multiply(0.5);
			drawGr.drawRect(popup.x - w / 2, popup.y + offsetY + triangleSize, w, h);
			drawGr.moveTo(popup.x, popup.y + offsetY);
			drawGr.lineTo(popup.x - triangleSize, popup.y + offsetY + triangleSize);
			drawGr.lineTo(popup.x + triangleSize, popup.y + offsetY + triangleSize);

			for (i in 0...trackUnderConstruction.cost) {
				constructionCardPlaceholders[i].visible = true;
				constructionCardPlaceholders[i].x = popup.x - w / 2 + placeholderWidth / 2 + Gui.scale(10) + i * (placeholderWidth + Gui.scale(10));
				constructionCardPlaceholders[i].y = popup.y + offsetY + triangleSize + h / 2;
			}
		}

		drawGr.beginFill(0x735b2f);
		drawGr.lineStyle();
		for (station in stations) {
			drawGr.drawCircle(station.x, station.y, 150);
		}
	}
}
