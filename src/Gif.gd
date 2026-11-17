extends RefCounted

# Codificador de GIF animado (paleta global, transparência no índice 0, LZW).


static func codificar(imagens: Array, fps: int) -> PackedByteArray:
	var out := PackedByteArray()
	if imagens.is_empty():
		return out
	var w: int = (imagens[0] as Image).get_width()
	var h: int = (imagens[0] as Image).get_height()
	# paleta: cores exatas se couberem em 255, senão cubo 6x6x6
	var unicas := {}
	var cabe: bool = true
	for im in imagens:
		var img: Image = im
		var dados: PackedByteArray = img.get_data()
		var i: int = 0
		while i < dados.size():
			if dados[i + 3] >= 128:
				var chave: int = (dados[i] << 16) | (dados[i + 1] << 8) | dados[i + 2]
				if not unicas.has(chave):
					unicas[chave] = unicas.size() + 1
					if unicas.size() > 255:
						cabe = false
						break
			i += 4
		if not cabe:
			break
	var paleta := PackedByteArray()
	paleta.resize(256 * 3)
	if cabe:
		for chave in unicas.keys():
			var idx: int = unicas[chave]
			paleta[idx * 3] = (chave >> 16) & 255
			paleta[idx * 3 + 1] = (chave >> 8) & 255
			paleta[idx * 3 + 2] = chave & 255
	else:
		for r in range(6):
			for g in range(6):
				for b in range(6):
					var idx2: int = 1 + r * 36 + g * 6 + b
					paleta[idx2 * 3] = r * 51
					paleta[idx2 * 3 + 1] = g * 51
					paleta[idx2 * 3 + 2] = b * 51
	out.append_array("GIF89a".to_ascii_buffer())
	_u16(out, w)
	_u16(out, h)
	out.append(0xF7)
	out.append(0)
	out.append(0)
	out.append_array(paleta)
	out.append_array(PackedByteArray([0x21, 0xFF, 0x0B]))
	out.append_array("NETSCAPE2.0".to_ascii_buffer())
	out.append_array(PackedByteArray([0x03, 0x01, 0x00, 0x00, 0x00]))
	var atraso: int = maxi(2, int(roundf(100.0 / float(maxi(fps, 1)))))
	for im in imagens:
		var img2: Image = im
		var d: PackedByteArray = img2.get_data()
		var indices := PackedByteArray()
		indices.resize(w * h)
		var p: int = 0
		var k: int = 0
		while k < d.size():
			var idx3: int = 0
			if d[k + 3] >= 128:
				if cabe:
					idx3 = unicas[(d[k] << 16) | (d[k + 1] << 8) | d[k + 2]]
				else:
					idx3 = 1 + int(roundf(float(d[k]) / 51.0)) * 36 + int(roundf(float(d[k + 1]) / 51.0)) * 6 + int(roundf(float(d[k + 2]) / 51.0))
			indices[p] = idx3
			p += 1
			k += 4
		out.append_array(PackedByteArray([0x21, 0xF9, 0x04, (2 << 2) | 1]))
		_u16(out, atraso)
		out.append(0)
		out.append(0)
		out.append(0x2C)
		_u16(out, 0)
		_u16(out, 0)
		_u16(out, w)
		_u16(out, h)
		out.append(0)
		out.append(8)
		var lzw: PackedByteArray = _lzw(indices, 8)
		var pos: int = 0
		while pos < lzw.size():
			var n: int = mini(255, lzw.size() - pos)
			out.append(n)
			out.append_array(lzw.slice(pos, pos + n))
			pos += n
		out.append(0)
	out.append(0x3B)
	return out


static func _u16(b: PackedByteArray, v: int) -> void:
	b.append(v & 255)
	b.append((v >> 8) & 255)


# LZW do GIF (mesma lógica do codificador clássico de Kevin Weiner).
# O estado fica num Dictionary para as funções auxiliares poderem alterá-lo.
static func _escrever(st: Dictionary, codigo: int) -> void:
	var o: PackedByteArray = st["out"]
	var acum: int = int(st["acum"]) | (codigo << int(st["cont"]))
	var cont: int = int(st["cont"]) + int(st["nb"])
	while cont >= 8:
		o.append(acum & 255)
		acum >>= 8
		cont -= 8
	st["out"] = o
	st["acum"] = acum
	st["cont"] = cont
	if int(st["livre"]) > int(st["max"]) or bool(st["flag"]):
		if bool(st["flag"]):
			st["nb"] = int(st["tam"]) + 1
			st["max"] = (1 << int(st["nb"])) - 1
			st["flag"] = false
		else:
			st["nb"] = int(st["nb"]) + 1
			st["max"] = 4096 if int(st["nb"]) == 12 else (1 << int(st["nb"])) - 1


static func _lzw(dados: PackedByteArray, tam_min: int) -> PackedByteArray:
	var limpar: int = 1 << tam_min
	var fim: int = limpar + 1
	var st := {"out": PackedByteArray(), "acum": 0, "cont": 0, "nb": tam_min + 1, "max": (1 << (tam_min + 1)) - 1,
		"livre": limpar + 2, "flag": true, "tam": tam_min}
	var tabela := {}
	_escrever(st, limpar)
	var ent: int = dados[0]
	for i in range(1, dados.size()):
		var c: int = dados[i]
		var chave: int = (ent << 8) | c
		if tabela.has(chave):
			ent = tabela[chave]
		else:
			_escrever(st, ent)
			ent = c
			if int(st["livre"]) < 4096:
				tabela[chave] = int(st["livre"])
				st["livre"] = int(st["livre"]) + 1
			else:
				tabela.clear()
				st["livre"] = limpar + 2
				st["flag"] = true
				_escrever(st, limpar)
	_escrever(st, ent)
	_escrever(st, fim)
	var saida: PackedByteArray = st["out"]
	if int(st["cont"]) > 0:
		saida.append(int(st["acum"]) & 255)
	return saida
