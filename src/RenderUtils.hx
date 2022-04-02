import h2d.col.Point;

class RenderUtils {
	public static function drawRails(drawGr:h2d.Graphics, start:Point, end:Point) {
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

	public static function drawRailroadTies(drawGr:h2d.Graphics, start:Point, end:Point) {
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
}
