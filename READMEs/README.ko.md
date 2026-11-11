<h1 align="center">EhPanda</h1>

<h4 align="center">iOS용 비공식 E-Hentai 앱</h4>

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

## 설치 방법
1. [Releases](https://github.com/EhPanda-Team/EhPanda/releases)에서 IPA 파일을 다운로드하세요.
2. [AltStore](https://altstore.io) 같은 도구로 기기에 설치하세요.

<sub>iOS / iPadOS 27.0 이상이 필요합니다.</sub>

## 커뮤니티
[![Twitter](https://img.shields.io/badge/Twitter-2CA5E0?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/ehpandaapp)
[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/BSBE9FCBTq)
[![Telegram](https://img.shields.io/badge/Telegram-858585?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/ehpanda)

## 면책 조항
이 앱의 콘텐츠는 모두 E-Hentai에서 가져오며, E-Hentai 사용자가 올린 것입니다.

**E-Hentai 콘텐츠 이용에 따른 책임은 사용자 본인에게 있습니다.**

## 분석
EhPanda는 얼마나 많은 사람이 앱을 사용하는지, 어떤 기능이 중요한지 개발자가 파악할 수 있도록 익명 분석 데이터를 [TelemetryDeck](https://telemetrydeck.com)에 전송합니다. **공유할 범위는 앱을 처음 열 때 선택하며, 설정 → 일반 → 분석에서 언제든지 바꿀 수 있습니다. 선택하기 전에는 아무것도 전송되지 않습니다.** 수준은 세 가지입니다.

- **최소**: EhPanda가 설치되어 있다는 사실과 앱을 받은 곳만 보냅니다.
- **기본**: 최소 항목에 더해 앱 사용 빈도, 사용하는 화면과 기능, 기기 모델과 앱 버전 같은 기술 정보, 발생한 오류의 종류를 보냅니다.
- **전체**: 기본 항목에 더해 읽기 및 다운로드 활동과 주요 설정을 보냅니다.

어떤 수준에서도 갤러리의 식별자·토큰·제목, 갤러리나 페이지의 URL, 검색어 텍스트, 태그 값, 사용자 이름, 쿠키를 비롯한 모든 자격 증명, 파일 경로는 절대 포함되지 않습니다.

최소 수준에서는 설치 신호 하나를 설치당 한 번만 전송합니다. 여기에는 앱을 받은 곳(GitHub, AltStore, SideStore, AltStore PAL 중 하나)과 이 설치를 위해 만든 임의의 식별자만 담기며, 기기에 관한 정보는 담기지 않습니다. 공식 다운로드 파일에는 각각 배포된 곳이 표시되어 있으므로, 이 신호는 어떤 방법으로 설치했는지가 아니라 어떤 다운로드 파일을 쓰는지를 알려 줍니다. TelemetryDeck SDK는 시작되지 않습니다.

기본 수준에서는 같은 설치 신호를 보내고 TelemetryDeck SDK를 시작하며, 다음 정보를 추가로 전송합니다.
- 앱 사용 빈도: SDK 자체의 세션 신호와 집계값(처음 연 날짜, 세션 횟수, 사용한 날짜 수, 세션 길이 등)
- 사용하는 화면과 기능: 여는 탭과 홈 섹션, 필터와 빠른 검색 패널, 저장된 검색, 태그 탭(태그의 네임스페이스만 보내며 값은 보내지 않음), 검색의 특징(검색어 자체가 아니라 단어 수, 태그 문법 사용 여부, 검색어 길이, 결과 개수의 대략적인 범위), 첫 실행 화면을 마친 것과 그때 고른 수준, 설정에서 수준을 기본 또는 전체로 바꾼 것(이전 수준과 새 수준), 댓글 관리(차단, 차단 해제, 숨겨진 댓글 보기, 게시 경고에 대한 응답, 신고 결과: 전송됨, 실패, 사용할 수 없음, 사이트에서 열림)
- 모든 이벤트에 함께 담기는 앱을 받은 곳
- 발생한 오류의 종류(로그인 실패와 Cloudflare 확인 포함)
- SDK가 모든 이벤트에 자체적으로 덧붙이는 표준 기술 정보: 기기 모델과 아키텍처, 화면 크기·배율·방향, 운영체제 버전, 앱 버전과 빌드 번호, 디버그 또는 시뮬레이터 빌드 여부, 언어·지역·텍스트 방향·시간대, 이벤트가 전송된 날짜와 시각, 그리고 시스템 화면 모드와 손쉬운 사용 설정(밝은 모드 또는 어두운 모드, 텍스트 크기, 볼드체 텍스트, 동작 줄이기, 투명도 줄이기, 색상 반전, 대비 증가, 색상 사용 없이 구별)

전체 수준에서는 여기에 더해 여는 갤러리(카테고리와 네임스페이스별 태그 수만 보내며 갤러리 자체는 보내지 않음), 페이지 수와 시간의 구간으로 나타낸 읽기 세션, 다운로드 결과(완료 또는 실패 등), 그리고 모든 이벤트에 함께 전송되는 다섯 가지 앱 설정(갤러리 사이트, 로그인 상태, 읽기 방향, 두 페이지 보기, 태그 번역)의 현재 값을 전송합니다.

기본과 전체 수준에서는 이벤트에 TelemetryDeck에 내장된 익명 설치 식별자가 포함되며, 이 값은 기기에서 해시 처리된 뒤에 전송됩니다. 이 식별자는 사용자 본인과 연결되지 않으며, iOS가 기기의 공급업체 식별자를 다시 생성할 때, 즉 같은 개발자의 앱을 모두 삭제할 때 초기화됩니다. TelemetryDeck은 IP 주소를 보관하지 않습니다. 데이터 처리 방식은 [TelemetryDeck 개인정보 처리방침](https://telemetrydeck.com/privacy)을 참고하세요.

공식 릴리스는 릴리스 워크플로가 저장소 시크릿에서 가져온 분석 자격 증명을 포함해 빌드되므로, 선택한 수준에서 허용하는 정보를 전송합니다. 해당 자격 증명 없이 만든 빌드는 어떤 수준을 선택하든 아무것도 전송하지 않습니다. 소스에서 직접 빌드한 경우와 포크에서는 자격 증명이 없어 분석이 비활성화됩니다.
