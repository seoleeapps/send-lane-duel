# Three Purses 온라인 기반

프로젝트 `send-lane-duel`과 Android·iOS 앱 등록을 완료했다. 실제 서비스 연결·분석 수집·클라우드 백업·순위 집계는 Production 단계 작업이며 현재 개발용 게임은 로컬 저장만 사용한다.

- 운영 접근: 등록된 GCP 프로비저너와 Firebase 자동화, 사람 운영자는 `ih@seorilabs.com`.
- `wellknowngeek@gmail.com` Owner 직접 부여는 조직 정책 `ORG_MUST_INVITE_EXTERNAL_OWNERS`로 거부됐다. 초대·수락은 미완료이고 우회하지 않았다.
- 과금 연결 명령은 실행하지 않았다. Billing 상태 조회는 공용 프로젝트의 Cloud Billing API 비활성으로 실패했다. 무료 상태가 확인됐다고 기록하지 않는다.
- 네이티브 SDK 설정은 로컬 자격증명 저장소에서 빌드 시 주입한다. 분석을 Web Measurement Protocol으로 대체하지 않는다.
- 현재 보안 규칙과 인덱스는 로컬 검증 대상이며 운영 배포하지 않았다.

```bash
npm ci --ignore-scripts
~/.config/seorilabs/scripts/firebase-cli.sh emulators:exec \
  --project demo-three-purses --only firestore 'npm test'
```

지연 검수 도구는 `tools/verify_daily.py`. 내려받은 상위 100개 기록을 재생해 결과 감사 파일만 쓴다. 운영에서는 이 결과를 토대로 서버 권한으로 거짓 기록을 집계에서 제외하고 `top/current`를 갱신하는 일일 작업을 연결해야 한다. 현재 도구 실행은 클라우드 수정이나 예약 작업 등록을 하지 않는다.
