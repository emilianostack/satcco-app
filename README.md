# SATCCO App

Aplicativo Flutter para gestão de avaliações. Professores criam formulários, atribuem-nos a turmas e geram QR Codes para que alunos respondam. O sistema calcula notas automaticamente.

---

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Configuração do Firebase](#configuração-do-firebase)
- [Configuração do Gmail (SMTP) e arquivo .env](#configuração-do-gmail-smtp-e-arquivo-env)
- [Estrutura do projeto](#estrutura-do-projeto)
- [Telas e funcionalidades](#telas-e-funcionalidades)
- [Serviços e banco de dados](#serviços-e-banco-de-dados)
- [Armazenamento de dados (Firestore)](#armazenamento-de-dados-firestore)

---

## Pré-requisitos

- Flutter SDK `^3.11.4`
- Conta no [Firebase Console](https://console.firebase.google.com)
- Conta Gmail com verificação em duas etapas ativada (para SMTP)

---

## Configuração do Firebase

### 1. Criar o projeto no Firebase Console

1. Acesse o [Firebase Console](https://console.firebase.google.com) e clique em **Adicionar projeto**.
2. Ative o **Firebase Authentication** → método de login **E-mail/senha**.
3. Ative o **Cloud Firestore** → modo de produção (ajuste as regras conforme necessário).

Após criar o projeto e adicionar os dois aplicativos (Android e iOS), a seção **Seus aplicativos** no Firebase Console deve estar assim:

<img width="606" height="444" alt="image" src="https://github.com/user-attachments/assets/d37df53d-4f17-418c-8d6e-3f2085394873" />
[Aplicativos configurados no Firebase Console]

### 2. Gerar o arquivo de configuração para Android

1. No console do Firebase, acesse **Configurações do projeto → Seus aplicativos → Adicionar aplicativo → Android**.
2. Informe o nome do pacote (encontrado em `android/app/build.gradle`, campo `applicationId`).
3. Faça o download do arquivo `google-services.json`.
4. Coloque-o em `android/app/google-services.json`.
5. Verifique se `android/build.gradle` contém o plugin:
   ```groovy
   classpath 'com.google.gms:google-services:4.x.x'
   ```
6. Verifique se `android/app/build.gradle` aplica o plugin no final:
   ```groovy
   apply plugin: 'com.google.gms.google-services'
   ```

### 3. Gerar o arquivo de configuração para iOS

1. No console do Firebase, acesse **Configurações do projeto → Seus aplicativos → Adicionar aplicativo → iOS**.
2. Informe o Bundle ID (encontrado em Xcode → pasta `Runner` → campo `Bundle Identifier`).
3. Faça o download do arquivo `GoogleService-Info.plist`.
4. Abra o projeto iOS no Xcode (`ios/Runner.xcworkspace`) e arraste o arquivo `GoogleService-Info.plist` para dentro da pasta `Runner` (marque a opção **Copy items if needed**).
5. Execute `cd ios && pod install` para atualizar os pods do Firebase.

> **Atenção:** nunca commite `google-services.json` ou `GoogleService-Info.plist` em repositórios públicos — eles contêm chaves de API.

---

## Configuração do Gmail (SMTP) e arquivo .env

O aplicativo usa SMTP do Gmail via pacote `mailer` para enviar:

- Códigos de verificação de cadastro (6 dígitos, válidos por 10 minutos).
- Comprovantes de avaliação em PDF para o e-mail do aluno.
- Relatórios de notas em PDF para o e-mail do professor.

### 1. Criar uma Senha de App no Gmail

> Requer verificação em duas etapas ativada na conta Google.

1. Acesse [myaccount.google.com/security](https://myaccount.google.com/security).
2. Em **Como você faz login no Google**, clique em **Verificação em duas etapas**.
3. Role até o final da página e clique em **Senhas de app**.
4. Selecione o aplicativo **Outro (nome personalizado)**, digite `SATCCO App` e clique em **Gerar**.
5. Copie a senha de 16 caracteres exibida.

### 2. Criar o arquivo `.env`

Na raiz do projeto (mesma pasta do `pubspec.yaml`), crie o arquivo `.env`:

```env
SMTP_EMAIL=seu-email@gmail.com
SMTP_PASSWORD=xxxx xxxx xxxx xxxx
```

- `SMTP_EMAIL`: o endereço Gmail usado para enviar os e-mails.
- `SMTP_PASSWORD`: a senha de app gerada no passo anterior (com ou sem espaços).

> O arquivo `.env` já está declarado em `pubspec.yaml` como asset:
>
> ```yaml
> flutter:
>   assets:
>     - .env
> ```
>
> Adicione `.env` ao `.gitignore` para não expor credenciais.

---

## Estrutura do projeto

```
lib/
├── main.dart                          # Entrada do app, inicialização Firebase + dotenv
├── login/
│   ├── auth_router.dart               # Redireciona para home do professor ou do aluno
│   ├── login_page.dart                # Tela de login
│   └── cadastro_page.dart             # Cadastro com verificação por e-mail
├── professor/
│   ├── home_page.dart                 # Dashboard do professor
│   ├── perguntas_page.dart            # Banco de questões
│   ├── formularios_page.dart          # Listagem de formulários
│   ├── criar_formulario_page.dart     # Criação/edição de formulário
│   ├── turmas_page.dart               # Listagem de turmas
│   ├── turma_detail_page.dart         # Detalhe de turma (alunos, formulários, notas)
│   ├── qr_code_page.dart              # Geração e encerramento de sessão QR Code
│   └── historico_page.dart            # Histórico consolidado de respostas
├── aluno/
│   ├── home_aluno_page.dart           # Dashboard do aluno (formulários pendentes/respondidos)
│   ├── scanner_page.dart              # Leitor de QR Code
│   └── responder_formulario_page.dart # Resposta ao formulário e exibição da nota
├── services/
│   ├── auth_service.dart              # Wrapper do Firebase Authentication
│   ├── pdf_service.dart               # Geração de PDFs (notas)
│   ├── email/
│   │   └── email_service.dart         # Envio de e-mails via SMTP
│   └── database/
│       ├── usuarios_db.dart           # Coleção usuarios + processamento de convites
│       ├── turmas_db.dart             # Coleção turmas + subcoleções alunos e formulários
│       ├── formularios_db.dart        # Coleção formularios + subcoleção perguntas
│       ├── perguntas_db.dart          # Coleção perguntas (banco de questões)
│       ├── respostas_db.dart          # Coleção respostas
│       ├── sessoes_db.dart            # Coleção sessoes_qrcode
│       └── codigos_db.dart            # Coleção codigos_verificacao
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
| -------- | -------------------- | --------------------------------------------------------------------------------------------------------- |
| Login    | `login_page.dart`    | E-mail e senha via Firebase Auth.                                                                         |
| Cadastro | `cadastro_page.dart` | Registro de professor ou aluno. Envia código de verificação por e-mail antes de criar a conta.            |
| Roteador | `auth_router.dart`   | Após login, verifica o tipo do usuário (`professor` ou `aluno`) e redireciona para a home correspondente. |

---

### Área do Professor

#### Home do Professor (`home_page.dart`)

Dashboard com quatro atalhos em grade:

- **Formulários** — gerencia avaliações.
- **Histórico** — visualiza notas por formulário.
- **Alunos** — gerencia turmas.
- **Banco de Questões** — biblioteca de perguntas reutilizáveis.

#### Banco de Questões (`perguntas_page.dart`)

Biblioteca de perguntas pertencentes ao professor. Cada pergunta tem um título e um dos cinco tipos:

| Tipo               | Descrição                                                         |
| ------------------ | ----------------------------------------------------------------- |
| `escala`           | Escala numérica de 0 a 10.                                        |
| `sim_nao`          | Botões Sim / Não com resposta correta configurável.               |
| `verdadeiro_falso` | Botões Verdadeiro / Falso com resposta correta configurável.      |
| `multipla_escolha` | Até 10 opções com uma opção correta marcada.                      |
| `texto`            | Resposta textual livre (não entra no cálculo automático de nota). |

Ações disponíveis: criar, editar e remover perguntas. A remoção é bloqueada se a pergunta estiver vinculada a um formulário com respostas de alunos.

#### Formulários (`formularios_page.dart` e `criar_formulario_page.dart`)

Permite criar e editar formulários de avaliação compostos por perguntas do banco de questões. Na criação/edição:

- Seleciona as perguntas desejadas.
- Define o **peso** de cada pergunta (inteiro ≥ 0).
- **Reordena** as perguntas por arrastar e soltar.

Um formulário não pode ser removido se algum aluno já o respondeu.

#### QR Code de Sessão (`qr_code_page.dart`)

O professor gera um QR Code para uma sessão de avaliação. O aluno escaneia o código para acessar o formulário. A sessão pode ser encerrada manualmente; novas sessões podem ser criadas para o mesmo formulário.

#### Turmas (`turmas_page.dart` e `turma_detail_page.dart`)

Gerenciamento de turmas com três abas:

- **Alunos** — convida alunos por e-mail, ativa/desativa participantes e remove membros.
- **Formulários** — atribui formulários à turma, gera QR Codes de sessão e exporta relatório de notas em PDF (download ou envio por e-mail ao professor).
- **Notas** — exibe as notas de cada aluno por formulário em cards expansíveis, com nome, e-mail e nota calculada.

A exclusão de uma turma é bloqueada se algum aluno já respondeu a um formulário atribuído a ela.

#### Histórico / Notas (`historico_page.dart`)

Visão consolidada de todas as respostas recebidas, agrupadas por formulário, com nome do aluno, data de resposta e nota calculada (colorida: verde ≥ 7, laranja ≥ 5, vermelho < 5).

---

### Área do Aluno

#### Home do Aluno (`home_aluno_page.dart`)

Exibe as turmas às quais o aluno pertence. A tela possui duas abas:

- **Pendentes** — formulários ainda não respondidos, agrupados por turma.
- **Respondidos** — formulários já respondidos com a nota obtida.

O botão de QR Code no cabeçalho abre diretamente o leitor de câmera.

#### Escanear QR Code (`scanner_page.dart`)

Abre a câmera para escanear o QR Code gerado pelo professor. Valida se a sessão está ativa e redireciona para o formulário correspondente.

#### Responder Formulário (`responder_formulario_page.dart`)

Exibe as perguntas do formulário sequencialmente. Ao submeter:

- Calcula a nota automaticamente com base nos pesos e nas respostas corretas.
- Armazena a resposta com ID determinístico (`{formularioId}_{alunoId}`) para evitar duplicatas.
- Exibe a nota e oferece opção de enviar comprovante em PDF para o e-mail do aluno.

**Lógica de cálculo da nota:**

| Tipo da pergunta                          | Pontuação                                          |
| ----------------------------------------- | -------------------------------------------------- |
| `escala`                                  | `(valor / 10) × peso`                              |
| `sim_nao`, `verdadeiro_falso`, `multipla_escolha` | `peso × 10` se correta, `0` se incorreta |
| `texto`                                   | Não entra no cálculo.                              |

Nota final = `(pontos obtidos / pontos possíveis) × 10`, limitada a 10,0. Se o formulário contiver apenas perguntas do tipo `texto`, a nota fica como `null`.

---

## Serviços e banco de dados

### Serviços

| Arquivo                          | Responsabilidade                                                                   |
| -------------------------------- | ---------------------------------------------------------------------------------- |
| `auth_service.dart`              | Wrapper do Firebase Auth (login, cadastro, logout, stream de estado).              |
| `email_service.dart`             | Envio de e-mails via SMTP Gmail: código de verificação, comprovante PDF e relatório de notas PDF. |
| `pdf_service.dart`               | Geração de PDFs: relatório de notas da turma (professor) e comprovante do aluno.   |

### Camada de banco de dados (`services/database/`)

| Arquivo              | Coleção Firestore principal      | Principais operações                                         |
| -------------------- | -------------------------------- | ------------------------------------------------------------ |
| `usuarios_db.dart`   | `usuarios`                       | CRUD de perfil, busca por e-mail, processamento de convites. |
| `turmas_db.dart`     | `turmas` + subcoleções           | CRUD de turmas, gestão de alunos e formulários atribuídos.   |
| `formularios_db.dart`| `formularios` + subcoleção perguntas | CRUD de formulários, batch write de perguntas com ordem.  |
| `perguntas_db.dart`  | `perguntas`                      | CRUD do banco de questões do professor.                      |
| `respostas_db.dart`  | `respostas`                      | Submissão e consulta de respostas (batch por lista de IDs).  |
| `sessoes_db.dart`    | `sessoes_qrcode`                 | Criar e encerrar sessões de QR Code.                         |
| `codigos_db.dart`    | `codigos_verificacao`            | Salvar, verificar e remover códigos de verificação por e-mail (TTL 10 min). |

---

## Armazenamento de dados (Firestore)

### Coleções principais

#### `usuarios/{uid}`

Documento criado no cadastro para cada usuário.

| Campo       | Tipo            | Descrição                                                 |
| ----------- | --------------- | --------------------------------------------------------- |
| `nome`      | string          | Nome completo.                                            |
| `email`     | string          | E-mail de login.                                          |
| `tipo`      | string          | `'professor'` ou `'aluno'`.                               |
| `turmas`    | array\<string\> | IDs das turmas às quais o aluno pertence (apenas alunos). |
| `criado_em` | timestamp       | Data de criação.                                          |

---

#### `convites/{email}`

Convite pendente para alunos que ainda não possuem conta.

| Campo       | Tipo            | Descrição                                           |
| ----------- | --------------- | --------------------------------------------------- |
| `turma_ids` | array\<string\> | IDs das turmas para as quais o aluno foi convidado. |

Ao concluir o cadastro ou o login, o sistema processa e remove o convite automaticamente.

---

#### `turmas/{turmaId}`

Representa uma turma criada por um professor.

| Campo          | Tipo      | Descrição                      |
| -------------- | --------- | ------------------------------ |
| `nome`         | string    | Nome da turma.                 |
| `professor_id` | string    | UID do professor proprietário. |
| `criado_em`    | timestamp | Data de criação.               |

**Subcoleção `turmas/{turmaId}/alunos/{email}`**

| Campo          | Tipo         | Descrição                                                 |
| -------------- | ------------ | --------------------------------------------------------- |
| `email`        | string       | E-mail do aluno (também é o ID do documento).             |
| `aluno_id`     | string\|null | UID do aluno (null se ainda não tem conta).               |
| `nome`         | string\|null | Nome do aluno (preenchido após cadastro).                 |
| `ativo`        | bool         | Se o aluno está ativo na turma.                           |
| `convidado_em` | timestamp    | Data do convite.                                          |

**Subcoleção `turmas/{turmaId}/formularios/{formularioId}`**

| Campo          | Tipo      | Descrição                       |
| -------------- | --------- | ------------------------------- |
| `titulo`       | string    | Título do formulário atribuído. |
| `atribuido_em` | timestamp | Data da atribuição.             |

---

#### `perguntas/{perguntaId}`

Banco de questões — cada pergunta pertence a um professor.

| Campo              | Tipo            | Descrição                                                               |
| ------------------ | --------------- | ----------------------------------------------------------------------- |
| `titulo`           | string          | Enunciado da pergunta.                                                  |
| `tipo`             | string          | `escala`, `sim_nao`, `verdadeiro_falso`, `multipla_escolha` ou `texto`. |
| `professor_id`     | string          | UID do professor.                                                       |
| `criado_em`        | timestamp       | Data de criação.                                                        |
| `opcoes`           | array\<string\> | Opções de resposta (apenas `multipla_escolha`).                         |
| `opcao_correta`    | number          | Índice da opção correta (apenas `multipla_escolha`).                    |
| `resposta_correta` | string          | `'sim'`/`'nao'` ou `'verdadeiro'`/`'falso'` (conforme o tipo).          |

---

#### `formularios/{formularioId}`

Formulário de avaliação composto por perguntas do banco de questões.

| Campo             | Tipo      | Descrição                           |
| ----------------- | --------- | ----------------------------------- |
| `titulo`          | string    | Título do formulário.               |
| `professor_id`    | string    | UID do professor proprietário.      |
| `total_perguntas` | number    | Quantidade de perguntas vinculadas. |
| `criado_em`       | timestamp | Data de criação.                    |

**Subcoleção `formularios/{formularioId}/perguntas/{perguntaId}`**

Snapshot das perguntas no momento da composição do formulário (dados desnormalizados para que a resposta funcione mesmo se a pergunta original for editada).

| Campo              | Tipo            | Descrição                                            |
| ------------------ | --------------- | ---------------------------------------------------- |
| `pergunta_id`      | string          | Referência ao documento em `perguntas/`.             |
| `titulo`           | string          | Enunciado copiado no momento da composição.          |
| `tipo`             | string          | Tipo da pergunta.                                    |
| `peso`             | number          | Peso da pergunta no cálculo da nota (inteiro ≥ 0).   |
| `ordem`            | number          | Posição da pergunta no formulário (0-based).         |
| `opcoes`           | array\<string\> | Opções (apenas `multipla_escolha`).                  |
| `opcao_correta`    | number          | Índice da opção correta (apenas `multipla_escolha`). |
| `resposta_correta` | string          | Resposta correta (`sim_nao` / `verdadeiro_falso`).   |

---

#### `respostas/{formularioId_alunoId}`

Resposta de um aluno a um formulário. O ID do documento é determinístico (`{formularioId}_{alunoId}`) para garantir unicidade e evitar duplicatas.

| Campo           | Tipo         | Descrição                                                    |
| --------------- | ------------ | ------------------------------------------------------------ |
| `formulario_id` | string       | ID do formulário respondido.                                 |
| `sessao_id`     | string\|null | ID da sessão QR Code (null se acesso direto).                |
| `aluno_id`      | string       | UID do aluno.                                                |
| `aluno_nome`    | string       | Nome do aluno no momento da resposta.                        |
| `aluno_email`   | string\|null | E-mail do aluno.                                             |
| `respostas`     | array\<map\> | Lista de respostas por pergunta (ver abaixo).                |
| `nota`          | number\|null | Nota calculada de 0 a 10 (null se só há perguntas de texto). |
| `respondido_em` | timestamp    | Data e hora da submissão.                                    |

Cada item do array `respostas`:

| Campo         | Tipo       | Descrição                                                  |
| ------------- | ---------- | ---------------------------------------------------------- |
| `pergunta_id` | string     | ID da pergunta.                                            |
| `tipo`        | string     | Tipo da pergunta.                                          |
| `resposta`    | dynamic    | Valor respondido pelo aluno.                               |
| `correta`     | bool\|null | Se a resposta está correta (null para `texto` e `escala`). |
| `peso`        | number     | Peso usado no cálculo.                                     |

---

#### `sessoes_qrcode/{sessaoId}`

Representa uma sessão de aplicação de formulário via QR Code.

| Campo           | Tipo         | Descrição                   |
| --------------- | ------------ | --------------------------- |
| `formulario_id` | string       | ID do formulário associado. |
| `turma_id`      | string\|null | ID da turma (opcional).     |
| `status`        | string       | `'ativa'` ou `'encerrada'`. |
| `criado_em`     | timestamp    | Data de criação da sessão.  |

---

#### `codigos_verificacao/{email}`

Código temporário enviado por e-mail para verificação no cadastro.

| Campo       | Tipo   | Descrição                                      |
| ----------- | ------ | ---------------------------------------------- |
| `email`     | string | E-mail do destinatário.                        |
| `codigo`    | string | Código de 6 dígitos.                           |
| `expira_em` | number | Timestamp Unix (ms) de expiração (10 minutos). |

O documento é removido imediatamente após o cadastro ser concluído com sucesso.
