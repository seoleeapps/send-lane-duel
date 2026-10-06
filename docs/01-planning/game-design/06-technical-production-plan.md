# 기술 제작 계획

- 제품명: Three Purses. 작업 id `send-lane-duel`
- 문서 상태: approved
- 소유자: syous
- 버전/수정일: v0.1 / 2026-10-06
- Source of truth: 엔진과 구조, 데이터 계약, 분석 이벤트, 성능 예산, 저장, 서버 경계, 플랫폼 연동, 제작 단계, 명령
- Depends on: `02-gdd.md` v0.1, `03-ui-ux-spec.md` v0.1, `../policy-review.md`
- Open blockers: Core 사람 플레이테스트, 대표 화면 방향 선택, 실기기·SDK·출시 검수
- 승인 근거: 2026-10-06 사용자 전체 제작 승인 및 구현 계획 실행 요청

## 아키텍처와 엔진

- 엔진: Godot 4.7.2(로컬 실행 파일 및 `global-versions.yaml` 일치 확인), GDScript 엄격 타입, 2D, 세로 고정. 사내 `godot-game`, `game-outgame-framework` 스킬의 시작 템플릿을 쓴다.
- 층 구분

| 층 | 내용 | 규칙 |
| --- | --- | --- |
| 도메인 코어 | 난수, 웨이브, 전투, 진영·경제, 지휘관, 런 상태 기계 | 엔진 노드·시간·부동소수에 의존하지 않는 순수 스크립트. `sim/run_sim.py` 의 core 부분을 1:1 로 옮긴다 |
| 응용 | 런 진행, 저장, 일일 도전 시드, 광고·분석 호출 | 코어의 행동과 결과만 주고받는다 |
| 표현 | 화면, 전투 재생, 효과 | 코어가 낸 결과(박자별 사건 목록)를 재생만 한다. 표현이 결과를 바꾸지 않는다 |
| 연동 | Firebase, 광고 SDK, 마켓 | 인터페이스 뒤에 둔다. 마켓별 구현을 갈아 끼운다 |

- 결정론: 모든 계산은 정수다. 난수는 xorshift32(13, 17, 5)이고 흐름은 `route`, `wave`, `draft`, `commander` 로 나눈다. 흐름 시드 = (런 시드 × 2654435761 + 흐름 번호 + 16 × 보조 번호) mod 2^32. GDScript 의 정수는 64비트이므로 연산마다 `& 0xFFFFFFFF` 로 자른다.
- 전투 재생: 코어의 `resolve` 를 사건 목록(박자, 자리, 대상, 피해, 죽음, 누수)을 함께 내도록 확장한다. 결과 값은 벡터와 같아야 한다.

## 데이터 계약

| 파일 | 내용 | 검사 |
| --- | --- | --- |
| `data/core/rules.json` | 상수, 상성표, 웨이브, 지휘관 배율, 격, 일일 도전 점수, 난수 | `tools/validate_content.py` |
| `data/content/units.json` | 계열 4 × 단계 3 | 같음 |
| `data/content/mercenaries.json` | 용병 8 | 같음 |
| `data/content/commanders.json` | 지휘관 6 | 같음 |
| `data/content/draft.json` | 증표 10, 편성 4, 훈장 | 같음 |
| `data/monetization/bm-profile.json` | 광고 배치, 한도, 원격 설정 키 | `monetization/tools/validate_bm.py` |
| `tests/fixtures/vectors.json` | 전투 60, 런 40 | 구현체 단위 테스트의 입력 |

게임 저장소로 승격할 때 `data/` 를 그대로 복사해 `res://data/` 로 읽는다. 표시 이름은 번역 표로 옮기고 JSON 의 `name_*` 는 기본값으로만 쓴다.

행동 형식(코어 입력): `{"builds": [["place", 자리, 계열] | ["upgrade", 자리] | ["replace", 자리, 계열]], "workers": 수, "packs": [용병 id 목록]}`.

## 분석 이벤트 분류

질문에서 거꾸로 설계한다. GA4 권장 이벤트 이름을 우선 쓴다.

| 질문 | 지표 | 이벤트 | 주요 파라미터 | 발생 시점 |
| --- | --- | --- | --- | --- |
| 튜토리얼에서 어디서 나가나 | 단계별 도달률 | `tutorial_begin`, `tutorial_step`, `tutorial_complete` | `step` | 튜토리얼 판마다 |
| 런은 어디서 끝나나 | 장·판별 종료 분포 | `level_start`, `level_end` | `level_name`(장-지휘관), `success`, `fail_reason`, `rounds_used`, `castle_left` | 장 시작·종료 |
| 어떤 지휘관이 어렵나 | 지휘관별 실패율 | `level_end` | `commander_id`, `chapter_armor` | 장 종료 |
| 배분은 어떻게 하나 | 금화 사용 비율 | `round_resolved` | `gold_defense`, `gold_worker`, `gold_merc`, `my_damage`, `cmd_damage`, `captives` | 판 정산(표본 20%) |
| 길과 보상 선택이 갈리나 | 선택 분포 | `route_chosen`, `draft_picked` | `options`, `picked` | 선택 시 |
| 런 결과와 길이 | 완주율, 런 시간 | `run_end` | `status`, `chapters`, `score`, `preset_id`, `ascension`, `mode`, `duration_s` | 런 종료 |
| 일일 도전이 잔존에 기여하나 | 참여율, 참여자 D7 | `post_score` | `score`, `mode=daily` | 제출 |
| 광고는 어디서 보나 | 요청·노출·실패·보상 | `ad_requested`, `ad_impression`, `ad_failed`, `rewarded_earned` | `placement_id`, `format`, `app_market`, `runtime_platform`, `release_version` | 광고 흐름 |
| 전면 광고가 이탈을 만드나 | 전면 노출 뒤 60초 안 세션 종료 비율, 켠 집단과 끈 집단의 D1·D7 | `ad_impression`, `session_end` | `format=interstitial`, `seconds_since_ad` | 광고 뒤 |
| 오류 | 저장 실패, 벡터 불일치 | `app_exception` | `kind` | 발생 시 |

검증: 내부 빌드에서 GA4 디버그 보기로 위 이벤트를 두 세션 동안 확인한다. 출시 뒤에는 `ga4-bigquery-analytics` 로 조회한다.

## 성능 예산

| 항목 | 예산 | 측정 |
| --- | --- | --- |
| 프레임 | 60fps, 저사양 기기(3GB 램 Android)에서 30fps 이상 유지 | 실기기 프레임 분포 |
| 전투 계산 | 한 판 `resolve` 2회 5ms 이하 | 코어 단위 측정 |
| 예상 수치 갱신 | 배분 조작마다 16ms 이하(적 최대 약 80기 × 8박) | 프로파일러 |
| 메모리 | 300MB 이하 | 실기기 |
| 설치 크기 | 80MB 이하 | 빌드 산출물 |
| 첫 실행에서 조작 가능까지 | 5초 이하(중간 사양) | 녹화 |
| 발열·배터리 | 10분 플레이에서 프레임 저하 없음 | 실기기 |

## 저장 마이그레이션

- 기기 저장: `user://save.json`. 최상위에 `schema_version`.

| 영역 | 필드 |
| --- | --- |
| 계정 진행 | 훈장, 해금한 편성, 최고 격, 도감 발견 목록, 꾸미기 |
| 진행 중인 런 | 런 시드, 편성, 격, 모드, 행동 기록(길·보상·판별 행동) |
| 일일 도전 | 날짜(UTC), 제출 여부, 점수 |
| 설정 | 소리, 진동, 속도, 접근성, 언어 |

- 런은 시드와 행동 기록으로 처음부터 다시 계산해 복원한다. 중간 상태를 저장하지 않으므로 형식이 바뀌어도 깨질 곳이 적다.
- 규칙 버전(`rules.schema`)이 바뀌면 진행 중인 런은 훈장을 정산하고 닫는다. 계정 진행은 유지한다.
- 쓰기는 임시 파일에 쓴 뒤 이름을 바꾼다. 읽기 실패 시 직전 백업으로 복구한다.
- 마이그레이션 함수는 버전마다 하나씩 두고, 이전 버전 저장 파일 표본으로 단위 테스트한다.

## 백엔드와 보안 경계

- Firebase: 익명 로그인, Firestore, Remote Config, Analytics, Crashlytics. 상시 서버 없음.
- Firestore 문서

| 경로 | 내용 | 쓰기 | 읽기 |
| --- | --- | --- | --- |
| `users/{uid}` | 계정 진행 백업, 닉네임 | 본인 | 본인 |
| `daily/{yyyymmdd}/scores/{uid}` | 점수, 닉네임, 쓴 판, 남은 금화, 제출 시각, 행동 기록 | 본인, 하루 1회 생성만(수정 불가) | 모두(상위 100 조회) |
| `daily/{yyyymmdd}/top` | 상위 100 묶음 문서 | 서버 또는 지연 집계 | 모두 |

- 비용: 일일 도전 제출 1회 = 쓰기 1, 순위 조회 = 읽기 1(묶음 문서). 무료 할당(하루 쓰기 20,000, 읽기 50,000, POL-082) 안에서 하루 참여자 약 2만 명까지 0원.
- 순위표 기록 검증(DEC-007, C 지연 검수 확정)

| 안 | 방법 | 비용 | 위험 |
| --- | --- | --- | --- |
| A 서버 재실행 | 제출 시 Cloud Functions 가 행동 기록을 같은 코어로 재생해 점수를 확인 | Blaze 요금제 필요(POL-083). 호출 월 200만 회까지 무료. 코어를 JavaScript 로 한 벌 더 유지 | 코어 두 벌의 불일치. 벡터로 막는다 |
| B 검증 없음 | 규칙으로 형식만 검사(점수 상한, 하루 1회) | 0원 | 조작 점수가 상위에 노출. 보상이 없어 피해는 체면뿐 |
| C 지연 검수 | B 로 받고, 상위 100 만 하루 한 번 로컬 스크립트로 재생해 지움 | 0원, 사람 손 또는 예약 작업 | 하루 동안 조작 기록이 보임 |

추천은 C 로 시작하고 조작이 실제로 문제가 되면 A 로 간다. 부계정으로 같은 시드를 연습하는 것은 어느 안으로도 막지 못한다(SRC-011). 그래서 순위 보상을 두지 않는다.

- 닉네임: 영문·한글·숫자 2~12자, 금칙어 목록, 기본값은 무작위 조합. 계정·데이터 삭제는 서버의 검증된 관리자 작업으로 `users/{uid}` 와 모든 `scores/{uid}` 를 지운다. 첫 시도 초기화를 막기 위해 클라이언트는 점수를 삭제하지 못한다(POL-022).
- App Check: Godot 공식 지원이 없다(POL-084). 출시 범위에서는 Firestore 규칙으로만 막고, 필요해지면 네이티브 플러그인을 검토한다.
- 전면 광고 판단은 응용 층의 한 곳(`AdGate`)에서 한다: 세션 번호 2 이상, 플레이 3분 이상, 마지막 전면 뒤 120초 이상, 세션 3회·하루 8회 미만, 직전 휴지에 보상형을 보지 않았음, 튜토리얼 아님. 값은 원격 설정에서 받고 기본값은 `bm-profile.json`.
- 비밀값은 저장소에 넣지 않는다. 자격증명은 `seorilabs-credentials` 절차를 따른다.

## 플랫폼 연동

| 항목 | Google Play | App Store |
| --- | --- | --- |
| 빌드 | AAB, targetSdk 36(POL-007), 16KB 페이지 정렬 확인(POL-008), x64 Linux 러너 | Xcode 보관·업로드. 비공개 저장소는 Xcode Cloud |
| 광고 | 전면 + 보상형. 동의 관리(UMP) 먼저(POL-041). 전면은 5초 안에 닫기, 뒤로 가기로 닫힘(POL-001) | 같음 + 추적 허용 요청(ATT)을 광고 SDK 초기화 전에(POL-023). 거부해도 광고와 보상은 동작 |
| 결제 | 없음. 결제 라이브러리를 넣지 않는다 | 없음 |
| 개인정보 | 데이터 안전 양식(POL-004), 처리방침 링크 | 개인정보 라벨(POL-024), 개인정보 매니페스트(POL-025), 계정 삭제(POL-022) |
| 문구 | — | 다른 플랫폼 이름을 화면과 문구에 넣지 않는다(POL-028) |
| 등급 | IARC 설문(POL-009) | 연령 등급 설문. 잦은 카툰 폭력이면 13+ 예상(POL-027) |

광고 SDK 선택(DEC-008, 전면과 보상형을 모두 지원해야 한다): AdMob 은 Godot 공식 SDK 가 없고 커뮤니티 플러그인(Poing Studios, Godot 4.5 이상)뿐이다(POL-044, POL-045). AppLovin MAX 는 공식 Godot 4 플러그인이 있다(POL-046). 사내 다른 Godot 게임이 쓰는 SDK 를 먼저 확인하고 같은 것을 쓴다. Vertical Slice 전에 두 마켓에서 보상형 광고 1회 시청까지 시험한다.

마켓별 차이는 연동 층의 구현 교체로만 처리하고 도메인 코어와 화면은 공유한다. 앱인토스는 범위 밖이다.

## 제작 단계

| 게이트 | 보이는 결과 | 범위 | 종료 기준 |
| --- | --- | --- | --- |
| Core Gate | 회색 상자 그림으로 한 런이 돌아간다 | 도메인 코어, SCR-003~007 뼈대, 기기 저장 | AC-001~004 통과, 사람 5명 테스트(`00-product-brief.md` 기준) |
| Vertical Slice | 선택한 세계관의 아트·소리로 첫 세션이 완성된다 | 튜토리얼, 1장 지휘관 2종 최종 품질, 대표 화면 목표 대비 비교 | `03-ui-ux-spec.md` UI 인수 증거, 광고 SDK 시험 |
| Production | 전체 콘텐츠와 메타 | 지휘관 6, 증표 10, 편성 4, 격, 도감, 일일 도전, 분석, 전면·보상형 광고 | AC-001~013, 이벤트 확인 |
| Hardening | 실기기 품질 | 성능 예산, 접근성, 저장 복구, 오프라인 | `07-qa-launch-plan.md` 검수표 |
| Release | 서명 빌드와 스토어 자료 | 등급, 개인정보, 문구 검수 | 론칭 게이트 |
| Evidence | 소프트론칭 지표 | — | 성공·중단 기준 판정 |

Core Gate 의 첫 작업은 코어를 옮기고 벡터 100건을 통과시키는 것이다. 화면은 그다음이다.

## 빌드와 테스트 명령

게임 저장소의 Core 검사와 개발용 APK:

```bash
bash scripts/check.sh
godot --path . --script res://tests/run_ui.gd -- --save=user://tests-ui/save.json
python3 -I tools/sim/run_sim.py --runs 1000 --json build/qa/run-sim.json
godot --headless --path . --export-debug "Android Core Playtest" build/android/three-purses-core.apk
cd firebase
npm ci --ignore-scripts
~/.config/seorilabs/scripts/firebase-cli.sh emulators:exec --project demo-three-purses --only firestore 'npm test'
```

개발용 APK는 Godot 비 Gradle 템플릿의 minSdk 24·targetSdk 36을 사용한다. 승인된 제품 지원 하한 28은 Production Gradle export에서 적용하고 검사한다. 현재 APK는 테스트용 디버그 서명이고 스토어 제출용 서명·AAB·iOS archive는 없다.

헤드리스 로그에서 `SCRIPT ERROR`, `ERROR:`, 누락 리소스를 읽는다. 빌드 성공을 화면 품질 완료로 보지 않는다.

## 구현 승인 반영 — 2026-10-06

제품 계약은 승인되었습니다. 현재 실행 원장은 이 문서와 `../../02-decisions/ADR-001-approved-product.md`입니다. 이름 Three Purses, 태엽 장난감 세계관, Android/iOS, 영어/한국어, 타깃 20~40대, 소프트론칭 캐나다·호주·한국, AdMob·Poing, 순위표 지연 검수로 확정했습니다. 과거 초안의 미확정 표기는 위 결정으로 대체됩니다. 아트 시안 선택·사람 테스트·실기기·마켓 확인은 별도 미완료 증거입니다.
