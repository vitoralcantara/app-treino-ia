# Contexto do Projeto: App de Treino IA

Este arquivo contém o histórico técnico e decisões de arquitetura para orientar o Gemini em novas sessões.

## Funcionalidades Principais Implementadas

1.  **Integração Nativa com Google Gemini:**
    *   Geração automática de treinos baseada em preferências do usuário e biblioteca de exercícios.
    *   **Seleção Dinâmica de Modelo:** O app consulta a API do Google para listar e usar sempre a versão "Flash" mais recente disponível para a API Key configurada.
    *   **Configurações de Segurança:** Filtros de segurança ajustados (`HarmBlockThreshold.none`) para evitar bloqueios falsos-positivos em conteúdos de atividade física.

2.  **Upload de Documentos:**
    *   Suporte para anexo de arquivos **PDF, Word (.docx), Excel (.xlsx) e Texto (.txt)** como contexto para a IA.
    *   Extração local de texto para arquivos Office e envio nativo (`DataPart`) para PDFs.

3.  **Gestão de Rotinas:**
    *   Sistema de importação inteligente: pergunta ao usuário se deseja **substituir a rotina atual** (arquivando a antiga) ou apenas **adicionar à lista** como inativa.
    *   Persistência segura da API Key usando `flutter_secure_storage`.

4.  **Experiência do Usuário (UX):**
    *   Melhorias no teclado iOS: fecha ao tocar fora, ao rolar a tela, ao clicar na seta de voltar ou ao usar o gesto de voltar do sistema.
    *   Feedback de carregamento ("Gerando...") com indicadores visuais durante chamadas à API.

## Arquitetura Técnica

*   **Linguagem/Framework:** Dart / Flutter.
*   **Gerência de Estado:** Riverpod 2.x (utilizando `NotifierProvider` para Settings e Providers globais).
*   **Banco de Dados:** SQLite (`sqflite`).
    *   **Versão Atual:** 12.
    *   **Tabela `exercises`:** Inclui colunas para `suggested_sets`, `suggested_reps` e `workout_specific_notes`.
*   **IA SDK:** `google_generative_ai` integrada ao `AiService`.

## Convenções de Código

*   Sempre utilizar `debugPrint` em vez de `print`.
*   Sempre verificar `if (mounted)` antes de interagir com o `BuildContext` após chamadas assíncronas.
*   Manter a `temperature: 0.2` nas configurações da IA para garantir que a resposta em JSON seja determinística e válida.

## Estado Atual
O projeto está estável, com as integrações de IA e banco de dados sincronizadas. A próxima etapa pode envolver refinamento da interface de histórico ou novas capacidades analíticas para os treinos salvos.
