# 콩이 (가칭)

ADHD에 맞춘 iPhone + Apple Watch 앱. 식사·음주·복약을 한 앱의 세 모드로 관리한다.
지금은 **공통 뼈대 + 복약 모드**까지 만들어져 있다.

## 지금 되는 것

- 약 추가/수정: 이름, 먹는 시간(여러 개), 늦은 복용 마감 시간, 남은 개수
- 복약 알림: 예정 시각 + 안 누르면 10분·30분 뒤 다시 알림, 마감 시간 이후엔 알림 없음
- 알림에서 바로 "먹었어요" (워치로 온 알림에서도 가능)
- 두 번 먹기 방지: 2시간 안에 또 누르거나 오늘 횟수를 다 채웠으면 한 번 더 확인
- 남은 약이 7일분 이하면 "처방 챙길 때" 안내
- 포인트와 콩이 키우기: 포인트는 줄지 않고, 3일 넘게 쉬다 돌아오면 두 배
- Apple Watch 앱: 약 상태 보기, "먹었어요", 진동, 콩이 반응

## 내 iPhone과 워치에 설치하기

Mac이 꼭 필요하다.

1. Mac App Store에서 **Xcode**(16 이상)를 설치한다.
2. 터미널에서 XcodeGen을 설치한다 (Homebrew가 없으면 https://brew.sh 먼저):
   ```sh
   brew install xcodegen
   ```
3. 이 저장소를 받는다:
   ```sh
   git clone https://github.com/bboram0609-ux/to-do.git
   cd to-do
   ```
4. `project.yml`을 열어 `BUNDLE_ID_PREFIX: com.example`을 본인 것으로 바꾼다 (예: `com.bboram`).
5. 프로젝트를 만들고 연다:
   ```sh
   xcodegen
   open Kongi.xcodeproj
   ```
6. Xcode 왼쪽에서 `Kongi` 프로젝트 → `Kongi`, `KongiWatch` 타깃 각각 **Signing & Capabilities** → **Team**에서 내 Apple ID를 고른다.
7. iPhone을 USB로 연결하고, 위쪽 실행 대상에서 내 iPhone을 고른 뒤 ▶ 를 누른다.
   처음이면 iPhone **설정 → 개인정보 보호 및 보안 → 개발자 모드**를 켜야 한다.
   워치 앱은 iPhone 앱과 함께 설치된다 (안 되면 실행 대상을 `KongiWatch` + 내 워치로 바꿔 한 번 실행).

무료 Apple ID로 설치하면 **7일마다 다시 설치**해야 한다. 오래 쓰려면 Apple Developer Program(연 99달러)에 가입한다.

## 아직 확인하지 못한 것

이 코드는 Mac 없이 작성해서 **아직 한 번도 빌드해 보지 않았다.** 처음 빌드할 때 작은 오류가 날 수 있다.
오류 메시지를 그대로 복사해 주면 고친다. 특히 워치 앱을 iPhone 앱에 넣는 설정(`project.yml`의 `copy` 부분)은
실제 기기에서 확인이 필요하다.

## 폴더 구조

```
project.yml          Xcode 프로젝트 설정 (XcodeGen)
App/Shared/          iPhone·워치 공통: 콩이 그림, 대사, 복약 규칙
App/iOS/             iPhone 앱: 화면, 저장, 알림, 워치 연결
App/Watch/           워치 앱
```

- 콩이를 바꾸려면 `App/Shared/KongiView.swift`(그림)와 `KongiColors.swift`(색)만 고치면 된다.
- 대사는 `App/Shared/KongiLines.swift`에 있다.

## 다음 단계

1. 실기기 빌드 확인
2. 워치 시계 화면 표시(컴플리케이션)와 iPhone 홈 화면 위젯
3. 식사 모드 → 음주 모드 → 세 모드 연결
