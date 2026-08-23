# Mining Empire

Estado atual do repositório: **build estéril de diagnóstico** para Roblox.

O pipeline publica somente um place mínimo, sem sistemas antigos do jogo, usado para diagnosticar o problema de provisionamento/entrada de servidor.

## Arquivos ativos

- `scripts/sterile-place.rbxmk.lua` — gera o place mínimo atual.
- `scripts/prepare-place.sh` — prepara o arquivo `Mining-Empire.rbxl`.
- `.github/workflows/publish-roblox.yml` — publica via Roblox Open Cloud e reinicia os servidores do Universe.
- `.deploy/last-publish.txt` — registra a última publicação aceita.

## Roblox

- Universe: `10715548183`
- Place: `138523274489009`

Commits contendo `[DEPLOY_ROBLOX]` disparam a publicação automática.

## Base licenciada

O submódulo `minershaven/` permanece apenas como fonte licenciada de um DataModel de entrada para o `rbxmk`; o transformer atual remove todo o conteúdo do place antes de gerar o build estéril.

Upstream: `berezaa/minershaven`  
Revisão: `d5c8b41ca8ed9f1bd91176ec397e8dff9a259130`  
Licença: Apache License 2.0

Os avisos de terceiros permanecem em `THIRD_PARTY_NOTICES.md`.
