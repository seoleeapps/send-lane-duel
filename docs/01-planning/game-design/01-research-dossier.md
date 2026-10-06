# 리서치 조사서

- 제품명: Three Purses. 작업 id `send-lane-duel`
- 문서 상태: approved
- 소유자: syous
- 버전/수정일: v0.1 / 2026-10-06
- Source of truth: 출처 원장(SRC-###), 경쟁작 매트릭스, 리뷰 종합, 가설
- Depends on: Obsidian `inbox/2026-10-06 RTS 유즈맵 모바일 재론칭 시장 조사.md`
- Open blockers: Core 사람 플레이테스트, 대표 화면 방향 선택, 실기기·SDK·출시 검수
- 승인 근거: 2026-10-06 사용자 전체 제작 승인 및 구현 계획 실행 요청

## 조사 범위

- 조사일과 접근일: 2026-10-06. 스토어 수치는 미국 스토어 기준.
- 대상: 방어와 보내기를 함께 하는 직접 경쟁작의 1인 모드, 일일 도전이 있는 인접작, 보상형 광고와 잔존율 벤치마크, 스토어·광고·개인정보 정책.
- 표기: 사실은 출처에서 직접 확인한 것, 추론은 해석, 미확인은 근거를 찾지 못한 것.
- 한계: 실기기 플레이 확인은 하지 않았다. 리뷰 표본은 Steam 영어 최근 부정 리뷰 각 40건과 App Store 미국 최근 1~3점 리뷰다.

## 출처 원장

| ID | 제목 | URL | 뒷받침하는 내용 | 신뢰도 |
| --- | --- | --- | --- | --- |
| SRC-001 | Legion TD 2 Steam 상점 | https://store.steampowered.com/app/469600/ | 모드, 캠페인, 온라인 필수, 가격 | 1차 |
| SRC-002 | Steam 리뷰 API | https://store.steampowered.com/appreviews/469600?json=1&language=all | 리뷰 수, 최근 부정 리뷰 원문 | 1차, 표본 40건 |
| SRC-003 | Legion TD 2 위키 | https://legiontd2.wiki.gg/wiki/Legion_TD_2 | 캠페인 상대 7명, 한 판 20~25분 | 검색 요약 |
| SRC-004 | Legion TD 2 개발자 질의응답 | https://steamcommunity.com/app/469600/discussions/0/601900568252841730 | 모바일 이식 계획 없음, 신작은 모바일 검토 | 검색 요약, 2025-03 |
| SRC-005 | Mechabellum 2.0 기사 | https://turnbasedlovers.com/overview/mechabellum-2-0/ | 무료판과 로그라이트 모드 | 2차 |
| SRC-006 | Google Play 상점 페이지(Lucky Defense 외) | https://play.google.com/store/apps/details?id=com.percent.aos.luckydefense | 평점, 다운로드 구간, 광고·결제 표기 | 1차 |
| SRC-007 | App Store 리뷰 RSS | https://itunes.apple.com/us/rss/customerreviews/id=6482291732/sortby=mostrecent/json | 최근 저평점 리뷰 원문 | 1차 |
| SRC-008 | Lucky Defense 매출 분석 | https://sensortower.com/ko/blog/Lucky-Defense-has-become-the-highest-grossing-Korean-strategy-game | 다운로드·매출·한국 비중 | 추정치 |
| SRC-009 | Random Dice 솔로 모드 | https://www.pockettactics.com/random-dice/solo-mode | 솔로 모드 구조 | 2021년 기준 |
| SRC-010 | Bloons TD Battles 2 위키 | https://www.bloonswiki.com/BTDB2 | 1인 모드 종류 | 검색 요약 |
| SRC-011 | Slay the Spire 일일 등반 토론 | https://steamcommunity.com/app/646570/discussions/0/1743357605566110144 | 순위표 조작 증언 | 이용자 증언 |
| SRC-012 | 일일 등반 소개 | https://intothespine.com/2018/03/05/slay-the-spire-daily-climb/ | 전원 같은 시드와 변형 규칙 | 검색 요약 |
| SRC-013 | BTD6 조작 토론 | https://steamcommunity.com/app/960090/discussions/0/3819655463302453074 | 상위 기록 조작과 보상 전 삭제 | 이용자 증언 |
| SRC-014 | BTD6 일일 챌린지 위키 | https://www.bloonswiki.com/Daily_Challenge_(BTD6) | 일일 챌린지 구조 | 검색 요약 |
| SRC-015 | Isle of Arrows 소개 | https://www.androidpolice.com/isle-of-arrows-new-digital-board-game/ | 일일 방어, 유료 판매 | 2022년 기사 |
| SRC-016 | Appodeal eCPM 보고서 2024 Q4 | https://appodeal.com/wp-content/uploads/2025/03/Quarterly_Mobile_eCPM_Report_-_Q4_2024.pdf | 지역별 보상형 광고 단가 | 1차, 그래프 판독 |
| SRC-018 | Unity 수익화 보고서 기사 | http://www.pocketgamer.biz/unity-global-rewarded-ad-engagement-rose-by-32-in-2023/ | 보상형 광고 참여율 | 2차, 2023년 |
| SRC-019 | GameAnalytics 2025 벤치마크 | https://investgame.net/wp-content/uploads/2025/02/2025-GameAnalytics-Mobile-Gaming-Benchmarks.pdf | 장르별 잔존율·세션 | 1차, 2024년 데이터 |
| SRC-022 | Vampire Survivors 모바일 수익화 | https://mobilegamer.biz/vampire-survivors-mobile-hits-3m-downloads/ | 선택형 보상 광고만 사용 | 검색 요약 |
| SRC-023 | Rush Royale 누적 매출 발표 | https://about.my.games/news/567 | 누적 5억 달러 | 회사 발표 |
| SRC-024 | Ninja Kiwi 의 AutoAttack 인수 | https://www.pocketgamer.com/bloons-td-6/ninja-kiwi-acquire-autoattack | Legion 신작 개발 | 2차 |
| SRC-025 | 111퍼센트 대 뉴노멀소프트 1심 | https://byline.network/2026/04/9-421/ | 부정경쟁 인정, 약 5억 5,700만 원 | 2차, 원문 확인 |
| SRC-026 | 전략 장르 설치당 광고비 | https://foxdata.com/en/blogs/2026-mobile-game-user-acquisition-cost-benchmarks-how-much-should-you-spend/ | iOS 약 5.5달러, Android 약 4.0달러 | 2차 집계 |

정책 출처(POL-###)는 `../policy-review.md` 에 있다. 공식 원문은 Google Play 광고 정책 https://support.google.com/googleplay/android-developer/answer/9857753 , Apple 심사 지침 https://developer.apple.com/app-store/review/guidelines/ , AdMob 보상형 광고 정책 https://support.google.com/admob/answer/7313578 , Firestore 할당량 https://firebase.google.com/docs/firestore/quotas 다.

## 경쟁작 매트릭스

직접 경쟁작(방어 + 상대에게 보내기)

| 게임 | 플랫폼·가격 | 한 판 | 1인 모드 | 평가 수 | 우리와 다른 점 |
| --- | --- | --- | --- | --- | --- |
| Legion TD 2 | PC, 유료 | 20~25분 | 캠페인(상대 7명), AI 난이도 10단계. 1인도 온라인 필수 | Steam 15,333건, 긍정 86% | PC·가로·긴 판. 모바일 없음(SRC-001~004) |
| Mechabellum | PC, 유료 + 무료판 | 미확인 | 연습 AI, 생존 모드, 로그라이트 모드(상대는 다른 이용자 편성 복제) | Steam 19,825건, 긍정 84% | 자동 전투 편성 대결. 보내기 경제 없음(SRC-005) |
| Bloons TD Battles 2 | 모바일·Steam, 무료 + 광고·결제 | 미확인 | AI 가 보내는 공격을 버티는 1인 챌린지 | iOS 52,241건 4.66점 | 실시간 대전이 본체. 강제 광고 불만(SRC-007, 010) |
| Rush Royale | 모바일, 무료 + 광고·결제 | 미확인 | 2인 협동 방어 | Play 77.2만 건 4.3점 | 뽑기·합성 중심, 보내기 없음(SRC-006) |
| Lucky Defense | 모바일, 무료 + 광고·결제 | 미확인 | 2인 협동이 핵심 | Play 21.6만 건 4.3점 | 뽑기 운 중심, 보내기 없음(SRC-006, 008) |

인접작(일일 도전)

| 게임 | 일일 도전 방식 | 순위표 문제 |
| --- | --- | --- |
| Slay the Spire | 전원 같은 시드와 변형 규칙으로 점수 경쟁(SRC-012) | 불가능한 점수, 부계정으로 같은 시드 연습(SRC-011) |
| Bloons TD 6 | 매일 챌린지 하나, 클리어 보상은 고정. 순위 경쟁은 주간 레이스(SRC-014) | 조작 기록이 보상 지급 전 삭제된다는 증언(SRC-013) |
| Isle of Arrows | 전원 같은 시작 지도, 최고 점수 순위(SRC-015) | 미확인 |

추론: "방어 + 보내기 + 수입"을 세로·오프라인·1인 로그라이크로 묶은 모바일 직접 경쟁작은 이번 검색에서 찾지 못했다. 부재를 확정한 것은 아니다.

## 리뷰와 플레이어 문제 종합

| 반복되는 불만 | 근거 | 우리 설계의 대응 |
| --- | --- | --- |
| 1인 플레이인데 온라인 필수, 끊기면 판이 날아감 | Legion TD 2, Lucky Defense, BTD Battles 2 리뷰(SRC-002, 007) | 오프라인 우선, 판마다 자동 저장과 이어하기 |
| 돈을 써야 이긴다 | Rush Royale, Lucky Defense, Random Dice(SRC-007) | 결제 상품이 없다. 런 안의 힘을 팔지 않음 |
| 강제 광고, 닫히지 않는 광고 | BTD Battles 2, Rush Royale(SRC-007) | **이 불만과 충돌하는 결정을 했다(DEC-003 개정: 전면 광고 주력).** 완화책: 판 도중에는 없음, 장 사이·런 사이에서만, 5초 안에 닫힘. 광고 제거 상품은 두지 않는다. 위험은 `00-product-brief.md` R-08 |
| 확률 조작 의심 | Lucky Defense, Random Dice(SRC-007) | 전투에 난수가 없다. 패배 화면이 원인을 그림으로 보여 준다 |
| AI 가 내 편성을 매 판 받아친다 | Mechabellum 생존 모드(SRC-002) | 지휘관은 성향대로 움직인다. 내 진영에 반응하는 것은 '저격' 한 종이고 직전 판만 본다고 도감에 밝힌다 |
| 배우기 어렵다 | Legion TD 2, Mechabellum(SRC-002) | 1장을 체험형 튜토리얼로, 계열과 용병을 장 보상으로 하나씩 연다 |
| 로그라이트 모드가 얕다 | Mechabellum(SRC-002) | 지휘관 6 × 장 속성 4 × 편성 × 증표로 조합을 만든다. 출시 뒤 지휘관을 더한다 |
| 느리고 정지가 안 된다 | Legion TD 2(SRC-002) | 언제든 정지, 2배속, 전투 건너뛰기 |

## 기회와 위험

기회

- 모바일 직계작이 없고, PC 원조 개발사는 모바일 이식 계획이 없다고 밝혔다(SRC-004).
- 경쟁작의 불만 중 과금과 온라인 필수는 "힘을 팔지 않는 오프라인 디펜스"라는 약속과 정확히 반대편에 있다. 강제 광고 불만은 우리도 전면 광고를 쓰므로 차별점이 아니다.
- 보상형 광고만 쓰는 로그라이크의 선례가 있다(SRC-022). 우리는 수익을 위해 전면 광고를 더하기로 했다.

위험

- 원조 IP 를 가진 Ninja Kiwi 의 모바일 신작 가능성(SRC-024).
- 전략 장르는 설치당 광고비가 높다(SRC-026). 사내 병목은 유입이다.
- 보상형 광고 단가는 2024년 4분기 기준 미국 Android 약 13달러, 한국 약 14달러, 중남미 약 1.8달러다(SRC-016). 소규모 신작은 더 낮을 수 있다.
- 일일 순위표는 인접작 모두에서 조작 문제가 보고됐다(SRC-011, 013).

벤치마크(GameAnalytics 2024년 데이터, 전략 장르 중앙값, SRC-019): D1 19.0~20.7%, D7 3.2~3.6%, D28 0.66~0.77%, 세션 5.3~5.6분, 하루 4.2~4.4회. 보상형 광고 시청 DAU 비율은 캐주얼 36%, RPG 37.6%(SRC-018, 전략 수치 없음).

## 검증할 가설

| ID | 가설 | 지표 | 검증 시점 |
| --- | --- | --- | --- |
| H-01 | 세 갈래 배분은 3런 안에 이해된다 | 튜토리얼 장 완료율, 2번째 런 시작률 | Core Gate |
| H-02 | 지휘관 성향 읽기가 재방문 이유가 된다 | 지휘관별 승률이 런 수에 따라 오르는가 | 소프트론칭 |
| H-03 | 한 런 6~10분이 전략 장르 세션(5~6분)과 맞는다 | 런 중단율, 런 길이 분포 | Vertical Slice |
| H-04 | 일일 도전이 D7 을 올린다 | 일일 도전 참여자와 비참여자의 D7 | 소프트론칭 |
| H-05 | 보상형 광고 2곳으로 DAU 20% 이상이 하루 한 번 본다 | 광고 시청 DAU 비율 | 소프트론칭 |
| H-06 | 장 사이 전면 광고는 D7 을 1%p 넘게 깎지 않는다 | 켠 집단과 끈 집단의 D1·D7, 평점 | 소프트론칭 |

## 결정 반영

| 조사 결과 | 반영한 결정 |
| --- | --- |
| 실시간·기록 대전의 불공정(사내 검산)과 경쟁작의 매칭·봇 불만 | PvE 전용 + 일일 도전(DEC-005) |
| 과금 불만 | 결제 상품 없음(DEC-024) |
| 강제 광고 불만 | 수익을 위해 전면 광고를 채택(DEC-003 개정). 자연 휴지 한정·닫기 5초로 완화(DEC-025) |
| AI 가 받아친다는 불만 | 지휘관은 성향대로, 반응형은 한 종만(DEC-012) |
| 순위표 조작 | 순위 보상 없음, 검증 방식은 DEC-007 |
| 온라인 필수 불만 | 오프라인 우선(DEC-006) |

## 구현 승인 반영 — 2026-10-06

제품 계약은 승인되었습니다. 현재 실행 원장은 이 문서와 `../../02-decisions/ADR-001-approved-product.md`입니다. 이름 Three Purses, 태엽 장난감 세계관, Android/iOS, 영어/한국어, 타깃 20~40대, 소프트론칭 캐나다·호주·한국, AdMob·Poing, 순위표 지연 검수로 확정했습니다. 과거 초안의 미확정 표기는 위 결정으로 대체됩니다. 아트 시안 선택·사람 테스트·실기기·마켓 확인은 별도 미완료 증거입니다.
