# Comunhao Workspace

Esta workspace agora esta organizada em tres apps Flutter separadas e um pacote partilhado.

## Estrutura

- `apps/comunhao`
  App dos membros.
- `apps/comunhao_igreja`
  App dos pastores e administradores da igreja.
- `apps/comunhao_super_admin`
  App da equipa central da plataforma.
- `packages/comunhao_shared`
  Bootstrap do Supabase, metadados comuns e widgets reutilizaveis.
- `supabase`
  Schema, migrations e seed do backend.

## Como abrir cada app

App dos membros:

```powershell
cd apps/comunhao
flutter run -d windows
```

App da igreja:

```powershell
cd apps/comunhao_igreja
flutter run -d windows
```

App do super admin:

```powershell
cd apps/comunhao_super_admin
flutter run -d windows
```

## Backend

As tres apps usam o backend central DeliGo Platform e o schema `comunhao`.

- URL: `https://tpmsgvkdjzoidvyiwwfk.supabase.co`
- Schema PostgREST: `comunhao`
- Projeto antigo `dxofxuajsrocbxdmekfx`: somente contingencia temporaria
- Demo church code: `VIDA123`

## Direcao de produto

- `Comunhao`
  Foco em membros, eventos, oracao e doacoes.
- `Comunhao Igreja`
  Foco em registrar a igreja, acompanhar aprovacao e gerir a operacao local.
- `Comunhao Super Admin`
  Foco em aprovar/rejeitar igrejas, governanca e suporte da plataforma.
