extends Control

# Ember Forja: editor de pixel art e criador de personagens para a engine Ember.

const Estilo = preload("res://src/Estilo.gd")
const Boto = preload("res://src/Boto.gd")
const Tela = preload("res://src/Tela.gd")
const Paleta = preload("res://src/Paleta.gd")
const Quadros = preload("res://src/Quadros.gd")
const Folha = preload("res://src/Folha.gd")
const CorPicker = preload("res://src/CorPicker.gd")
const Documento = preload("res://src/Documento.gd")
const Exportador = preload("res://src/Exportador.gd")
const Formato = preload("res://src/Formato.gd")
const Seletor = preload("res://src/Seletor.gd")

const FPS_OPCOES := [4, 6, 8, 12, 16, 24]
const FERR_PINCEL := ["lapis", "borracha"]
const FERR_FORMA := ["linha", "retangulo"]
const SESSAO := "user://forja/sessao.json"

var doc: Variant = null
var tela: Tela = null
var paleta: Paleta = null
var quadros_ui: Quadros = null

var _raiz: Control = null
var _olho: Boto = null
var _folha: Variant = null
var _toast_rot: Label = null
var _tmr_play: Timer = null
var _tmr_save: Timer = null
var _tmr_toast: Timer = null
var _u: float = 64.0
var _ferr: String = "lapis"
var _cor_i: int = 3
var _limpo: bool = false
var _tocando: bool = false
var _ultimo_tam: Vector2 = Vector2.ZERO
var _inferior: VBoxContainer = null
var _gaveta: String = ""
var _ub: float = 64.0
var _paisagem: bool = false
var _ult_pincel: String = "lapis"
var _ult_forma: String = "retangulo"
var _pend_imgs: Array = []
var _btn_play: Boto = null
var _btn_fps: Boto = null
var _exp_status: Label = null
var _vista_salva := {}
var _seletor: Variant = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Estilo.FUNDO)
	doc = Documento.new()
	var ult: String = Documento.ultimo_id()
	if ult == "" or not doc.abrir(ult):
		doc.novo("Novo personagem", 64, 64)
	tela = Tela.new()
	tela.doc = doc
	tela.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tela.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tela.mudou.connect(_apos_desenho)
	tela.hitbox_mudou.connect(_agendar_save)
	tela.cor_captada.connect(_ao_captar_cor)
	paleta = Paleta.new()
	paleta.escolhida.connect(_ao_escolher_cor)
	paleta.editar.connect(_abrir_cor)
	paleta.nova.connect(_abrir_cor.bind(-1))
	quadros_ui = Quadros.new()
	quadros_ui.doc = doc
	quadros_ui.escolhido.connect(_ao_escolher_quadro)
	_tmr_play = Timer.new()
	_tmr_play.timeout.connect(_passo_play)
	add_child(_tmr_play)
	_tmr_save = Timer.new()
	_tmr_save.one_shot = true
	_tmr_save.wait_time = 0.6
	_tmr_save.timeout.connect(_salvar)
	add_child(_tmr_save)
	_tmr_toast = Timer.new()
	_tmr_toast.one_shot = true
	_tmr_toast.wait_time = 3.0
	_tmr_toast.timeout.connect(_esconder_toast)
	add_child(_tmr_toast)
	get_viewport().size_changed.connect(_ao_redimensionar)
	_seletor = Seletor.new()
	_seletor.escolhidos.connect(_ao_importar)
	_seletor.falhou.connect(_toast)
	add_child(_seletor)
	_restaurar_sessao()
	_recarregar_tudo()
	_aplicar_vista_salva.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_salvar()


func _ao_redimensionar() -> void:
	if get_viewport_rect().size != _ultimo_tam:
		_montar.call_deferred()


func _recarregar_tudo() -> void:
	_cor_i = clampi(_cor_i, 0, doc.paleta.size() - 1)
	paleta.definir(doc.paleta, _cor_i)
	tela.cor = doc.paleta[_cor_i]
	tela.ferramenta = _ferr
	tela.atualizar()
	quadros_ui.doc = doc
	quadros_ui.atualizar()
	_montar()
	tela.ajustar.call_deferred()


# ---------- montagem da interface (responsiva) ----------
#
# Em cima: Personagem (ação/golpe atual), Importar, Salvar.
# No meio: a arte e a faixa de quadros (com desfazer/refazer).
# Embaixo: a "gaveta". Normalmente mostra os botões principais (dock); ao tocar num deles,
# a gaveta daquela ferramenta ocupa o lugar e as outras somem até tocar em voltar.

func _b(icone: String, cb: Callable, rotulo: String = "") -> Boto:
	var b := Boto.new(icone, rotulo)
	b.custom_minimum_size = Vector2(_u, _u)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cb.is_valid():
		b.pressionado.connect(cb)
	return b


# Botão que cabe na linha: sem largura mínima, divide o espaço com os vizinhos.
func _bt(icone: String, rotulo: String, cb: Callable, alt: float, ratio: float = 1.0) -> Boto:
	var b := Boto.new(icone, rotulo)
	b.custom_minimum_size = Vector2(0, alt)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = ratio
	b.tam_fonte = int(_u * 0.22)
	if cb.is_valid():
		b.pressionado.connect(cb)
	return b


func _item(icone: String, rotulo: String, cb: Callable, ativo: bool = false) -> Boto:
	var b := _bt(icone, rotulo, cb, _ub)
	b.ativo = ativo
	return b


func _legenda() -> String:
	var s: Dictionary = doc.sequencia()
	return "%s   %d/%d" % [str(s["nome"]), doc.quadro + 1, doc.quadros().size()]


func _soltar_persistentes() -> void:
	for n in [tela, paleta, quadros_ui]:
		if n.get_parent() != null:
			n.get_parent().remove_child(n)


func _montar() -> void:
	var vp: Vector2 = get_viewport_rect().size
	_ultimo_tam = vp
	_u = Estilo.unidade(vp)
	_paisagem = vp.x > vp.y * 1.15
	_ub = _u * (0.85 if _paisagem else 1.0)
	_soltar_persistentes()
	if _raiz != null:
		remove_child(_raiz)
		_raiz.queue_free()
		_raiz = null
	if _olho != null:
		remove_child(_olho)
		_olho.queue_free()
		_olho = null
	_inferior = null
	_btn_play = null
	_btn_fps = null
	tela.somente_ver = _limpo or _tocando
	tela.legenda = "" if _limpo else _legenda()
	tela.ferramenta = _ferr

	var m := {"left": 0, "top": 0, "right": 0, "bottom": 0}
	if OS.has_feature("mobile"):
		var seg: Rect2i = DisplayServer.get_display_safe_area()
		var ja: Vector2i = DisplayServer.window_get_size()
		m["left"] = maxi(seg.position.x, 0)
		m["top"] = maxi(seg.position.y, 0)
		m["right"] = maxi(ja.x - seg.end.x, 0)
		m["bottom"] = maxi(ja.y - seg.end.y, 0)
	_raiz = MarginContainer.new()
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad: int = 0 if _limpo else int(_u * 0.08)
	_raiz.add_theme_constant_override("margin_left", int(m["left"]) + pad)
	_raiz.add_theme_constant_override("margin_top", int(m["top"]) + pad)
	_raiz.add_theme_constant_override("margin_right", int(m["right"]) + pad)
	_raiz.add_theme_constant_override("margin_bottom", int(m["bottom"]) + pad)
	add_child(_raiz)
	move_child(_raiz, 0)

	if _limpo:
		_raiz.add_child(tela)
		_olho = _b("olho", _alternar_limpo)
		_olho.custom_minimum_size = Vector2(_u, _u)
		_olho.size = Vector2(_u, _u)
		_olho.position = Vector2(vp.x - _u - float(m["right"]) - 10.0, float(m["top"]) + 10.0)
		_olho.ativo = true
		add_child(_olho)
		tela.ajustar.call_deferred()
		return

	var sep: int = int(_u * 0.08)
	var centro := VBoxContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.add_theme_constant_override("separation", sep)
	centro.add_child(_barra_topo(sep))
	centro.add_child(tela)
	centro.add_child(_faixa_quadros(sep))
	_inferior = VBoxContainer.new()
	_inferior.add_theme_constant_override("separation", sep)
	centro.add_child(_inferior)
	_raiz.add_child(centro)
	_encher_inferior()


func _barra_topo(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	var alt: float = _u * 0.95
	var p := Boto.new("pessoa", str(doc.sequencia()["nome"]))
	p.linha = true
	p.custom_minimum_size = Vector2(0, alt)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_stretch_ratio = 2.2
	p.tam_fonte = int(_u * 0.3)
	p.pressionado.connect(_abrir_sequencias)
	h.add_child(p)
	h.add_child(_bt("importar", "Importar", _abrir_importar, alt))
	h.add_child(_bt("salvar", "Salvar", _abrir_salvar, alt))
	return h


func _faixa_quadros(sep: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	var alt: float = _u * (0.9 if _paisagem else 1.15)
	var bd := _bt("desfazer", "", _desfazer, alt)
	bd.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bd.custom_minimum_size = Vector2(alt * 0.8, alt)
	var br := _bt("refazer", "", _refazer, alt)
	br.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	br.custom_minimum_size = Vector2(alt * 0.8, alt)
	h.add_child(bd)
	h.add_child(br)
	quadros_ui.custom_minimum_size = Vector2(0, alt)
	quadros_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(quadros_ui)
	return h


# ---------- gavetas (parte de baixo) ----------

func _limpar_inferior() -> void:
	if paleta.get_parent() != null:
		paleta.get_parent().remove_child(paleta)
	_btn_play = null
	_btn_fps = null
	if _inferior == null:
		return
	for n in _inferior.get_children():
		_inferior.remove_child(n)
		n.queue_free()


func _reconstruir_inferior() -> void:
	if _inferior == null or not is_instance_valid(_inferior):
		return
	_encher_inferior()


func _encher_inferior() -> void:
	_limpar_inferior()
	match _gaveta:
		"cor":
			_gaveta_cor()
		"pincel":
			_gaveta_pincel()
		"forma":
			_gaveta_forma()
		"vista":
			_gaveta_vista()
		"quadros":
			_gaveta_quadros()
		_:
			_dock()


func _abrir_gaveta(nome: String) -> void:
	if nome == "pincel" and not FERR_PINCEL.has(_ferr):
		_set_ferr(_ult_pincel)
	elif nome == "forma" and not FERR_FORMA.has(_ferr):
		_set_ferr(_ult_forma)
	_gaveta = nome
	_reconstruir_inferior.call_deferred()


func _fechar_gaveta() -> void:
	_gaveta = ""
	_reconstruir_inferior.call_deferred()


func _icone_forma() -> String:
	if _ult_forma == "retangulo" and tela.cheio:
		return "retangulo_cheio"
	return _ult_forma


func _linha_gaveta() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_u * 0.06))
	return h


func _voltar(titulo: String) -> Boto:
	return _bt("baixo", titulo, _fechar_gaveta, _ub)


func _dock() -> void:
	var h := _linha_gaveta()
	var bc := _bt("", "Cor", _abrir_gaveta.bind("cor"), _ub)
	bc.cor_amostra = doc.paleta[_cor_i]
	h.add_child(bc)
	h.add_child(_item(_ult_pincel, "Pincel", _abrir_gaveta.bind("pincel"), FERR_PINCEL.has(_ferr)))
	h.add_child(_item(_icone_forma(), "Forma", _abrir_gaveta.bind("forma"), FERR_FORMA.has(_ferr)))
	h.add_child(_item("balde", "Balde", _escolher_ferr.bind("balde"), _ferr == "balde"))
	h.add_child(_item("ajustar", "Vista", _abrir_gaveta.bind("vista"), _ferr == "mao"))
	h.add_child(_item("quadros", "Quadros", _abrir_gaveta.bind("quadros"), _tocando))
	if doc.e_golpe():
		h.add_child(_item("hitbox", "Hitbox", _escolher_ferr.bind("hitbox"), _ferr == "hitbox"))
	_inferior.add_child(h)


func _gaveta_cor() -> void:
	var l1 := _linha_gaveta()
	l1.add_child(_voltar("Cores"))
	l1.add_child(_item("conta", "Captar", _escolher_ferr.bind("conta"), _ferr == "conta"))
	l1.add_child(_item("engrenagem", "Editar", _abrir_cor.bind(_cor_i)))
	l1.add_child(_item("mais", "Nova", _abrir_cor.bind(-1)))
	_inferior.add_child(l1)
	paleta.custom_minimum_size = Vector2(0, _ub * 1.4)
	paleta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inferior.add_child(paleta)
	paleta.definir(doc.paleta, _cor_i)


func _gaveta_pincel() -> void:
	var l1 := _linha_gaveta()
	l1.add_child(_voltar("Pincel"))
	l1.add_child(_item("lapis", "Lápis", _escolher_ferr.bind("lapis"), _ferr == "lapis"))
	l1.add_child(_item("borracha", "Borracha", _escolher_ferr.bind("borracha"), _ferr == "borracha"))
	l1.add_child(_item("espelho", "Espelho", _alternar.bind("espelho"), tela.espelho))
	_inferior.add_child(l1)
	var l2 := _linha_gaveta()
	for n in [1, 2, 3, 4]:
		var b := _item("ponto", "%d px" % n, _definir_pincel.bind(n), tela.tam_pincel == n)
		b.extra = n
		l2.add_child(b)
	_inferior.add_child(l2)


func _gaveta_forma() -> void:
	var l1 := _linha_gaveta()
	l1.add_child(_voltar("Forma"))
	l1.add_child(_item("linha", "Linha", _escolher_ferr.bind("linha"), _ferr == "linha"))
	l1.add_child(_item("retangulo", "Retângulo", _escolher_ferr.bind("retangulo"), _ferr == "retangulo"))
	l1.add_child(_item("retangulo_cheio" if tela.cheio else "retangulo", "Cheio" if tela.cheio else "Vazado", _alternar_cheio, tela.cheio))
	l1.add_child(_item("", "Fixo", _alternar_fixo, tela.forma_fixa))
	_inferior.add_child(l1)
	if tela.forma_fixa:
		var mx: int = maxi(doc.largura, doc.altura)
		_stepper(_inferior, "Largura", tela.forma_w, 1, 1, mx, _set_forma.bind("w"), _ub * 0.85)
		_stepper(_inferior, "Altura", tela.forma_h, 1, 1, mx, _set_forma.bind("h"), _ub * 0.85)


func _gaveta_vista() -> void:
	var l1 := _linha_gaveta()
	l1.add_child(_voltar("Vista"))
	l1.add_child(_item("mao", "Mão", _escolher_ferr.bind("mao"), _ferr == "mao"))
	l1.add_child(_item("ajustar", "Ajustar", _ajustar_vista))
	l1.add_child(_item("grade", "Grade", _alternar.bind("grade"), tela.grade))
	l1.add_child(_item("cebola", "Cebola", _alternar.bind("cebola"), tela.cebola))
	l1.add_child(_item("olho", "Limpa", _alternar_limpo))
	_inferior.add_child(l1)


func _gaveta_quadros() -> void:
	var l1 := _linha_gaveta()
	l1.add_child(_voltar("Quadros"))
	_btn_play = _item("pausa" if _tocando else "play", "Tocar", _alternar_play, _tocando)
	l1.add_child(_btn_play)
	_btn_fps = _item("", "%d fps" % int(doc.sequencia()["fps"]), _ciclar_fps)
	l1.add_child(_btn_fps)
	_inferior.add_child(l1)
	var l2 := _linha_gaveta()
	l2.add_child(_item("mais", "Novo", _add_quadro.bind(false)))
	l2.add_child(_item("copiar", "Duplicar", _add_quadro.bind(true)))
	l2.add_child(_item("lixo", "Apagar", _del_quadro))
	l2.add_child(_item("esq", "Antes", _mover_quadro.bind(-1)))
	l2.add_child(_item("dir", "Depois", _mover_quadro.bind(1)))
	_inferior.add_child(l2)


func _alternar_cheio() -> void:
	tela.cheio = not tela.cheio
	_agendar_save()
	_reconstruir_inferior.call_deferred()


func _alternar_fixo() -> void:
	tela.forma_fixa = not tela.forma_fixa
	_agendar_save()
	_reconstruir_inferior.call_deferred()


func _set_forma(v: int, qual: String) -> void:
	if qual == "w":
		tela.forma_w = v
	else:
		tela.forma_h = v
	_agendar_save()


func _definir_pincel(n: int) -> void:
	tela.tam_pincel = n
	_agendar_save()
	_reconstruir_inferior.call_deferred()


# ---------- ferramentas ----------

func _set_ferr(id: String) -> void:
	_ferr = id
	if FERR_PINCEL.has(id):
		_ult_pincel = id
	elif FERR_FORMA.has(id):
		_ult_forma = id
	tela.ferramenta = id
	_agendar_save()
	tela.queue_redraw()


func _escolher_ferr(id: String) -> void:
	_set_ferr(id)
	_reconstruir_inferior.call_deferred()


func _alternar(nome: String) -> void:
	match nome:
		"espelho":
			tela.espelho = not tela.espelho
		"grade":
			tela.grade = not tela.grade
		"cebola":
			tela.cebola = not tela.cebola
			tela.atualizar()
	tela.queue_redraw()
	_agendar_save()
	_reconstruir_inferior.call_deferred()


func _desfazer() -> void:
	if doc.desfazer():
		_apos_trocar_seq()


func _refazer() -> void:
	if doc.refazer():
		_apos_trocar_seq()


func _ajustar_vista() -> void:
	tela.ajustar()


func _alternar_limpo() -> void:
	_limpo = not _limpo
	tela._auto_ajuste = true
	_montar()


# ---------- cores ----------

func _ao_escolher_cor(i: int) -> void:
	_cor_i = i
	_agendar_save()
	paleta.definir(doc.paleta, i)
	tela.cor = doc.paleta[i]
	if _ferr == "borracha" or _ferr == "mao" or _ferr == "hitbox":
		_escolher_ferr("lapis")
	_reconstruir_inferior.call_deferred()


func _ao_captar_cor(c: Color) -> void:
	var achou: int = -1
	for i in range(doc.paleta.size()):
		if doc.paleta[i] == c:
			achou = i
			break
	if achou < 0:
		doc.paleta.append(c)
		achou = doc.paleta.size() - 1
		doc.marcar_sujo()
		_agendar_save()
	_ao_escolher_cor(achou)
	_escolher_ferr("lapis")


func _abrir_cor(i: int) -> void:
	var f: Variant = _nova_folha("Cor")
	var c: VBoxContainer = f.conteudo
	var pk := CorPicker.new()
	var largura: float = minf(get_viewport_rect().size.x * 0.8, _u * 7.0)
	pk.custom_minimum_size = Vector2(largura, _u * 5.0)
	pk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var atual: Color = doc.paleta[i] if i >= 0 else tela.cor
	pk.definir(atual)
	c.add_child(pk)
	var linha := HBoxContainer.new()
	linha.add_theme_constant_override("separation", int(_u * 0.12))
	var amostra := _b("", Callable())
	(amostra as Boto).cor_amostra = atual
	pk.mudou.connect(_ao_mudar_picker.bind(amostra))
	linha.add_child(amostra)
	linha.add_child(_b("check", _aplicar_cor.bind(i, pk, f)))
	if i >= 0 and doc.paleta.size() > 2:
		linha.add_child(_b("lixo", _apagar_cor.bind(i, f)))
	c.add_child(linha)


func _ao_mudar_picker(cor: Color, amostra: Boto) -> void:
	amostra.cor_amostra = cor
	amostra.queue_redraw()


func _aplicar_cor(i: int, pk: Variant, f: Variant) -> void:
	var cor: Color = pk.cor()
	if i < 0:
		doc.paleta.append(cor)
		i = doc.paleta.size() - 1
	else:
		doc.paleta[i] = cor
	doc.marcar_sujo()
	_agendar_save()
	f.fechar()
	_ao_escolher_cor(i)


func _apagar_cor(i: int, f: Variant) -> void:
	var nova := PackedColorArray()
	for k in range(doc.paleta.size()):
		if k != i:
			nova.append(doc.paleta[k])
	doc.paleta = nova
	doc.marcar_sujo()
	_agendar_save()
	f.fechar()
	_cor_i = clampi(_cor_i, 0, nova.size() - 1)
	_ao_escolher_cor(_cor_i)


# ---------- quadros e animação ----------

func _ao_escolher_quadro(i: int) -> void:
	doc.ir_quadro(i)
	_sincronizar()


func _add_quadro(duplicar: bool) -> void:
	doc.adicionar_quadro(duplicar)
	_sincronizar()
	_agendar_save()


func _del_quadro() -> void:
	doc.remover_quadro()
	_sincronizar()
	_agendar_save()


func _mover_quadro(d: int) -> void:
	doc.mover_quadro(d)
	_sincronizar()
	_agendar_save()


func _sincronizar() -> void:
	tela.atualizar()
	quadros_ui.atualizar()
	tela.legenda = "" if _limpo else _legenda()
	tela.queue_redraw()


func _apos_desenho() -> void:
	quadros_ui.atualizar()
	_agendar_save()


func _apos_trocar_seq() -> void:
	if not doc.e_golpe() and _ferr == "hitbox":
		_ferr = "lapis"
	_tocando = false
	_tmr_play.stop()
	_montar()
	_sincronizar()


func _alternar_play() -> void:
	if doc.quadros().size() < 2:
		_toast("Crie mais de um quadro para animar.")
		return
	_tocando = not _tocando
	if _tocando:
		_tmr_play.wait_time = 1.0 / float(maxi(int(doc.sequencia()["fps"]), 1))
		_tmr_play.start()
	else:
		_tmr_play.stop()
	tela.somente_ver = _limpo or _tocando
	_atualizar_play()
	tela.queue_redraw()


func _atualizar_play() -> void:
	if _btn_play != null and is_instance_valid(_btn_play):
		_btn_play.icone = "pausa" if _tocando else "play"
		_btn_play.ativo = _tocando
		_btn_play.queue_redraw()


func _passo_play() -> void:
	var n: int = doc.quadros().size()
	if n < 2:
		return
	doc.ir_quadro((doc.quadro + 1) % n)
	tela.atualizar()
	quadros_ui.atualizar()


func _ciclar_fps() -> void:
	var atual: int = int(doc.sequencia()["fps"])
	var i: int = FPS_OPCOES.find(atual)
	var novo: int = int(FPS_OPCOES[(i + 1) % FPS_OPCOES.size()])
	doc.sequencia()["fps"] = novo
	doc.marcar_sujo()
	if _btn_fps != null and is_instance_valid(_btn_fps):
		_btn_fps.rotulo = "%d fps" % novo
		_btn_fps.queue_redraw()
	if _tocando:
		_tmr_play.wait_time = 1.0 / float(novo)
	_agendar_save()


# ---------- salvar ----------

func _agendar_save() -> void:
	doc.marcar_sujo()
	_tmr_save.start()


func _salvar() -> void:
	if doc == null:
		return
	if doc.sujo:
		var erro: String = doc.salvar()
		if erro != "":
			_toast(erro)
	_salvar_sessao()


# Guarda o estado do app (ferramenta, cor, zoom...) para reabrir exatamente como estava.
func _salvar_sessao() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var d := {"id": doc.id, "ferr": _ferr, "cor": _cor_i, "espelho": tela.espelho, "grade": tela.grade,
		"cebola": tela.cebola, "pincel": tela.tam_pincel, "cheio": tela.cheio, "forma_fixa": tela.forma_fixa, "fw": tela.forma_w, "fh": tela.forma_h, "zoom": tela.zoom,
		"ox": tela.origem.x, "oy": tela.origem.y, "auto": tela._auto_ajuste, "vp": [vp.x, vp.y]}
	DirAccess.make_dir_recursive_absolute("user://forja/")
	var f := FileAccess.open(SESSAO, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()


func _restaurar_sessao() -> void:
	if not FileAccess.file_exists(SESSAO):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSAO))
	if typeof(d) != TYPE_DICTIONARY or str((d as Dictionary).get("id", "")) != doc.id:
		return
	var s: Dictionary = d
	_ferr = str(s.get("ferr", "lapis"))
	if _ferr == "hitbox" and not doc.e_golpe():
		_ferr = "lapis"
	_cor_i = clampi(int(s.get("cor", 3)), 0, doc.paleta.size() - 1)
	tela.espelho = bool(s.get("espelho", false))
	tela.grade = bool(s.get("grade", false))
	tela.cebola = bool(s.get("cebola", false))
	tela.tam_pincel = clampi(int(s.get("pincel", 1)), 1, 4)
	tela.cheio = bool(s.get("cheio", false))
	tela.forma_fixa = bool(s.get("forma_fixa", true))
	tela.forma_w = clampi(int(s.get("fw", 16)), 1, 512)
	tela.forma_h = clampi(int(s.get("fh", 16)), 1, 512)
	if FERR_PINCEL.has(_ferr):
		_ult_pincel = _ferr
	elif FERR_FORMA.has(_ferr):
		_ult_forma = _ferr
	_vista_salva = s


func _aplicar_vista_salva() -> void:
	var s: Dictionary = _vista_salva
	_vista_salva = {}
	if s.is_empty() or bool(s.get("auto", true)):
		return
	var vp: Vector2 = get_viewport_rect().size
	var v: Array = s.get("vp", [])
	if v.size() == 2 and absf(float(v[0]) - vp.x) < 2.0 and absf(float(v[1]) - vp.y) < 2.0:
		tela.zoom = float(s.get("zoom", tela.zoom))
		tela.origem = Vector2(float(s.get("ox", 0.0)), float(s.get("oy", 0.0)))
		tela._auto_ajuste = false
		tela.queue_redraw()


# ---------- painéis ----------

func _nova_folha(titulo: String) -> Variant:
	if _folha != null and is_instance_valid(_folha):
		_folha.queue_free()
	var f := Folha.new()
	add_child(f)
	f.configurar(titulo, _u, get_viewport_rect().size)
	_folha = f
	return f


func _fechar_folha() -> void:
	if _folha != null and is_instance_valid(_folha):
		_folha.fechar()


func _rotulo(texto: String, cor: Color = Estilo.TEXTO, escala: float = 0.34) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", int(_u * escala))
	l.add_theme_color_override("font_color", cor)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _linha(rotulo: String, icone: String, cb: Callable, ativo: bool = false) -> Boto:
	var b := Boto.new(icone, rotulo)
	b.linha = true
	b.ativo = ativo
	b.custom_minimum_size = Vector2(0, _u * 1.1)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cb.is_valid():
		b.pressionado.connect(cb)
	return b


func _stepper(pai: Control, titulo: String, valor: int, passo: int, mn: int, mx: int, cb: Callable, alt: float = 0.0) -> void:
	var a: float = alt if alt > 0.0 else _u * 0.9
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", int(_u * 0.1))
	var l := _rotulo(titulo)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := _rotulo(str(valor), Estilo.DESTAQUE, 0.4)
	v.custom_minimum_size = Vector2(a * 1.3, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var menos := _b("menos", _passo.bind(v, -passo, mn, mx, cb))
	menos.custom_minimum_size = Vector2(a, a)
	menos.size_flags_horizontal = Control.SIZE_SHRINK_END
	var mais := _b("mais", _passo.bind(v, passo, mn, mx, cb))
	mais.custom_minimum_size = Vector2(a, a)
	mais.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(menos)
	h.add_child(v)
	h.add_child(mais)
	pai.add_child(h)


func _passo(v: Label, delta: int, mn: int, mx: int, cb: Callable) -> void:
	var novo: int = clampi(int(v.text) + delta, mn, mx)
	v.text = str(novo)
	cb.call(novo)


# --- personagem: animações e golpes ---

func _abrir_sequencias() -> void:
	var f: Variant = _nova_folha("Personagem")
	var c: VBoxContainer = f.conteudo
	c.add_child(_linha("Importar sprites (vários de uma vez)", "importar", _abrir_importar))
	var nome := LineEdit.new()
	nome.text = doc.nome
	nome.custom_minimum_size = Vector2(0, _u)
	nome.add_theme_font_size_override("font_size", int(_u * 0.4))
	nome.text_changed.connect(_ao_nome)
	c.add_child(nome)
	_stepper(c, "Altura do corpo (px)", doc.altura_px, 2, 8, 600, _ao_altura)
	c.add_child(_rotulo("Todos os quadros olham para:", Estilo.SUAVE))
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", int(_u * 0.1))
	var bdir: Array = []
	for par in [["esquerda", "esq", "Esquerda"], ["direita", "dir", "Direita"]]:
		var bt := _b(str(par[1]), Callable(), str(par[2]))
		bt.custom_minimum_size = Vector2(0, _u * 1.1)
		bt.ativo = (doc.direcao == str(par[0]))
		bdir.append(bt)
		dh.add_child(bt)
	(bdir[0] as Boto).pressionado.connect(_set_direcao.bind("esquerda", bdir))
	(bdir[1] as Boto).pressionado.connect(_set_direcao.bind("direita", bdir))
	c.add_child(dh)
	c.add_child(_rotulo("Animações", Estilo.SUAVE))
	for i in range(doc.sequencias.size()):
		var s: Dictionary = doc.sequencias[i]
		if str(s["tipo"]) != "slot":
			continue
		c.add_child(_linha_seq(i))
	c.add_child(_rotulo("Golpes", Estilo.SUAVE))
	for i in range(doc.sequencias.size()):
		var s2: Dictionary = doc.sequencias[i]
		if str(s2["tipo"]) != "golpe":
			continue
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", int(_u * 0.1))
		var r: Control = _linha_seq(i)
		h.add_child(r)
		var g := _b("engrenagem", _abrir_ficha.bind(i))
		g.size_flags_horizontal = Control.SIZE_SHRINK_END
		g.custom_minimum_size = Vector2(_u * 1.1, _u * 1.1)
		h.add_child(g)
		c.add_child(h)
	c.add_child(_linha("Novo golpe", "mais", _novo_golpe))


func _linha_seq(i: int, cb: Callable = Callable()) -> Control:
	var s: Dictionary = doc.sequencias[i]
	var acao: Callable = cb if cb.is_valid() else _escolher_seq.bind(i)
	var b := _linha(str(s["nome"]), "quadros", acao, i == doc.seq) as Boto
	var q: Array = s["quadros"]
	if not q.is_empty():
		b.textura = ImageTexture.create_from_image(q[0])
		b.sub = str(q.size())
	return b


func _set_direcao(d: String, botoes: Array) -> void:
	doc.direcao = d
	(botoes[0] as Boto).ativo = (d == "esquerda")
	(botoes[1] as Boto).ativo = (d == "direita")
	tela.queue_redraw()
	_agendar_save()


func _ao_nome(t: String) -> void:
	doc.nome = t
	_agendar_save()


func _ao_altura(v: int) -> void:
	doc.altura_px = v
	tela.queue_redraw()
	_agendar_save()


func _escolher_seq(i: int) -> void:
	doc.selecionar(i)
	if _folha != null:
		_folha.fechar()
	_apos_trocar_seq()


func _novo_golpe() -> void:
	var i: int = doc.adicionar_golpe()
	doc.selecionar(i)
	_agendar_save()
	_abrir_ficha(i)
	_apos_trocar_seq()


func _abrir_ficha(i: int) -> void:
	var s: Dictionary = doc.sequencias[i]
	var g: Dictionary = s["golpe"]
	var f: Variant = _nova_folha("Golpe")
	var c: VBoxContainer = f.conteudo
	var nome := LineEdit.new()
	nome.text = str(g["nome"])
	nome.custom_minimum_size = Vector2(0, _u)
	nome.add_theme_font_size_override("font_size", int(_u * 0.4))
	nome.text_changed.connect(_ao_nome_golpe.bind(i))
	c.add_child(nome)
	var botoes := HBoxContainer.new()
	botoes.add_theme_constant_override("separation", int(_u * 0.08))
	var lista: Array = []
	for b in Formato.BOTOES:
		var bb := _b("", Callable(), str(b))
		bb.custom_minimum_size = Vector2(0, _u)
		(bb as Boto).ativo = (str(g["botao"]) == str(b))
		lista.append(bb)
		botoes.add_child(bb)
	for k in range(lista.size()):
		(lista[k] as Boto).pressionado.connect(_ficha_botao.bind(i, str(Formato.BOTOES[k]), lista))
	c.add_child(botoes)
	_stepper(c, "Dano", int(g["dano"]), 10, 0, 999, _set_golpe.bind(i, "dano"))
	_stepper(c, "Início (frames)", int(g["startup"]), 1, 0, 60, _set_golpe.bind(i, "startup"))
	_stepper(c, "Ativo (frames)", int(g["active"]), 1, 1, 60, _set_golpe.bind(i, "active"))
	_stepper(c, "Recuperação (frames)", int(g["recovery"]), 1, 0, 90, _set_golpe.bind(i, "recovery"))
	_stepper(c, "Força", int(g["forca"]), 1, 1, 3, _set_golpe.bind(i, "forca"))
	_stepper(c, "Custo de energia", int(g["custo"]), 10, 0, 300, _set_golpe.bind(i, "custo"))
	_stepper(c, "Energia ganha", int(g["energia_ganha"]), 10, 0, 300, _set_golpe.bind(i, "energia_ganha"))
	for par in [["so_ar", "Só no ar"], ["antichao", "Anti-chão"], ["blowoff", "Blow off"]]:
		var chave: String = str(par[0])
		var t := _linha(str(par[1]), "check", Callable(), bool(g[chave])) as Boto
		t.pressionado.connect(_ficha_alternar.bind(i, chave, t))
		c.add_child(t)
	c.add_child(_linha("Editar hitbox na arte", "hitbox", _ir_hitbox.bind(i)))
	if not bool(g.get("base", false)):
		c.add_child(_linha("Apagar golpe", "lixo", _apagar_golpe.bind(i)))


func _ao_nome_golpe(t: String, i: int) -> void:
	(doc.sequencias[i]["golpe"] as Dictionary)["nome"] = t
	doc.sequencias[i]["nome"] = t
	_agendar_save()


func _set_golpe(v: Variant, i: int, chave: String) -> void:
	(doc.sequencias[i]["golpe"] as Dictionary)[chave] = v
	_agendar_save()


func _ficha_botao(i: int, b: String, lista: Array) -> void:
	(doc.sequencias[i]["golpe"] as Dictionary)["botao"] = b
	for k in range(lista.size()):
		(lista[k] as Boto).ativo = (str(Formato.BOTOES[k]) == b)
	_agendar_save()


func _ficha_alternar(i: int, chave: String, t: Boto) -> void:
	var g: Dictionary = doc.sequencias[i]["golpe"]
	g[chave] = not bool(g[chave])
	t.ativo = bool(g[chave])
	_agendar_save()


func _ir_hitbox(i: int) -> void:
	doc.selecionar(i)
	_ferr = "hitbox"
	if _folha != null:
		_folha.fechar()
	_apos_trocar_seq()


func _apagar_golpe(i: int) -> void:
	doc.remover_golpe(i)
	if _folha != null:
		_folha.fechar()
	_agendar_save()
	_apos_trocar_seq()


# --- importar sprites ---
# Fluxo: escolher origem (galeria/arquivos, vários de uma vez) -> dizer para qual ação ou golpe vão.

func _abrir_importar() -> void:
	var f: Variant = _nova_folha("Importar sprites")
	var c: VBoxContainer = f.conteudo
	c.add_child(_linha("Galeria de fotos", "png", _pedir_import.bind("galeria")))
	c.add_child(_linha("Explorador de arquivos", "projeto", _pedir_import.bind("arquivos")))
	c.add_child(_rotulo("Escolha vários sprites de uma vez. Depois você diz para qual ação ou golpe eles vão (andando, soco, um golpe novo...). Cada imagem vira um quadro, ajustada ao tamanho da arte (pés na base).", Estilo.SUAVE, 0.28))


func _pedir_import(origem: String) -> void:
	_fechar_folha()
	_seletor.pedir(origem, true, "imagem")


func _ao_importar(caminhos: PackedStringArray) -> void:
	var imgs: Array = []
	var lista: Array = Array(caminhos)
	lista.sort_custom(func(a, b): return str(a).naturalnocasecmp_to(str(b)) < 0)
	for c in lista:
		var im: Image = Image.load_from_file(str(c))
		if im != null and not im.is_empty():
			imgs.append(im)
	if imgs.is_empty():
		_toast("Nao consegui ler as imagens escolhidas.")
		return
	_pend_imgs = imgs
	_abrir_destino()


func _abrir_destino() -> void:
	var f: Variant = _nova_folha("Destino (%d sprites)" % _pend_imgs.size())
	var c: VBoxContainer = f.conteudo
	c.add_child(_rotulo("Golpe novo", Estilo.SUAVE))
	var ed := LineEdit.new()
	ed.placeholder_text = "Nome do golpe (ex: Hadouken)"
	ed.custom_minimum_size = Vector2(0, _u)
	ed.add_theme_font_size_override("font_size", int(_u * 0.4))
	c.add_child(ed)
	c.add_child(_linha("Criar golpe e importar", "mais", _import_novo_golpe.bind(ed)))
	c.add_child(_rotulo("Ações do personagem", Estilo.SUAVE))
	for i in range(doc.sequencias.size()):
		if str(doc.sequencias[i]["tipo"]) == "slot":
			c.add_child(_linha_seq(i, _import_para.bind(i)))
	c.add_child(_rotulo("Golpes", Estilo.SUAVE))
	for i in range(doc.sequencias.size()):
		if str(doc.sequencias[i]["tipo"]) == "golpe":
			c.add_child(_linha_seq(i, _import_para.bind(i)))


func _import_novo_golpe(ed: LineEdit) -> void:
	var t: String = ed.text.strip_edges()
	var i: int = doc.adicionar_golpe()
	if t != "":
		(doc.sequencias[i]["golpe"] as Dictionary)["nome"] = t
		doc.sequencias[i]["nome"] = t
	_import_para(i)


# Os sprites entram no fim dos quadros da ação/golpe escolhido.
func _import_para(i: int) -> void:
	_fechar_folha()
	if _pend_imgs.is_empty():
		return
	doc.selecionar(i)
	doc.ir_quadro(doc.quadros().size() - 1)
	var n: int = doc.inserir_quadros(_pend_imgs)
	_pend_imgs = []
	_tocando = false
	_tmr_play.stop()
	_montar()
	_sincronizar()
	_agendar_save()
	_toast("%d quadro(s) em %s." % [n, str(doc.sequencia()["nome"])])


# --- exportar ---

func _exportar(tipo: String) -> void:
	_salvar()
	var r: Dictionary = {}
	match tipo:
		"png":
			r = Exportador.png_quadro(doc)
		"folha":
			r = Exportador.png_folha(doc)
		"gif":
			r = Exportador.gif(doc)
		"ember":
			r = Exportador.ember(doc)
	if _exp_status != null and is_instance_valid(_exp_status):
		_exp_status.text = str(r.get("msg", ""))


# --- salvar, exportar e projetos ---

func _abrir_salvar() -> void:
	var f: Variant = _nova_folha("Salvar e exportar")
	var c: VBoxContainer = f.conteudo
	c.add_child(_linha("Salvar agora", "salvar", _salvar_manual))
	c.add_child(_rotulo("Exportar", Estilo.SUAVE))
	c.add_child(_linha("PNG do quadro", "png", _exportar.bind("png")))
	c.add_child(_linha("PNG folha de sprites", "quadros", _exportar.bind("folha")))
	c.add_child(_linha("GIF da animação", "gif", _exportar.bind("gif")))
	c.add_child(_linha("Personagem (.ember)", "ember", _exportar.bind("ember")))
	_exp_status = _rotulo("", Estilo.SUAVE, 0.3)
	c.add_child(_exp_status)
	c.add_child(_rotulo("Novo personagem (tamanho da arte)", Estilo.SUAVE))
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", int(_u * 0.08))
	h.add_theme_constant_override("v_separation", int(_u * 0.08))
	for n in [32, 48, 64, 96, 128, 192]:
		h.add_child(_b("", _novo_projeto.bind(int(n)), str(n)))
	c.add_child(h)
	var lista: Array = Documento.listar_projetos()
	if not lista.is_empty():
		c.add_child(_rotulo("Abrir personagem", Estilo.SUAVE))
		for p in lista:
			c.add_child(_linha(str(p["nome"]), "pessoa", _abrir_projeto_id.bind(str(p["id"])), str(p["id"]) == doc.id))


func _salvar_manual() -> void:
	doc.marcar_sujo()
	_salvar()
	_toast("Projeto salvo.")


func _novo_projeto(n: int) -> void:
	_salvar()
	doc.novo("Novo personagem", n, n)
	_ferr = "lapis"
	if _folha != null:
		_folha.fechar()
	_recarregar_tudo()
	_agendar_save()


func _abrir_projeto_id(id: String) -> void:
	_salvar()
	if doc.abrir(id):
		_ferr = "lapis"
		if _folha != null:
			_folha.fechar()
		_recarregar_tudo()
	else:
		_toast("Nao consegui abrir esse projeto.")


# ---------- aviso rápido ----------

func _toast(texto: String) -> void:
	if _toast_rot == null:
		_toast_rot = Label.new()
		_toast_rot.add_theme_stylebox_override("normal", Estilo.caixa(Estilo.PAINEL, Estilo.DESTAQUE, 12, 2))
		_toast_rot.add_theme_color_override("font_color", Estilo.TEXTO)
		_toast_rot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast_rot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_toast_rot)
	_toast_rot.add_theme_font_size_override("font_size", int(_u * 0.32))
	_toast_rot.text = texto
	_toast_rot.size = Vector2(minf(get_viewport_rect().size.x * 0.9, 900.0), _u * 0.9)
	_toast_rot.position = Vector2((get_viewport_rect().size.x - _toast_rot.size.x) * 0.5, get_viewport_rect().size.y * 0.12)
	_toast_rot.visible = true
	move_child(_toast_rot, get_child_count() - 1)
	_tmr_toast.start()


func _esconder_toast() -> void:
	if _toast_rot != null:
		_toast_rot.visible = false