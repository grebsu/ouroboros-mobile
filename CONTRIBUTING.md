# Contribuindo para o Ouroboros Mobile

## Como contribuir
1. Fork o repositório
2. Crie um branch com `feature/` ou `fix/`
3. Siga as regras de análise estática (`flutter analyze`)
4. Escreva testes para novas funcionalidades
5. Envie um Pull Request para `main`

## Configuração do ambiente
- Flutter 3.24+
- SQLite (já incluso)
- Execute `flutter pub get` e `flutter gen-l10n` (se usar internacionalização)

## Estrutura do projeto (após refatoração)
```
lib/
├── core/           # serviços compartilhados (db, logger, cache)
├── features/       # features isoladas
│   ├── study/
│   ├── sync/
│   └── stats/
└── shared/         # widgets, utils, models
```

## Padrões de commit
Use [Conventional Commits](https://www.conventionalcommits.org/):
- `feat: adiciona sincronização Wi-Fi`
- `fix: corrige migração do banco v2->v3`
- `docs: atualiza README com badges`
- Ao contribuir, você concorda que seu código será licenciado sob a GPLv3.

## Direitos Autorais e Licenciamento

Todo o código contribuído será automaticamente licenciado sob a **GNU GPL v3**. Ao enviar um Pull Request, você confirma que tem o direito de licenciar seu trabalho sob essa licença.

## Testes
Execute `flutter test` antes de commitar. Cobertura mínima desejada: 70% para core/domain.

## Dúvidas?
Abra uma issue ou contate @grebsu.
