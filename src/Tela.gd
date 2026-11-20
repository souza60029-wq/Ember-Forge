extends Control

# A área de desenho: mostra o quadro atual, desenha com o dedo, zoom e arrasto com dois dedos.

const Estilo = preload("res://src/Estilo.gd")

signal mudou
signal cor_captada(c: Color)
signal hitbox_mudou

const CORPO := 120.0   # altura do corpo na escala da engine (hitbox é guardada nessa escala)

var doc: Variant = null
var ferramenta: String = "lapis"
var cor: Color = Color.BLACK
var espelho: bool = false
var grade: bool = false
var cebola: bool = false
var cheio: bool = false
var tam_pincel: int = 1
var forma_fixa: bool = true   # retangulo: tamanho escolhido antes (forma_w x forma_h)
var forma_w: int = 16
var forma_h: int = 16
var somente_ver: bool = false
var legenda: String = ""
var zoom: float = 8.0
var origem: Vector2 = Vector2.ZERO

var _tex: ImageTexture = null
var _tex_prev: ImageTexture = null
var _fundo: ImageTexture = null
var _fundo_tam: Vector2i = Vector2i.ZERO
var _img_tam: Vector2i = Vector2i.ZERO   # tamanho do quadro mostrado (cada sprite tem o seu)
var _dedos := {}
var _gesto: bool = false
var _g_dist: float = 0.0
var _g_mid: Vector2 = Vector2.ZERO
var _tracando: bool = false
var _antes: PackedByteArray = PackedByteArray()
var _base: Image = null
var _ini: Vector2i = Vector2i.ZERO
var _ult: Vector2i = Vector2i(-9999, -9999)
var _ult_pos: Vector2 = Vector2.ZERO
var _auto_ajuste: bool = true
var _hb_modo: String = ""
var _hb_fixo: Vector2 = Vector2.ZERO
var _hb_off: Vector2 = Vector2.ZERO
var _hb_rect: Rect2 = Rect2()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(_ao_redimensionar)


func _ao_redimensionar() -> void:
	if _auto_ajuste:
		ajustar()
	queue_redraw()


# ---------- vista ----------

func ajustar() -> void:
	if doc == null or size.x < 8.0 or size.y < 8.0:
		return
	# O "palco" é o maior sprite da sequência; cada quadro fica centralizado e com os pés na base dele.
	var sw: int = 1
	var sh: int = 1
	for im in doc.quadros():
		sw = maxi(sw, (im as Image).get_width())
		sh = maxi(sh, (im as Image).get_height())
	var img: Image = doc.imagem()
	var w: float = float(sw)
	var h: float = float(sh)
	var z: float = minf((size.x - 12.0) / w, (size.y - 12.0) / h)
	zoom = maxf(1.0, floorf(z)) if z >= 1.0 else maxf(0.25, z)
	var palco: Vector2 = (size - Vector2(w, h) * zoom) * 0.5
	origem = palco + Vector2((w - float(img.get_width())) * 0.5, h - float(img.get_height())) * zoom
	_img_tam = Vector2i(img.get_width(), img.get_height())
	_auto_ajuste = true
	queue_redraw()


func atualizar() -> void:
	if doc == null:
		return
	var img: Image = doc.imagem()
	var nt := Vector2i(img.get_width(), img.get_height())
	if _img_tam != Vector2i.ZERO and nt != _img_tam:
		# mudou de tamanho: os pés (base, centro) ficam no mesmo lugar da tela
		var pe: Vector2 = origem + Vector2(float(_img_tam.x) * 0.5, float(_img_tam.y)) * zoom
		origem = pe - Vector2(float(nt.x) * 0.5, float(nt.y)) * zoom
	_img_tam = nt
	if _tex == null or _tex.get_size() != Vector2(img.get_width(), img.get_height()):
		_tex = ImageTexture.create_from_image(img)
	else:
		_tex.update(img)
	_tex_prev = null
	var q: Array = doc.quadros()
	if cebola and doc.quadro > 0:
		_tex_prev = ImageTexture.create_from_image(q[doc.quadro - 1])
	if _auto_ajuste:
		ajustar()
	queue_redraw()


func _img_pos(p: Vector2) -> Vector2:
	return (p - origem) / zoom


func _celula(p: Vector2) -> Vector2i:
	var v: Vector2 = _img_pos(p)
	return Vector2i(int(floorf(v.x)), int(floorf(v.y)))


func _checker(t: Vector2i) -> ImageTexture:
	if _fundo == null or _fundo_tam != t:
		var im := Image.create(t.x, t.y, false, Image.FORMAT_RGBA8)
		for y in range(t.y):
			for x in range(t.x):
				var par: bool = ((x / 4) + (y / 4)) % 2 == 0
				im.set_pixel(x, y, Color(0.30, 0.27, 0.40) if par else Color(0.22, 0.20, 0.32))
		_fundo = ImageTexture.create_from_image(im)
		_fundo_tam = t
	return _fundo


# ---------- desenho da tela ----------

func _draw() -> void:
	if doc == null:
		return
	if _tex == null:
		atualizar()
	var atual: Image = doc.imagem()
	var iw: int = atual.get_width()
	var ih: int = atual.get_height()
	var w: float = float(iw)
	var h: float = float(ih)
	var r := Rect2(origem, Vector2(w, h) * zoom)
	draw_rect(Rect2(Vector2.ZERO, size), Estilo.FUNDO, true)
	draw_texture_rect(_checker(Vector2i(iw, ih)), r, false)
	if cebola and not somente_ver and _tex_prev != null:
		var ps: Vector2 = _tex_prev.get_size()
		draw_texture_rect(_tex_prev, Rect2(origem + Vector2((w - ps.x) * 0.5, h - ps.y) * zoom, ps * zoom), false, Color(1, 1, 1, 0.3))
	draw_texture_rect(_tex, r, false)
	if somente_ver:
		return
	if grade and zoom >= 6.0:
		var gc := Color(1, 1, 1, 0.12)
		for x in range(iw + 1):
			draw_line(origem + Vector2(float(x) * zoom, 0.0), origem + Vector2(float(x) * zoom, h * zoom), gc, 1.0)
		for y in range(ih + 1):
			draw_line(origem + Vector2(0.0, float(y) * zoom), origem + Vector2(w * zoom, float(y) * zoom), gc, 1.0)
	draw_rect(r.grow(1.0), Estilo.BORDA, false, 2.0)   # moldura por fora: nunca cobre um pixel do sprite
	# guia dos pés: centro e base da imagem (a engine alinha o sprite por aí)
	var gx: float = origem.x + w * 0.5 * zoom
	draw_line(Vector2(gx, r.end.y - 14.0), Vector2(gx, r.end.y), Estilo.DESTAQUE, 2.0)
	draw_line(Vector2(gx - 8.0, r.end.y - 1.0), Vector2(gx + 8.0, r.end.y - 1.0), Estilo.DESTAQUE, 2.0)
	# seta: para onde o sprite olha
	var dir: float = -1.0 if doc.direcao == "esquerda" else 1.0
	var ay: float = r.end.y - 8.0
	draw_colored_polygon(PackedVector2Array([Vector2(gx + dir * 46.0, ay), Vector2(gx + dir * 26.0, ay - 10.0), Vector2(gx + dir * 26.0, ay + 10.0)]), Estilo.DESTAQUE)
	draw_line(Vector2(gx + dir * 12.0, ay), Vector2(gx + dir * 28.0, ay), Estilo.DESTAQUE, 3.0)
	if espelho:
		draw_line(Vector2(gx, r.position.y), Vector2(gx, r.end.y), Color(1, 0.5, 0.2, 0.35), 1.0)
	if doc.e_golpe():
		_desenhar_hitbox()
	if legenda != "":
		draw_string(ThemeDB.fallback_font, Vector2(10.0, 22.0), legenda, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20.0, 16, Color(1, 1, 1, 0.75))


# Hitbox do golpe: guardada na escala da engine (corpo = 120), aqui convertida para pixels da imagem.
func _fator() -> float:
	return CORPO / maxf(float(doc.altura_px), 1.0)


# A hitbox é medida a partir do centro/base do sprite, então depende do tamanho DESTE sprite.
func _hitbox_para_pixels() -> Rect2:
	var hb: Dictionary = doc.sequencia()["golpe"]["hitbox"]
	var k: float = _fator()
	var iw: float = float(doc.imagem().get_width())
	var ih: float = float(doc.imagem().get_height())
	var x0: float = iw * 0.5 + float(hb["x"]) / k
	if doc.direcao == "esquerda":
		# a hitbox é guardada "para a frente"; se o sprite olha para a esquerda, a frente é a esquerda
		x0 = iw * 0.5 - (float(hb["x"]) + float(hb["w"])) / k
	return Rect2(x0, ih + float(hb["y"]) / k, float(hb["w"]) / k, float(hb["h"]) / k)


func _pixels_para_hitbox(rp: Rect2) -> void:
	var k: float = _fator()
	var hb: Dictionary = doc.sequencia()["golpe"]["hitbox"]
	var iw: float = float(doc.imagem().get_width())
	var ih: float = float(doc.imagem().get_height())
	if doc.direcao == "esquerda":
		hb["x"] = clampi(int(roundf((iw * 0.5 - (rp.position.x + rp.size.x)) * k)), -200, 200)
	else:
		hb["x"] = clampi(int(roundf((rp.position.x - iw * 0.5) * k)), -200, 200)
	hb["y"] = clampi(int(roundf((rp.position.y - ih) * k)), -200, 0)
	hb["w"] = clampi(int(roundf(rp.size.x * k)), 1, 300)
	hb["h"] = clampi(int(roundf(rp.size.y * k)), 1, 300)


func _desenhar_hitbox() -> void:
	var rp: Rect2 = _hb_rect if _hb_modo != "" else _hitbox_para_pixels()
	var rs := Rect2(origem + rp.position * zoom, rp.size * zoom)
	var ativo: bool = ferramenta == "hitbox"
	draw_rect(rs, Color(1, 0.15, 0.2, 0.28 if ativo else 0.12), true)
	draw_rect(rs, Color(1, 0.3, 0.3, 0.95 if ativo else 0.5), false, 2.0)
	if ativo:
		for p in [rs.position, Vector2(rs.end.x, rs.position.y), Vector2(rs.position.x, rs.end.y), rs.end]:
			draw_rect(Rect2(p - Vector2(8, 8), Vector2(16, 16)), Color(1, 0.9, 0.3), true)


# ---------- toques ----------

func _gui_input(ev: InputEvent) -> void:
	if doc == null:
		return
	var t := ev as InputEventScreenTouch
	if t != null:
		if t.pressed:
			_dedos[t.index] = t.position
			if _dedos.size() == 1:
				_gesto = false
				_comecar(t.position)
			elif _dedos.size() == 2:
				_cancelar_traco()
				_gesto = true
				_iniciar_gesto()
		else:
			if _dedos.size() == 1 and not _gesto:
				_terminar(t.position)
			_dedos.erase(t.index)
			if _dedos.is_empty():
				_gesto = false
		accept_event()
		return
	var d := ev as InputEventScreenDrag
	if d != null:
		_dedos[d.index] = d.position
		if _gesto and _dedos.size() >= 2:
			_atualizar_gesto()
		elif _dedos.size() == 1 and not _gesto:
			_arrastar(d.position)
		accept_event()


func _iniciar_gesto() -> void:
	var ks: Array = _dedos.keys()
	var a: Vector2 = _dedos[ks[0]]
	var b: Vector2 = _dedos[ks[1]]
	_g_dist = maxf(a.distance_to(b), 1.0)
	_g_mid = (a + b) * 0.5


func _atualizar_gesto() -> void:
	var ks: Array = _dedos.keys()
	var a: Vector2 = _dedos[ks[0]]
	var b: Vector2 = _dedos[ks[1]]
	var dist: float = maxf(a.distance_to(b), 1.0)
	var mid: Vector2 = (a + b) * 0.5
	var ponto: Vector2 = (_g_mid - origem) / zoom
	zoom = clampf(zoom * dist / _g_dist, 0.25, 80.0)
	origem = mid - ponto * zoom
	_g_dist = dist
	_g_mid = mid
	_auto_ajuste = false
	queue_redraw()


func _pan_mode() -> bool:
	return somente_ver or ferramenta == "mao"


func _comecar(pos: Vector2) -> void:
	_ult_pos = pos
	if _pan_mode():
		return
	if ferramenta == "hitbox":
		if doc.e_golpe():
			_hb_comecar(pos)
		return
	var c: Vector2i = _celula(pos)
	var img: Image = doc.imagem()
	if ferramenta == "conta":
		if _dentro(img, c):
			var px: Color = img.get_pixel(c.x, c.y)
			if px.a > 0.0:
				cor_captada.emit(px)
		return
	_tracando = true
	_antes = img.get_data()
	_ini = c
	_ult = Vector2i(-9999, -9999)
	if ferramenta == "linha" or ferramenta == "retangulo":
		_base = Image.new()
		_base.copy_from(img)
		if ferramenta == "retangulo" and forma_fixa:
			_desenhar_forma_fixa(img, c)
			_mostrar(img)
	if ferramenta == "balde":
		_preencher(img, c)
		_terminar(pos)
		return
	if ferramenta == "lapis" or ferramenta == "borracha":
		_ponto_linha(img, c, c)
		_ult = c
		_mostrar(img)


func _arrastar(pos: Vector2) -> void:
	if _pan_mode():
		origem += pos - _ult_pos
		_ult_pos = pos
		_auto_ajuste = false
		queue_redraw()
		return
	if ferramenta == "hitbox":
		_hb_arrastar(pos)
		return
	if not _tracando:
		return
	var img: Image = doc.imagem()
	var c: Vector2i = _celula(pos)
	match ferramenta:
		"lapis", "borracha":
			_ponto_linha(img, _ult, c)
			_ult = c
		"linha":
			img.copy_from(_base)
			_ponto_linha(img, _ini, c)
		"retangulo":
			img.copy_from(_base)
			if forma_fixa:
				_desenhar_forma_fixa(img, c)
			else:
				_retangulo(img, _ini, c)
	_mostrar(img)


func _terminar(pos: Vector2) -> void:
	if ferramenta == "hitbox":
		_hb_terminar()
		return
	if not _tracando:
		return
	_tracando = false
	var img: Image = doc.imagem()
	if img.get_data() != _antes:
		doc.empurrar_undo(_antes)
		mudou.emit()
	_base = null
	_mostrar(img)


func _cancelar_traco() -> void:
	if _tracando:
		_tracando = false
		var img: Image = doc.imagem()
		img.set_data(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8, _antes)
		_base = null
		_mostrar(img)
	_hb_modo = ""


func _mostrar(img: Image) -> void:
	if _tex != null:
		_tex.update(img)
	queue_redraw()


# ---------- pixels ----------

func _dentro(img: Image, c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < img.get_width() and c.y < img.get_height()


func _cor_ferramenta() -> Color:
	return Color(0, 0, 0, 0) if ferramenta == "borracha" else cor


func _ponto(img: Image, x: int, y: int) -> void:
	var c: Color = _cor_ferramenta()
	var n: int = tam_pincel
	var deslocar: int = (n - 1) / 2
	for dy in range(n):
		for dx in range(n):
			var px: int = x - deslocar + dx
			var py: int = y - deslocar + dy
			if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
				img.set_pixel(px, py, c)
			if espelho:
				var mx: int = img.get_width() - 1 - px
				if mx >= 0 and py >= 0 and mx < img.get_width() and py < img.get_height():
					img.set_pixel(mx, py, c)


func _ponto_linha(img: Image, a: Vector2i, b: Vector2i) -> void:
	if a.x < -9000:
		a = b
	var x0: int = a.x
	var y0: int = a.y
	var dx: int = absi(b.x - x0)
	var dy: int = -absi(b.y - y0)
	var sx: int = 1 if x0 < b.x else -1
	var sy: int = 1 if y0 < b.y else -1
	var err: int = dx + dy
	var guarda: int = 0
	while guarda < 4000:
		guarda += 1
		_ponto(img, x0, y0)
		if x0 == b.x and y0 == b.y:
			break
		var e2: int = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _retangulo(img: Image, a: Vector2i, b: Vector2i) -> void:
	var x0: int = mini(a.x, b.x)
	var x1: int = maxi(a.x, b.x)
	var y0: int = mini(a.y, b.y)
	var y1: int = maxi(a.y, b.y)
	if cheio:
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				_ponto(img, x, y)
		return
	_ponto_linha(img, Vector2i(x0, y0), Vector2i(x1, y0))
	_ponto_linha(img, Vector2i(x1, y0), Vector2i(x1, y1))
	_ponto_linha(img, Vector2i(x1, y1), Vector2i(x0, y1))
	_ponto_linha(img, Vector2i(x0, y1), Vector2i(x0, y0))


# Retangulo de tamanho escolhido: o centro segue o dedo, solta para fixar.
func _desenhar_forma_fixa(img: Image, c: Vector2i) -> void:
	var w: int = maxi(forma_w, 1)
	var h: int = maxi(forma_h, 1)
	var a := Vector2i(c.x - w / 2, c.y - h / 2)
	_retangulo(img, a, Vector2i(a.x + w - 1, a.y + h - 1))


func _igual(a: Color, b: Color) -> bool:
	if a.a < 0.01 and b.a < 0.01:
		return true
	return a == b


func _preencher(img: Image, c: Vector2i) -> void:
	if not _dentro(img, c):
		return
	var alvo: Color = img.get_pixel(c.x, c.y)
	var nova: Color = cor
	if _igual(alvo, nova):
		return
	var pilha: Array = [c]
	var vistos := {}
	var limite: int = img.get_width() * img.get_height() + 8
	while not pilha.is_empty() and limite > 0:
		limite -= 1
		var p: Vector2i = pilha.pop_back()
		var chave: int = p.y * img.get_width() + p.x
		if vistos.has(chave):
			continue
		if not _dentro(img, p) or not _igual(img.get_pixel(p.x, p.y), alvo):
			continue
		vistos[chave] = true
		img.set_pixel(p.x, p.y, nova)
		pilha.append(Vector2i(p.x + 1, p.y))
		pilha.append(Vector2i(p.x - 1, p.y))
		pilha.append(Vector2i(p.x, p.y + 1))
		pilha.append(Vector2i(p.x, p.y - 1))


# ---------- hitbox ----------

func _hb_comecar(pos: Vector2) -> void:
	var rp: Rect2 = _hitbox_para_pixels()
	var rs := Rect2(origem + rp.position * zoom, rp.size * zoom)
	var cantos: Array = [rs.position, Vector2(rs.end.x, rs.position.y), Vector2(rs.position.x, rs.end.y), rs.end]
	var opostos: Array = [rs.end, Vector2(rs.position.x, rs.end.y), Vector2(rs.end.x, rs.position.y), rs.position]
	for i in range(4):
		if pos.distance_to(cantos[i]) <= 34.0:
			_hb_modo = "canto"
			_hb_fixo = _img_pos(opostos[i])
			_hb_rect = rp
			return
	if rs.has_point(pos):
		_hb_modo = "mover"
		_hb_off = _img_pos(pos) - rp.position
		_hb_rect = rp
		return
	_hb_modo = "novo"
	_hb_fixo = _img_pos(pos)
	_hb_rect = Rect2(_hb_fixo, Vector2(1, 1))


func _hb_arrastar(pos: Vector2) -> void:
	if _hb_modo == "":
		return
	var p: Vector2 = _img_pos(pos)
	if _hb_modo == "mover":
		_hb_rect.position = p - _hb_off
	else:
		var a: Vector2 = Vector2(minf(p.x, _hb_fixo.x), minf(p.y, _hb_fixo.y))
		var b: Vector2 = Vector2(maxf(p.x, _hb_fixo.x), maxf(p.y, _hb_fixo.y))
		_hb_rect = Rect2(a, Vector2(maxf(b.x - a.x, 1.0), maxf(b.y - a.y, 1.0)))
	queue_redraw()


func _hb_terminar() -> void:
	if _hb_modo == "":
		return
	_pixels_para_hitbox(_hb_rect)
	_hb_modo = ""
	hitbox_mudou.emit()
	queue_redraw()
