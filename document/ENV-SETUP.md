# 키(환경변수) 세팅 방법

키 값은 각 폴더의 `.env.local`에만 넣는다. `.env.local`은 `.gitignore`에 걸려 있어서 커밋되지 않는다.
키를 채팅·코드·문서에 붙여넣지 않는다.

## 1. 키 발급

### Supabase (새 프로젝트)
1. https://supabase.com/dashboard → New project (이름: `pickshot`, 리전: Northeast Asia (Seoul))
2. Project Settings → API에서 아래 값 확인
   - Project URL → `SUPABASE_URL`
   - anon(또는 publishable) key → `SUPABASE_ANON_KEY` (공개 값, 앱에 들어가도 됨 — 보안은 RLS가 담당)
   - service_role(또는 secret) key → `SUPABASE_SERVICE_ROLE_KEY` (**비밀**, 서버에서만)

### Gemini (새 키)
1. https://aistudio.google.com/apikey → Create API key
2. → `GEMINI_API_KEY` (**비밀**, 서버에서만)
3. 기존 cartoonhouse에 노출된 키는 같은 화면에서 삭제

## 2. `.env.local` 만들기

```bash
cp ~/pickshot/app/.env.example ~/pickshot/app/.env.local
cp ~/pickshot/admin/.env.example ~/pickshot/admin/.env.local
```
그다음 각 `.env.local`을 열어 값을 채운다.

| 변수 | app | admin | 공개 여부 |
|---|---|---|---|
| Supabase URL | `VITE_SUPABASE_URL` | `NEXT_PUBLIC_SUPABASE_URL` | 공개 |
| Supabase anon key | `VITE_SUPABASE_ANON_KEY` | `NEXT_PUBLIC_SUPABASE_ANON_KEY` | 공개 |
| Supabase service role key | `SUPABASE_SERVICE_ROLE_KEY` | `SUPABASE_SERVICE_ROLE_KEY` | **비밀** |
| Gemini API key | `GEMINI_API_KEY` | `GEMINI_API_KEY` | **비밀** |

> 비밀 값에는 `VITE_` / `NEXT_PUBLIC_` 접두사를 절대 붙이지 않는다. 붙이면 앱 코드에 그대로 노출된다.

## 3. 코드에서 읽는 곳

| 파일 | 내용 |
|---|---|
| `app/src/lib/env.ts` | 앱 공개 값 (`env.supabaseUrl`, `env.supabaseAnonKey`) |
| `app/src/lib/env.server.ts` | 앱 서버 함수용 비밀 값 (`getGeminiApiKey()`, `getSupabaseServiceRoleKey()`) — `createServerFn` 핸들러 안에서만 호출 |
| `admin/lib/env.ts` | 관리자 웹 공개·비밀 값 |

값이 비어 있으면 어떤 변수가 빠졌는지 오류 메시지로 알려준다.

## 4. 운영 배포
- `.env.local`은 내 PC 개발용. 운영(Cloud Run)에서는 서비스 환경변수(비밀 값은 Secret Manager)로 같은 이름을 넣는다.
- 앱의 `VITE_` 값은 빌드할 때 코드에 들어가므로, 빌드 환경(Cloud Build)에도 넣어야 한다.
