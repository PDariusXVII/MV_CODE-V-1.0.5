# Notas da refatoração

## Origem das decisões

A versão funcional fornecida já usava `flutter_code_editor` com `CodeController` e
`CodeField`. A versão quebrada havia substituído esse caminho por Monaco carregado em
uma WebView, com assets JavaScript e uma ponte assíncrona para abrir/salvar arquivos.

Nesta correção, o mecanismo do editor voltou ao padrão da versão funcional:

- editor de código renderizado diretamente por Flutter;
- `flutter_code_editor` 0.3.5;
- highlighting local por `highlight` / `flutter_highlight`;
- estado das abas mantido pelo `WorkspaceController`;
- SAF preservado para acesso seguro a pastas no Android;
- WebView restrita à pré-visualização HTML.

## O que foi removido

- `assets/editor/**` (bundle do Monaco);
- `monaco_editor_view.dart`;
- ponte JavaScript Flutter ↔ editor;
- plataforma Windows da versão desktop;
- caches de build e Kotlin;
- configuração de minimapa, específica do editor antigo.

## Erros atacados

- Travamento em "Preparando editor...": removido junto com o bootstrap do Monaco.
- Assertion `_dependents.isEmpty`: o editor deixa de reparentar/desativar a árvore de
  uma WebView e o bootstrap do app passa a executar `ensureInitialized` e `runApp`
  na mesma zona.
- Logs de cache incremental Kotlin: caches não são distribuídos e
  `kotlin.incremental=false` é mantido para a primeira reconstrução.
- Gradle 9.1 da versão quebrada: wrapper voltou a 8.14, igual ao projeto funcional.
