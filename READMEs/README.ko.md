<h1 align="center">EhPanda</h1>

<h4 align="center">iOS의 비공식 E-Hentai 애플리케이션</h4>

<p align="center">
<img src="https://user-images.githubusercontent.com/31207151/105609404-0acbff00-5de4-11eb-9e88-f3c6e0ba9d44.png" width="400"></img>
</p>

<p align="center">
  <a href="/README.md">English</a>・
  <a href="/READMEs/README.de.md">Deutsch</a>・
  <a href="/READMEs/README.ko.md">한국어</a>・
  <a href="/READMEs/README.jpn.md">日本語</a>・
  <a href="/READMEs/README.cht.md">繁體中文</a>・
  <a href="/READMEs/README.chs.md">简体中文</a>
</p>

## 다운로드
1. [Releases](https://github.com/EhPanda-Team/EhPanda/releases)에서 ipa 파일을 다운로드 받으세요.
2. [AltStore](https://altstore.io)를 사용해서 ipa 파일을 설치할 수 있습니다.

## 시스템 요구 사항
iOS / iPadOS 버전이 26.0 이상인지 확인해주세요.

## 컨텐츠와 저작권
이 앱의 내용은 E-Hentai을 통해 제공되고, E-Hentai의 모든 내용은 앱 이용자가 만듭니다.

**사용자 스스로가 E-Hentai를 방문하는 책임을 지는 것에 동의합니다.**

## 분석
EhPanda는 어떤 기능이 중요한지 관리자가 파악할 수 있도록 익명 분석 데이터를 [TelemetryDeck](https://telemetrydeck.com)에 전송합니다. **기본적으로 켜져 있으며, 설정 → 일반 → 분석에서 언제든지 끌 수 있습니다.**

전송되는 데이터는 사용 상황을 대략적으로 나타냅니다. 어떤 화면과 패널을 열었는지, 검색은 본문이 아니라 형태로(단어 수, 태그 문법 사용 여부, 검색어 길이, 결과 개수의 대략적인 범위), 읽기 세션은 페이지 수와 시간의 구간으로, 다운로드 결과(완료 또는 실패 등), 발생한 오류의 종류, 그리고 모든 이벤트에 함께 전송되는 여섯 가지 앱 설정(갤러리 사이트, 로그인 상태, 읽기 방향, 양면 보기 모드, 태그 번역, 목록 표시 방식)입니다. 갤러리의 식별자·토큰·제목, 갤러리나 페이지의 URL, 검색어 텍스트, 태그 값, 사용자 이름, 쿠키를 비롯한 모든 자격 증명, 파일 경로는 결코 포함되지 않습니다.

또한 모든 이벤트에는 TelemetryDeck SDK가 자체적으로 덧붙이는 표준 기술 정보가 포함됩니다. 기기 모델과 아키텍처, 화면 크기·배율·방향, 운영체제 버전, 앱 버전과 빌드 번호, 디버그 또는 시뮬레이터 빌드 여부, 언어·지역·문자 배열 방향·시간대, 그리고 해당 이벤트가 전송된 날짜와 시각입니다. 여기에 더해 시스템 화면 모드와 손쉬운 사용 설정(밝은 모드 또는 어두운 모드, 텍스트 크기, 굵은 텍스트, 동작 줄이기, 투명도 줄이기, 색상 반전, 대비 증가, 색상 없이 구분)과 사용량을 나타내는 집계값(처음 연 날짜, 세션 횟수, 사용한 날짜 수, 세션 길이)도 전송됩니다.

이벤트에는 TelemetryDeck에 내장된 익명 설치 식별자가 포함되며, 이 값은 기기에서 해시 처리된 뒤에 전송되고 TelemetryDeck은 IP 주소를 보관하지 않습니다. 이 식별자는 사용자 본인과 연결되지 않으며, iOS가 기기의 공급업체 식별자를 다시 생성할 때, 즉 같은 개발자의 앱을 모두 삭제할 때 초기화됩니다. 데이터 처리 방식은 [TelemetryDeck 개인정보 처리방침](https://telemetrydeck.com/privacy)을 참고하세요.

"분석 데이터 공유"를 끄면 위에 설명한 모든 이벤트와 그에 함께 전송되던 여섯 가지 앱 설정의 전송이 중단됩니다. 다만 얼마나 많은 사람이 앱을 사용하는지 파악할 수 있도록 설치 자체는 계속 집계됩니다. 즉 익명 식별자와 앞 문단의 기술 정보는 세션마다 한 번씩 계속 전송됩니다. 이 설정을 끄면 파악되는 정보가 크게 줄어들지만, 앱이 완전히 침묵하는 것은 아닙니다.

로컬 분석 설정 파일(`Config/Analytics.local.xcconfig`) 없이 만든 빌드는 이 설정과 관계없이 아무것도 전송하지 않습니다. 소스에서 직접 빌드한 경우와 해당 파일 없이 배포된 릴리스에서는 분석이 자동으로 비활성화됩니다.

## 문의, 피드백
[![Twitter](https://img.shields.io/badge/Twitter-2CA5E0?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/ehpandaapp)
[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/BSBE9FCBTq)
[![Telegram](https://img.shields.io/badge/Telegram-858585?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/ehpanda)

## 화면캡쳐
https://ehpanda.app
