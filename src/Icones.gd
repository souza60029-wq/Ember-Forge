extends RefCounted

# Ícones desenhados em código (sem arquivos de imagem), dentro de um quadrado de 48 unidades.

static func _v(c: Vector2, s: float, x: float, y: float) -> Vector2:
	return c + Vector2(x, y) * s


# Para trocar um ícone por uma imagem sua: coloque res://icones/<nome>.png (quadrada, fundo transparente).
# Se o arquivo existir ele é usado; se não, vale o desenho em código abaixo.
static var _cache := {}

const ALIAS := {
	"inicio_criar": "lapis", "inicio_importar": "importar", "inicio": "projeto",
	"golpe_lp": "hitbox", "golpe_lk": "hitbox", "golpe_hp": "hitbox", "golpe_hk": "hitbox",
	"golpe_bo": "hitbox", "golpe_custom": "hitbox", "golpe_novo": "mais", "tamanho": "ajustar",
}


static func _png(nome: String) -> Texture2D:
	if _cache.has(nome):
		return _cache[nome]
	var tex: Texture2D = null
	var cam: String = "res://icones/" + nome + ".png"
	if ResourceLoader.exists(cam):
		tex = load(cam) as Texture2D
	_cache[nome] = tex
	return tex


static func desenhar(ci: CanvasItem, nome: String, r: Rect2, cor: Color, extra: int = 1) -> void:
	var tex: Texture2D = _png(nome)
	if tex != null:
		var lado: float = minf(r.size.x, r.size.y)
		ci.draw_texture_rect(tex, Rect2(r.get_center() - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false)
		return
	if ALIAS.has(nome):
		nome = str(ALIAS[nome])
	var c: Vector2 = r.get_center()
	var s: float = minf(r.size.x, r.size.y) / 48.0
	var w: float = maxf(2.0, 2.6 * s)
	match nome:
		"lapis":
			ci.draw_line(_v(c, s, -11, 11), _v(c, s, 10, -10), cor, 7.0 * s)
			ci.draw_colored_polygon(PackedVector2Array([_v(c, s, -18, 18), _v(c, s, -16, 9), _v(c, s, -9, 16)]), cor)
			ci.draw_line(_v(c, s, 11, -11), _v(c, s, 15, -15), cor, 5.0 * s)
		"borracha":
			ci.draw_colored_polygon(PackedVector2Array([_v(c, s, -17, 5), _v(c, s, -3, -12), _v(c, s, 15, 3), _v(c, s, 1, 19)]), cor)
			ci.draw_line(_v(c, s, -8, -3), _v(c, s, 7, 11), Estilo_fundo(), 2.0 * s)
		"balde":
			ci.draw_polyline(PackedVector2Array([_v(c, s, -14, -4), _v(c, s, 14, -4), _v(c, s, 9, 16), _v(c, s, -9, 16), _v(c, s, -14, -4)]), cor, w)
			ci.draw_arc(_v(c, s, 0, -4), 10.0 * s, PI, TAU, 12, cor, w)
			ci.draw_circle(_v(c, s, 18, 10), 3.5 * s, cor)
		"conta":
			ci.draw_line(_v(c, s, -15, 15), _v(c, s, 5, -5), cor, 4.0 * s)
			ci.draw_circle(_v(c, s, 10, -10), 6.5 * s, cor)
			ci.draw_line(_v(c, s, -15, 15), _v(c, s, -17, 17), cor, 3.0 * s)
		"linha":
			ci.draw_line(_v(c, s, -14, 14), _v(c, s, 14, -14), cor, w)
			ci.draw_circle(_v(c, s, -14, 14), 4.0 * s, cor)
			ci.draw_circle(_v(c, s, 14, -14), 4.0 * s, cor)
		"retangulo":
			ci.draw_rect(Rect2(_v(c, s, -15, -10), Vector2(30, 20) * s), cor, false, w)
		"retangulo_cheio":
			ci.draw_rect(Rect2(_v(c, s, -15, -10), Vector2(30, 20) * s), cor, true)
		"mao":
			ci.draw_line(_v(c, s, -16, 0), _v(c, s, 16, 0), cor, w)
			ci.draw_line(_v(c, s, 0, -16), _v(c, s, 0, 16), cor, w)
			for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				var p: Vector2 = c + d * 16.0 * s
				var o: Vector2 = Vector2(-d.y, d.x)
				ci.draw_colored_polygon(PackedVector2Array([p + d * 3.0 * s, p - d * 4.0 * s + o * 5.0 * s, p - d * 4.0 * s - o * 5.0 * s]), cor)
		"hitbox":
			ci.draw_rect(Rect2(_v(c, s, -15, -12), Vector2(30, 24) * s), cor, false, w)
			for k in [Vector2(-15, -12), Vector2(15, -12), Vector2(-15, 12), Vector2(15, 12)]:
				ci.draw_rect(Rect2(_v(c, s, k.x - 3.5, k.y - 3.5), Vector2(7, 7) * s), cor, true)
		"espelho":
			for k in range(-3, 4):
				if k % 2 == 0:
					ci.draw_line(_v(c, s, 0, k * 5.0 - 2.5), _v(c, s, 0, k * 5.0 + 2.5), cor, w)
			ci.draw_polyline(PackedVector2Array([_v(c, s, -5, -11), _v(c, s, -16, 0), _v(c, s, -5, 11), _v(c, s, -5, -11)]), cor, w)
			ci.draw_colored_polygon(PackedVector2Array([_v(c, s, 5, -11), _v(c, s, 16, 0), _v(c, s, 5, 11)]), cor)
		"grade":
			ci.draw_rect(Rect2(_v(c, s, -15, -15), Vector2(30, 30) * s), cor, false, w)
			for k in [-5.0, 5.0]:
				ci.draw_line(_v(c, s, k, -15), _v(c, s, k, 15), cor, w * 0.7)
				ci.draw_line(_v(c, s, -15, k), _v(c, s, 15, k), cor, w * 0.7)
		"cebola":
			ci.draw_circle(_v(c, s, -6, 0), 11.0 * s, Color(cor.r, cor.g, cor.b, cor.a * 0.4))
			ci.draw_arc(_v(c, s, 6, 0), 11.0 * s, 0.0, TAU, 24, cor, w)
		"ponto":
			ci.draw_circle(c, (2.5 + float(extra) * 3.2) * s, cor)
		"desfazer", "refazer":
			var f: float = 1.0 if nome == "desfazer" else -1.0
			var ctr: Vector2 = c + Vector2(2.0 * f, 3.0) * s
			if nome == "desfazer":
				ci.draw_arc(ctr, 12.0 * s, -1.3, 2.6, 20, cor, w)
			else:
				ci.draw_arc(ctr, 12.0 * s, PI - 2.6, PI + 1.3, 20, cor, w)
			ci.draw_polyline(PackedVector2Array([_v(c, s, 7.0 * f, -16), _v(c, s, 6.0 * f, -8), _v(c, s, -1.0 * f, -10)]), cor, w)
		"ajustar":
			for sx in [-1.0, 1.0]:
				for sy in [-1.0, 1.0]:
					var q: Vector2 = _v(c, s, 15.0 * sx, 15.0 * sy)
					ci.draw_polyline(PackedVector2Array([q - Vector2(0, 9.0 * sy) * s, q, q - Vector2(9.0 * sx, 0) * s]), cor, w)
		"olho":
			ci.draw_polyline(PackedVector2Array([_v(c, s, -18, 0), _v(c, s, -9, -9), _v(c, s, 0, -12), _v(c, s, 9, -9), _v(c, s, 18, 0)]), cor, w)
			ci.draw_polyline(PackedVector2Array([_v(c, s, -18, 0), _v(c, s, -9, 9), _v(c, s, 0, 12), _v(c, s, 9, 9), _v(c, s, 18, 0)]), cor, w)
			ci.draw_circle(c, 5.5 * s, cor)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([_v(c, s, -8, -13), _v(c, s, -8, 13), _v(c, s, 14, 0)]), cor)
		"pausa":
			ci.draw_rect(Rect2(_v(c, s, -11, -13), Vector2(8, 26) * s), cor, true)
			ci.draw_rect(Rect2(_v(c, s, 3, -13), Vector2(8, 26) * s), cor, true)
		"mais":
			ci.draw_line(_v(c, s, -13, 0), _v(c, s, 13, 0), cor, w * 1.2)
			ci.draw_line(_v(c, s, 0, -13), _v(c, s, 0, 13), cor, w * 1.2)
		"menos":
			ci.draw_line(_v(c, s, -13, 0), _v(c, s, 13, 0), cor, w * 1.2)
		"copiar":
			ci.draw_rect(Rect2(_v(c, s, -15, -15), Vector2(20, 20) * s), cor, false, w)
			ci.draw_rect(Rect2(_v(c, s, -5, -5), Vector2(20, 20) * s), cor, false, w)
		"lixo":
			ci.draw_rect(Rect2(_v(c, s, -11, -8), Vector2(22, 24) * s), cor, false, w)
			ci.draw_line(_v(c, s, -15, -10), _v(c, s, 15, -10), cor, w)
			ci.draw_line(_v(c, s, -5, -14), _v(c, s, 5, -14), cor, w)
		"esq":
			ci.draw_polyline(PackedVector2Array([_v(c, s, 7, -13), _v(c, s, -7, 0), _v(c, s, 7, 13)]), cor, w * 1.2)
		"dir":
			ci.draw_polyline(PackedVector2Array([_v(c, s, -7, -13), _v(c, s, 7, 0), _v(c, s, -7, 13)]), cor, w * 1.2)
		"cima":
			ci.draw_polyline(PackedVector2Array([_v(c, s, -13, 7), _v(c, s, 0, -7), _v(c, s, 13, 7)]), cor, w * 1.2)
		"baixo":
			ci.draw_polyline(PackedVector2Array([_v(c, s, -13, -7), _v(c, s, 0, 7), _v(c, s, 13, -7)]), cor, w * 1.2)
		"salvar":
			ci.draw_rect(Rect2(_v(c, s, -15, -15), Vector2(30, 30) * s), cor, false, w)
			ci.draw_rect(Rect2(_v(c, s, -8, -15), Vector2(16, 10) * s), cor, false, w * 0.8)
			ci.draw_rect(Rect2(_v(c, s, -9, 3), Vector2(18, 12) * s), cor, false, w * 0.8)
		"exportar":
			ci.draw_line(_v(c, s, 0, 8), _v(c, s, 0, -15), cor, w)
			ci.draw_polyline(PackedVector2Array([_v(c, s, -8, -7), _v(c, s, 0, -15), _v(c, s, 8, -7)]), cor, w)
			ci.draw_polyline(PackedVector2Array([_v(c, s, -14, 2), _v(c, s, -14, 15), _v(c, s, 14, 15), _v(c, s, 14, 2)]), cor, w)
		"importar":
			ci.draw_line(_v(c, s, 0, -15), _v(c, s, 0, 8), cor, w)
			ci.draw_polyline(PackedVector2Array([_v(c, s, -8, 0), _v(c, s, 0, 8), _v(c, s, 8, 0)]), cor, w)
			ci.draw_polyline(PackedVector2Array([_v(c, s, -14, 2), _v(c, s, -14, 15), _v(c, s, 14, 15), _v(c, s, 14, 2)]), cor, w)
		"pessoa":
			ci.draw_circle(_v(c, s, 0, -9), 7.0 * s, cor)
			ci.draw_arc(_v(c, s, 0, 17), 14.0 * s, PI, TAU, 16, cor, w * 1.4)
		"engrenagem":
			ci.draw_arc(c, 9.0 * s, 0.0, TAU, 20, cor, w)
			for k in range(8):
				var a: float = float(k) * TAU / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * 11.0 * s, c + Vector2(cos(a), sin(a)) * 16.0 * s, cor, w * 1.3)
		"fechar":
			ci.draw_line(_v(c, s, -12, -12), _v(c, s, 12, 12), cor, w * 1.2)
			ci.draw_line(_v(c, s, 12, -12), _v(c, s, -12, 12), cor, w * 1.2)
		"check":
			ci.draw_polyline(PackedVector2Array([_v(c, s, -13, 1), _v(c, s, -4, 11), _v(c, s, 14, -11)]), cor, w * 1.3)
		"projeto":
			ci.draw_rect(Rect2(_v(c, s, -16, -12), Vector2(32, 26) * s), cor, false, w)
			ci.draw_polyline(PackedVector2Array([_v(c, s, -16, -12), _v(c, s, -16, -17), _v(c, s, -4, -17), _v(c, s, 0, -12)]), cor, w)
		"ember":
			ci.draw_colored_polygon(PackedVector2Array([_v(c, s, 0, -19), _v(c, s, 11, -4), _v(c, s, 13, 7), _v(c, s, 6, 17), _v(c, s, -6, 17), _v(c, s, -13, 7), _v(c, s, -9, -4), _v(c, s, -3, -10)]), cor)
		"png":
			ci.draw_rect(Rect2(_v(c, s, -16, -13), Vector2(32, 26) * s), cor, false, w)
			ci.draw_colored_polygon(PackedVector2Array([_v(c, s, -12, 9), _v(c, s, -3, -3), _v(c, s, 4, 5), _v(c, s, 8, 0), _v(c, s, 12, 9)]), cor)
		"gif":
			ci.draw_rect(Rect2(_v(c, s, -17, -10), Vector2(24, 20) * s), cor, false, w)
			ci.draw_rect(Rect2(_v(c, s, -7, -15), Vector2(24, 20) * s), cor, false, w)
		"quadros":
			ci.draw_rect(Rect2(_v(c, s, -15, -9), Vector2(18, 18) * s), cor, false, w)
			ci.draw_rect(Rect2(_v(c, s, 1, -9), Vector2(14, 18) * s), cor, true)
		_:
			if nome != "pessoa":
				desenhar(ci, "pessoa", r, cor, extra)


static func Estilo_fundo() -> Color:
	return Color("1f1835")