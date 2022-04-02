import h2d.col.Point;
import RenderUtils.*;
import Card;
import Utils.*;

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

	override function init() {
		Card.init();
		setUpCamera();

		addEventListener(onMapEvent);

		setUpGameModel();

		addChild(drawGr);

		handCards.push(new Card(Track, this, LAYER_UI));
		handCards.push(new Card(Money, this, LAYER_UI));
		handCards.push(new Card(Track, this, LAYER_UI));
		handCards.push(new Card(Station, this, LAYER_UI));
		handCards.push(new Card(Station, this, LAYER_UI));
		for (card in handCards) {
			card.obj.x = width / 2;
			card.obj.y = height / 2;
			card.onRelease = onReleaseHandCard;
		}
		arrangeHand();

		final deck = new Card(Backside, this, LAYER_UI);
		deck.homePos.x = Gui.scale(74);
		deck.homePos.y = height - Gui.scale(252);
		deck.returnToHomePos();
		deck.canMove = false;
		final deck = new Card(Backside, this, LAYER_UI);
		deck.homePos.x = Gui.scale(77);
		deck.homePos.y = height - Gui.scale(251);
		deck.returnToHomePos();
		deck.canMove = false;
		final deckNext = new Card(Backside, this, LAYER_UI);
		deckNext.homePos.x = Gui.scale(80);
		deckNext.homePos.y = height - Gui.scale(250);
		deckNext.returnToHomePos();

		if (new js.html.URLSearchParams(js.Browser.window.location.search).get("fps") != null) {
			addChildAt(fpsText, LAYER_UI);
		}

		for (i in 0...5) {
			final placeholder = new h2d.Bitmap(Card.CARD_TILES[Track], this);
			placeholder.scale(Gui.scale(2));
			placeholder.alpha = 0.5;
			placeholder.visible = false;
			constructionCardPlaceholders.push(placeholder);
		}
	}

	function setUpCamera() {
		// Set up fixed camera for UI elements.
		final uiCamera = new h2d.Camera(this);
		uiCamera.layerVisible = (layer) -> layer == LAYER_UI;
		interactiveCamera = uiCamera;

		// Set up moving camera for map.
		camera.anchorX = 0.5;
		camera.anchorY = 0.5;
		camera.clipViewport = true;
		camera.layerVisible = (layer) -> layer == LAYER_MAP;
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
		stations.push(points[1].multiply(0.1).add(points[0].multiply(0.9)));
	}

	function onReleaseHandCard(card:Card, pt:Point) {
		var mapPt = pt.clone();
		camera.screenToCamera(mapPt);

		switch (card.type) {
			case Track:
				if (trackUnderConstruction != null && trackUnderConstruction.paid < trackUnderConstruction.cost) {
					final placeholder = constructionCardPlaceholders[trackUnderConstruction.paid];
					if (toPoint(placeholder).distance(mapPt) < 450) {
						trace("Building track!");
						handCards.remove(card);

						trackUnderConstruction.cards.push(card);

						// Move to map layer.
						card.obj.remove();
						addChild(card.obj);

						var cardPos = toPoint(card.obj);
						camera.screenToCamera(cardPos);
						card.obj.x = cardPos.x;
						card.obj.y = cardPos.y;

						trackUnderConstruction.paid++;

						tween(card.obj, 1.0, {
							x: placeholder.x,
							y: placeholder.y,
							scaleX: placeholder.scaleX,
							scaleY: placeholder.scaleY,
						}).onComplete(() -> {
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
	}

	function arrangeHand() {
		var i = 0;
		for (card in handCards) {
			card.homePos.x = width * 0.5 + Math.min(width * 0.75, handCards.length * Gui.scale(60)) * (i / (handCards.length - 1) - 0.5);
			card.homePos.y = height - Gui.scale(50);
			card.homeRotation = (i / (handCards.length - 1) - 0.5) * Math.PI * 0.2;
			card.returnToHomePos();
			i++;
		}
	}

	function onMapEvent(event:hxd.Event) {
		event.propagate = false;

		if (event.kind == EPush) {
			clickedPt = new Point(event.relX, event.relY);
			final pt = clickedPt.clone();
			camera.screenToCamera(pt);

			var closestPoint = null;
			for (track in tracks) {
				final closestPointTrack = projectToLineSegment(pt, points[track.start], points[track.end]);
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
