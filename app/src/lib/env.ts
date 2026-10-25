// 앱(브라우저)에서 쓰는 공개 환경변수
// 값은 app/.env.local 에서 Vite가 자동으로 읽어 온다 (VITE_ 접두사만 앱 코드에 노출됨)
// 비밀 키는 여기에 두지 않는다 → env.server.ts

function required(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(`환경변수 ${name}이(가) 비어 있어요. app/.env.local을 확인하세요.`)
  }
  return value
}

export const env = {
  supabaseUrl: required('VITE_SUPABASE_URL', import.meta.env.VITE_SUPABASE_URL),
  supabaseAnonKey: required('VITE_SUPABASE_ANON_KEY', import.meta.env.VITE_SUPABASE_ANON_KEY),
}
