import App from './App.vue'
import './assets/tailwind.css'
import './assets/modernizr-webp.js'
import { createApp } from 'vue'
import { createI18n } from 'vue-i18n'
import { library } from "@fortawesome/fontawesome-svg-core"
import { FontAwesomeIcon } from '@fortawesome/vue-fontawesome'
import { faGithub } from '@fortawesome/free-brands-svg-icons/faGithub'
import { faDiscord } from '@fortawesome/free-brands-svg-icons/faDiscord'
import { faTelegram } from '@fortawesome/free-brands-svg-icons/faTelegram'
import { faEnvelope } from "@fortawesome/free-solid-svg-icons/faEnvelope"

const messages = {
    'en': {
        title: {
            swiftui: 'Built with SwiftUI & Combine',
            cat_browse: 'Browse',
            cat_retrieve: 'Retrieve',
            cat_customize: 'Customize',
            cat_network: 'Network',
            cat_ele_category: 'Category',
            cat_ele_detail: 'Detail',
            cat_ele_comment: 'Comment',
            cat_ele_hath_archive: 'Hath Archive',
            cat_ele_torrent: 'Torrent',
            cat_ele_ehSetting: 'E-Hentai Setting',
            cat_ele_filter: 'Filter',
            cat_ele_setting: 'Setting',
            cat_ele_domainFronting: 'Bypass SNI Filtering'
        },
        desc: {
            app: 'An unofficial E-Hentai app for iOS.',
            system: 'Requires iOS / iPadOS 15.0 or later.',
            swiftui: 'Smooth, elegant, powerful.',
            cat_ele_category: 'EhPanda supports almost every E-Hentai categories. Download feature is not available at present though.',
            cat_ele_detail: 'Help you know more about this gallery and find more associated contents.',
            cat_ele_comment: 'You can join the discussion by posting / editing a comment, or giving a reaction to it.',
            cat_ele_hath_archive: 'Happen to own a Hath client? Thanks for your contribution! Here\'s a feature for you.',
            cat_ele_torrent_s1: 'Save your best memory,',
            cat_ele_torrent_s2: 'once and for all.',
            cat_ele_ehSetting: 'Handy, native, fully localized. The best way to configure your E-Hentai account on mobile devices.',
            cat_ele_filter: 'Filter settings will be automatically applied and eventually affect the search result.',
            cat_ele_setting: 'You can login, turn on optional features or modify the app icon, tint color here.',
            cat_ele_domainFronting: 'Hentai contents are fantastic. We believe watching them should be a fundamental right for any adults. We noticed there are people who cannot access E-Hentai due to a limited network. Hey, we here to help, turn it on and EhPanda will handle everything.'
        }
    },
    'de': {
        title: {
            swiftui: 'Mit SwiftUI & Combine erstellt',
            cat_browse: 'Finde was du willst',
            cat_retrieve: 'Herunterladen',
            cat_customize: 'Anpassbar',
            cat_network: 'Network',
            cat_ele_category: 'Kategorien',
            cat_ele_detail: 'Detaillierte Beschreibungen',
            cat_ele_comment: 'Kommentiere',
            cat_ele_hath_archive: 'Hath Archiv',
            cat_ele_torrent: 'Torrent',
            cat_ele_ehSetting: 'E-Hentai Setting',
            cat_ele_filter: 'Filtern',
            cat_ele_setting: 'Einstellungen',
            cat_ele_domainFronting: 'Bypass SNI Filtering'
        },
        desc: {
            app: 'Eine inoffizielle E-Hentai app für iOS.',
            system: 'Erfordert iOS / iPadOS 15.0 oder neuer.',
            swiftui: 'Einfach, Elegant, Mächtig.',
            cat_ele_category: 'EhPanda unterstützt fast alle E-Hentai Kategorien.',
            cat_ele_detail: 'helfen dir, mehr über Galerien zu erfahren und ähnliche zu finden',
            cat_ele_comment: 'Nimm an der Diskussion teil, indem du Kommentare verfasst oder bearbeitest und auf andere reagierst',
            cat_ele_hath_archive: 'Hast du einen Hath client? Danke für deine Unterstützung, diese Funktion ist für dich',
            cat_ele_torrent_s1: 'Speichere deine besten Erinnerungen,',
            cat_ele_torrent_s2: 'ein für alle Mal.',
            cat_ele_ehSetting: 'Handy, native, fully localized. The best way to configure your E-Hentai account on mobile devices.', 
            cat_ele_filter: 'Filter-Einstellungen werden automatisch angewendet und helfen dir genau das zu finden nach dem du suchst.',
            cat_ele_setting: 'Hier kannst du dich einloggen und die App an deinen Geschmack anpassen',
            cat_ele_domainFronting: 'Hentai contents are fantastic. We believe watching them should be a fundamental right for any adults. We noticed there are people who cannot access E-Hentai due to a limited network. Hey, we here to help, turn it on and EhPanda will handle everything.' 
         }
    },
    'ko': {
        title: {
            swiftui: 'SwiftUI & Combine 으로 프로래밍',
            cat_browse: '열람',
            cat_retrieve: '획득',
            cat_customize: '나의 설정',
            cat_network: '네트워크',
            cat_ele_category: '카테고리',
            cat_ele_detail: '상세정보',
            cat_ele_comment: '평가',
            cat_ele_hath_archive: 'Hath 분류',
            cat_ele_torrent: '토렌트',
            cat_ele_ehSetting: 'E-Hentai 설정',
            cat_ele_filter: '옵션',
            cat_ele_setting: '설정',
            cat_ele_domainFronting: 'SNI차단 우회'
        },
        desc: {
            app: 'iOS의 비공식 E-Hentai 에플리케이션',
            system: 'iOS / iPadOS 15.0 이상',
            swiftui: 'Smooth, elegant, powerful.',
            cat_ele_category: 'EhPanda가 거의 모두 E-Hentai의 카테고리에 가능합니다. 다로운드 기능 지금까지 제공하지 못 합니다.',
            cat_ele_detail: '이 갤러리를 알아보기와 유사한 내용을 찾아보기에 도움을 제공해드립니다.',
            cat_ele_comment: '댓글 남기기, 편집, 그리고 소통을 통해서 Hentai들의 활동을 참가합시다.',
            cat_ele_hath_archive: 'Hath클라이언트 있습니까? E-Hentai에 대한 지지를 감사합니다! 이 것은 당신을 위해 준비한 기능입니다.',
            cat_ele_torrent_s1: '가장 좋은 기억을',
            cat_ele_torrent_s2: '영원히 간직하세요.',
            cat_ele_ehSetting: '편리, 네이티브, 완전 로컬라이제이션. 모바일 장치에서 E-Hentai 계정을 구성하는 가장 좋은 방법입니다.',
            cat_ele_filter: '옵션 설정이 자동으로 적용하여, 검색 결과에 영향을 미칩니다.',
            cat_ele_setting: '여기서 로그인이나 가능한 기능을 선택하고 주제색과 아니콘 수정할 수 있니다.',
            cat_ele_domainFronting: 'Hentai의 내용물은 최고입니다. 우리는 그들을 읽는 것이 모든 어른들에게 기본권이 되어야 한다고 믿습니다. 제한된 통신망으로 인하여 E-Hentai에 접속할 수 없는 사람들이 있다는 것을 알게 되었습니다. 하지만, 우리는 도와주러 왔잖아요! 애플 켜면 EhPanda가 다 알아서 할 겁니다.'
        }
    },
    'ja': {
        title: {
            swiftui: 'SwiftUI & Combine で構築',
            cat_browse: '閲覧',
            cat_retrieve: '取得',
            cat_customize: 'カスタマイズ',
            cat_network: 'ネットワーク',
            cat_ele_category: 'カテゴリー',
            cat_ele_detail: '詳細',
            cat_ele_comment: 'コメント',
            cat_ele_hath_archive: 'Hath アーカイブ',
            cat_ele_torrent: 'トレント',
            cat_ele_ehSetting: 'E-Hentai 設定',
            cat_ele_filter: 'フィルター',
            cat_ele_setting: '設定',
            cat_ele_domainFronting: 'SNI フィルタリング回避'
        },
        desc: {
            app: 'iOS の非公式 E-Hentai アプリ',
            system: 'iOS・iPadOS 15.0 以上であることが必要です。',
            swiftui: '素早く、優雅で、パワフル。',
            cat_ele_category: 'EhPanda は、ほとんどの E-Hentai カテゴリーを対応しています。ダウンロード機能はまだです。',
            cat_ele_detail: '特定のギャラリーについての情報やその関連コンテンツを探すには、この機能がお力添えになるでしょう。',
            cat_ele_comment: 'コメントを書いたり編集したり、またはそれらに反応したりして、紳士同士で話し合いましょう。',
            cat_ele_hath_archive: 'Hath クライエントお持ちですか？ご貢献ありがとうございます！より快適に Hath できるための機能を差し上げます。',
            cat_ele_torrent_s1: '最高の思い出を、',
            cat_ele_torrent_s2: 'いつまでも。',
            cat_ele_ehSetting: '使いやすい、ネイティブ、地域化済み。モバイルデバイスでこの上ない E-Hentai 設定ツールです。',
            cat_ele_filter: 'フィルター設定は自動的に有効化し、検索結果に影響を与えるように作られています。',
            cat_ele_setting: 'ログイン、機能の有効化、アプリアイコンやテーマの色の変更は、ここでできます。',
            cat_ele_domainFronting: 'ポルノは素晴らしいものです。それを閲覧することを大人なら誰でもあるべき、基本的な権利だと考えています。しかし、ネットワークが制限され、E-Hentai にアクセス不可になっている人はたくさんいます。でも、もう大丈夫ですよ、この機能をオンにして、あとは任せてください。'
        }
    },
    'zh': {
        title: {
            swiftui: '以 SwiftUI & Combine 構築',
            cat_browse: '瀏覽',
            cat_retrieve: '獲取',
            cat_customize: '自訂',
            cat_network: '網路',
            cat_ele_category: '分類',
            cat_ele_detail: '詳情',
            cat_ele_comment: '評論',
            cat_ele_hath_archive: 'Hath 封存',
            cat_ele_torrent: '種子',
            cat_ele_ehSetting: 'E-Hentai 設定',
            cat_ele_filter: '篩選器',
            cat_ele_setting: '設定',
            cat_ele_domainFronting: '繞過 SNI 阻斷'
        },
        desc: {
            app: 'iOS 的非官方 E-Hentai 應用程式',
            system: '須使用 iOS / iPadOS 15.0 或以上。',
            swiftui: '流暢、優雅、強大。',
            cat_ele_category: 'EhPanda 幾乎支援所有 E-Hentai 分類類型。目前尚未支援下載功能。',
            cat_ele_detail: '幫助你瞭解這個畫廊、搜尋更多相似內容。',
            cat_ele_comment: '通過發佈、編輯和回覆評論，參與紳士們的討論吧。',
            cat_ele_hath_archive: '碰巧有一台 Hath 客戶端嗎？感謝你對 E-Hentai 的貢獻！這是專為你準備的功能。',
            cat_ele_torrent_s1: '種子恆久遠，',
            cat_ele_torrent_s2: '一顆永流傳。',
            cat_ele_ehSetting: '易用、原生、完整本地化。移動設備上設定 E-Hentai 帳戶的最佳方式。',
            cat_ele_filter: '設定篩選器後將會自動生效並影響搜尋結果。',
            cat_ele_setting: '你可以在這裡登入、啓用自訂功能、修改 App 圖示或主題色。',
            cat_ele_domainFronting: '本子是很棒的東西。我們認為瀏覽它們應當是每個成年人的基本權利。但同時我們也留意到許多人網路受到限制無法訪問到 E-Hentai。於是我們就來幫忙了，啟用這個功能，剩下的事情交給 EhPanda 吧。'
        }
    },
    'zh-CN': {
        title: {
            swiftui: '以 SwiftUI & Combine 构筑',
            cat_browse: '浏览',
            cat_retrieve: '获取',
            cat_customize: '自定义',
            cat_network: '网络',
            cat_ele_category: '分类',
            cat_ele_detail: '详情',
            cat_ele_comment: '评论',
            cat_ele_hath_archive: 'Hath 归档',
            cat_ele_torrent: '种子',
            cat_ele_ehSetting: 'E-Hentai 设置',
            cat_ele_filter: '筛选器',
            cat_ele_setting: '设置',
            cat_ele_domainFronting: '绕过 SNI 阻断'
        },
        desc: {
            app: 'iOS 的非官方 E-Hentai 应用程序',
            system: '要求iOS / iPadOS 15.0 或以上。',
            swiftui: '流畅、优雅、强大。',
            cat_ele_category: 'EhPanda 对 E-Hentai 几乎所有的分类提供了支持。下载功能目前尚未实装。',
            cat_ele_detail: '帮助你了解这个画廊、查找更多相似内容。',
            cat_ele_comment: '通过发布、编辑和回复评论，参与绅士们的讨论吧。',
            cat_ele_hath_archive: '碰巧有一台 Hath 客户端吗？感谢你对 E-Hentai 的贡献！这是专为你准备的功能。',
            cat_ele_torrent_s1: '种子恒久远，',
            cat_ele_torrent_s2: '一颗永流传。',
            cat_ele_ehSetting: '易用、原生、完整本地化。移动设备上配置 E-Hentai 帐户的最佳方式。',
            cat_ele_filter: '筛选器设置将被自动生效，并对搜索结果产生影响。',
            cat_ele_setting: '你可以在这里登录、启用可选功能、修改 App 图标或主题色。',
            cat_ele_domainFronting: '本子是很棒的东西。我们认为浏览它们应当是每个成年人的基本权利。但同时我们也留意到许多人网络受到限制无法访问到 E-Hentai。于是我们就来帮忙了，启用这个功能，剩下的事情交给 EhPanda 吧。'
        }
    }
}

const i18n = createI18n({
    locale: navigator.language,
    fallbackLocale: 'en',
    messages,
})

library.add(faGithub)
library.add(faDiscord)
library.add(faTelegram)
library.add(faEnvelope)

createApp(App).use(i18n)
    .component('fa-icon', FontAwesomeIcon)
    .mount('#app')