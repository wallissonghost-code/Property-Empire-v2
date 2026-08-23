# Mining Empire

Base de desenvolvimento Roblox para **Mining Empire**.

O projeto usa como fundação técnica o código open-source de **Miner's Haven**, criado por Andrew Bereza e distribuído sob **Apache License 2.0**.

## Identidade do jogo

- Nome do projeto: **Mining Empire**
- A marca `Miner's Haven` não faz parte da identidade comercial deste jogo.
- Todo conteúdo novo, interface, progressão, monetização, museu e direção visual serão próprios do Mining Empire.

## Base técnica licenciada

- Upstream: https://github.com/berezaa/minershaven
- Revisão fixada: `d5c8b41ca8ed9f1bd91176ec397e8dff9a259130`
- Licença: Apache License 2.0
- Créditos e avisos de terceiros devem ser preservados conforme a licença.

O upstream permanece isolado no submódulo `minershaven/`. Isso permite manter a origem auditável e evita misturar código de terceiros com as nossas alterações.

## Roblox

Deploy configurado para:

- Universe: `10715548183`
- Place: `138523274489009`

Commits em `main` contendo `[DEPLOY_ROBLOX]` publicam a base no Roblox via Open Cloud.

## Fase atual

A base original está instalada e publicada. A partir deste ponto a customização será feita em camadas próprias do Mining Empire, priorizando:

1. remoção/substituição de branding antigo;
2. auditoria de DataStores, monetização e serviços externos;
3. mineração e progressão próprias;
4. integração do museu;
5. UI mobile própria;
6. balanceamento e otimização.

Veja `CUSTOMIZATION_PLAN.md` e `THIRD_PARTY_NOTICES.md`.
