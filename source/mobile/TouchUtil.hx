package mobile;

#if mobile
import flixel.FlxG;
import flixel.FlxCamera;
import flixel.math.FlxPoint;
import flash.geom.Point;

class TouchUtil 
{
	/**
	 * Utilities for touch input
	 */
	private static var _cachePoint:Point = new Point();
	/**
	 * Converts Flash TouchEvent coordinate to world coordinate.
	 * Code basically copied from FlxTouch and FlxPointer.
	 */
	public static function stageToWorldPoint(x:Float, y:Float, ?camera:FlxCamera, ?point:FlxPoint):FlxPoint {
		if (point == null) point = new FlxPoint();
		if (camera == null) camera = FlxG.camera;
		_cachePoint.setTo(x, y);
		_cachePoint = FlxG.game.globalToLocal(_cachePoint);
		var _x = Std.int(_cachePoint.x / FlxG.scaleMode.scale.x);
		var _y = Std.int(_cachePoint.y / FlxG.scaleMode.scale.y);
		point.x = (_x - camera.x + 0.5 * camera.width * (camera.zoom - camera.initialZoom)) / camera.zoom + camera.scroll.x;
		point.y = (_y - camera.y + 0.5 * camera.height * (camera.zoom - camera.initialZoom)) / camera.zoom + camera.scroll.y;
		return point;
	}

	/**
	 * Not really a touch function, but calculates the distance from a point to a strum scroll axis thing
	 * @param point			Point to query
	 * @param strumPoint 	Point of the strum bar arrow
	 * @param strumAngle	Scroll Angle, in deg
	 */
	public static inline function distanceToScroll(point:FlxPoint, strumPoint:FlxPoint, strumAngle:Float):Float {
		return Math.abs((point.x - strumPoint.x) * Math.sin(strumAngle * Math.PI / 180) - (point.y - strumPoint.y) * Math.cos(strumAngle * Math.PI / 180));
	}

}
#end