# Three Purses 제작·검증 상태

확인일: 2026-10-07. **기획 승인과 Core 소프트웨어 구현을 완료했다. 사람 검증은 0/5명으로 Core Gate는 아직 통과하지 않았다. 전체 게임 제작·출시 완료가 아니다.**

## 구현된 동작

- 정수 전투·분리 난수 흐름·표 기반 AI, 4장 원정과 길 선택, 금화 배분·배치·강화·교체, 포로·장 보상·훈장·편성 해금·격.
- 원자적 기기 저장, 검증된 백업 복구, 행동 기록 재생으로 복귀, 실패한 저장의 진행·보상 불변, 정산 중복 방지.
- 오프라인 일일 도전: UTC 날짜별 첫 시도 예약, 재시도는 연습, 기기 기록. 온라인 업로드·공개 순위표는 연결하지 않았다.
- 실제 초기화 후 시작, 홈·편성·도감·설정, 영어·한국어, 큰 글자·움직임 축소·전투 속도, 기기 저장 삭제 확인.
- 광고 노출 조건 검사만 구현. 실제 SDK·광고 노출·보상 지급은 없으며 모든 배치 기본값은 꺼져 있다.
- 서버용 보안 규칙과 Python 기록 재생 감사 도구. Firebase 프로젝트·Android/iOS 앱 등록만 완료했고 규칙은 운영에 배포하지 않았다.

## 재현 가능한 검사

| 검사 | 결과 | 명령·증거 |
| --- | --- | --- |
| 콘텐츠·순수 코어 경계 | 통과 | `bash scripts/check.sh` |
| 참조 전투·런 | 60/60 + 40/40, assertion 962 | `tests/run_vectors.gd` |
| 저장·복귀·정산·실패·백업 | 1,807 checks, 실패 0 | `tests/run_session.gd`, 별도 `user://tests-session/` |
| 광고 정책 | 16 checks, 실패 0 | `tests/run_ads.gd`. 실제 SDK 시험 아님 |
| 일일 재생 감사 | Python unittest | `tests/test_daily_verifier.py`: 벡터 40건, 거짓 결과·형식·음수 자리 거부 |
| 실제 렌더와 입력 | 83 checks, 실패·Godot 오류 0 | `tests/run_ui.gd`, Apple M3 OpenGL Compatibility |
| Firestore 권한 | 2 tests, 실패 0 | `firebase/rules.test.mjs`, `demo-three-purses` 로컬 에뮬레이터 |
| 승인 설계 구조 | 오류·경고 0 | `validate_design_pack.py --strict` |
| 수익화 정책 구조 | 오류 0, BM-073 경고 1 | 배치 스키마 밖 최소 플레이 원격 키를 `application/ad_policy.gd`에서 참조 |

UI 검사는 실제 슬롯 팝업 선택·일꾼 버튼·출전·전투 건너뛰기·결과 계속·승리 정산 닫기를 입력으로 확인한다. 참조 런의 행동 데이터와 길·보상 선택은 테스트에서 공급하며 사람 플레이테스트로 세지 않는다. 용병 최대 5종 상태의 360 폭도 검사했다. 목록 카드 위 드래그는 데스크톱 터치 에뮬레이션으로 확인했다. 한글 큰 글자 360×640, 390×844, 430×932 캡처와 버튼 경계를 확인했다.

저장 초기화가 필요한 자동 검사는 `user://tests-ui/`, `user://tests-session/`, `user://tests-startup/`만 사용한다. 실제 게임 기본 저장은 `user://save.json`이다. 확정 전 금화 배분 미리보기는 저장하지 않고, 출전이 성공한 판과 선택 결과를 저장한다.

## Android 개발 빌드

`build/android/three-purses-core.apk`는 ARM64 개발용 디버그 APK다. 마켓 제출용 키·AAB가 아니다. 패키지는 `com.seoleeapps.sendlaneduel`, 버전 0.1.0/1, targetSdk 36이다. 비 Gradle Godot 템플릿의 minSdk 24를 사용한다. 제품 지원 하한 28은 Production Gradle 빌드에서 적용한다.

Android 16 ARM64 에뮬레이터에서 실제 슬롯 터치 배치·출전·건너뛰기·판 정산과 강제 종료 후 저장 active/profile의 정확한 복귀를 확인했다. 이 장치의 페이지 크기는 **4KB**다. APK ZIP 16KB 정렬 검사와 실제 16KB 기기 실행은 다른 검사이며, 실제 휴대폰·iPhone·16KB 기기 QA는 미실시다. 최종 빌드 식별자와 추가 실행 증거는 `evidence/core-gate.json`에 기록한다.

## 다음 단계에 남은 항목

1. [사람 5명 테스트](core-playtest.md): 4명 이상 자발적 두 번째 런, 3런 후 지휘관 성향 2개 설명. 현재 0/5명. OP-01 상성 영향·욕심 지휘관·난이도는 이 결과로 다시 검산한다. 수치는 임의 변경하지 않았다.
2. [대표 화면 A/B 선택](../../assets/art/concepts/README.md). 생성 시안은 제품 아트·실행 화면이 아니다. 선택한 방향으로 튜토리얼 첫 세션·타이틀·실제 아트·사운드와 목표/실행 비교를 만든다.
3. Production: Firebase 익명 인증·클라우드 저장/충돌·온라인 순위와 일일 검수 작업, 네이티브 분석·오류 수집·원격 설정, AdMob/Poing 두 마켓 시험·5초 닫기·중복 보상 방지, 공통 우편과 지원/정책 연결.
4. Hardening/Release: 실제 Android·iPhone·16KB 기기, 복구·성능·접근성·현지화·마켓 정책·상표/유사성 검토, 서명 후보와 계정 소유권 확인. 심사 제출·공개 출시 권한은 아직 없다.

공통 아웃게임 검사 `validate_outgame.py --stage implementation` 및 `--stage release`는 **미통과**다. 튜토리얼·우편·관측 기능, 설정의 도움말·문의·정책 연결과 해당 실행 증거가 아직 없고, 출시 검사는 제품 아트·실기기·마켓 SDK 증거도 없다. Core 자동 검사를 이 전체 출시 검사 통과로 대신 기록하지 않는다. 실행 원장 `release/app-launch-ledger.json`의 schema-only 검사는 형식 검사이며 90개 적용 항목은 pending이다.

Firebase 운영 접근과 외부 Owner 초대·과금 조회 제약은 [Firebase 상태](../../firebase/README.md)에 기록했다. 자격증명 값·경쟁작 추출본은 이 저장소에 넣지 않았다.


## PR 검토

게임 PR #1의 Godot Core CI는 소스 commit `9991b2f`에서 통과했다. Copilot 리뷰를 두 차례 요청했지만 주간 사용 한도(HTTP 429)로 의견을 생성하지 못했다. 직접 검토에서 잘못된 행동의 부분 적용, 저장 실패 시 진행 확정, 일일 기록 삭제 후 재제출, 팝업 입력 중 화면 제거, 손상된 세션 번호·설정의 시작 오류를 확인·보정하고 회귀 검사를 통과시켰다. 이 기록은 동료 리뷰 완료를 뜻하지 않는다. 최신 PR HEAD 검사 상태는 GitHub에서 별도로 확인한다.
