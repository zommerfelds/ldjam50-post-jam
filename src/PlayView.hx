import h2d.col.Point;

class PlayView extends GameState {
	override function init() {
		addEventListener(onEvent);
	}

	function onEvent(event:hxd.Event) {
		switch (event.kind) {
			case EPush:
			default:
		}
	}

	override function update(dt:Float) {}
}
