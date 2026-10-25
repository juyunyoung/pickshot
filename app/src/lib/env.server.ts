// 서버 전용 비밀 환경변수 — createServerFn 핸들러 안에서만 호출한다
// 개발: app/.env.local / 운영: Cloud Run 환경변수(또는 Secret Manager)
// 모듈 최상단에서 미리 읽어 두지 않는다 (앱 번들에 섞여 들어가는 것을 막기 위해)

function required(name: string): string {
  const value = process.env[name]
  if (!value) {
    throw new Error(`서버 환경변수 ${name}이(가) 비어 있어요. app/.env.local 또는 배포 환경변수를 확인하세요.`)
  }
  return value
}

export const getSupabaseServiceRoleKey = () => required('SUPABASE_SERVICE_ROLE_KEY')
export const getGeminiApiKey = () => required('GEMINI_API_KEY')
