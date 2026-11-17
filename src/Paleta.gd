extends Control

# Faixa de cores em duas linhas, rolando para o lado. Toque escolhe; toque na cor escolhida edita;
# o último quadrado (+) cria uma cor nova.

const Estilo = preload("res://src/Estilo.gd")
const Icones = preload("res://src/Icones.gd")

signal escolhida(i: int)
signal editar(i: int)
signal nova

var cores: PackedColorArray = PackedColorArray()
var sel: int = 0
var _rolagem: float = 0.0
var _arrasto: bool = false
var _inicio: Vector2 = Vector2.ZERO
var _baixo: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func _lado() -> float:
	return size.y * 0.5


func _colunas() -> int:
	return int(ceilf(float(cores.size() + 1) / 2.0))


func _max_rolagem() -> float:
	return maxf(0.0, float(_colunas()) * _lado() - size.x)


func _rect_cor(i: int) -> Rect2:
	var l: float = _lado()
	return Rect2(float(i / 2) * l - _rolagem, float(i % 2) * l, l, l)


func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_baixo = true
			_arrasto = false
			_inicio = mb.position
		else:
			if _baixo and not _arrasto:
				_tocar(mb.position)
			_baixo = false
		accept_event()
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and _baixo:
		if absf(mm.position.x - _inicio.x) > 10.0:
			_arrasto = true
		if _arrasto:
			_rolagem = clampf(_rolagem - mm.relative.x, 0.0, _max_rolagem())
			queue_redraw()
		accept_event()


func _tocar(p: Vector2) -> void:
	for i in range(cores.size() + 1):
		if _rect_cor(i).has_point(p):
			if i == cores.size():
				nova.emit()
			elif i == sel:
				editar.emit(i)
			else:
				escolhida.emit(i)
			return


func definir(lista: PackedColorArray, i: int) -> void:
	cores = lista
	sel = clampi(i, 0, maxi(cores.size() - 1, 0))
	_rolagem = clampf(_rolagem, 0.0, _max_rolagem())
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Estilo.PAINEL, true)
	for i in range(cores.size()):
		var r: Rect2 = _rect_cor(i)
		if r.end.x < 0.0 or r.position.x > size.x:
			continue
		draw_rect(r.grow(-1.0), cores[i], true)
		if i == sel:
			draw_rect(r.grow(-2.0), Color.WHITE, false, 3.0)
			draw_rect(r.grow(-5.0), Color.BLACK, false, 2.0)
	var rn: Rect2 = _rect_cor(cores.size())
	draw_rect(rn.grow(-1.0), Estilo.PAINEL_CLARO, true)
	Icones.desenhar(self, "mais", rn.grow(-rn.size.x * 0.2), Estilo.TEXTO)
