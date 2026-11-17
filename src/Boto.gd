extends Control

# Botão de toque desenhado em código: ícone, rótulo opcional, miniatura opcional.

const Estilo = preload("res://src/Estilo.gd")
const Icones = preload("res://src/Icones.gd")

signal pressionado

var icone: String = ""
var rotulo: String = ""
var sub: String = ""
var ativo: bool = false:
	set(v):
		ativo = v
		queue_redraw()
var extra: int = 1
var textura: Texture2D = null
var linha: bool = false        # modo lista: miniatura à esquerda, texto ao lado
var cor_amostra: Color = Color(0, 0, 0, 0)
var tam_fonte: int = 0
var _baixo: bool = false


func _init(p_icone: String = "", p_rotulo: String = "") -> void:
	icone = p_icone
	rotulo = p_rotulo


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_baixo = true
	else:
		var dentro: bool = Rect2(Vector2.ZERO, size).has_point(mb.position)
		if _baixo and dentro:
			pressionado.emit()
		_baixo = false
	queue_redraw()
	accept_event()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var fundo: Color = Estilo.PAINEL_CLARO if _baixo else Estilo.PAINEL
	var borda: Color = Estilo.BORDA
	if ativo:
		fundo = Color(Estilo.DESTAQUE.r, Estilo.DESTAQUE.g, Estilo.DESTAQUE.b, 0.28)
		borda = Estilo.DESTAQUE
	draw_style_box(Estilo.caixa(fundo, borda, int(minf(size.x, size.y) * 0.22), 2), r)
	var fs: int = tam_fonte if tam_fonte > 0 else int(minf(size.y, 120.0) * 0.30)
	var fonte: Font = ThemeDB.fallback_font
	var cor: Color = Estilo.DESTAQUE if ativo else Estilo.TEXTO
	if linha:
		var lado: float = size.y - 12.0
		var ri := Rect2(6.0, 6.0, lado, lado)
		if textura != null:
			var ts: Vector2 = textura.get_size()
			var e: float = minf(lado / maxf(ts.x, 1.0), lado / maxf(ts.y, 1.0))
			draw_rect(ri, Color(0, 0, 0, 0.35), true)
			draw_texture_rect(textura, Rect2(ri.get_center() - ts * e * 0.5, ts * e), false)
		elif icone != "":
			Icones.desenhar(self, icone, ri.grow(-lado * 0.1), cor, extra)
		var x0: float = lado + 18.0
		draw_string(fonte, Vector2(x0, size.y * 0.5 + fs * 0.35), rotulo, HORIZONTAL_ALIGNMENT_LEFT, size.x - x0 - 12.0, fs, cor)
		if sub != "":
			draw_string(fonte, Vector2(0.0, size.y * 0.5 + fs * 0.35), sub, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 14.0, int(fs * 0.85), Estilo.SUAVE)
		return
	if cor_amostra.a > 0.0:
		draw_rect(r.grow(-size.x * 0.18), cor_amostra, true)
	if icone != "":
		var area := r.grow(-minf(size.x, size.y) * 0.16)
		if rotulo != "":
			area = Rect2(area.position, Vector2(area.size.x, area.size.y * 0.62))
		Icones.desenhar(self, icone, area, cor, extra)
	if rotulo != "":
		var y: float = size.y * 0.88 if icone != "" else size.y * 0.5 + float(fs) * 0.35
		draw_string(fonte, Vector2(0.0, y), rotulo, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, cor)
