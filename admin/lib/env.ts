// 관리자 웹 환경변수
// 값은 admin/.env.local 에서 Next.js가 자동으로 읽어 온다
// NEXT_PUBLIC_ 값은 빌드 때 코드에 박히므로 process.env.이름 형태로 그대로 적어야 한다

function required(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(`환경변수 ${name}이(가) 비어 있어요. admin/.env.local을 확인하세요.`)
  }
  return value
}

// 공개 값 (브라우저·서버 공통)
export const env = {
  supabaseUrl: required('NEXT_PUBLIC_SUPABASE_URL', process.env.NEXT_PUBLIC_SUPABASE_URL),
  supabaseAnonKey: required('NEXT_PUBLIC_SUPABASE_ANON_KEY', process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY),
}

// 비밀 값 — 서버 코드(Route Handler, Server Action)에서만 호출
export const getSupabaseServiceRoleKey = () =>
  required('SUPABASE_SERVICE_ROLE_KEY', process.env.SUPABASE_SERVICE_ROLE_KEY)
export const getGeminiApiKey = () => required('GEMINI_API_KEY', process.env.GEMINI_API_KEY)
