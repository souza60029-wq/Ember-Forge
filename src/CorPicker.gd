extends Control

# Seletor de cor por toque: quadrado de saturação/brilho e barra de matiz.

signal mudou(c: Color)

var h: float = 0.0
var s: float = 1.0
var v: float = 1.0
var _arr: String = ""


func definir(c: Color) -> void:
	h = c.h
	s = c.s
	v = c.v
	queue_redraw()


func cor() -> Color:
	return Color.from_hsv(h, s, v)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _rect_sv() -> Rect2:
	return Rect2(0, 0, size.x, size.y * 0.78)


func _rect_h() -> Rect2:
	return Rect2(0, size.y * 0.84, size.x, size.y * 0.16)


func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_arr = "sv" if _rect_sv().has_point(mb.position) else ("h" if _rect_h().grow(10.0).has_point(mb.position) else "")
			_mover(mb.position)
		else:
			_arr = ""
		accept_event()
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and _arr != "":
		_mover(mm.position)
		accept_event()


func _mover(p: Vector2) -> void:
	if _arr == "sv":
		var r: Rect2 = _rect_sv()
		s = clampf((p.x - r.position.x) / r.size.x, 0.0, 1.0)
		v = 1.0 - clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)
	elif _arr == "h":
		var r2: Rect2 = _rect_h()
		h = clampf((p.x - r2.position.x) / r2.size.x, 0.0, 0.999)
	else:
		return
	mudou.emit(cor())
	queue_redraw()


func _draw() -> void:
	var r: Rect2 = _rect_sv()
	var puro: Color = Color.from_hsv(h, 1.0, 1.0)
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([Color.WHITE, puro, puro, Color.WHITE]))
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color.BLACK, Color.BLACK]))
	var mx: Vector2 = Vector2(r.position.x + s * r.size.x, r.position.y + (1.0 - v) * r.size.y)
	draw_circle(mx, 11.0, Color.WHITE)
	draw_circle(mx, 8.0, cor())
	var rh: Rect2 = _rect_h()
	for i in range(6):
		var a: float = float(i) / 6.0
		var b: float = float(i + 1) / 6.0
		var x0: float = rh.position.x + a * rh.size.x
		var x1: float = rh.position.x + b * rh.size.x
		draw_polygon(PackedVector2Array([Vector2(x0, rh.position.y), Vector2(x1, rh.position.y), Vector2(x1, rh.end.y), Vector2(x0, rh.end.y)]),
			PackedColorArray([Color.from_hsv(a, 1, 1), Color.from_hsv(minf(b, 0.999), 1, 1), Color.from_hsv(minf(b, 0.999), 1, 1), Color.from_hsv(a, 1, 1)]))
	var hx: float = rh.position.x + h * rh.size.x
	draw_rect(Rect2(hx - 5.0, rh.position.y - 4.0, 10.0, rh.size.y + 8.0), Color.WHITE, false, 3.0)
