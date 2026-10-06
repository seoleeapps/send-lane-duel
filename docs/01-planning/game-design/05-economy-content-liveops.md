# 경제 콘텐츠 라이브옵스

- 제품명: Three Purses. 작업 id `send-lane-duel`
- 문서 상태: approved
- 소유자: syous
- 버전/수정일: v0.1 / 2026-10-06
- Source of truth: 재화 유입·소모, 밸런스 모델, 보상 일정, 콘텐츠 재고·예산, 카탈로그(생성 블록), 라이브옵스, 시뮬 증거, 원격 설정
- Depends on: `02-gdd.md` v0.1, `data/monetization/bm-profile.json`, `docs/07-qa/evidence/run-sim.json`
- Open blockers: Core 사람 플레이테스트, 대표 화면 방향 선택, 실기기·SDK·출시 검수
- 승인 근거: 2026-10-06 사용자 전체 제작 승인 및 구현 계획 실행 요청

## 재화 Source와 Sink

| 재화 | 범위 | 들어오는 곳 | 나가는 곳 | 팔거나 광고로 주나 |
| --- | --- | --- | --- | --- |
| 금화 | 런 안. 런이 끝나면 사라진다 | 시작 20, 판마다 수입(기본 12 + 일꾼 × 3 + 산 용병 묶음 수), 일찍 깬 전리품(아낀 판 × 12), 증표 | 유닛 10/14/22, 일꾼 10, 용병 묶음 8, 교체 | 아니오 |
| 성 체력 | 런 안 | 시작 26, 장 통과 +3, 증표 +6, 이어하기 광고(8 로 재시작) | 샌 적, 시간 초과 8/10/12/14 | 이어하기 보상형만(원정 한정, 런당 1회) |
| 훈장 | 계정 | 통과한 장 × 3, 완주 6, 일일 도전 첫 제출 5 | 편성 해금 30/60/100, 깃발 꾸미기 | 정산 2배 보상형 |

훈장으로 런 안의 힘을 사지 못한다. 편성은 선택지를 넓힐 뿐이고, 시뮬에서 기본 편성(첫 출정대 52.4%)이 가장 약한 편성이 아니다.

## 밸런스 모델

공식의 원장은 `02-gdd.md` 와 `data/core/rules.json` 이다. 여기서는 의도와 곡선만 적는다.

- 웨이브 체력 예산: 36 × 1.10^판(내림). 28판 동안 36 → 414.
- 금화 1당 막는 체력(1단계, 보통 상성, 8박): 저격대 5.6(단일), 포격대 4.8(3명 모두 맞을 때), 돌격대 4.8, 주술대 4.8. 3단계까지 올리면 누적 금화당 약 1.2배가 된다.
- 용병 금화 1당 체력: 무리 3.75, 정예 4.5. 방어가 금화당 더 효율적이므로 보내기는 **상성과 방식의 빈틈을 찌를 때만** 이득이다.
- 일꾼: 10 금화로 판마다 +3. 4판째부터 이득이고 런 후반 4판 안에서는 사지 않는 것이 맞다.
- 지휘관: 수입 배율 104~146%, 격마다 +12%. 시작 진영 예산 20/60/120/200.

난이도 목표와 현재값(`docs/07-qa/evidence/run-sim.json`, 1,000런, 격 0, 첫 출정대)

| 봇 | 뜻 | 완주율 | 목표 |
| --- | --- | --- | --- |
| 무작위 | 아무렇게나 | 0.1% | 5% 미만 |
| 균형·기억 없음 | 지휘관 용병을 예측하지 않음 | 9.6% | 초보의 상한 |
| 균형 | 도감 지식으로 예측 | 52.4% | 30~60% |
| 수비 | 넉넉히 막고 버팀 | 52.6% | 최선 대비 15%p 안 |
| 공격 | 일찍 깨고 전리품 | 38.8% | 최선 대비 15%p 안(13.8%p) |
| 균형·정보 상한 | 지휘관 용병을 정확히 앎 | 100% | 격으로 흡수 |

## 보상 일정

| 시점 | 보상 |
| --- | --- |
| 장 통과 | 3택 1(방어 계열, 용병, 증표), 성 체력 +3, 전리품 금화 |
| 런 정산 | 훈장(통과한 장 × 3, 완주 +6), 도감 칸 |
| 첫 완주 | 격 1 열림. 이후 완주마다 다음 격 |
| 훈장 30 / 60 / 100 | 편성 2 / 3 / 4번째 |
| 일일 도전 첫 제출 | 훈장 5 |

예상 속도(균형 봇 기준, 런마다 평균 2.55장 통과 → 훈장 약 11): 두 번째 편성까지 3런, 네 번째 편성까지 누적 약 17런.

## 콘텐츠 재고

| 종류 | 출시 | 조합 수 |
| --- | --- | --- |
| 지휘관 6 × 방어 계열 2개 조합 6 × 즐겨 쓰는 용병 8 | 288 가지 지휘관 변형 | 장마다 2명 제시 |
| 장의 웨이브 속성 | 4 | |
| 출정 편성 | 4 | |
| 장 보상 후보 | 계열 2 + 용병 6 + 증표 10 = 18 중 런마다 9개 제시 | |
| 격 | 6단계 | |

런 하나는 시드 하나로 결정된다. 일일 도전은 날짜에서 시드를 만든다.

## 콘텐츠 생산 예산

| 추가 단위 | 데이터 | 아트 | 검산 | 예상 공수 |
| --- | --- | --- | --- | --- |
| 지휘관 1명 | `commanders.json` 한 행. 새 고르는 법이면 코어 함수 추가 | 초상 2장, 성향 아이콘 | `run_sim.py --runs 1000` 에서 장 실패율 10~35% | 반나절 |
| 증표 1개 | `draft.json` 한 행. 새 효과 키면 코어 추가 | 아이콘 1 | 그 증표를 가진 런의 완주율 변화 ±10%p 안 | 2시간 |
| 방어 계열 1개 | `units.json` 한 행, 공격 속성 추가 시 상성표 확장 | 3단계 그림 | 편성별 완주율 재검산 | 하루 |
| 편성 1개 | `draft.json` 한 행 | 카드 그림 1 | 편성 완주율 40~60% | 2시간 |

상시 운영 인력이 없으므로 달마다 새 콘텐츠를 약속하지 않는다.

## 수익화 카탈로그

<!-- bm:ads:start -->
| 배치 | 형식 | 트리거 | 최초 노출 | 쿨다운 | 세션/일 상한 | 기본 상태 | 허들 | 원격 키 | 이벤트 |
| --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- |
| `interstitial_level_end` | 전면 | 레벨 종료 | 세션 2 | 120초 | 3 / 8 | 꺼짐 | 없음 | `interstitial_level_end_cooldown_s`, `interstitial_level_end_daily_cap`, `interstitial_level_end_enabled`, `interstitial_level_end_session_cap` | ad_requested, ad_impression, ad_failed |
| `rewarded_continue` | 보상형 | 레벨 실패 | 세션 1 | 120초 | 1 / 4 | 꺼짐 | 없음 | `rewarded_continue_cooldown_s`, `rewarded_continue_daily_cap`, `rewarded_continue_enabled`, `rewarded_continue_session_cap` | ad_requested, ad_impression, ad_failed, rewarded_earned |
| `rewarded_result_bonus` | 보상형 | 정산 화면 | 세션 1 | 60초 | 1 / 6 | 꺼짐 | 없음 | `rewarded_result_bonus_cooldown_s`, `rewarded_result_bonus_daily_cap`, `rewarded_result_bonus_enabled`, `rewarded_result_bonus_session_cap` | ad_requested, ad_impression, ad_failed, rewarded_earned |
<!-- bm:ads:end -->

`bm-profile.json` 에서 아래 블록을 `monetization/tools/render_catalog.py --write` 로 채운다. 손으로 고치지 않는다.

<!-- bm:catalog:start -->
| 항목 | SKU | 유형 | USD | Play KRW | App Store KRW | AIT KRW | 동기 | 허들 | 해금 | 복원 | 대전 영향 | 근거 |
| --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- |
| 상품 없음 | - | - | - | - | - | - | - | - | - | - | - | - |
<!-- bm:catalog:end -->

## 라이브옵스 캘린더

| 주기 | 내용 | 사람 손 |
| --- | --- | --- |
| 매일 | 일일 도전(시드 자동) | 없음 |
| 매주 | 없음(출시 범위) | 없음 |
| 분기 | 지휘관 1명 또는 증표 2개 추가 검토 | 데이터 + 검산 + 아트 |
| 수시 | 원격 설정으로 전면 광고 간격·한도·끄기, 보상형 한도, 난이도 상수 조정 | 지표 확인 뒤 |
| 출시 직후 | 전면 광고 켠 집단과 끈 집단 비교(`07-qa-launch-plan.md` 소프트론칭 실험) | 판정 1회 |

## 시뮬레이션 증거

- 명령: `python3 -I sim/run_sim.py --runs 1000 --json sim/out/run_sim.json`. 결과 `docs/07-qa/evidence/run-sim.json`.
- 지휘관별 장 실패율(균형 봇): 철벽 0.09, 돌격 0.15, 욕심 0.01, 변덕 0.15, 역습 0.21, 저격 0.33. 욕심이 너무 쉽고 저격이 가장 어렵다.
- 지휘관마다 최선 5%p 안의 운영이 둘 이상이다(철벽은 수비·균형, 돌격·욕심·역습은 세 운영 모두).
- 편성별 완주율(균형 봇): 첫 출정대 52.4%, 칼과 주문 40.6%, 긴 사거리 45.8%, 몰아치기 54.7%.
- 용병 하나를 못 쓰면 52.4% → 45.5%(중갑 무리 없이), 49.9%(외피 정예 없이).
- 격별 완주율(균형 봇, 500런): 48.6 → 43.0 → 35.0 → 32.8 → 31.0 → 23.8%.
- 일일 도전 점수: 같은 시드에서 봇 6종의 점수가 서로 다른 비율 62.8%. 동점 처리 규칙이 필요한 이유다.
- 통과하지 못한 것: 방어 계열과 웨이브 속성의 상성이 장 실패율을 낮추지 못한다(`02-gdd.md` OP-01). 욕심 지휘관 실패율 0.01 은 목표 범위(10~35%) 밖이다.
- 수익 시뮬: `python3 monetization/tools/simulate_ltv.py data/monetization/bm-profile.json --md -`. 프로필은 시제품 단계라 광고가 꺼져 있어 수익이 0 으로 나온다.
- 출시 단계로 가정한 추정(기획 저장소 `design/send-lane-duel/sim/out/ltv_launch_estimate.md`, 한국, 템플릿 목표 잔존 D1 28%·D7 12%·D30 5%, 광고 한도 최대치): 광고 ARPDAU 0.064달러(전면 0.058 + 보상형 0.007), LTV D90 0.39달러, D365 0.75달러. 매출은 전부 광고다. 광고 제거 결제를 뺀 영향은 약 2%다. 같은 가정에서 보상형만이면 LTV D90 은 약 0.04달러다.
- 이 추정은 입력의 56% 가 가설이다. 특히 전면 광고 단가(11.23달러)는 출처 없는 가설값이고, DAU 당 전면 5.4회 노출은 한도를 다 채웠을 때다. 잔존이 전면 광고로 깎이는 효과는 반영되지 않았다. 잔존이 20% 낮아지면 LTV D365 는 18% 준다.
- 손익 비교: 전략 장르 설치당 광고비는 Android 약 4달러(SRC-026)라 추정 LTV 0.4~0.75달러로는 유료 유입이 맞지 않는다. 유입은 계속 자연 유입이 전제다.

봇은 손으로 만든 요령이다. 사람의 재미와 실수는 반영하지 못한다.

## 원격 설정

<!-- bm:remote-config:start -->
| 키 | 타입 | 기본값 | 범위 | 용도 |
| --- | --- | --- | --- | --- |
| `interstitial_level_end_cooldown_s` | int | 120 | 0 ~ 600 | interstitial_level_end 쿨다운(초) |
| `interstitial_level_end_daily_cap` | int | 8 | 0 ~ 16 | interstitial_level_end 일 상한 |
| `interstitial_level_end_enabled` | bool | false | 해당 없음 | interstitial_level_end kill-switch |
| `interstitial_level_end_session_cap` | int | 3 | 0 ~ 6 | interstitial_level_end 세션 상한 |
| `interstitial_min_play_seconds` | int | 180 | 180 ~ 1800 | 전면 광고 첫 노출까지 실제 플레이한 시간. 최소 3분. |
| `rewarded_continue_cooldown_s` | int | 120 | 0 ~ 600 | rewarded_continue 쿨다운(초) |
| `rewarded_continue_daily_cap` | int | 4 | 0 ~ 12 | rewarded_continue 일 상한 |
| `rewarded_continue_enabled` | bool | false | 해당 없음 | rewarded_continue kill-switch |
| `rewarded_continue_session_cap` | int | 1 | 0 ~ 4 | rewarded_continue 세션 상한 |
| `rewarded_result_bonus_cooldown_s` | int | 60 | 0 ~ 600 | rewarded_result_bonus 쿨다운(초) |
| `rewarded_result_bonus_daily_cap` | int | 6 | 0 ~ 12 | rewarded_result_bonus 일 상한 |
| `rewarded_result_bonus_enabled` | bool | false | 해당 없음 | rewarded_result_bonus kill-switch |
| `rewarded_result_bonus_session_cap` | int | 1 | 0 ~ 4 | rewarded_result_bonus 세션 상한 |
<!-- bm:remote-config:end -->

게임 상수 중 원격으로 바꿀 수 있게 둘 것(기본값은 `rules.json`): `run.player_castle_hp`, `run.timeout_castle_damage`, `run.early_clear_gold_per_round`, `commander.income_pct`, `ascension.*`. 일일 도전에는 원격 값을 적용하지 않고 앱에 든 값만 쓴다(같은 날 같은 조건 보장).

## 구현 승인 반영 — 2026-10-06

제품 계약은 승인되었습니다. 현재 실행 원장은 이 문서와 `../../02-decisions/ADR-001-approved-product.md`입니다. 이름 Three Purses, 태엽 장난감 세계관, Android/iOS, 영어/한국어, 타깃 20~40대, 소프트론칭 캐나다·호주·한국, AdMob·Poing, 순위표 지연 검수로 확정했습니다. 과거 초안의 미확정 표기는 위 결정으로 대체됩니다. 아트 시안 선택·사람 테스트·실기기·마켓 확인은 별도 미완료 증거입니다.
