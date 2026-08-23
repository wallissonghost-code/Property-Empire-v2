# Mining Empire — base open-source

Este repositório foi substituído por uma base limpa usando o projeto open-source **Miner's Haven** de Andrew Bereza como ponto de partida técnico.

- Upstream: https://github.com/berezaa/minershaven
- Licença upstream: Apache License 2.0
- O nome e a marca **Miner's Haven** não devem ser usados comercialmente como identidade do nosso jogo.
- O jogo final deve usar identidade, nome, arte e conteúdo próprios.

O código upstream é incluído como submódulo em `minershaven/` e o arquivo `minershaven.rbxl` é publicado automaticamente no Place configurado pelo workflow.

## Deploy

Pushes em `main` com `[DEPLOY_ROBLOX]` no commit publicam `minershaven/minershaven.rbxl` via Roblox Open Cloud no Universe `10715548183`, Place `138523274489009`.

## Próxima etapa

Renomear, remover branding antigo, revisar monetização/DataStores remanescentes e adaptar a mineração para a identidade do novo jogo antes de lançamento público.
