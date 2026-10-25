-- 회원 정보 + SNS 게시 연동
-- 설계: document/AUTH-SNS.md

-- ─────────────────────────────────────────────
-- 공통: updated_at 자동 갱신
-- ─────────────────────────────────────────────
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ─────────────────────────────────────────────
-- profiles: 구글·애플·카카오·페이스북 기본정보의 합집합
-- ─────────────────────────────────────────────
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  signup_provider text not null default 'email'
    check (signup_provider in ('email', 'google', 'apple', 'kakao', 'facebook')),

  -- 교집합 (이메일 가입 시 입력)
  display_name text not null,
  email text,

  -- 합집합 (SNS에서 받은 경우만)
  email_verified boolean not null default false,
  is_private_email boolean not null default false, -- 애플 '이메일 가리기'
  full_name text,
  given_name text,
  family_name text,
  avatar_url text,
  locale text,

  -- 동의 기록
  terms_agreed_at timestamptz,
  privacy_agreed_at timestamptz,
  marketing_agreed_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

alter table public.profiles enable row level security;

create policy "본인 프로필 조회" on public.profiles
  for select to authenticated using (id = auth.uid());

create policy "본인 프로필 수정" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- 앱에서 고칠 수 있는 컬럼만 허용 (이메일·가입 방식 등은 서버·트리거만)
revoke insert, update, delete on public.profiles from anon, authenticated;
grant update (display_name, avatar_url, terms_agreed_at, privacy_agreed_at, marketing_agreed_at)
  on public.profiles to authenticated;

-- 가입 시 profiles 자동 생성
-- 이메일 가입은 signUp({ options: { data: { display_name } } })으로 이름을 넘긴다
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  provider text := coalesce(new.raw_app_meta_data ->> 'provider', 'email');
begin
  insert into public.profiles (
    id, signup_provider, display_name, email, email_verified, is_private_email,
    full_name, given_name, family_name, avatar_url, locale
  )
  values (
    new.id,
    case when provider in ('google', 'apple', 'kakao', 'facebook') then provider else 'email' end,
    coalesce(
      nullif(meta ->> 'display_name', ''),
      nullif(meta ->> 'name', ''),
      nullif(meta ->> 'full_name', ''),
      nullif(meta ->> 'nickname', ''),
      nullif(meta ->> 'preferred_username', ''),
      -- 애플 중계 주소 앞부분은 무작위 문자라 이름으로 쓰지 않음
      case when new.email not like '%@privaterelay.appleid.com'
           then nullif(split_part(new.email, '@', 1), '') end,
      '회원' -- 앱 첫 화면에서 이름 입력받기
    ),
    new.email,
    new.email_confirmed_at is not null or coalesce((meta ->> 'email_verified')::boolean, false),
    coalesce(new.email like '%@privaterelay.appleid.com', false),
    nullif(meta ->> 'full_name', ''),
    nullif(meta ->> 'given_name', ''),
    nullif(meta ->> 'family_name', ''),
    coalesce(nullif(meta ->> 'avatar_url', ''), nullif(meta ->> 'picture', '')),
    nullif(meta ->> 'locale', '')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- 이메일 변경·인증 시 profiles에 반영
create or replace function public.sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles
     set email = new.email,
         email_verified = new.email_confirmed_at is not null,
         is_private_email = coalesce(new.email like '%@privaterelay.appleid.com', false)
   where id = new.id;
  return new;
end;
$$;

create trigger on_auth_user_email_updated
  after update of email, email_confirmed_at on auth.users
  for each row execute function public.sync_profile_email();

-- ─────────────────────────────────────────────
-- social_connections: 게시용으로 연결한 SNS 계정
-- 등록·갱신은 서버(service role)만, 앱은 본인 것 조회·삭제
-- ─────────────────────────────────────────────
create table public.social_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null check (platform in ('instagram', 'facebook', 'threads')),
  external_user_id text not null, -- 메타 쪽 사용자 ID
  target_id text not null,        -- 게시 대상: 인스타 프로페셔널 계정 / 페이스북 페이지 / 쓰레드 사용자
  target_name text,               -- 화면 표시용 (계정명·페이지명)
  username text,
  scopes text[] not null default '{}',
  status text not null default 'active' check (status in ('active', 'expired', 'revoked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, platform, target_id)
);

create index social_connections_user_id_idx on public.social_connections (user_id);

create trigger social_connections_set_updated_at
  before update on public.social_connections
  for each row execute function public.set_updated_at();

alter table public.social_connections enable row level security;

create policy "본인 연결 조회" on public.social_connections
  for select to authenticated using (user_id = auth.uid());

create policy "본인 연결 해제" on public.social_connections
  for delete to authenticated using (user_id = auth.uid());

revoke insert, update on public.social_connections from anon, authenticated;

-- ─────────────────────────────────────────────
-- social_connection_tokens: 접근 토큰 (서버 전용)
-- RLS만 켜고 정책을 두지 않음 → 앱에서는 읽기·쓰기 불가
-- ─────────────────────────────────────────────
create table public.social_connection_tokens (
  connection_id uuid primary key references public.social_connections (id) on delete cascade,
  access_token text not null,
  token_expires_at timestamptz,
  updated_at timestamptz not null default now()
);

create trigger social_connection_tokens_set_updated_at
  before update on public.social_connection_tokens
  for each row execute function public.set_updated_at();

alter table public.social_connection_tokens enable row level security;
revoke all on public.social_connection_tokens from anon, authenticated;

-- ─────────────────────────────────────────────
-- social_posts: SNS 게시 요청·결과
-- 앱은 요청 등록·조회, 게시 처리와 결과 기록은 서버
-- ─────────────────────────────────────────────
create table public.social_posts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  connection_id uuid references public.social_connections (id) on delete set null,
  source_type text not null check (source_type in ('photo', 'frame_shot', 'diary')),
  source_id uuid not null,
  caption text,
  status text not null default 'queued'
    check (status in ('queued', 'publishing', 'published', 'failed')),
  external_post_id text,
  permalink text,
  error_message text,
  created_at timestamptz not null default now(),
  published_at timestamptz
);

create index social_posts_user_id_idx on public.social_posts (user_id, created_at desc);

alter table public.social_posts enable row level security;

create policy "본인 게시 기록 조회" on public.social_posts
  for select to authenticated using (user_id = auth.uid());

create policy "본인 계정으로 게시 요청" on public.social_posts
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.social_connections c
       where c.id = connection_id
         and c.user_id = auth.uid()
         and c.status = 'active'
    )
  );

-- 요청 등록 시 상태·결과 컬럼은 못 넣게 함
revoke insert, update, delete on public.social_posts from anon, authenticated;
grant insert (connection_id, source_type, source_id, caption) on public.social_posts to authenticated;
