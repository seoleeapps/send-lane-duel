# Google Play 내부 테스트

Three Purses `com.seoleeapps.sendlaneduel`의 0.1.1/2 오프라인 플레이 빌드를 Seolee Apps 계정에 배포했다. [참여 링크](https://play.google.com/apps/internaltest/4701444918455309978)에서 본인 Google 계정으로 테스트 참여 후 설치한다. 초기 테스트의 Play 표시 이름은 `com.seoleeapps.sendlaneduel (unreviewed)`다.

- [후보와 배포 상태](../release/internal-0.1.1-2.json)
- [실제 콘솔 재조회](../docs/07-qa/evidence/play-internal-release.txt)
- [참여 목록 재조회](../docs/07-qa/evidence/play-internal-testers.txt)
- [실행 로그](../docs/07-qa/evidence/internal-runtime.txt)

## 서명 AAB 재현

Godot 4.7.2와 공식 export template, Android SDK API 36·JDK 17을 준비하고 Godot Android 편집기 설정의 SDK/JDK 경로를 확인한다. 업로드 키는 `seorilabs-credentials`로 `app/send-lane-duel/google-play/upload-key`를 확인한다. 다른 앱 키를 사용하거나 비밀번호를 저장소에 넣지 않는다.

공식 `android_source.zip` SHA-256은 `a15416b528efb0a19a7d187e4d9f4e5336d0689144b111329fb4bd12c4447ad3`이다. bundletool 1.18.3 공식 JAR SHA-256은 `a099cfa1543f55593bc2ed16a70a7c67fe54b1747bb7301f37fdfd6d91028e29`이다.

```sh
python3 tools/export_android.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --template "$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/android_source.zip" \
  --bundletool build/tools/bundletool-all-1.18.3.jar \
  --upload-keystore "$HOME/.config/seorilabs/play-store/send-lane-duel-upload.jks" \
  --upload-env "$HOME/.config/seorilabs/play-store/send-lane-duel-keystore.env"
```

도구는 공식 템플릿 체크섬과 버전을 확인하고, 실행 권한을 포함해 생성용 `android/build`를 준비한다. 키·비밀번호는 환경변수로 내보내기에 전달하고 출력에서 숨긴다. 최종 AAB의 런타임 데이터·제외 자원·ARM64 구성·지원 API·게임 분류·디버그 여부를 검증한다. 기존 다른 버전 템플릿은 덮어쓰지 않는다. 산출물은 `build/android/three-purses.aab`다. 이 명령은 업로드나 출시를 수행하지 않는다.

새 업로드에는 기존 내부 트랙·버전 코드·업로드 인증서 지문을 먼저 확인하고 더 높은 버전 코드를 사용한다. 현재 후보 지문과 실제 AAB SHA-256은 배포 기록에 있다. Play App Signing의 앱 서명키와 로컬 업로드 키는 별도다.

## 남은 검증

내부 테스트 콘솔 상태와 두 본인 계정의 참여 초대 화면은 확인했다. 별도 Android 16 ARM64 4KB AVD에 AAB에서 생성한 APK를 설치해 첫 실행·연습 전투·강제 종료 복귀를 확인했다. 실제 휴대폰에서 Play Store 설치·16KB 기기·재미와 아트·음향 검토는 남아 있다. 온라인·광고 SDK는 이 후보에 포함되지 않는다. 프로덕션 공개·App Store 제출은 수행하지 않았다.
