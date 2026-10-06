# 정책 검토 — 유사성, 상표, 스토어 정책

- 문서 상태: draft
- 버전/수정일: v0.1 / 2026-10-06
- Source of truth: 유사성 감사표, 금지 목록, 정책 근거 POL-###
- 법률 자문이 아니다. 출시 전 변호사의 유사성 검토와 상표 조회가 론칭 게이트다(`game-design/07-qa-launch-plan.md`).

## 1. 왜 조심해야 하는가

- 이 게임은 스타크래프트·워크래프트 3 유즈맵에서 이어진 "방어 + 수입 + 상대에게 보내기" 장르의 구조를 쓴다.
- 장르의 추상적 규칙은 미국·한국·중국에서 일반적으로 보호 대상이 아니다. 위험은 두 가지다.
  - 블리자드와 원작 맵의 고유 표현: 이름, 종족·유닛, 그림, 지형, 수치표, 문구.
  - 특정 게임의 규칙 **조합과 표현 방식**을 통째로 따르는 것. 한국은 대법원 2019. 6. 27. 선고 2017다212095 가 규칙의 선택·배열·조합에 창작성이 있으면 보호한다고 했고, 2026-04-02 서울중앙지법은 랜덤 디펜스 게임 사이의 모방을 부정경쟁으로 인정해 약 5억 5,700만 원 배상을 명했다(SRC-025).
- 블리자드 약관은 커스텀 게임의 개념과 아이디어까지 자사 소유라고 적지만, 계약 당사자가 아닌 제3자를 직접 묶지는 못한다. 그래도 맵 파일, 데이터, 문구를 옮기는 것은 실제 위험이다.

## 2. 금지 목록

- 블리자드 작품과 원작 맵의 이름, 종족·세력·유닛 이름, 그림, 소리, 대사, 지형 배치.
- "LEGION TD"(미국 등록상표 4787210)와 비슷한 이름. "유즈맵", "○○ 모바일판" 같은 출처 연상 문구.
- 원작과 경쟁작의 유닛 목록, 수치표, 웨이브 표, 용병 목록을 참고해 수치를 정하는 것. 이 팩의 수치는 `sim/run_sim.py` 검산에서 나왔다.
- 경쟁작 화면을 참조 그림으로 쓰는 생성.
- 판타지 종족 군대, SF 군대 세계관(DEC-023).
- 뽑기 소환과 같은 유닛 합성을 핵심으로 쓰는 것(랜덤 디펜스 계열과의 조합 유사성).

## 3. 유사성 감사표

| 요소 | 장르 공통 | Legion TD 계열 | 랜덤 디펜스 히트작 | 이 게임 |
| --- | --- | --- | --- | --- |
| 내 레인을 유닛으로 방어 | 공통 | 있음 | 있음 | 있음 |
| 수입에 투자 | 공통 | 일꾼 | 없음 또는 다른 형태 | 일꾼 |
| 상대에게 유닛을 보내면 수입 증가 | 장르 하위 공통(여러 게임에 존재) | 있음 | 없음 | 있음 |
| 상대 | — | 실시간 사람, 팀전 | 실시간 협동·대전 | **AI 지휘관 1명, 성향표 공개** |
| 한 판 구조 | — | 웨이브 연속, 20분 이상 | 웨이브 연속 | **장 4개 × 최대 7판, 장마다 성 체력 대결** |
| 승패 | — | 왕 유닛 방어 | 누수 한도 | **지휘관 성을 제한 판 수 안에 함락, 못 하면 성 피해를 받고 통과** |
| 유닛 획득 | — | 진영별 유닛 목록에서 구매 | 무작위 뽑기와 합성 | **계열 4개 × 3단계, 자리 6칸, 편성으로 일부만 사용** |
| 전투 | — | 실시간 유닛 전투 | 실시간 | **박자 8번의 결정론 계산, 난수 없음** |
| 정보 | — | 상대 진영 관전 가능 | — | **지휘관 방어는 공개, 보낼 용병은 비공개** |
| 막아 낸 적의 처리 | — | 없음 | 없음 | **포로가 되어 다음 판 공짜 용병** |
| 런 구조 | — | 없음 | 일부 | **길 선택, 장 보상 3택 1, 격** |
| 수익화 | — | 유료 판매 | 뽑기·패스·광고 | 전면·보상형 광고(장르 공통 관행), **결제 상품 없음** |

굵은 글씨가 자체 규칙이다. 공통 요소는 세 줄, 자체 규칙은 아홉 줄이다. 화면 배치, 용어, 수치는 독자적으로 만든다. 이 표는 출시 전 법률 검토의 입력이다.

## 4. 스토어·광고·개인정보 정책 근거

접근일은 모두 2026-10-06. 확인 수준 A 는 원문 대조, B 는 공식 페이지 요약 확인, C 는 검색 요약.

| ID | 요구사항 | 우리 설계 | 출처 | 확인 |
| --- | --- | --- | --- | --- |
| POL-001 | 예상 밖 전면 광고 금지(앱 실행 직후, 화면을 떠날 때, 플레이 도중 등). 전면 광고는 15초 안에 닫을 수 있어야 한다. 보상형은 명시적으로 선택한 경우 예외 | 전면은 장 사이·런 사이의 전환 지점에서만, 5초 안에 닫기. 보상형은 버튼으로만 | https://support.google.com/googleplay/android-developer/answer/9857753 | B |
| POL-002 | 대상에 아동이 포함될 때 Families 정책 적용 | 13세 이상으로 선언 | https://support.google.com/googleplay/android-developer/answer/9893335 | B |
| POL-003 | 아동 대상이 아닌데 스토어 그림이 아동에게 소구하면 반려 가능 | 스토어 그림을 전략 게임으로 읽히게 | https://support.google.com/googleplay/android-developer/answer/9867159 | B |
| POL-004 | 데이터 안전 양식 필수, SDK 수집분 포함 | 익명 id, 닉네임, 광고 id, 분석·충돌 신고 | https://support.google.com/googleplay/android-developer/answer/10787469 | B |
| POL-005 | 처리방침 링크를 콘솔과 앱 안에 | 설정에 링크 | https://support.google.com/googleplay/android-developer/answer/10144311 | B |
| POL-006 | 계정 생성을 허용하면 앱 안 삭제 경로와 웹 링크 필요. 익명 계정 해당 여부는 명시 없음 | 삭제 버튼 + 웹 요청 페이지 | https://support.google.com/googleplay/android-developer/answer/13327111 | B |
| POL-007 | 2026-08-31 부터 신규 앱과 업데이트는 API 36 이상 대상 | targetSdk 36 | https://support.google.com/googleplay/android-developer/answer/11926878 | A |
| POL-008 | API 35 이상 대상 앱은 16KB 페이지 지원. 2027-02-01 부터 미대응 업데이트 차단 | 네이티브 라이브러리 정렬 검사 | https://developer.android.com/guide/practices/page-sizes | A |
| POL-009 | IARC 설문 등급 필수 | 설문 응답 | https://support.google.com/googleplay/android-developer/answer/9898843 | B |
| POL-020 | Apple 3.1.1: 기능 잠금 해제(광고 제거 포함)는 앱 내 구입을 쓰고 복원 수단을 둔다. 3.2.2: 광고 노출을 인위적으로 늘리거나 광고 표시가 주목적인 앱 금지 | 결제 상품이 없어 3.1.1 은 해당 없음. 전면은 한도 안에서만 | https://developer.apple.com/app-store/review/guidelines/ | B |
| POL-021 | Apple 5.1.1(i): 처리방침 링크와 수집 항목 명시 | 처리방침 | 같은 문서 | B |
| POL-022 | Apple 5.1.1(v): 계정 생성을 지원하면 앱 안 삭제 제공. 자동 생성 계정도 대상 | 설정의 계정·데이터 삭제 | https://developer.apple.com/support/offering-account-deletion-in-your-app/ | B |
| POL-023 | 추적은 허용 요청(ATT) 필요. 허용을 조건으로 보상 금지 | SDK 초기화 전 요청, 거부해도 광고 동작 | https://developer.apple.com/app-store/user-privacy-and-data-use/ | B |
| POL-024 | 개인정보 라벨에 SDK 수집분 신고 | 신고 | https://developer.apple.com/app-store/app-privacy-details/ | B |
| POL-025 | 개인정보 매니페스트와 필수 사유 API 선언 | 내보내기 산출물 확인 | https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api | B |
| POL-027 | 연령 등급 4+/9+/13+/16+/18+. 잦은 카툰 폭력은 13+ | 설문 결과로 확정 | https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions | B |
| POL-028 | Apple 2.3.10: 다른 모바일 플랫폼 이름·아이콘 금지 | iOS 문구·화면 분리 검수 | https://developer.apple.com/app-store/review/guidelines/ | B |
| POL-029 | Apple 4.1, 4.3: 모방 앱, 타사 이름·브랜드 사용 금지 | 2절 금지 목록 | 같은 문서 | B |
| POL-040 | AdMob 보상형: 명확한 선택과 사전 고지, 건너뛰어도 정상 이용, 현금성 보상 금지 | 버튼에 보상 명시 | https://support.google.com/admob/answer/7313578 | B |
| POL-041 | 유럽·영국·스위스는 인증 동의 관리 플랫폼 필요 | UMP | https://support.google.com/admob/answer/13554116 | B |
| POL-044 | Google Mobile Ads SDK 공식 플랫폼에 Godot 없음 | DEC-008 | https://developers.google.com/admob/android/quick-start | B |
| POL-045 | Godot 용 AdMob 은 커뮤니티 플러그인(Godot 4.5 이상) | 후보 | https://github.com/poing-studios/godot-admob-plugin | B |
| POL-046 | AppLovin MAX 공식 Godot 4 플러그인 | 후보 | https://support.applovin.com/en/max/godot/overview/integration | B |
| POL-062 | 확률형 아이템은 유상 구매 아이템이 대상 | 유료 상품 없음, 광고 보상은 확정 보상 | https://www.law.go.kr/LSW/lsLawLinkInfo.do?lsJoLnkSeq=900555115&lsId=010196&chrClsCd=010202 | B |
| POL-064 | 개인정보 처리방침 수립·공개 의무 | 한국어 처리방침 | https://www.pipc.go.kr/np/cop/bbs/selectBoardList.do?bbsId=BS217&mCode=D010030000 | C |
| POL-082 | Firestore 무료 할당: 읽기 5만, 쓰기 2만/일 | 제출 1쓰기, 조회 1읽기 | https://firebase.google.com/docs/firestore/quotas | B |
| POL-083 | Cloud Functions 배포는 Blaze 요금제 필요 | DEC-007 A 안의 조건 | https://firebase.google.com/docs/functions/get-started | B |
| POL-084 | App Check 공식 플랫폼에 Godot 없음 | 규칙으로만 방어 | https://firebase.google.com/docs/app-check | B |
| POL-100 | Android 터치 영역 48×48dp | UI 기준 | https://support.google.com/accessibility/android/answer/7101858 | B |
| POL-102 | Apple 컨트롤 44×44pt | UI 기준 | https://developer.apple.com/design/human-interface-guidelines/accessibility | A |
| POL-103 | Apple 안전 영역 준수 | UI 기준 | https://developer.apple.com/design/human-interface-guidelines/layout | A |
| POL-104 | Android targetSdk 35 이상은 끝까지 그리기 강제 | 인셋 처리 | https://developer.android.com/develop/ui/views/layout/edge-to-edge | B |

## 5. 확인하지 못한 것

1. Google 이 익명·자동 생성 계정을 계정 삭제 정책 대상으로 보는지.
2. 게임물관리위원회 자체등급분류 사업자 지정 현황에 두 마켓이 지금 포함되는지.
3. 광고 시청으로 얻는 보상에 대한 한국의 별도 규제 유무.
4. Godot 4 의 targetSdk 36 공식 지원 버전, 광고 플러그인의 16KB·개인정보 매니페스트 대응.
5. 제품명 후보의 USPTO, KIPRIS, EUIPO 상표.
6. Apple 지침에서 보상형 광고를 직접 허용하는 조항(관행상 허용으로 판단).

모두 Release 게이트 전에 다시 확인한다.
