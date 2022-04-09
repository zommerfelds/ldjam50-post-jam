import haxe.Timer;
import haxe.Exception;
import motion.Actuate;
import h2d.col.Point;
import RenderUtils.*;
import Card;
import Utils.*;

using Lambda;

class PlayView extends GameState {
	static final LAYER_MAP = 0;
	static final LAYER_UI = 1;

	final points = [];
	final tracks = [];
	final houses:Array<{
		center:Point,
		connectedStation:Null<Int>,
		bitmap:h2d.Bitmap
	}> = [];
	final water:Array<{
		x:Float,
		y:Float,
		w:Float,
		h:Float,
		differ:differ.shapes.Polygon,
	}> = [];
	final stations:Array<h2d.Bitmap> = [];
	var trackUnderConstruction:{
		start:Point,
		end:Point,
		cost:Int,
		paid:Int,
		cards:Array<Card>,
		valid:Bool,
	} = null;
	final drawGr = new h2d.Graphics();
	final fpsText = new Gui.Text("", null, 0.5);
	final tutorialText = new Gui.Text("", null, 0.7);
	final constructionCardPlaceholders:Array<h2d.Bitmap> = [];
	var clickedPt = null;
	var payDebtCard:Null<Card> = null;
	final handCards:Map<h2d.Object, Card> = [];
	final handCardsContainer = new h2d.Object();
	final nonHandCardsContainer = new h2d.Object();
	final seed = Std.random(0x7FFFFFFF);
	final rand:hxd.Rand;

	var movingHandCard:Null<Card> = null;

	static final STATION_RADIUS = 800.0;
	static final MAP_PIXEL_SCALE = 9;

	final tileHouse = hxd.Res.house.toTile();
	final tileStation = hxd.Res.station.toTile();

	final mapObjects = new h2d.Object();

	// The next cards on top of the deck. Once empty, a new set of cards is generated, kind of like in Tetris.
	final deckNextCards:Array<CardType> = [];

	var cardsDrawn = 0;
	var zooming = 0;

	public function new() {
		super();
		rand = new hxd.Rand(seed);
		trace("Random seed: " + seed);
	}

	override function init() {
		App.instance.musicChannel.pause = false;
		App.instance.musicChannel.fadeTo(/* volume= */ 0.5, /* time=*/ 3.0);
		setUpTiles();

		setUpCamera();

		addEventListener(onMapEvent);

		addChild(drawGr);

		setUpEntities();

		setUpDeck();
		setUpHand();

		setUpZoomButtons();

		addChildAt(nonHandCardsContainer, LAYER_UI);

		addChildAt(tutorialText, LAYER_UI);
		tutorialText.y = height - Gui.scale(300);
		tutorialText.x = width * 0.1;
		tutorialText.maxWidth = width * 0.9 / tutorialText.scaleX;

		if (new js.html.URLSearchParams(js.Browser.window.location.search).get("fps") != null) {
			addChildAt(fpsText, LAYER_UI);
		}

		for (i in 0...5) {
			final placeholder = new h2d.Bitmap(Card.CARD_TILES[Track], this);
			placeholder.scale(Gui.scale(3) / camera.scaleX);
			placeholder.alpha = 0.5;
			placeholder.visible = false;
			constructionCardPlaceholders.push(placeholder);
		}
	}

	function showMessage(text) {
		tutorialText.alpha = 1;
		tutorialText.text = text;
		Actuate.tween(tutorialText, 1.0, {alpha: 0.0}).delay(5.0);
	}

	function setUpTiles() {
		tileHouse.setCenterRatio();
		tileStation.setCenterRatio();
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
		final s = Gui.scale() * 0.35;
		camera.scale(s, s);
	}

	function setUpEntities() {
		addChild(mapObjects);
		// It's very slow to compute shadow for all objects together.
		// But this would have been nice.
		// mapObjects.filter = new h2d.filter.DropShadow(40.0, Math.PI * 0.7, 0, 0.6);

		points.push(new Point(0, -700));
		points.push(new Point(0, 700));
		final startArea = differ.shapes.Polygon.rectangle(0, 0, 700, 1800);

		for (i in 0...20) {
			final x = rand.rand() * (2 * 10000 - 3500) - 10000;
			final y = rand.rand() * (2 * 10000 - 3500) - 10000;
			final w = rand.rand() * 3000 + 500;
			final h = rand.rand() * 3000 + 500;
			final d = differ.shapes.Polygon.rectangle(x, y, w, h, false);
			if (differ.Collision.shapeWithShape(d, startArea) == null) {
				water.push({
					x: x,
					y: y,
					w: w,
					h: h,
					differ: d
				});
			}
		}

		for (i in -19...20) {
			for (j in -19...20) {
				if (rand.rand() > 0.1)
					continue;
				final pt = new Point((i + rand.rand() * 0.55) * 500, (j + rand.rand() * 0.55) * 500);
				if (differ.Collision.pointInPoly(pt.x, pt.y, startArea))
					continue;
				var inLake = false;
				for (lake in water) {
					if (differ.Collision.pointInPoly(pt.x, pt.y, lake.differ)) {
						inLake = true;
						break;
					}
				}
				if (inLake)
					continue;
				addHouse(pt, rand.random(4) * Math.PI / 2);
			}
		}

		tracks.push({start: 0, end: 1});

		final stationPos = points[0].multiply(0.1).add(points[1].multiply(0.9));
		final dir = points[1].sub(points[0]);
		final rotation = Math.atan2(dir.y, dir.x);
		placeStation(null, stationPos, rotation, false);
	}

	function onReleaseHandCard(card:Card, pt:Point) {
		movingHandCard = null;
		var mapPt = pt.clone();
		camera.screenToCamera(mapPt);

		Card.gobalCanMove = false;

		switch (card.type) {
			case Track:
				if (payDebtCard == null) {
					if (trackUnderConstruction != null
						&& trackUnderConstruction.valid
						&& trackUnderConstruction.paid < trackUnderConstruction.cost) {
						final placeholder = constructionCardPlaceholders[trackUnderConstruction.paid];
						if (toPoint(placeholder).distance(mapPt) < 450) {
							addCardToConstruction(card);
						} else {
							showMessage("Drag this card on the construction to pay a track.");
							hxd.Res.invalid.play();
						}
					} else {
						showMessage("First, start a construction by touching and dragging from a track.");
						hxd.Res.invalid.play();
					}
				} else {
					showMessage("You need to pay the debt first.");
					hxd.Res.invalid.play();
				}
				arrangeHand();
			case Money:
				if (payDebtCard != null) {
					payMoneyForDebt(card);
				} else {
					showMessage("You don't need to pay anything right now.");
					hxd.Res.invalid.play();
				}
				arrangeHand();
			case Station:
				final pointOnTrack = getClosestPointOnTrack(mapPt);
				if (payDebtCard == null) {
					if (placingStationValid(pt, mapPt, pointOnTrack.closestPoint)) {
						placeStation(card, pointOnTrack.closestPoint, pointOnTrack.rotation, true);
					} else {
						showMessage("Place this card on a track to build a station.");
						hxd.Res.invalid.play();
						arrangeHand();
					}
				} else {
					showMessage("You need to pay the debt first.");
					hxd.Res.invalid.play();
					arrangeHand();
				}
			default:
				// Ignore the move.
				hxd.Res.invalid.play();
				arrangeHand();
		}
	}

	function placingStationValid(screenPt, mapPt, pointOnTrack) {
		if (pointOnTrack.distance(mapPt) > STATION_RADIUS
			|| screenPt.y > height - Gui.scale(Card.NORMAL_CARD_SCALE) * Card.CARD_HEIGHT * 1.2)
			return false;
		for (station in stations) {
			if (pointOnTrack.distance(toPoint(station)) < 450)
				return false;
		}
		for (house in houses) {
			if (pointOnTrack.distance(toPoint(house.bitmap)) < 450)
				return false;
		}
		return true;
	}

	function addCardToConstruction(card) {
		hxd.Res.good.play();

		final placeholder = constructionCardPlaceholders[trackUnderConstruction.paid];
		trackUnderConstruction.cards.push(card);

		// Move to map layer.
		removeHandCard(card);
		addChild(card.obj);

		var cardPos = toPoint(card.obj);
		camera.screenToCamera(cardPos);
		card.obj.x = cardPos.x;
		card.obj.y = cardPos.y;
		card.obj.scale(1 / camera.scaleX);

		trackUnderConstruction.paid++;

		tween(card.obj, 0.7, {
			x: placeholder.x,
			y: placeholder.y,
			scaleX: placeholder.scaleX,
			scaleY: placeholder.scaleY,
		}).ease(motion.easing.Cubic.easeOut).onComplete(() -> {
			if (trackUnderConstruction == null) {
				// TODO: this happens sometimes, but I don't know how to repro yet.
				trace("ERROR: trackUnderConstruction shouldn't be null!");
				return;
			}
			if (trackUnderConstruction.paid == trackUnderConstruction.cost) {
				hxd.Res.build.play();

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

	function payMoneyForDebt(moneyCard) {
		final tmpPayDebtCard = payDebtCard;
		payDebtCard = null; // Set to null to you can spend more money during the tween.
		hxd.Res.good.play();
		removeHandCard(moneyCard);
		tween(tmpPayDebtCard.obj, 1.0, {
			scaleX: 0,
			scaleY: 0,
			alpha: 0,
		}).onComplete(() -> {
			tmpPayDebtCard.obj.remove();
		});
		makeNextDeckCard();
	}

	function placeStation(stationCard, pointOnTrack, rotation, makeMoney) {
		hxd.Res.build.play();

		addStation(pointOnTrack, rotation);
		if (stationCard != null) {
			removeHandCard(stationCard);
		}

		final tweenTime = 1.0;
		var moneyEarned = 0.0;
		for (house in houses) {
			if (pointOnTrack.distance(house.center) <= STATION_RADIUS && house.connectedStation == null) {
				house.connectedStation = stations.length - 1;
				if (makeMoney) {
					moneyEarned++;
					final card = newHandCard(Money);
					final screenPt = house.center.clone();
					camera.cameraToScreen(screenPt);
					card.obj.x = screenPt.x;
					card.obj.y = screenPt.y;
					card.obj.scale(0);
					card.obj.rotation = Math.random() * 2 * Math.PI;
					tween(card.obj, tweenTime, {
						scaleX: Gui.scale(Card.NORMAL_CARD_SCALE),
						scaleY: Gui.scale(Card.NORMAL_CARD_SCALE),
						rotation: 0,
					});
				}
			}
		}
		if (moneyEarned > 0) {
			Timer.delay(() -> {
				hxd.Res.good.play();
				arrangeHand();
			}, Std.int(tweenTime * 0.8 * 1000));
		} else {
			arrangeHand();
		}
	}

	function flipDeckCard(card:Card, pt:Point) {
		Card.gobalCanMove = false;
		hxd.Res.beep.play();
		card.canMove = false;
		tween(card.obj, 1.0, {
			x: width / 2,
			y: height / 2,
			scaleX: Gui.scale(Card.FULLSCREEN_CARD_SCALE),
			scaleY: Gui.scale(Card.FULLSCREEN_CARD_SCALE),
		});

		Actuate.timer(0.2).onComplete(() -> {
			tween(card.obj, 0.4, {
				scaleX: 0,
			}, /* overwrite= */ false).ease(motion.easing.Sine.easeIn).onComplete(() -> {
				final newCard = newCardFromDeck();
				copyTransform(card.obj, newCard.obj);
				card.obj.remove();
				tween(newCard.obj, 0.3, {
					scaleX: Gui.scale(Card.FULLSCREEN_CARD_SCALE),
				}, /* after= */ () -> {
					handleNewCard(newCard);
				}).ease(motion.easing.Sine.easeOut);
			});
		});
	}

	function handleNewCard(card:Card) {
		switch (card.type) {
			case Debt:
				hxd.Res.bad.play();
				payDebtCard = card;
				if (Lambda.exists(handCards, c -> c.type == Money)) {
					tween(card.obj, 1.0, {
						scaleX: Gui.scale(Card.FULLSCREEN_CARD_SCALE / 2),
						scaleY: Gui.scale(Card.FULLSCREEN_CARD_SCALE / 2),
					});
					card.onClickLocked = (card) -> {
						showMessage("Drag money to pay debt.");
					};
				} else {
					App.instance.musicChannel.fadeTo(/* volume= */ 0, /* time=*/ 3.0);
					tween(card.obj, 3.0,
						{
							scaleX: Gui.scale(Card.FULLSCREEN_CARD_SCALE * 4),
							scaleY: Gui.scale(Card.FULLSCREEN_CARD_SCALE * 4),
							rotation: Math.PI * 2,
						}).ease(motion.easing.Cubic.easeIn).delay(0.2).onComplete(() -> App.instance.switchState(new GameOverView(cardsDrawn)));
				}
			case Money | Track | Station:
				hxd.Res.good.play();
				// Let card go to hand (it's already assigned to the hand).
				card.canMove = true;
				arrangeHand();
				makeNextDeckCard();
			case Backside:
				throw new Exception("Invalid new card: " + card.type);
		}
		Card.gobalCanMove = true;
	}

	function newCardFromDeck():Card {
		if (deckNextCards.empty()) {
			deckNextCards.push(Track);
			deckNextCards.push(Track);
			deckNextCards.push(Track);
			deckNextCards.push(Station);
			if (rand.rand() < 0.5) {
				deckNextCards.push(Money);
			}
			for (i in 0...Std.int(1 + cardsDrawn * 0.02)) {
				deckNextCards.push(Debt);
			}

			rand.shuffle(deckNextCards);
		}

		cardsDrawn++;
		final type = deckNextCards.pop();
		final card = if (type == Debt) {
			newNonHandCard(Debt);
		} else {
			newHandCard(type);
		}
		card.canMove = false;
		return card;
	}

	function newHandCard(type:CardType):Card {
		final pos = getPositionForNewHandCard(type);
		final card = new Card(type, handCardsContainer, this, pos);
		handCards.set(card.obj, card);
		card.onRelease = onReleaseHandCard;
		card.onMove = (card, pt) -> {
			movingHandCard = card;
		};
		return card;
	}

	function newNonHandCard(type:CardType) {
		return new Card(type, nonHandCardsContainer, this);
	}

	function getPositionForNewHandCard(type:CardType) {
		for (i in 0...handCardsContainer.children.length) {
			if (handOrder(handCards[handCardsContainer.getChildAt(i)].type) > handOrder(type)) {
				return i;
			}
		}
		return handCardsContainer.children.length;
	}

	static function handOrder(type:CardType) {
		return switch (type) {
			case Money: 0;
			case Track: 1;
			case Station: 2;
			default: 999; // Should not be on the hand
		};
	}

	function removeHandCard(card:Card) {
		handCards.remove(card.obj);
		card.obj.remove();
	}

	function arrangeHand() {
		var i = 0;
		final numCards = handCardsContainer.children.length;

		for (cardObj in handCardsContainer.children) {
			final card = handCards[cardObj];
			if (numCards > 1) {
				card.homePos.x = width * 0.5 + Math.min(width * 0.75, numCards * Gui.scale(60)) * (i / (numCards - 1) - 0.5);
				card.homeRotation = (i / (numCards - 1) - 0.5) * Math.PI * 0.2;
			} else {
				card.homePos.x = width * 0.5;
				card.homeRotation = 0;
			}
			card.homePos.y = height - Gui.scale(50);
			card.homeScale = Card.NORMAL_CARD_SCALE;
			card.returnToHomePos();
			i++;
		}

		// A bit of a hack
		Card.gobalCanMove = true;
	}

	function getClosestPointOnTrack(pt) {
		var closestPoint = null;
		var closestTrack = null;
		for (track in tracks) {
			final closestPointTrack = projectToLineSegment(pt, points[track.start], points[track.end]);
			if (closestPoint == null || closestPointTrack.distance(pt) < closestPoint.distance(pt)) {
				closestPoint = closestPointTrack;
				closestTrack = track;
			}
		}
		final trackDir = points[closestTrack.start].sub(points[closestTrack.end]);
		return {
			closestPoint: closestPoint,
			rotation: Math.atan2(trackDir.y, trackDir.x),
		};
	}

	function onMapEvent(event:hxd.Event) {
		event.propagate = false;

		// Ignore multiple fingers
		if (event.touchId != null && event.touchId != 0)
			return;

		if (event.kind == EWheel) {
			scaleCamera(Math.exp(-event.wheelDelta * 0.3));
		}

		if (event.kind == EPush) {
			clickedPt = new Point(event.relX, event.relY);
			final pt = clickedPt.clone();
			camera.screenToCamera(pt);

			final closestPoint = getClosestPointOnTrack(pt).closestPoint;
			// For now you can't stop a construction in progress.
			final addingTrack = (closestPoint.distance(pt) < 100 && (trackUnderConstruction == null || trackUnderConstruction.paid == 0));
			if (addingTrack) {
				trackUnderConstruction = {
					start: closestPoint,
					end: pt,
					cost: 1,
					paid: 0,
					cards: [],
					valid: false,
				};
			}

			final startDragPos = new Point(event.relX, event.relY);
			var lastDragPos = startDragPos.clone();

			// Using startCapture ensures we still get events when going over other interactives.
			startCapture(event -> {
				// Ignore multiple fingers
				if (event.touchId != null && event.touchId != 0)
					return;
				if (event.kind == EFocus) // Seems like the first focus event has broken coordinates.
					return;
				final pt = new Point(event.relX, event.relY);
				camera.screenToCamera(pt);

				if (addingTrack) {
					// The longer you build the less it costs.
					final x = trackUnderConstruction.start.distance(pt) / 600;
					final newCost = Math.ceil(Math.pow(x, 0.7) - 0.5);
					if (newCost <= 5) {
						trackUnderConstruction.end = pt.clone();
						trackUnderConstruction.cost = newCost;
						trackUnderConstruction.valid = canBuildTrack(trackUnderConstruction.start, trackUnderConstruction.end);
					}

					// points[points.length - 1] = pt.clone();
				} else {
					// Moving camera
					if (event.kind == EMove) {
						camera.x += (lastDragPos.x - event.relX) / camera.scaleX;
						camera.y += (lastDragPos.y - event.relY) / camera.scaleY;
					}
				}

				if (clickedPt != null && startDragPos.distance(new Point(event.relX, event.relY)) > Gui.scale() * 30) {
					// If we scroll too far, don't consider this a click.
					clickedPt = null;
				}

				lastDragPos = new Point(event.relX, event.relY);

				if (event.kind == ERelease || event.kind == EReleaseOutside) {
					stopCapture();
					if (clickedPt != null && trackUnderConstruction != null && trackUnderConstruction.paid == 0) {
						trackUnderConstruction = null;
					}
				}
			});
		}
	}

	function canBuildTrack(start, end) {
		final ray = new differ.shapes.Ray(new differ.math.Vector(start.x, start.y), new differ.math.Vector(end.x, end.y));
		// For some reason the first ray doesn't collide if it originates in the shape (bug in the library?)
		final rayReversed = new differ.shapes.Ray(ray.end, ray.start);
		final padding = 70;
		for (house in houses) {
			final shape = differ.shapes.Polygon.rectangle(house.bitmap.x, house.bitmap.y, tileHouse.width * MAP_PIXEL_SCALE + padding,
				tileHouse.height * MAP_PIXEL_SCALE + padding);
			shape.rotation = hxd.Math.radToDeg(house.bitmap.rotation);
			if (differ.Collision.rayWithShape(ray, shape) != null || differ.Collision.rayWithShape(rayReversed, shape) != null)
				return false;
		}

		for (station in stations) {
			final shape = differ.shapes.Polygon.rectangle(station.x, station.y, tileStation.width * MAP_PIXEL_SCALE + padding,
				tileStation.height * MAP_PIXEL_SCALE + padding);
			shape.rotation = hxd.Math.radToDeg(station.rotation);
			if (differ.Collision.rayWithShape(ray, shape) != null || differ.Collision.rayWithShape(rayReversed, shape) != null)
				return false;
		}

		for (lake in water) {
			final shape = differ.shapes.Polygon.rectangle(lake.x + lake.w / 2, lake.y + lake.h / 2, lake.w - 130, lake.h - 130);
			if (differ.Collision.rayWithShape(ray, shape) != null || differ.Collision.rayWithShape(rayReversed, shape) != null)
				return false;
		}
		return true;
	}

	override function update(dt:Float) {
		drawMap();

		fpsText.text = "FPS: " + Math.round(hxd.Timer.fps());

		scaleCamera(Math.exp(dt * zooming * 2.0));
	}

	function scaleCamera(scale:Float) {
		final s = Math.max(0.05, Math.min(1, camera.scaleX * scale));
		camera.scaleX = s;
		camera.scaleY = s;
	}

	function drawMap() {
		var stationPreview = null;
		if (movingHandCard != null && movingHandCard.type == Station) {
			// Draw a circle for the station's range.
			final screenPt = toPoint(movingHandCard.obj);
			final mapPt = screenPt.clone();
			camera.screenToCamera(mapPt);
			final pointOnTrack = getClosestPointOnTrack(mapPt);
			if (placingStationValid(screenPt, mapPt, pointOnTrack.closestPoint)) {
				stationPreview = pointOnTrack.closestPoint;
			}
		}

		drawGr.clear();
		drawGr.beginFill(0x509450);
		drawGr.drawRect(-10000, -10000, 20000, 20000);

		drawGr.beginFill(0x63d0ff);
		for (lake in water) {
			drawGr.drawRoundedRect(lake.x + 100, lake.y + 100, lake.w - 200, lake.h - 200, 200);
		}

		for (house in houses) {
			if (stationPreview != null && stationPreview.distance(house.center) <= STATION_RADIUS && house.connectedStation == null) {
				house.bitmap.blendMode = Add;
			} else {
				house.bitmap.blendMode = Alpha;
			}
		}

		drawGr.endFill();
		drawGr.lineStyle(20, 0xa88a63);
		for (house in houses) {
			if (house.connectedStation == null)
				continue;
			drawGr.moveTo(house.center.x, house.center.y);
			drawGr.lineTo(stations[house.connectedStation].x, stations[house.connectedStation].y);
		}

		drawGr.lineStyle();
		drawGr.beginFill(0x382c26);
		for (point in points) {
			drawGr.drawCircle(point.x, point.y, 35);
		}
		if (trackUnderConstruction != null) {
			drawGr.drawCircle(trackUnderConstruction.start.x, trackUnderConstruction.start.y, 35);
			drawGr.drawCircle(trackUnderConstruction.end.x, trackUnderConstruction.end.y, 35);
		}

		drawGr.endFill();
		var railroadTiesColor = 0x662d0e;
		drawGr.lineStyle(15, railroadTiesColor);
		for (track in tracks) {
			drawRailroadTies(drawGr, points[track.start], points[track.end]);
		}
		if (trackUnderConstruction != null) {
			if (!trackUnderConstruction.valid) {
				railroadTiesColor = hxd.Math.colorLerp(railroadTiesColor, 0xff0000, 0.6);
			}
			drawGr.lineStyle(15, railroadTiesColor, 0.4);
			drawRailroadTies(drawGr, trackUnderConstruction.start, trackUnderConstruction.end);
		}

		var railColor = 0x000000;
		drawGr.lineStyle(10, railColor);
		for (track in tracks) {
			drawRails(drawGr, points[track.start], points[track.end]);
		}
		for (placeholder in constructionCardPlaceholders) {
			placeholder.visible = false;
		}
		if (trackUnderConstruction != null) {
			if (!trackUnderConstruction.valid) {
				railColor = hxd.Math.colorLerp(railColor, 0xff0000, 0.6);
			}
			drawGr.lineStyle(10, railColor, 0.4);
			drawRails(drawGr, trackUnderConstruction.start, trackUnderConstruction.end);

			if (trackUnderConstruction.valid) {
				drawGr.beginFill(0x706362);
				drawGr.lineStyle();

				final offsetY = 120;
				final triangleSize = 30;
				final placeholderWidth = constructionCardPlaceholders[0].getBounds().width;
				final w = (placeholderWidth + Gui.scale(10) / camera.scaleX) * trackUnderConstruction.cost + Gui.scale(10) / camera.scaleX;
				final h = constructionCardPlaceholders[0].getBounds().height + Gui.scale(20) / camera.scaleX;
				final popup = trackUnderConstruction.start.add(trackUnderConstruction.end).multiply(0.5);
				drawGr.drawRect(popup.x - w / 2, popup.y + offsetY + triangleSize, w, h);
				drawGr.moveTo(popup.x, popup.y + offsetY);
				drawGr.lineTo(popup.x - triangleSize, popup.y + offsetY + triangleSize);
				drawGr.lineTo(popup.x + triangleSize, popup.y + offsetY + triangleSize);

				for (i in 0...trackUnderConstruction.cost) {
					constructionCardPlaceholders[i].visible = true;
					constructionCardPlaceholders[i].x = popup.x - w / 2 + placeholderWidth / 2 + Gui.scale(10) / camera.scaleX
						+ i * (placeholderWidth + Gui.scale(10) / camera.scaleX);
					constructionCardPlaceholders[i].y = popup.y + offsetY + triangleSize + h / 2;
				}
			}
		}

		drawGr.beginFill(0x735b2f);
		drawGr.lineStyle();
		for (station in stations) {
			drawGr.drawCircle(station.x, station.y, 150);
		}

		if (stationPreview != null) {
			drawGr.endFill();
			drawGr.lineStyle(10, 0xffffff, 0.8);
			drawGr.drawCircle(stationPreview.x, stationPreview.y, STATION_RADIUS * 0.9);
		}
	}

	function setUpDeck() {
		final deck = newNonHandCard(Backside);
		deck.homePos.x = Gui.scale(74);
		deck.homePos.y = height - Gui.scale(252);
		deck.returnToHomePos(0.0);
		deck.canMove = false;
		final deck = newNonHandCard(Backside);
		deck.homePos.x = Gui.scale(77);
		deck.homePos.y = height - Gui.scale(251);
		deck.returnToHomePos(0.0);
		deck.canMove = false;
		final deck = newNonHandCard(Backside);
		deck.homePos.x = Gui.scale(80);
		deck.homePos.y = height - Gui.scale(250);
		deck.returnToHomePos(0.0);
		deck.canMove = false;
		makeNextDeckCard();
	}

	function makeNextDeckCard() {
		final deckNext = newNonHandCard(Backside);
		deckNext.homePos.x = Gui.scale(80);
		deckNext.homePos.y = height - Gui.scale(250);
		deckNext.returnToHomePos(0.0);
		deckNext.onRelease = flipDeckCard;
	}

	function setUpHand() {
		addChildAt(handCardsContainer, LAYER_UI);
		newHandCard(Money);
		newHandCard(Track);
		newHandCard(Track);
		newHandCard(Station);
		newHandCard(Station);
		arrangeHand();
	}

	function addHouse(center:Point, rotation:Float) {
		houses.push({
			center: center,
			connectedStation: null,
			bitmap: makeMapEntityBitmap(tileHouse, center, rotation),
		});
	}

	function addStation(center:Point, rotation:Float) {
		stations.push(makeMapEntityBitmap(tileStation, center, rotation));
	}

	function makeMapEntityBitmap(tile, pos, rotation) {
		// Could use normal map to make sun look better
		// https://community.heaps.io/t/solved-trying-making-2d-lighting-shaders-with-normal-maps/255
		final bitmap = new h2d.Bitmap(tile, mapObjects);
		bitmap.x = pos.x;
		bitmap.y = pos.y;
		bitmap.rotation = rotation;
		bitmap.scale(MAP_PIXEL_SCALE);
		bitmap.filter = new h2d.filter.DropShadow(4.0, -rotation + Math.PI, 0, 0.6);
		return bitmap;
	}

	function setUpZoomButtons() {
		final plus = new Gui.Text("+", null, 1.5);
		plus.dropShadow = {
			dx: Gui.scale(0.5),
			dy: Gui.scale(0.5),
			color: 0xffffff,
			alpha: 1.0,
		};
		plus.textColor = 0;
		plus.x = Gui.scale(40);
		plus.y = height * 0.4;
		plus.textAlign = Center;
		addChildAt(plus, LAYER_UI);
		final plusInteractive = new h2d.Interactive(plus.getBounds().width / plus.scaleX * 1.1, plus.getBounds().height / plus.scaleY * 0.8, plus);
		plusInteractive.x = -plusInteractive.width / 2;
		plusInteractive.onPush = e -> zooming = 1;
		plusInteractive.onRelease = e -> zooming = 0;

		final minus = new Gui.Text("-", null, 1.5);
		minus.dropShadow = {
			dx: Gui.scale(0.5),
			dy: Gui.scale(0.5),
			color: 0xffffff,
			alpha: 1.0,
		};
		minus.textColor = 0;
		minus.x = Gui.scale(43);
		minus.y = height * 0.4 + Gui.scale(80);
		minus.textAlign = Center;
		addChildAt(minus, LAYER_UI);
		final minusInteractive = new h2d.Interactive(minus.getBounds().width / minus.scaleX * 1.1, minus.getBounds().height / minus.scaleY * 0.8, minus);
		minusInteractive.x = -minusInteractive.width / 2;
		minusInteractive.onPush = e -> zooming = -1;
		minusInteractive.onRelease = e -> zooming = 0;
	}
}
