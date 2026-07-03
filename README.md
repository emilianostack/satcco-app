# SATCCO App

Aplicativo Flutter para gestão de avaliações. Professores criam formulários, atribuem-nos a turmas e geram QR Codes para que alunos respondam. O sistema calcula notas automaticamente.

O app consome a API própria [`sattco_api`](https://github.com/emilianostack/satcco_api/) (Node.js + Express + PostgreSQL, autenticação JWT) — não usa mais Firebase.

---

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Configuração do arquivo .env](#configuração-do-arquivo-env)
- [Rodando localmente](#rodando-localmente)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Telas e funcionalidades](#telas-e-funcionalidades)
- [Camada de acesso à API (`services/`)](#camada-de-acesso-à-api-services)

---

## Pré-requisitos

- Flutter SDK `^3.11.4`
- A API [`sattco_api`](https://github.com/emilianostack/satcco_api/)  rodando (local via Docker ou publicada) — veja o README dela para subir o backend e o Postgres.

---

## Configuração do arquivo .env

Na raiz do projeto (mesma pasta do `pubspec.yaml`), crie o arquivo `.env`:

```env
API_BASE_URL=http://SEU_IP_OU_HOST:3000/api/v1
```

- Em **emulador Android**, use `http://10.0.2.2:3000/api/v1` (alias especial para o `localhost` da máquina host).
- Em **simulador iOS** ou **macOS desktop**, `http://localhost:3000/api/v1` funciona diretamente.
- Em **dispositivo físico** (Android ou iOS), use o IP da máquina na rede local (ex.: `http://192.168.0.10:3000/api/v1`, obtido com `ipconfig getifaddr en0` no macOS) — o aparelho precisa estar na mesma rede Wi-Fi.

> O arquivo `.env` já está declarado em `pubspec.yaml` como asset:
>
> ```yaml
> flutter:
>   assets:
>     - .env
> ```
>
> Ele já está no `.gitignore` — nunca commite `.env` com URLs internas de produção.

Como a API roda em HTTP simples durante o desenvolvimento (sem HTTPS), o projeto já tem as exceções necessárias:

- **Android**: `android:usesCleartextTraffic="true"` em `AndroidManifest.xml`.
- **iOS**: `NSAppTransportSecurity` / `NSAllowsArbitraryLoads` em `Info.plist`.

---

## Rodando localmente

```bash
flutter pub get
flutter run
```

Para dispositivo físico, depois de trocar `API_BASE_URL` no `.env`, é preciso reiniciar o app por
completo (hot reload/restart não recarrega o `.env`, que é lido uma única vez no `main()`).

---

## Estrutura do projeto

```
lib/
├── main.dart                          # Entrada do app: lê token salvo, valida sessão, monta a árvore
├── login/
│   ├── auth_router.dart               # Redireciona para home do professor ou do aluno
│   ├── login_page.dart                # Tela de login
│   └── cadastro_page.dart             # Cadastro com verificação por e-mail (código de 6 dígitos)
├── professor/
│   ├── home_page.dart                 # Dashboard do professor
│   ├── perguntas_page.dart            # Banco de questões
│   ├── formularios_page.dart          # Listagem de formulários
│   ├── criar_formulario_page.dart     # Criação/edição de formulário
│   ├── turmas_page.dart               # Listagem de turmas
│   ├── turma_detail_page.dart         # Detalhe de turma (alunos, formulários, notas, PDF)
│   ├── qr_code_page.dart              # Geração e encerramento de sessão QR Code
│   ├── historico_page.dart            # Histórico consolidado de respostas
│   └── minhas_avaliacoes_page.dart    # Formulários que o professor foi convidado a responder
├── aluno/
│   ├── home_aluno_page.dart           # Dashboard do aluno (formulários pendentes/respondidos)
│   ├── scanner_page.dart              # Leitor de QR Code
│   └── responder_formulario_page.dart # Resposta ao formulário e exibição da nota
├── services/
│   ├── api_client.dart                # Cliente HTTP único: monta URL, injeta JWT, trata erros
│   ├── token_store.dart               # Persistência segura do JWT (flutter_secure_storage)
│   ├── auth_service.dart              # Login/cadastro/logout + stream de estado de autenticação
│   ├── usuario.dart                   # Modelo tipado do usuário autenticado
│   ├── route_observer.dart            # RouteObserver global — recarrega listas ao voltar de uma tela
│   ├── pdf_service.dart               # Geração de PDFs (relatório de notas)
│   └── api/                           # Um wrapper por recurso da API REST
│       ├── usuarios_api.dart
│       ├── turmas_api.dart
│       ├── perguntas_api.dart
│       ├── formularios_api.dart
│       ├── sessoes_api.dart
│       ├── respostas_api.dart
│       └── alunos_api.dart
└── widgets/
    ├── custom_button.dart             # Botão reutilizável com estado de carregamento
    ├── custom_textfield.dart          # Campo de texto reutilizável
    ├── empty_state.dart               # Placeholder para listas vazias
    └── question_type_icon.dart        # Ícone colorido por tipo de questão
```

---

## Telas e funcionalidades

### Fluxo de autenticação

| Tela     | Arquivo              | Descrição                                                                                                 |
| -------- | --------------------- | --------------------------------------------------------------------------------------------------------- |
| Login    | `login_page.dart`     | E-mail e senha, autentica via `POST /auth/login`.                                                          |
| Cadastro | `cadastro_page.dart`  | Registro de professor ou aluno. Envia um código de 6 dígitos por e-mail (`POST /auth/solicitar-codigo`), o usuário confirma (`POST /auth/verificar-codigo`) e só então a conta é criada (`POST /auth/registro`). |
| Roteador | `auth_router.dart`    | Após login, direciona para a home do `professor` ou do `aluno` conforme o campo `tipo` já embutido no usuário retornado pela API. |

---

### Área do Professor

#### Home do Professor (`home_page.dart`)

Dashboard com atalhos para: **Formulários**, **Histórico**, **Alunos** (turmas), **Banco de Questões** e **Minhas Avaliações** (formulários de turmas onde o professor foi convidado a participar como respondente).

#### Banco de Questões (`perguntas_page.dart`)

Biblioteca de perguntas pertencentes ao professor. Cada pergunta tem um título e um dos cinco tipos:

| Tipo               | Descrição                                                         |
| ------------------- | ------------------------------------------------------------------ |
| `escala`            | Escala numérica de 0 a 10.                                        |
| `sim_nao`           | Botões Sim / Não com resposta correta configurável.               |
| `verdadeiro_falso`  | Botões Verdadeiro / Falso com resposta correta configurável.      |
| `multipla_escolha`  | Até 10 opções com uma opção correta marcada.                      |
| `texto`             | Resposta textual livre (não entra no cálculo automático de nota). |

Ações disponíveis: criar, editar e remover perguntas. A remoção é bloqueada se a pergunta estiver vinculada a um formulário.

#### Formulários (`formularios_page.dart` e `criar_formulario_page.dart`)

Permite criar e editar formulários de avaliação compostos por perguntas do banco de questões. Na criação/edição:

- Seleciona as perguntas desejadas.
- Define o **peso** de cada pergunta (inteiro ≥ 0).
- **Reordena** as perguntas por arrastar e soltar.

Ao salvar, o backend congela (snapshot) o título/tipo/opções de cada pergunta selecionada — editar a pergunta original depois não altera formulários já montados. Um formulário não pode ser removido se algum aluno já o respondeu.

#### QR Code de Sessão (`qr_code_page.dart`)

O professor gera um QR Code para uma sessão de avaliação. O aluno escaneia o código para acessar o formulário sem precisar navegar pelo app. A sessão pode ser encerrada manualmente; novas sessões podem ser criadas para o mesmo formulário.

#### Turmas (`turmas_page.dart` e `turma_detail_page.dart`)

Gerenciamento de turmas com três abas:

- **Alunos** — convida alunos por e-mail (o backend envia o convite e resolve automaticamente se já existe conta), ativa/desativa participantes e remove membros. Também permite convidar outros professores para colaborar na turma.
- **Formulários** — atribui formulários à turma, gera QR Codes de sessão e exporta relatório de notas em PDF (download ou compartilhamento nativo).
- **Notas** — exibe as notas de cada aluno (e de professores convidados que também responderam) por formulário, com nome, e-mail e nota calculada pelo servidor.

A exclusão de uma turma é bloqueada se algum aluno já respondeu a um formulário atribuído a ela.

#### Histórico / Notas (`historico_page.dart`)

Visão consolidada de todas as respostas recebidas, agrupadas por formulário, com nome do respondente, data e nota calculada (colorida: verde ≥ 7, laranja ≥ 5, vermelho < 5).

#### Minhas Avaliações (`minhas_avaliacoes_page.dart`)

Lista os formulários das turmas onde o professor foi convidado como participante (não dono), separados em abas **Pendentes** / **Respondidos** — o mesmo fluxo de resposta usado pelo aluno.

---

### Área do Aluno

#### Home do Aluno (`home_aluno_page.dart`)

Exibe as turmas às quais o aluno pertence, com duas abas:

- **Pendentes** — formulários ainda não respondidos, agrupados por turma.
- **Respondidos** — formulários já respondidos com a nota obtida.

Ao voltar de responder um formulário (via QR ou direto na lista), a aba muda automaticamente para "Respondidos". O botão de QR Code no cabeçalho abre diretamente o leitor de câmera.

#### Escanear QR Code (`scanner_page.dart`)

Abre a câmera para escanear o QR Code gerado pelo professor. Valida se a sessão está ativa (`GET /sessoes-qrcode/:token`, público) e abre o formulário correspondente.

#### Responder Formulário (`responder_formulario_page.dart`)

Exibe as perguntas do formulário sequencialmente. A origem dos dados depende do contexto:

- **Via QR Code** (`sessaoToken` presente): usa a consulta pública da sessão, que já retorna formulário + perguntas — não exige o respondente ser dono do formulário.
- **Acesso direto** (lista do aluno ou "Minhas Avaliações"): usa `GET /formularios/:id/responder`, liberado para qualquer usuário autenticado com acesso ao formulário (aluno matriculado numa turma onde ele foi atribuído, professor convidado, ou o próprio dono testando).

Ao submeter (`POST /respostas`), o **backend** calcula a nota (com base nos pesos e nas respostas corretas do snapshot congelado) e a devolve na resposta — o app não recalcula nada localmente, exceto no "Modo Teste" (pré-visualização do professor, que nunca persiste no servidor).

---

## Camada de acesso à API (`services/`)

| Arquivo                 | Responsabilidade                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------ |
| `api_client.dart`        | Único ponto que conhece a URL base e o formato de erro da API (`{error}`) — todo o resto passa por ele. |
| `token_store.dart`       | Salva/lê/limpa o JWT entre execuções do app (`flutter_secure_storage`).                               |
| `auth_service.dart`      | Login, cadastro (com código de verificação), logout e `Stream<Usuario?>` de estado de autenticação.   |
| `route_observer.dart`    | `RouteObserver` global registrado no `MaterialApp` — telas de lista se inscrevem nele para recarregar automaticamente sempre que voltam a ficar visíveis, mesmo quando a tela filha usa `pushReplacement`/`popUntil`. |
| `pdf_service.dart`       | Geração de PDFs: relatório de notas da turma e comprovante individual, usando o pacote `printing`.     |
| `api/*.dart`             | Um wrapper por recurso (`turmas_api.dart`, `perguntas_api.dart`, etc.) — cada método retorna `Map`/`List<Map>` no mesmo formato JSON devolvido pela API, sem camada de modelo intermediária. |

Cada tela de lista guarda um contador de "geração" de requisição (`_reqGen`) para descartar
respostas de rede que cheguem fora de ordem (ex.: um GET disparado antes de uma exclusão que
demora mais para responder que um GET disparado depois) — sem isso, dados desatualizados podem
sobrescrever o resultado de uma ação mais recente.

---

## Imagens:

## Professor:
<p align="center">
  <img src="https://github.com/user-attachments/assets/2c476971-a60f-4212-9568-0eee6e890149" width="250"/>
  <img src="https://github.com/user-attachments/assets/2b4d39d8-daaa-4dfd-8ef8-7e3f8a936a5e" width="250"/>
  <img src="https://github.com/user-attachments/assets/7d8a2263-0f2d-40f7-ac84-2a95a6783087" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/f9ce83df-a7f8-4d0c-8254-633361aea3f1" width="250"/>
  <img src="https://github.com/user-attachments/assets/5853799c-bd25-42af-9b9f-3d65879c8ca2" width="250"/>
  <img src="https://github.com/user-attachments/assets/d5c38261-2a7f-4214-a0a8-03558863f5ba" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/bd5adf95-9d34-4b24-995e-4dbeccb936d2" width="250"/>
  <img src="https://github.com/user-attachments/assets/08f72555-ad9e-4335-8725-41699800545a" width="250"/>
  <img src="https://github.com/user-attachments/assets/6d076a69-7c43-4cae-a76e-50057ba26296" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/f46e7df0-8656-4711-b539-4500c1cc8f30" width="250"/>
  <img src="https://github.com/user-attachments/assets/6b702391-895c-4c37-a6e6-bac99ff7b7e2" width="250"/>
  <img src="https://github.com/user-attachments/assets/667622cd-1213-43ff-a760-5491b7e87ab5" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/804c19b0-1cd8-4e8b-ab47-37b5026fecbd" width="250"/>
  <img src="https://github.com/user-attachments/assets/536149f5-4788-4429-970d-bb1bb0cef630" width="250"/>
  <img src="https://github.com/user-attachments/assets/6b0e5bd0-61a8-4a75-a177-cde83e40d756" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/ecefb8d6-9c8a-4b66-8443-0dbe4eb47fb2" width="250"/>
  <img src="https://github.com/user-attachments/assets/3d0c4568-d746-457c-8a35-b27286953133" width="250"/>
  <img src="https://github.com/user-attachments/assets/2b34a04f-4b1d-493a-9770-5d28b1dcdd5c" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/2f940eaa-5ba8-4d9b-9d5a-7b4245942c03" width="250"/>
  <img src="https://github.com/user-attachments/assets/54802aac-04dd-47a1-b6f3-abfe8057ffc8" width="250"/>
  <img src="https://github.com/user-attachments/assets/283df4ed-56eb-49ab-9653-8e03fba50057" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/6f6f1633-60ef-4500-8884-ea1461800c5a" width="250"/>
  <img src="https://github.com/user-attachments/assets/b27f2a92-c3e8-4db4-b415-971743f71f0c" width="250"/>
  <img src="https://github.com/user-attachments/assets/ade0cb75-260b-4d46-85df-d83e0b9424a4" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/a522c690-b08e-4d09-8d5f-ec7b9a02ec85" width="250"/>
  <img src="https://github.com/user-attachments/assets/b095b55f-70c4-4ed9-8b49-ec106a254b02" width="250"/>
</p>


---


## Aluno:
<p align="center">
  <img src="https://github.com/user-attachments/assets/92f536f1-706f-486d-9e11-d52e789526a7" width="250"/>
  <img src="https://github.com/user-attachments/assets/1cc04991-696d-4a79-9b5a-b0684b25baa6" width="250"/>
  <img src="https://github.com/user-attachments/assets/804eed03-e427-4845-bc1b-cf21867082fd" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/c8aa582d-c60a-4557-b79e-5cb22e4c4bc4" width="250"/>
  <img src="https://github.com/user-attachments/assets/81807432-097d-49e3-8650-edd2474acd8a" width="250"/>
  <img src="https://github.com/user-attachments/assets/da6dde5e-0d4b-48f8-b2b0-1c351cdf1187" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/faa1aff3-a52e-4433-87a4-393ae073077a" width="250"/>
</p>

## Professor:
<p align="center">
  <img src="https://github.com/user-attachments/assets/707d1391-5d74-43da-bec4-f2633e83ae78" width="250"/>
  <img src="https://github.com/user-attachments/assets/a301d6b3-3219-406c-903a-cc6762d16960" width="250"/>
  <img src="https://github.com/user-attachments/assets/21abda2f-a85a-4151-85ce-88a8405bf37e" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/45a0bc82-e2e1-4faa-997d-8cf1b5743d12" width="250"/>
  <img src="https://github.com/user-attachments/assets/8ada44fe-fd21-45a1-b64d-29b9a4cc857c" width="250"/>
  <img src="https://github.com/user-attachments/assets/547998d1-d874-41be-84ca-a58c7c22eb51" width="250"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/99f0e36e-7a2d-4967-87b7-266a3bfc885b" width="250"/>
  <img src="https://github.com/user-attachments/assets/4c919582-02da-43b5-9ac2-d1e9a31b2fb6" width="250"/>
  <img src="https://github.com/user-attachments/assets/1962ab1d-4f42-4b46-91f6-041b423defc7" width="250"/>
  <img src="https://github.com/user-attachments/assets/37346003-4b77-4915-933b-b3df51171694" width="250" />

</p>
