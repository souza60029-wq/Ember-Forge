extends SceneTree

# Testes do Ember Forja (rodam no GitHub Actions, sem tela).

const Documento = preload("res://src/Documento.gd")
const Exportador = preload("res://src/Exportador.gd")
const Formato = preload("res://src/Formato.gd")
const Gif = preload("res://src/Gif.gd")

var falhas: int = 0


func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("ok: ", msg)
	else:
		print("FALHA: ", msg)
		falhas += 1


func _initialize() -> void:
	var d := Documento.new()
	d.novo("Teste Forja", 32, 32)
	_ok(d.sequencias.size() == Formato.SLOTS.size() + Formato.BOTOES.size(), "sequencias criadas")

	# desenhar + desfazer + refazer
	d.direcao = "esquerda"
	d.selecionar(0)
	var img: Image = d.imagem()
	var antes: PackedByteArray = img.get_data()
	img.set_pixel(3, 4, Color.RED)
	d.empurrar_undo(antes)
	_ok(d.desfazer(), "desfazer devolve true")
	_ok(d.imagem().get_pixel(3, 4).a == 0.0, "desfazer apagou o pixel")
	_ok(d.refazer(), "refazer devolve true")
	_ok(d.imagem().get_pixel(3, 4) == Color.RED, "refazer devolveu o pixel")

	# quadros
	d.adicionar_quadro(true)
	d.imagem().set_pixel(10, 10, Color.BLUE)
	d.adicionar_quadro(false)
	d.imagem().set_pixel(20, 20, Color.GREEN)
	_ok(d.quadros().size() == 3, "tres quadros")
	d.mover_quadro(-1)
	_ok(d.quadro == 1, "mover quadro")

	# golpe com hitbox
	var gi: int = d.adicionar_golpe()
	d.selecionar(gi)
	d.imagem().set_pixel(5, 5, Color.WHITE)
	(d.sequencia()["golpe"]["hitbox"] as Dictionary)["w"] = 55

	# GIF
	var gifb: PackedByteArray = Gif.codificar(d.quadros(), 8)
	d.selecionar(0)
	var gifb2: PackedByteArray = Gif.codificar(d.quadros(), 8)
	_ok(gifb.size() > 20 and gifb2.size() > 20, "gif gerado")
	_ok(gifb2.slice(0, 6).get_string_from_ascii() == "GIF89a", "cabecalho do gif")
	_ok(gifb2[gifb2.size() - 1] == 0x3B, "final do gif")
	var fg := FileAccess.open("res://teste_saida.gif", FileAccess.WRITE)
	if fg != null:
		fg.store_buffer(gifb2)
		fg.close()
	# um gif com muitas cores (força o cubo 6x6x6 e a tabela LZW grande)
	var grande := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(64):
			grande.set_pixel(x, y, Color8((x * 4) % 256, (y * 4) % 256, (x * y) % 256, 255))
	var gb: PackedByteArray = Gif.codificar([grande, grande], 12)
	var fg2 := FileAccess.open("res://teste_saida_grande.gif", FileAccess.WRITE)
	if fg2 != null:
		fg2.store_buffer(gb)
		fg2.close()
	_ok(gb[gb.size() - 1] == 0x3B, "gif grande termina certo")

	# .ember
	var m: Dictionary = Exportador.montar_ember(d)
	_ok(bool(m["ok"]), "montar_ember ok: " + str(m.get("erro", "")))
	var erro_zip: String = Exportador.gravar_zip("res://teste_saida.ember", m)
	_ok(erro_zip == "", "gravar zip: " + erro_zip)
	var zr := ZIPReader.new()
	_ok(zr.open("res://teste_saida.ember") == OK, "abrir zip")
	var arqs: PackedStringArray = zr.get_files()
	_ok(arqs.has("personagem.json") and arqs.has("ember.json"), "json no zip")
	var pj: Variant = JSON.parse_string(zr.read_file("personagem.json").get_string_from_utf8())
	_ok(typeof(pj) == TYPE_DICTIONARY, "personagem.json valido")
	var norm: Dictionary = Formato.normalizar(pj)
	_ok(bool(norm["ok"]), "engine aceita o personagem")
	var p: Dictionary = norm["personagem"]
	_ok(str(p["olhando"]) == "esquerda", "direcao do sprite exportada")
	var parado: Array = p["sprites"]["parado"]
	_ok(parado.size() == 3, "tres sprites em 'parado'")
	for nome in parado:
		_ok(arqs.has(str(nome)), "sprite no zip: " + str(nome))
		var png := Image.new()
		_ok(png.load_png_from_buffer(zr.read_file(str(nome))) == OK, "png valido: " + str(nome))
	var achou: bool = false
	for g in p["golpes"]:
		if int(g["hitbox"]["w"]) == 55 and (g["frames"] as Array).size() == 1:
			achou = true
	_ok(achou, "golpe novo com hitbox e quadro")
	zr.close()

	# salvar e abrir
	_ok(d.salvar() == "", "salvar projeto")
	var d2 := Documento.new()
	_ok(d2.abrir(d.id), "abrir projeto")
	_ok(d2.direcao == "esquerda", "direcao salva")
	_ok(d2.sequencias.size() == d.sequencias.size(), "mesmas sequencias")
	_ok(d2.sequencias[0]["quadros"].size() == 3, "mesmos quadros")
	_ok((d2.sequencias[0]["quadros"][0] as Image).get_pixel(3, 4) == Color.RED, "pixel salvo")

	print("falhas: ", falhas)
	quit(falhas)
