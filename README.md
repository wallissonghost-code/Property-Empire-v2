# Mining Empire

Estado atual: **build mínimo criado do zero**, sem herdar nenhum `.rbxl` antigo.

## Arquivos ativos

- `scripts/current-place.rbxmk.lua` — cria um DataModel novo do zero.
- `scripts/prepare-place.sh` — gera `Mining-Empire.rbxl`.
- `.github/workflows/publish-roblox.yml` — audita o Universe/Place, publica via Open Cloud e solicita reinício dos servidores.
- `.deploy/last-publish.txt` — registra a última publicação aceita.
- `.deploy/roblox-diagnostics.txt` — registra a configuração retornada pelas APIs do Roblox.

## Roblox

- Universe: `10715548183`
- Root Place configurado: `138523274489009`
- Server size retornado pelo Cloud API: `50`

## Diagnóstico atual

O DataModel atual foi publicado com sucesso a partir de um arquivo novo. O Roblox Cloud API confirma que o Place configurado é o root do Universe.

A auditoria também encontrou que o Universe está com `visibility=PRIVATE`. A tentativa do workflow de ativá-lo pelo endpoint legado retornou `403 Forbidden`, indicando que a credencial atual não possui essa permissão específica.

Enquanto essa configuração de acesso não for alterada no Roblox, a experiência pode continuar presa em "Aguardando um servidor disponível" mesmo com um place válido.
