# Ember Forja

Editor de pixel art e criador de personagens para a engine **Ember** (iPhone e Android).

## O que já faz (v0.1)

- Desenhar: lápis, borracha, balde, conta-gotas, linha, retângulo (toque de novo para preencher), mão, espelho (simetria), grade, cebola (quadro anterior), pincel 1 a 4 px.
- Zoom e arrasto com dois dedos. Desfazer e refazer.
- Paleta com 30 cores, editor de cor por toque, cores novas.
- Sequências de quadros: adicionar, duplicar, apagar, mover, tocar a animação, fps.
- Tela limpa: só a arte e o olho para voltar.
- Personagem: 17 animações da engine + os 5 golpes base + golpes novos. Ficha do golpe (dano, início, ativo, recuperação, força, custo...) e hitbox desenhada em cima da arte.
- Exporta: PNG do quadro, PNG folha de sprites, GIF animado e `.ember` (o mesmo formato que a engine importa).
- Salva sozinho. Projetos ficam em `user://forja/`.

## Pés do sprite

A engine alinha o sprite pelo **centro da base da imagem** (os pés). A marca laranja na base da tela mostra esse ponto.

## Pastas

- `src/` scripts do app. `src/Formato.gd` é uma cópia do `engine/formato/Formato.gd` da engine: mantenha igual.
- `testes/` testes que rodam no GitHub Actions.
- `.github/workflows/` teste, Android e iOS.
