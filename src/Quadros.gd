extends Control

# Faixa com as miniaturas dos quadros da sequência. Toque escolhe; arrastar rola.

const Estilo = preload("res://src/Estilo.gd")

signal escolhido(i: int)

var doc: Variant = null
var _tex: Array = []
var _rolagem: float = 0.0
var _baixo: bool = false
var _arrasto: bool = false
var _inicio: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _lado() -> float:
	return maxf(size.y - 12.0, 16.0)


func atualizar() -> void:
	_tex.clear()
	if doc != null:
		for img in doc.quadros():
			_tex.append(ImageTexture.create_from_image(img))
		_mostrar_atual()
	queue_redraw()


func _mostrar_atual() -> void:
	var passo: float = _lado() + 6.0
	var x: float = 6.0 + float(doc.quadro) * passo
	if x - _rolagem < 0.0:
		_rolagem = maxf(0.0, x - 6.0)
	elif x + passo - _rolagem > size.x:
		_rolagem = x + passo - size.x


func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_baixo = true
			_arrasto = false
			_inicio = mb.position
		else:
			if _baixo and not _arrasto:
				var passo: float = _lado() + 6.0
				var i: int = int(floorf((mb.position.x + _rolagem - 6.0) / passo))
				if i >= 0 and i < _tex.size():
					escolhido.emit(i)
			_baixo = false
		accept_event()
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and _baixo:
		if absf(mm.position.x - _inicio.x) > 10.0:
			_arrasto = true
		if _arrasto:
			var total: float = float(_tex.size()) * (_lado() + 6.0) + 6.0
			_rolagem = clampf(_rolagem - mm.relative.x, 0.0, maxf(0.0, total - size.x))
			queue_redraw()
		accept_event()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Estilo.PAINEL, true)
	var l: float = _lado()
	for i in range(_tex.size()):
		var r := Rect2(6.0 + float(i) * (l + 6.0) - _rolagem, 6.0, l, l)
		if r.end.x < 0.0 or r.position.x > size.x:
			continue
		var atual: bool = doc != null and i == doc.quadro
		draw_rect(r, Color(0.25, 0.22, 0.36), true)
		var t: Texture2D = _tex[i]
		var ts: Vector2 = t.get_size()
		var e: float = minf(l / ts.x, l / ts.y)
		draw_texture_rect(t, Rect2(r.get_center() - ts * e * 0.5, ts * e), false)
		draw_rect(r, Estilo.DESTAQUE if atual else Estilo.BORDA, false, 3.0 if atual else 1.5)
		draw_string(ThemeDB.fallback_font, r.position + Vector2(4.0, 14.0), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
