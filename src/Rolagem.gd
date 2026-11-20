extends ScrollContainer

# ScrollContainer que rola arrastando o dedo, mesmo quando o toque começa em cima de um botão.
# Usa os eventos de mouse emulados pelo toque (os mesmos que a paleta e a faixa de quadros já usam).
# Controles filhos com o meta "sem_rolar" (ex.: seletor de cor) ficam de fora e recebem o arrasto.

var _arr: bool = false
var _acum: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED


func _sobre_bloqueado(p: Vector2) -> bool:
	if get_child_count() == 0:
		return false
	for n in get_child(0).get_children():
		if n is Control and n.has_meta("sem_rolar") and (n as Control).get_global_rect().has_point(p):
			return true
	return false


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var mb := ev as InputEventMouseButton
	if mb != null:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_arr = get_global_rect().has_point(mb.position) and not _sobre_bloqueado(mb.position)
				_acum = 0.0
			else:
				_arr = false
		elif mb.pressed and get_global_rect().has_point(mb.position):
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				scroll_vertical -= 90
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				scroll_vertical += 90
		return
	var mm := ev as InputEventMouseMotion
	if mm != null and _arr and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_acum -= mm.relative.y
		var passo: int = int(_acum)
		if passo != 0:
			scroll_vertical += passo
			_acum -= float(passo)
