# Comunhao

Base inicial da Comunhao, uma plataforma digital white-label para igrejas com foco em receita recorrente.

## Objetivo

Construir um MVP com foco em:

- doacoes e dizimos digitais
- eventos e anuncios
- pedidos de oracao
- notificacoes push
- painel administrativo simples

## Fluxo atual do utilizador

O onboarding agora segue o modelo multi-igreja da Comunhao:

1. o utilizador abre a app
2. escolhe a igreja por pesquisa, QR Code ou codigo
3. cria conta com nome, telefone, palavra-passe e data de nascimento opcional
4. confirma o numero por OTP de SMS
5. entra diretamente como `Membro`

O login usa apenas:

- numero de telefone
- palavra-passe

Nao existe aprovacao manual depois do registo.

## Estrutura

- `lib/` app Flutter
- `docs/mvp-igreja-digital.md`
- `docs/flutter-implementation-plan.md`
- `supabase/schema.sql`

## Decisao de produto

O MVP nao tenta competir com Tithely, Subsplash ou Planning Center em tudo.
Ele comeca pela dor mais facil de vender:

1. receber ofertas e dizimos no telemovel
2. comunicar eventos e avisos
3. organizar pedidos de oracao e membros

## Modelo de negocio inicial

- Setup: 10.000 a 35.000 MZN por igreja
- Mensalidade: 1.500 a 6.000 MZN por igreja
- Taxa opcional sobre pagamentos: 1% a 3%

## Modelo da marca

- `Comunhao` e a plataforma principal
- cada igreja pode aparecer como app personalizado, por exemplo `Igreja Vida Nova App`
- a mesma base serve varias igrejas, mudando branding, contactos e configuracoes

## Como visualizar

Para abrir a demo no navegador:

```powershell
flutter run -d chrome
```

Para abrir a demo no desktop Windows:

```powershell
flutter run -d windows
```

No VS Code, tambem podes abrir a pasta e pressionar `F5`.

## Supabase

A app ja esta ligada ao backend central DeliGo Platform.

- URL do projeto: `https://tpmsgvkdjzoidvyiwwfk.supabase.co`
- schema: `comunhao`
- igreja demo publica: `Igreja Vida Nova`
- codigo de entrada demo: `VIDA123`
- seed remoto criado com anuncios, eventos, campanhas e canais como `M-Pesa` e `e-Mola`

O projeto remoto ja tem:

- `join_code` por igreja
- `profiles.phone` unico
- `birth_date` opcional para recuperacao de conta
- trigger para criar `profiles` e `memberships` automaticamente
- papeis: `super_admin`, `church_admin`, `pastor`, `leader`, `member`
- estados: `active`, `blocked`, `removed`, `transferred`

Para que o OTP funcione em producao, ainda precisas configurar um provider de SMS no painel do Supabase. Sem isso, o registo por telefone mostra erro de envio de SMS.

## White-label por igreja

A mesma app serve varias igrejas. O que muda por igreja vem do Supabase:

- nome do app
- tagline
- cores
- codigo de entrada
- contactos
- canais de pagamento
- anuncios
- eventos
- campanhas
