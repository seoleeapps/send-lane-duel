# Three Purses 제작·검증 상태

확인일: 2026-10-07. **장난감 아트·전투 움직임·음악과 효과음·직접 조작하는 3턴 연습을 적용한 0.1.1/2를 Google Play 내부 테스트에 배포했다.** Seolee Apps 콘솔에서 활성·내부 테스터에게 제공됨을 다시 확인했고, [참여 링크](https://play.google.com/apps/internaltest/4701444918455309978)를 두 본인 Google 계정에서 확인했다. 사용자의 “게임으로 만든 후에 다시 볼게” 요청으로 사람 검토를 이 빌드 이후로 옮겼다. 사람 결과는 0/5명이며 최종 시각 승인·재미 검증·온라인 서비스·공개 출시는 남아 있다. 제작 순서와 내부 테스트 승인 근거는 [ADR-001](../02-decisions/ADR-001-approved-product.md)이다.

## 플레이 동작

- 첫 시작: 수비병 배치 → 일꾼 추가 → 공격 병력 3묶음을 실제 전투로 해보는 3턴 연습. 필요한 조작을 강조하며 배치·다음 수입·성 체력의 변화를 보여 준다. 건너뛰기·중단 복귀·설정에서 다시 배우기를 지원한다.
- 연습 저장과 원정 진행·훈장을 분리했다. 출전 전 배분과 출전 후 결과를 저장하고, 결과 확인 전 강제 종료하면 같은 결과로 복귀한다. 완료를 조작 없이 체크하거나 영구 보상을 반복 지급하지 않는다.
- 태엽 병사·성·나무 작업대·황동 버튼, 병력 이동·타격·체력·누수·강화 표시, 길·보상·편성 그림과 전체 콘텐츠 도감을 적용했다. B 방향은 구현자가 채택한 기준이며 사용자 승인으로 기록하지 않았다. [실행 비교](playable-visual-review.md).
- BGM 3개·효과음 13개를 실제 화면과 전투에 연결했다. 소리 끄기·큰 글자·움직임 축소·전투 속도를 지원한다. 영어·한국어.
- 정수 전투와 기존 수치, 4장 원정·길 선택·배분·배치·강화·교체·포로·장 보상·훈장·편성 해금·격, 원자적 저장·검증된 백업·기록 재생 복귀·중복 정산 방지는 유지한다.
- 오프라인 일일 도전: UTC 날짜별 첫 시도 예약, 재시도는 연습, 기기 기록. 온라인 순위는 연결하지 않았다. 광고는 노출 조건 검사만 있으며 실제 SDK·노출·광고 보상 지급은 꺼져 있다.

## 검증

| 검사 | 결과 | 증거 |
| --- | --- | --- |
| 콘텐츠·순수 코어 경계 | 통과 | `bash scripts/check.sh`, `evidence/core-check.txt` |
| 참조 전투·런 | 60/60 + 40/40, assertion 962 | `tests/run_vectors.gd` |
| 저장·복귀·정산·실패·백업 | 1,807 checks, 실패 0 | `tests/run_session.gd` |
| 실제 연습·완료·중단·실패·중복 방지 | 56 checks, 실패 0 | `tests/run_practice.gd` |
| 광고 정책 | 16 checks, 실패 0 | `tests/run_ads.gd`. 실제 SDK 시험 아님 |
| 일일 재생 감사 | Python 3 tests, 실패 0 | 기존 정상/위조/형식 검사 |
| 실제 렌더와 입력 | 202 checks, 실패·Godot 오류 0 | `tests/run_ui.gd`, Apple M3 OpenGL Compatibility, `evidence/ui-check.txt` |
| Android 16 ARM64 | 3턴 실제 터치·배분/결과 강제 종료 복귀·APK 갱신 후 저장 보존 통과 | `evidence/android-runtime.json` |
| 실제 APK 구성 | 제외 자원 0, ARM64 ZIP·ELF 16KB 정렬 통과 | `tools/inspect_core_apk.py`, `evidence/apk-inspection.json` |
| BGM 디코딩 | 3개 모두 클리핑 0 | `evidence/audio-decoded.json`. 사람 청취는 미실시 |
| Firestore 권한 | 기존 2 tests 통과, 이번 변경 없음 | `evidence/firebase-rules.txt`, 로컬 에뮬레이터. 운영 배포 없음 |

UI 자동 입력은 첫 시작·연습 3단계·도감 4탭·슬롯 선택·일꾼·최대 용병 5종·출전·전투 결과·참조 원정 승리 정산을 확인한다. 한국어 큰 글자 360×640·390×844·430×932의 버튼 경계와 실제 화면을 확인했다. 참조 런의 길·보상 데이터 일부는 테스트가 공급한다. 사람 플레이테스트로 세지 않는다.

분리 경로를 명시한 정상 저장 초기화 자동 검사는 `user://tests-ui/`, `user://tests-session/`, `user://tests-startup/`만 사용한다. 실제 게임 기본 저장은 `user://save.json`이다. Android 검사는 별도로 만든 빈 테스트 AVD에서 이 패키지의 기본 저장을 썼으며 기존 사용자 AVD·기기 저장은 변경하지 않았다.

## Android 빌드

[개발용 APK](../../build/android/three-purses-playable.apk)는 0.1.1/2, `com.seoleeapps.sendlaneduel`, ARM64 디버그 APK다. targetSdk 36, 비 Gradle Godot 템플릿 minSdk 24다. 서명·마켓 제출용 AAB가 아니다. 동결 소스 SHA·APK SHA는 `evidence/android-build.json`에 기록했다.

[내부 테스트용 AAB](../../build/android/three-purses.aab)는 Godot 4.7.2 공식 Gradle 템플릿과 앱 전용 업로드 키를 사용한 release 빌드다. 제품 지원 하한 minSdk 28, targetSdk 36, ARM64, 게임 분류를 실제 매니페스트에서 확인했다. bundletool 검증·서명 지문 대조·ELF 16KB 정렬·AAB에서 생성한 APK의 ZIP 16KB 정렬을 통과했다. 이 APK를 별도 Android 16 ARM64 4KB AVD에 설치하여 첫 실행·수비병 배치와 첫 전투·연습 2단계 강제 종료 복귀를 확인했다. 서명키는 저장소 밖 카탈로그에 등록하고 로컬·BeeStation 암호화 백업의 임시 복원을 통과했다. [빌드 절차](../../play-store/README.md), [후보·배포 기록](../../release/internal-0.1.1-2.json), [콘솔 재조회](evidence/play-internal-release.txt).

내부 테스트는 활성 상태이며 본인 계정 2개만 포함한 `Three Purses owner QA` 목록을 선택했다. 실제 Play Store 설치는 아직 확인하지 않았다. 초기 내부 테스트여서 Play에 `com.seoleeapps.sendlaneduel (unreviewed)`가 표시된다. 공개 스토어 등록·심사·프로덕션 출시는 별도다. 콘솔의 가독화 파일·네이티브 디버그 기호 미업로드 경고 2개는 출시 차단 오류가 아니며 기록에 남겼다.

Android 16 에뮬레이터의 페이지 크기는 **4KB**다. ZIP/ELF 정렬 통과는 실제 16KB 기기 실행과 다르다. 실제 휴대폰·iPhone·16KB 기기 검사는 미실시다. 새 AVD 초기 실행 중 OS가 Activity를 다시 시작한 것은 별도로 조사했고, 안정된 콜드 스타트·터치·저장 복귀의 해당 게임 PID 로그에서 `SCRIPT ERROR`, `ERROR:`, `FATAL EXCEPTION`, `Fatal signal`은 0건이었다.

## 남은 제작·출시 조건

1. [사람 5명 테스트](core-playtest.md): 4명 자발적 두 번째 런·3런 후 지휘관 성향 2개 설명. 현재 0/5명. 사용자 요청으로 아트·안내를 적용한 빌드 이후 실시한다. 밸런스는 임의 변경하지 않았다.
2. 사용자 시각·조작성·음향 검토. 전체 첫 세션 시나리오, 적 구별 그림·전체 에셋 인수조건, 실제 기기 성능·접근성·현지화 검수는 남아 있다.
3. Production: Firebase 익명 인증·클라우드 저장/충돌·온라인 순위와 일일 재생 검수 작업, 분석·오류 수집·원격 설정, AdMob/Poing 마켓별 동작·닫기·중복 보상 방지, 우편·문의·정책 연결.
4. Hardening/Release: 실제 Android·iPhone·16KB 기기, Play 설치 확인, 마켓 정책·상표/유사성 검토, 출시 서비스가 포함된 서명 후보와 iOS archive. Android 내부 테스트 배포만 승인됐으며 과금 연결·심사 제출·공개 출시 권한은 없다.

공통 아웃게임 전체 검사는 **미통과**다. 실제 연습 연결은 구현했지만 공통 영구 튜토리얼 보상 키는 채택하지 않았고, 설정의 지원/정책·우편·관측 기능·전체 계약 증거가 없다. 현재 검사 결과는 프로필/증거 감사이며 저장소 테스트를 별도로 실행했다. 출시 검사에는 실제 기기·최종 시각 승인·마켓 SDK 증거도 없다. [출시 원장](../../release/app-launch-ledger.json)의 90개 항목은 pending이며 로컬 빌드 완료를 출시 조건 전체 통과로 세지 않는다.

Firebase 프로젝트·Android/iOS 앱 등록만 완료했다. 운영 접근·Owner 초대·과금 조회 제약은 [Firebase 상태](../../firebase/README.md)에 있다. 자격증명 값·경쟁작 추출본은 저장소에 없다.

## 검토 기록

연습 저장은 출전 전체 검증→원자적 저장 성공→표시 순서이며 본 원정/훈장은 분리한다. 전투 그림은 저장된 결과를 읽어 재생하고 전투 계산을 수정하지 않는다. 직접 검토와 자동 검사로 저장 실패·잘못된 연습 행동·중복 출전·완료/건너뛰기·규칙 버전 변경·화면 전환·작은 화면 입력을 확인했다. Copilot의 요청·응답 및 최신 PR HEAD CI는 GitHub PR에 따로 기록한다.


### Mac 개발 저장 변경 사고

2026-10-07 09:48 UI 재검사 명령에서 `-- --save=user://tests-ui/save.json`을 빠뜨려 Mac 기본 `user://save.json`에 연습 완료·시험 훈장·편성 해금·참조 런 정산을 기록했다. 변경 전 원정 상태의 정확한 복사본을 찾지 못했으며 이전 진행을 완전히 복구하지 못했다. 현재 기본 저장과 `.bak`는 `build/qa/mac-save-incident/`에 별도 보존했고 추가 초기화·복구 덮어쓰기는 하지 않았다. APK/사용자 Android 장치의 저장은 이 사고에 포함되지 않는다.

`tests/run_ui.gd`는 지정한 분리 경로 인자가 없으면 Main을 생성하기 전에 종료한다. 경로 없는 재현 검사에서 실패 코드 1과 기본 저장/백업 SHA 불변을 확인했고, 올바른 경로의 실제 렌더 검사는 202개 통과했다. 증거: `evidence/ui-save-guard.json`. 이전의 실패 캡처는 올바른 경로 검사 결과로 다시 생성했다.
