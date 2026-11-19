extends Control

# Painel que aparece por cima de tudo (exportar, projeto, personagem...). Toque fora ou no X fecha.

const Estilo = preload("res://src/Estilo.gd")
const Boto = preload("res://src/Boto.gd")
const Rolagem = preload("res://src/Rolagem.gd")

signal fechada

var conteudo: VBoxContainer = null
var _painel: PanelContainer = null


func configurar(titulo: String, u: float, tela: Vector2) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)
	_painel = PanelContainer.new()
	_painel.custom_minimum_size = Vector2(minf(tela.x * 0.94, 860.0), minf(tela.y * 0.88, 1100.0))
	_painel.add_theme_stylebox_override("panel", Estilo.caixa(Estilo.FUNDO, Estilo.BORDA, 18, 3))
	_painel.mouse_filter = Control.MOUSE_FILTER_STOP
	centro.add_child(_painel)
	var margem := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margem.add_theme_constant_override("margin_" + lado, int(u * 0.2))
	_painel.add_child(margem)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(u * 0.15))
	margem.add_child(col)
	var topo := HBoxContainer.new()
	col.add_child(topo)
	var rot := Label.new()
	rot.text = titulo
	rot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot.add_theme_font_size_override("font_size", int(u * 0.42))
	rot.add_theme_color_override("font_color", Estilo.DESTAQUE)
	rot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	topo.add_child(rot)
	var x := Boto.new("fechar")
	x.custom_minimum_size = Vector2(u * 0.9, u * 0.9)
	x.pressionado.connect(fechar)
	topo.add_child(x)
	var rolagem := Rolagem.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(rolagem)
	conteudo = VBoxContainer.new()
	conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conteudo.add_theme_constant_override("separation", int(u * 0.14))
	rolagem.add_child(conteudo)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.62), true)


func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
		if _painel != null and not _painel.get_global_rect().has_point(mb.global_position):
			fechar()
	accept_event()


func fechar() -> void:
	fechada.emit()
	queue_free()