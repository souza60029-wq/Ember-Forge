extends RefCounted

# O personagem que está sendo criado: tamanho da arte, paleta, e uma lista de sequências.
# Cada sequência é uma animação (parado, andando...) ou um golpe, com seus quadros (imagens).

const Formato = preload("res://src/Formato.gd")

const PASTA := "user://forja/"
const MAX_UNDO := 60
const PALETA_PADRAO := [
	"#000000", "#1a1c2c", "#333c57", "#566c86", "#94b0c2", "#f4f4f4", "#ffffff",
	"#5d275d", "#b13e53", "#ef7d57", "#ffcd75", "#a7f070", "#38b764", "#257179",
	"#29366f", "#3b5dc9", "#41a6f6", "#73eff7",
	"#fff0e6", "#f5d6c6", "#e8b796", "#c98b6b", "#8a5a44", "#5a3a2e", "#3d2b24",
	"#d9a066", "#8f563b", "#663931", "#ff2d55", "#7c3aed",
]

var id: String = "novo_personagem"
var nome: String = "Novo personagem"
var largura: int = 64
var altura: int = 64
var altura_px: int = 52
var direcao: String = "direita"   # para onde o sprite olha em TODOS os quadros: "direita" ou "esquerda"
var paleta: PackedColorArray = PackedColorArray()
var sequencias: Array = []
var seq: int = 0
var quadro: int = 0
var sujo: bool = false

var _undo: Array = []
var _redo: Array = []
var _tudo_sujo: bool = true
var _sujos := {}


func novo(p_nome: String, w: int, h: int) -> void:
	nome = p_nome
	id = Formato.sanitizar_id(p_nome) + "_" + str(int(Time.get_unix_time_from_system()) % 100000)
	largura = clampi(w, 8, 512)
	altura = clampi(h, 8, 512)
	altura_px = int(float(altura) * 0.8)
	direcao = "direita"
	paleta = PackedColorArray()
	for h_ in PALETA_PADRAO:
		paleta.append(Color(str(h_)))
	sequencias = []
	for slot in Formato.SLOTS:
		sequencias.append(_nova_seq(str(slot), "slot", str(Formato.ROTULOS_SLOT.get(slot, slot)), {}))
	for b in Formato.BOTOES:
		var g: Dictionary = Formato.golpe_base(str(b))
		sequencias.append(_nova_seq("golpe_" + str(b), "golpe", str(g["nome"]), g))
	seq = 0
	quadro = 0
	_undo.clear()
	_redo.clear()
	_tudo_sujo = true
	sujo = true
	garantir()


func _nova_seq(p_id: String, tipo: String, p_nome: String, golpe: Dictionary) -> Dictionary:
	return {"id": p_id, "tipo": tipo, "nome": p_nome, "fps": 8, "quadros": [], "golpe": golpe}


func adicionar_golpe() -> int:
	var g: Dictionary = Formato.padrao_golpe()
	var n: int = 1
	for s in sequencias:
		if str(s["tipo"]) == "golpe" and not bool((s["golpe"] as Dictionary).get("base", false)):
			n += 1
	g["nome"] = "Golpe %d" % n
	g["base"] = false
	sequencias.append(_nova_seq("golpe_%d_%d" % [n, Time.get_ticks_msec() % 10000], "golpe", str(g["nome"]), g))
	_marcar_estrutura()
	return sequencias.size() - 1


func remover_golpe(i: int) -> void:
	if i < 0 or i >= sequencias.size():
		return
	var s: Dictionary = sequencias[i]
	if str(s["tipo"]) != "golpe" or bool((s["golpe"] as Dictionary).get("base", false)):
		return
	sequencias.remove_at(i)
	seq = clampi(seq, 0, sequencias.size() - 1)
	quadro = 0
	garantir()
	_marcar_estrutura()


# ---------- acesso ----------

func sequencia() -> Dictionary:
	return sequencias[seq]


func quadros() -> Array:
	return sequencias[seq]["quadros"]


func imagem() -> Image:
	garantir()
	return quadros()[quadro]


# largura x altura = tamanho PADRÃO de um sprite novo. Cada quadro pode ter o seu próprio tamanho.
func nova_imagem() -> Image:
	var img := Image.create(largura, altura, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


# Toda sequência aberta tem pelo menos um quadro.
func garantir() -> void:
	var q: Array = quadros()
	if q.is_empty():
		q.append(nova_imagem())
		_marcar_estrutura()
	quadro = clampi(quadro, 0, q.size() - 1)


func selecionar(i: int) -> void:
	seq = clampi(i, 0, sequencias.size() - 1)
	quadro = 0
	garantir()
	_undo.clear()
	_redo.clear()


func ir_quadro(i: int) -> void:
	quadro = clampi(i, 0, quadros().size() - 1)


func e_golpe() -> bool:
	return str(sequencia()["tipo"]) == "golpe"


# ---------- quadros ----------

func adicionar_quadro(duplicar: bool) -> void:
	var q: Array = quadros()
	var novo_img: Image = nova_imagem()
	if not q.is_empty():
		var atual: Image = q[quadro]
		if duplicar:
			novo_img.copy_from(atual)
		else:
			# quadro em branco com o mesmo tamanho do quadro atual
			novo_img = Image.create(atual.get_width(), atual.get_height(), false, Image.FORMAT_RGBA8)
			novo_img.fill(Color(0, 0, 0, 0))
	q.insert(quadro + 1, novo_img)
	quadro += 1
	_marcar_estrutura()


# Coloca imagens importadas como quadros novos. Cada sprite mantém o SEU tamanho (a engine usa o tamanho
# do sprite para posicionar e para desenhar a hitbox). Se a sequência só tem um quadro vazio,
# a primeira imagem ocupa o lugar dele.
func inserir_quadros(imagens: Array) -> int:
	var q: Array = quadros()
	var n: int = 0
	for im in imagens:
		var img: Image = Image.new()
		img.copy_from(im)
		img.convert(Image.FORMAT_RGBA8)
		if n == 0 and q.size() == 1 and (q[0] as Image).is_invisible():
			q[0] = img
			quadro = 0
		else:
			q.insert(quadro + 1, img)
			quadro += 1
		n += 1
	if n > 0:
		_marcar_estrutura()
	return n


# Muda o tamanho do sprite atual (só dele). O desenho fica centralizado e com os pés na base.
func redimensionar_quadro(nw: int, nh: int) -> void:
	nw = clampi(nw, 4, 2048)
	nh = clampi(nh, 4, 2048)
	var img: Image = imagem()
	var ow: int = img.get_width()
	var oh: int = img.get_height()
	if nw == ow and nh == oh:
		return
	empurrar_undo(img.get_data(), ow, oh)
	var novo_img: Image = Image.create(nw, nh, false, Image.FORMAT_RGBA8)
	novo_img.fill(Color(0, 0, 0, 0))
	var dx: int = (nw - ow) / 2
	var dy: int = nh - oh
	var sx: int = maxi(0, -dx)
	var sy: int = maxi(0, -dy)
	var px: int = maxi(0, dx)
	var py: int = maxi(0, dy)
	var cw: int = mini(ow - sx, nw - px)
	var ch: int = mini(oh - sy, nh - py)
	if cw > 0 and ch > 0:
		novo_img.blit_rect(img, Rect2i(sx, sy, cw, ch), Vector2i(px, py))
	img.copy_from(novo_img)
	_sujos["%d_%d" % [seq, quadro]] = true
	marcar_sujo()


func remover_quadro() -> void:
	var q: Array = quadros()
	if q.size() <= 1:
		q[0].fill(Color(0, 0, 0, 0))
	else:
		q.remove_at(quadro)
		quadro = clampi(quadro, 0, q.size() - 1)
	_marcar_estrutura()


func mover_quadro(d: int) -> void:
	var q: Array = quadros()
	var j: int = quadro + d
	if j < 0 or j >= q.size():
		return
	var img: Image = q[quadro]
	q.remove_at(quadro)
	q.insert(j, img)
	quadro = j
	_marcar_estrutura()


# ---------- desfazer / refazer ----------

# w/h: tamanho do quadro ANTES da mudança (se omitidos, vale o tamanho atual do quadro).
func empurrar_undo(dados_antes: PackedByteArray, w: int = 0, h: int = 0) -> void:
	var atual: Image = quadros()[quadro]
	_sujos["%d_%d" % [seq, quadro]] = true
	_undo.append({"s": seq, "q": quadro, "d": dados_antes,
		"w": w if w > 0 else atual.get_width(), "h": h if h > 0 else atual.get_height()})
	if _undo.size() > MAX_UNDO:
		_undo.pop_front()
	_redo.clear()
	marcar_sujo()


func desfazer() -> bool:
	return _trocar(_undo, _redo)


func refazer() -> bool:
	return _trocar(_redo, _undo)


func _trocar(de: Array, para: Array) -> bool:
	if de.is_empty():
		return false
	var e: Dictionary = de.pop_back()
	var s: int = int(e["s"])
	var q: int = int(e["q"])
	if s < 0 or s >= sequencias.size():
		return false
	var lista: Array = sequencias[s]["quadros"]
	if q < 0 or q >= lista.size():
		return false
	var img: Image = lista[q]
	para.append({"s": s, "q": q, "d": img.get_data(), "w": img.get_width(), "h": img.get_height()})
	img.set_data(int(e.get("w", img.get_width())), int(e.get("h", img.get_height())), false, Image.FORMAT_RGBA8, e["d"])
	seq = s
	quadro = q
	_sujos["%d_%d" % [s, q]] = true
	marcar_sujo()
	return true


# ---------- salvar / abrir ----------

func marcar_sujo() -> void:
	sujo = true


func _marcar_estrutura() -> void:
	_tudo_sujo = true
	sujo = true


func salvar() -> String:
	var pasta: String = PASTA + id + "/"
	DirAccess.make_dir_recursive_absolute(pasta)
	if _tudo_sujo:
		var d := DirAccess.open(pasta)
		if d != null:
			for f in d.get_files():
				if f.ends_with(".png"):
					d.remove(f)
	var meta_seqs: Array = []
	for i in range(sequencias.size()):
		var s: Dictionary = sequencias[i]
		var q: Array = s["quadros"]
		meta_seqs.append({"id": s["id"], "tipo": s["tipo"], "nome": s["nome"], "fps": s["fps"], "golpe": s["golpe"], "n": q.size()})
		for j in range(q.size()):
			var arq: String = pasta + "s%d_q%d.png" % [i, j]
			if _tudo_sujo or not FileAccess.file_exists(arq) or _sujos.has("%d_%d" % [i, j]) or (i == seq and j == quadro):
				(q[j] as Image).save_png(arq)
	var cores: Array = []
	for c in paleta:
		cores.append(c.to_html(false))
	var meta := {"id": id, "nome": nome, "largura": largura, "altura": altura, "altura_px": altura_px, "direcao": direcao,
		"paleta": cores, "seq": seq, "quadro": quadro, "sequencias": meta_seqs}
	var f := FileAccess.open(pasta + "projeto.json", FileAccess.WRITE)
	if f == null:
		return "Nao consegui salvar o projeto."
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	var u := FileAccess.open(PASTA + "ultimo.txt", FileAccess.WRITE)
	if u != null:
		u.store_string(id)
		u.close()
	_tudo_sujo = false
	_sujos.clear()
	sujo = false
	return ""


func abrir(p_id: String) -> bool:
	var pasta: String = PASTA + p_id + "/"
	if not FileAccess.file_exists(pasta + "projeto.json"):
		return false
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(pasta + "projeto.json"))
	if typeof(meta) != TYPE_DICTIONARY:
		return false
	var m: Dictionary = meta
	id = str(m.get("id", p_id))
	nome = str(m.get("nome", "Sem nome"))
	largura = clampi(int(m.get("largura", 64)), 8, 512)
	altura = clampi(int(m.get("altura", 64)), 8, 512)
	altura_px = clampi(int(m.get("altura_px", 52)), 8, 600)
	direcao = "esquerda" if str(m.get("direcao", "direita")) == "esquerda" else "direita"
	paleta = PackedColorArray()
	for h_ in m.get("paleta", PALETA_PADRAO):
		paleta.append(Color(str(h_)))
	if paleta.is_empty():
		for h_ in PALETA_PADRAO:
			paleta.append(Color(str(h_)))
	sequencias = []
	var lista: Array = m.get("sequencias", [])
	for i in range(lista.size()):
		var e: Dictionary = lista[i]
		var g: Dictionary = e.get("golpe", {}) if typeof(e.get("golpe", {})) == TYPE_DICTIONARY else {}
		var s: Dictionary = _nova_seq(str(e.get("id", "x%d" % i)), str(e.get("tipo", "slot")), str(e.get("nome", "")), g)
		s["fps"] = clampi(int(e.get("fps", 8)), 1, 60)
		var q: Array = s["quadros"]
		for j in range(int(e.get("n", 0))):
			var img: Image = Image.load_from_file(pasta + "s%d_q%d.png" % [i, j])
			if img == null or img.is_empty():
				img = nova_imagem()
			img.convert(Image.FORMAT_RGBA8)
			q.append(img)
		sequencias.append(s)
	if sequencias.is_empty():
		novo(nome, largura, altura)
		return true
	seq = clampi(int(m.get("seq", 0)), 0, sequencias.size() - 1)
	quadro = int(m.get("quadro", 0))
	_undo.clear()
	_redo.clear()
	garantir()
	_tudo_sujo = false
	sujo = false
	return true


static func listar_projetos() -> Array:
	var r: Array = []
	var d := DirAccess.open(PASTA)
	if d == null:
		return r
	for pasta in d.get_directories():
		var arq: String = PASTA + pasta + "/projeto.json"
		if FileAccess.file_exists(arq):
			var m: Variant = JSON.parse_string(FileAccess.get_file_as_string(arq))
			if typeof(m) == TYPE_DICTIONARY:
				r.append({"id": pasta, "nome": str((m as Dictionary).get("nome", pasta))})
	return r


static func ultimo_id() -> String:
	if FileAccess.file_exists(PASTA + "ultimo.txt"):
		return FileAccess.get_file_as_string(PASTA + "ultimo.txt").strip_edges()
	return ""