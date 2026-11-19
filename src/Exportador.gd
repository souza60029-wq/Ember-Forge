extends RefCounted

# Exporta PNG, folha de sprites, GIF e o personagem completo no formato .ember da engine.

const Formato = preload("res://src/Formato.gd")
const Gif = preload("res://src/Gif.gd")


# Onde os arquivos vão parar. iPhone: Arquivos > No meu iPhone > Ember Forja > exportados.
static func pasta_saida() -> String:
	var base: String = "user://exportados/"
	if OS.get_name() == "Android":
		var dl: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
		if dl != "":
			base = dl.path_join("EmberForja") + "/"
	DirAccess.make_dir_recursive_absolute(base)
	return base


static func _gravar(nome: String, bytes: PackedByteArray) -> Dictionary:
	var pasta: String = pasta_saida()
	var f := FileAccess.open(pasta + nome, FileAccess.WRITE)
	if f == null:
		# plano B: pasta interna do app
		DirAccess.make_dir_recursive_absolute("user://exportados/")
		pasta = "user://exportados/"
		f = FileAccess.open(pasta + nome, FileAccess.WRITE)
		if f == null:
			return {"ok": false, "msg": "Nao consegui gravar o arquivo."}
	f.store_buffer(bytes)
	f.close()
	return {"ok": true, "msg": "Salvo: " + ProjectSettings.globalize_path(pasta + nome) if OS.get_name() != "iOS" else "Salvo em Ember Forja > exportados > " + nome}


static func _limpo(texto: String) -> String:
	return Formato.sanitizar_id(texto)


static func png_quadro(doc: Variant) -> Dictionary:
	var nome: String = "%s_%s_%d.png" % [_limpo(doc.nome), str(doc.sequencia()["id"]), doc.quadro + 1]
	return _gravar(nome, (doc.imagem() as Image).save_png_to_buffer())


# Cada sprite tem o seu tamanho. Na folha e no GIF (que precisam de células iguais) cada um
# fica centralizado e com os pés na base da maior caixa. Os PNGs individuais e o .ember mantêm o tamanho de cada sprite.
static func _caixa(imagens: Array) -> Vector2i:
	var w: int = 1
	var h: int = 1
	for im in imagens:
		w = maxi(w, (im as Image).get_width())
		h = maxi(h, (im as Image).get_height())
	return Vector2i(w, h)


static func _na_caixa(im: Image, w: int, h: int) -> Image:
	var iw: int = im.get_width()
	var ih: int = im.get_height()
	if iw == w and ih == h:
		return im
	var saida: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	saida.fill(Color(0, 0, 0, 0))
	saida.blit_rect(im, Rect2i(0, 0, iw, ih), Vector2i((w - iw) / 2, h - ih))
	return saida


static func _uniformizar(imagens: Array) -> Array:
	var c: Vector2i = _caixa(imagens)
	var r: Array = []
	for im in imagens:
		r.append(_na_caixa(im as Image, c.x, c.y))
	return r


static func folha(imagens: Array) -> Image:
	var c: Vector2i = _caixa(imagens)
	var f := Image.create(c.x * imagens.size(), c.y, false, Image.FORMAT_RGBA8)
	f.fill(Color(0, 0, 0, 0))
	for i in range(imagens.size()):
		f.blit_rect(_na_caixa(imagens[i] as Image, c.x, c.y), Rect2i(0, 0, c.x, c.y), Vector2i(i * c.x, 0))
	return f


static func png_folha(doc: Variant) -> Dictionary:
	var nome: String = "%s_%s_folha.png" % [_limpo(doc.nome), str(doc.sequencia()["id"])]
	return _gravar(nome, folha(doc.quadros()).save_png_to_buffer())


static func gif(doc: Variant) -> Dictionary:
	var q: Array = doc.quadros()
	if q.size() < 2:
		return {"ok": false, "msg": "O GIF precisa de 2 quadros ou mais."}
	var nome: String = "%s_%s.gif" % [_limpo(doc.nome), str(doc.sequencia()["id"])]
	return _gravar(nome, Gif.codificar(_uniformizar(q), int(doc.sequencia()["fps"])))


# Monta o personagem.json e os sprites. Devolve {ok, erro, personagem, arquivos: {caminho: bytes}}.
static func montar_ember(doc: Variant) -> Dictionary:
	var arquivos := {}
	var sprites := {}
	var golpes: Array = []
	var usados := {}
	for s in doc.sequencias:
		var q: Array = s["quadros"]
		var vazio: bool = q.is_empty()
		if str(s["tipo"]) == "slot":
			var lista: Array = []
			if not vazio:
				for j in range(q.size()):
					var nome: String = "sprites/%s_%d.png" % [str(s["id"]), j + 1]
					arquivos[nome] = (q[j] as Image).save_png_to_buffer()
					lista.append(nome)
			sprites[str(s["id"])] = lista
		else:
			var g: Dictionary = (s["golpe"] as Dictionary).duplicate(true)
			var slug: String = _limpo(str(g.get("nome", "golpe")))
			var n: int = 2
			var base: String = slug
			while usados.has(slug):
				slug = "%s_%d" % [base, n]
				n += 1
			usados[slug] = true
			var frames: Array = []
			if not vazio:
				for j in range(q.size()):
					var nome2: String = "golpes/%s/%d.png" % [slug, j + 1]
					arquivos[nome2] = (q[j] as Image).save_png_to_buffer()
					frames.append(nome2)
			g["frames"] = frames
			golpes.append(g)
	var p := {"formato": Formato.VERSAO, "id": doc.id, "nome": doc.nome, "altura_px": doc.altura_px, "olhando": doc.direcao,
		"sprites": sprites, "golpes": golpes, "magias": []}
	var norm: Dictionary = Formato.normalizar(p)
	if not bool(norm["ok"]):
		return {"ok": false, "erro": str(norm["erro"]), "personagem": {}, "arquivos": {}}
	return {"ok": true, "erro": "", "personagem": norm["personagem"], "arquivos": arquivos}


static func gravar_zip(caminho: String, m: Dictionary) -> String:
	var p: Dictionary = m["personagem"]
	var zip := ZIPPacker.new()
	if zip.open(caminho) != OK:
		return "Nao consegui criar " + caminho
	var manifesto := {"formato": "ember-personagem", "versao": 1, "id": str(p["id"]), "nome": str(p["nome"])}
	zip.start_file("ember.json")
	zip.write_file(JSON.stringify(manifesto).to_utf8_buffer())
	zip.close_file()
	zip.start_file("personagem.json")
	zip.write_file(JSON.stringify(p, "\t").to_utf8_buffer())
	zip.close_file()
	for nome in (m["arquivos"] as Dictionary).keys():
		zip.start_file(str(nome))
		zip.write_file(m["arquivos"][nome])
		zip.close_file()
	zip.close()
	return ""


static func ember(doc: Variant) -> Dictionary:
	var m: Dictionary = montar_ember(doc)
	if not bool(m["ok"]):
		return {"ok": false, "msg": str(m["erro"])}
	var pasta: String = pasta_saida()
	var nome: String = str(m["personagem"]["id"]) + ".ember"
	var erro: String = gravar_zip(pasta + nome, m)
	if erro != "":
		erro = gravar_zip("user://exportados/" + nome, m)
		if erro != "":
			return {"ok": false, "msg": erro}
	return {"ok": true, "msg": "Personagem salvo: %s (%d imagens)" % [nome, (m["arquivos"] as Dictionary).size()]}