package helper;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;

using haxe.macro.Tools;
#end

// Utils that make use of Macros so they need a bit more care
class CoolMacro {
	#if macro
	public static macro function merge<T>(base:ExprOf<T>, ext:ExprOf<T>):ExprOf<T> {
		var block = [];
		var fields:Array<ObjectField> = [];
		switch (Context.typeof(base).follow()) {
			case TAnonymous(_.get() => struct):
				for (f in struct.fields) {
					var fname = f.name;
					fields.push({
						field: fname,
						expr: macro if ($ext.$fname != null) {
							$ext.$fname;
						} else {
							$base.$fname;
						}
					});
				}
			default:
				return Context.error("Object type expected.", Context.currentPos());
		}
		var result = {expr: EObjectDecl(fields), pos: Context.currentPos()};
		block.push(macro $result);
		return macro $b{block};
	}
	#else
	public static macro function merge(base, ext);
	#end
}