extends RefCounted

# Cores e medidas do Ember Forja.

const FUNDO := Color("120e1f")
const PAINEL := Color("1f1835")
const PAINEL_CLARO := Color("2b2248")
const BORDA := Color("5a46a8")
const DESTAQUE := Color("ff7a1a")
const TEXTO := Color("f4eeff")
const SUAVE := Color("9d93b8")


# Tamanho de um botão de toque. Telas pequenas (alta densidade) ganham botões maiores
# em relação à tela; telas grandes ganham mais espaço para a arte.
static func unidade(tela: Vector2) -> float:
	var dpi: float = float(DisplayServer.screen_get_dpi())
	if dpi <= 0.0:
		dpi = 160.0
	var lado: float = minf(tela.x, tela.y)
	return clampf(minf(dpi * 0.28, lado / 6.5), 44.0, 120.0)


static func caixa(fundo: Color, borda: Color, raio: int = 12, larg: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fundo
	sb.border_color = borda
	sb.set_border_width_all(larg)
	sb.set_corner_radius_all(raio)
	return sb
