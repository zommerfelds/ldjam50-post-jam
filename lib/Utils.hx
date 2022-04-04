import h2d.col.IPoint;
import h2d.col.Point;
import motion.Actuate;

class Utils {
	public static function floatToStr(n:Float, prec = 3) {
		n = Math.round(n * Math.pow(10, prec));
		var str = '' + n; // TODO: use string builder
		var len = str.length;
		if (len <= prec) {
			while (len < prec) {
				str = '0' + str;
				len++;
			}
			return '0.' + str;
		} else {
			return str.substr(0, str.length - prec) + '.' + str.substr(str.length - prec);
		}
	}

	public static function toPoint(p) {
		return new Point(p.x, p.y);
	}

	public static function toIPoint(p) {
		return new IPoint(p.x, p.y);
	}

	public static inline function pointToStr<T>(p:{x:T, y:T}) {
		return p.x + "/" + p.y;
	}

	/** Same as hxd.Math.valueMove(), but for vectors. **/
	public static function moveTowards(p:Point, target:Point, maxDistanceDelta:Float) {
		final d = target.sub(p);
		final length = d.length();
		if (length <= maxDistanceDelta) {
			return target;
		}
		return p.add(d.multiply(maxDistanceDelta / length));
	}

	/** Returns the signed shortest angle difference from angle1 to angle2. */
	public static function angularDiff(angle1:Float, angle2:Float):Float {
		var r = (angle1 - angle2) % (Math.PI * 2);
		if (r > Math.PI) {
			r -= Math.PI * 2;
		} else if (r < -Math.PI) {
			r += Math.PI * 2;
		}
		return r;
	}

	/** Normalizes the angle to be in [0, 2*Pi[ */
	public static inline function normAngle(a:Float):Float {
		return hxd.Math.ufmod(a, Math.PI * 2);
	}

	public static inline function normAtan2(y:Float, x:Float):Float {
		return normAngle(Math.atan2(y, x));
	}

	public static function className<T>(t:T) {
		return Type.getClassName(Type.getClass(t));
	}

	public static function distToLineSegment(p:Point, l0:Point, l1:Point) {
		return p.distance(projectToLineSegment(p, l0, l1));
	}

	public static function projectToLineSegment(p:Point, l0:Point, l1:Point):Point {
		// From https://stackoverflow.com/a/1501725/3810493
		final d2 = l0.distanceSq(l1);
		if (d2 == 0.0)
			return l0; // l0 == l1 case
		// Consider the line extending the segment, parameterized as v + t (w - v).
		// We find projection of point p onto the line.
		// It falls where t = [(p-v) . (w-v)] / |w-v|^2
		// We clamp t from [0,1] to handle points outside the segment vw.
		final t = Math.max(0, Math.min(1, p.sub(l0).dot(l1.sub(l0)) / d2));
		return l0.add(l1.sub(l0).multiply(t)); // Projection falls on the segment
	}

	public static function posUpdated(obj:h2d.Object) {
		// Tween is not smart enough to call the setter.
		obj.x = obj.x;
	}

	/** Tween for Heaps objects.
		Careful with onComplete() as it might get dropped if the tween is overwritten. Use `after` instead.
	**/
	public static function tween(obj, time:Float, properties:Dynamic, overwrite = true, after = null) {
		if (after != null) {
			Actuate.timer(time).onComplete(after);
		}
		return Actuate.tween(obj, time, properties, overwrite).onUpdate(() -> posUpdated(obj)).onComplete(() -> posUpdated(obj));
	}

	public static function copyTransform(fromObj:h2d.Object, toObj:h2d.Object) {
		toObj.x = fromObj.x;
		toObj.y = fromObj.y;
		toObj.scaleX = fromObj.scaleX;
		toObj.scaleY = fromObj.scaleY;
		toObj.rotation = fromObj.rotation;
	}
}
