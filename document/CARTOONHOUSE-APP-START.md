# 카툰하우스(가칭) — 새 앱 시작 문서

> 2026-10-25 작성. 이전 세션에서 기획·분석한 내용을 새 세션이 이어받기 위한 문서.
> 새 세션은 이 문서를 먼저 읽고, 아래 "8. 정해야 할 것"부터 사용자에게 확인한 뒤 시작한다.

---

## 1. 기획 취지

### 왜 만드나
- **달조아랩 포트폴리오 확장.** 달조아랩(daljoalab.com)은 소상공인·중소기업 대상 "AI + 모바일 앱" 제작 1인 스튜디오다. 현재 실제 사례는 여행 앱 heeva 하나뿐이라, **AI 이미지 기능이 중심인 두 번째 사례**가 필요하다.
- **덕질 앱 시장을 겨냥한 데모·영업 자산.** 홈페이지·크몽에 "덕질 앱도 만들어요"를 추가하려는데, 말로만이 아니라 실제로 동작하는 앱을 보여주려 한다.
- **흩어진 두 앱을 하나로.** 이전에 만든 `cartoonDiary`(AI 만화 일기)와 `cartoonhouse`(만화 일기 + 친구 집 + 사진 합성)는 뿌리가 같지만, 미완성·버그·보안 문제가 많다. 좋은 기능만 모아 **heeva2.0과 같은 Supabase 구조로 새로 만든다.**

### 무엇을 보여주고 싶나 (세일즈 포인트)
1. **사진 기능 + AI** — 최애 캐릭터 사진으로 나만의 프레임을 만들고(AI 배경 지우기), 프레임을 씌워 바로 촬영
2. **생성형 AI** — 하루 일기를 내 캐릭터가 나오는 4컷 만화로 자동 생성
3. **꾸준히 쓰게 만드는 구조** — 최애 작품(집)과 캐릭터(친구)를 모으고, 호감도·앨범으로 쌓이는 재미

## 2. 한 줄 정의
**내 최애와 함께 사는 집** — 최애 작품(집)과 캐릭터(친구)를 모으고, 캐릭터 프레임으로 같이 사진을 찍고, 하루를 AI 4컷 만화 일기로 남기는 앱.

## 3. 참고 저장소

| 저장소 | 용도 | 비고 |
|---|---|---|
| `juyunyoung/heeva2.0` | **기술 구조 템플릿** (app + admin + supabase) | 비공개 |
| `juyunyoung/cartoonhouse` | 기능 참고: 친구 집, 캐릭터 앨범, AI 합성, 만화 일기 + 기억 추출 | 비공개. FastAPI + React, 구글 클라우드(BigQuery·GCS) |
| `juyunyoung/cartoonDiary` | 기능 참고: AI 만화 일기 원본, PRD·설계 문서 | 공개. FastAPI + React, AWS(RDS·S3·Bedrock Nova) |
| `juyunyoung/daljoalab-web` | 완성 후 포트폴리오로 올릴 홈페이지 | 제작 사례 섹션 `#case` 구조 참고 |

**코드는 복사하지 말고 흐름만 참고해서 새로 짠다.** (두 앱 모두 구조적 문제가 많음 — 4장 참고)

## 4. 기존 두 앱 분석 요약

### 공통: AI 만화 일기 파이프라인
일기 → (cartoonhouse만) 기억 추출 → 스토리보드(컷별 장면·감정·대사·카메라) → 컷별 이미지 프롬프트 → 컷 이미지 생성 → AI 시각 검수(PASS/FAIL + 수정 힌트) → 실패 컷만 프롬프트 수정 후 재생성(최대 2회) → 완성
- 캐릭터 일관성: 사용자 아바타 이미지를 첫 컷 참조로, 이후 컷은 앞 컷 참조 + 고정 seed + 짧은 외형 설명을 모든 컷에 추가
- 프롬프트 원칙: 영어, 카메라 앵글 다양화, 말풍선·글자 금지, 주인공은 "the character"
- 스타일 4종(cute / comedy / drama / minimal), 무드 10종(아이콘: crying, curious, emotionless, motivated, normal, sad, sigh, soft_smile, surprised, very_happy)

### cartoonhouse에만 있는 것
- **친구 집** = 최애 작품(comics), **친구** = 캐릭터(comic_character: 이름, 메모, 대표 사진, 호감도), 호감도 순위
- **캐릭터별 사진 앨범**(photo_info)
- **AI 합성 사진**: 내 사진 + 캐릭터 사진 + 키워드 2개 → Gemini 이미지 모델로 한 장 합성
- **기억 추출**: 일기에서 인물·반려동물·장소·물건과 외형 특징을 뽑아 저장 → 다음 만화에 반영
- 작품 뉴스·정보 검색(Gemini 검색, 네이버 책 API)
- 사용 모델: Gemini (`gemini-2.5-flash` 텍스트·검수, `gemini-3-pro-image-preview` 이미지, `text-embedding-004` 임베딩)

### 그대로 가져오면 안 되는 문제
- 만화 컷 수가 **1로 하드코딩** (4컷 아님)
- AI 작업 상태가 **서버 메모리**에만 있음 → 재시작하면 사라짐, 서버 여러 대 불가
- 친구 집 화면은 **API 경로가 안 맞아 대부분 동작 안 함**, 라우트 순서 버그로 일부 API 가려짐
- **인증 없는 API 다수** (남의 프로필 이미지 덮어쓰기 가능, 작업 목록 전체 노출 등)
- AI 합성에서 **안전 필터를 전부 꺼 둠**(BLOCK_NONE)
- 저장소 이름은 S3인데 실제는 GCS → 검수·이어붙이기 단계가 조용히 실패
- ORM과 SQL 스키마의 ID 타입 불일치
- ⚠️ **cartoonhouse 저장소에 `.env`가 커밋돼 있고 AWS 액세스 키·Gemini 키·DB 비밀번호 등이 노출**됨 → 키 교체 필요(사용자 확인 대기 중). 새 앱에서는 절대 `.env`를 커밋하지 않는다.

## 5. heeva2.0 구조 (그대로 따를 틀)

- **app/**: TanStack Start(SPA 모드) + React 19 + Vite + Tailwind v4 + shadcn/Radix + React Query, Capacitor 8로 안드로이드·iOS
  - 파일 기반 라우트(`src/routes`, 하단 탭은 `_tabs.*.tsx`), `src/services/*.service.ts`에 Supabase 쿼리, AI 호출은 `createServerFn`(비밀 키는 핸들러 안에서만 읽기)
  - OTA 앱 업데이트: `scripts/publish-ota.ts` + `app_releases` 테이블 + `src/lib/ota/*`
- **admin/**: Next.js 15 관리자 웹, 역할(admin/partner/curator) + 메뉴 권한 테이블
- **supabase/**: `migrations/`, Storage 버킷, Edge Functions
- **배포**: Cloud Build → Cloud Run(Docker), 네이티브는 `cap sync`

**heeva에서 따라 하지 말 것**
- RLS를 `USING (true)`로 전체 공개한 테이블들 → 새 앱은 전부 `auth.uid()` 기준
- localStorage 가짜 로그인(mock) → 새 앱은 Supabase Auth만
- 공개 Storage 버킷 → 새 앱은 개인 사진이라 비공개 + 서명 URL
- `.env` 커밋 (heeva도 `app/.env`가 커밋돼 있음)

## 6. 새 앱 설계

### 기능
| 기능 | 출처 | 비고 |
|---|---|---|
| 회원가입·로그인 | 공통 | Supabase Auth |
| 내 아바타 만들기 | 공통 | 성별·나이·헤어·안경·주근깨 선택 → AI 얼굴 생성, 프롬프트·seed 저장 |
| 친구 집(최애 작품)·친구(캐릭터) | cartoonhouse | 등록·수정, 호감도, 순위 |
| 캐릭터 앨범 | cartoonhouse | 업로드 / 합성 / 프레임 촬영 사진 모음 |
| **프레임 만들기** | 신규 | AI 배경 지우기 + 배치·꾸미기 + (선택) AI 배경 생성 |
| **프레임 촬영** | 신규 | 카메라 위에 프레임 겹쳐 촬영, 네컷 연속 촬영 |
| AI 합성 사진 | cartoonhouse | 나 + 캐릭터, 결과를 앨범에 저장, 안전 필터 기본값 |
| AI 4컷 만화 일기 | 공통 | 4컷 복구, 무드를 프롬프트에 반영 |
| 일기 의미 검색 | 공통 | pgvector |
| 기억 추출 | cartoonhouse | 등장 인물 일관성 |
| 관리자 웹 | heeva | 회원·신고·AI 사용량·프레임 템플릿·앱 업데이트 |
| 작품 뉴스·정보 | cartoonhouse | 2차 |

### 프레임 기능 상세
- **만들기**: 앨범 사진 선택 → AI 누끼 → 틀 선택(1컷·네컷·폴라로이드·스티커형) → 캐릭터 위치·크기·회전, 배경색·문구·날짜 → (선택) "벚꽃, 파스텔" 입력해 AI 배경 → 저장
- **촬영**: 프레임 선택 → 카메라 화면에 겹쳐 보기 → 촬영(네컷은 4회) → 한 장으로 합성 저장 → 캐릭터 앨범 자동 등록 → 공유

### AI 작업 처리
1. 앱이 `jobs` 테이블에 작업 등록
2. Edge Function(또는 서버 함수)이 백그라운드 처리하며 `jobs.status/progress` 갱신
3. 앱은 Supabase Realtime으로 진행률 표시 → 재시작해도 기록 유지

### 데이터 (주요 테이블)
`profiles`, `houses`, `characters`, `character_photos`, `frames`, `frame_templates`, `diaries`, `diary_panels`, `diary_embeddings`(pgvector), `memories`, `memory_facts`, `jobs`, `ai_usage`, `app_releases`, `admin_menu_permissions`
- 모든 테이블 `auth.uid()` 기준 RLS
- Storage 비공개 버킷: `avatars`, `characters`, `frames`, `photos`, `diaries`

### 꼭 지킬 것
- **저작권·초상권**: 캐릭터 이미지는 사용자가 직접 올린 것만. 앱이 공식 이미지를 제공하거나 AI로 유명 캐릭터를 그리지 않음. 사진은 기본 비공개.
- **AI 안전 필터 기본값 유지**
- **AI 비용 한도**: 사용자별 일일 횟수 제한(예: 만화 일기 3회, 합성 10회)
- **유료 프레임 판매 시 인앱결제**(애플·구글). 예약·실물 상품만 PG(토스페이먼츠) 가능

## 7. 개발 순서

| 단계 | 내용 | 결과물 |
|---|---|---|
| 0. 기반 | heeva 틀 복사·정리(이름·appId·버킷·키 이름 변경, mock 로그인 제거), Supabase 스키마·RLS·버킷, 로그인, 프로필 | 로그인되는 빈 앱 |
| 1. 친구 집 | 작품·캐릭터 등록, 호감도·순위, 캐릭터 앨범 (AI 없음) | 핵심 덕질 기능 |
| 2. 프레임 | 프레임 만들기 + 촬영 + AI 배경 지우기 | **신규 핵심 기능** |
| 3. AI 합성 | 나 + 캐릭터 합성 → 앨범 저장 | |
| 4. 만화 일기 | 아바타 생성, AI 4컷 일기(jobs + Realtime) | |
| 5. 마무리 | 일기 검색, 기억 추출, 관리자 웹, OTA, 스토어 준비 | 출시 |

완성 후: 화면 캡처 → daljoalab.com 제작 사례 + 크몽 포트폴리오에 추가

## 8. 정해야 할 것 (새 세션에서 먼저 확인)
1. **코드 저장소**: 새 저장소 추천(예: `juyunyoung/cartoonhouse-app`) — 사용자가 GitHub에서 만들면 연결
2. **앱 이름**: 가칭 "카툰하우스"
3. **AI 모델**: Gemini 계속 사용? (새 API 키 발급 권장 — 기존 키는 노출됨)
4. **Supabase 프로젝트**: 새로 생성 후 URL·anon key 전달 (service role key는 채팅에 붙이지 말고 환경변수로)
5. **시작 범위**: 0~2단계부터 진행할지

## 9. 작업 규칙 (사용자 선호)
- 답변은 간결하게, 반존대 말투
- 큰 작업(대량 코드 생성 등)은 시작 전에 확인받기 — 토큰 소모가 크면 미리 말하기
- 다음 단계 진행·데이터 조회 전에 먼저 동의 구하기
- 기술명(Flutter 등)은 홍보 문구에 쓰지 않음 ("안드로이드·iOS"로 표현)
- 세션 종료 시 결정사항·진행상황·다음 할 일을 `docs/sessions/YYYY-MM-DD.md`로 정리
