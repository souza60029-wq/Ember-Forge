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
var _p0: Vector2 = Vector2.ZERO


func _init(p_icone: String = "", p_rotulo: String = "") -> void:
	icone = p_icone
	rotulo = p_rotulo


func _ready() -> void:
	# PASS: o dedo que começa num botão ainda consegue rolar um painel por baixo dele.
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE


func _gui_input(ev: InputEvent) -> void:
	var mm := ev as InputEventMouseMotion
	if mm != null:
		# arrastou: era rolagem, não um toque
		if _baixo and mm.position.distance_to(_p0) > 18.0:
			_baixo = false
			queue_redraw()
		return
	var mb := ev as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_baixo = true
		_p0 = mb.position
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
		if rotulo != "":
			var ar: Rect2 = r.grow(-minf(size.x, size.y) * 0.16)
			ar = Rect2(ar.position, Vector2(ar.size.x, ar.size.y * 0.62))
			var la: float = minf(ar.size.x, ar.size.y)
			var rs := Rect2(ar.get_center() - Vector2(la, la) * 0.5, Vector2(la, la))
			draw_rect(rs, cor_amostra, true)
			draw_rect(rs, Color(1, 1, 1, 0.85), false, 2.0)
		else:
			draw_rect(r.grow(-size.x * 0.18), cor_amostra, true)
	var area := r.grow(-minf(size.x, size.y) * 0.16)
	if rotulo != "":
		area = Rect2(area.position, Vector2(area.size.x, area.size.y * 0.62))
	if textura != null:
		var tsz: Vector2 = textura.get_size()
		var esc: float = minf(area.size.x / maxf(tsz.x, 1.0), area.size.y / maxf(tsz.y, 1.0))
		draw_rect(Rect2(area.get_center() - tsz * esc * 0.5, tsz * esc), Color(0, 0, 0, 0.35), true)
		draw_texture_rect(textura, Rect2(area.get_center() - tsz * esc * 0.5, tsz * esc), false)
	elif icone != "":
		Icones.desenhar(self, icone, area, cor, extra)
	if sub != "":
		draw_string(fonte, Vector2(0.0, float(fs) + 4.0), sub, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 8.0, int(fs * 0.9), Estilo.DESTAQUE)
	if rotulo != "":
		var y: float = size.y * 0.88 if (icone != "" or cor_amostra.a > 0.0) else size.y * 0.5 + float(fs) * 0.35
		draw_string(fonte, Vector2(0.0, y), rotulo, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, cor)
