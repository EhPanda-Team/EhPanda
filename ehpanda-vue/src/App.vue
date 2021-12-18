<template>
  <nav class="fixed flex items-center justify-between w-screen bg-white bg-opacity-50 opacity-0 backdrop-blur-2xl backdrop-filter dark:bg-black dark:bg-opacity-10 h-14">
      <p class="ml-8 text-2xl font-semibold text-black opacity-90 dark:text-white">EhPanda</p>
      <div class="flex mr-8 opacity-90">
        <a href="https://github.com/tatsuz0u/EhPanda">
            <fa-icon :icon="['fab', 'github']" class="plain-icon" />
        </a>
        <a href="https://discord.gg/BSBE9FCBTq">
            <fa-icon :icon="['fab', 'discord']" class="ml-4 plain-icon" />
        </a>
        <a href="https://t.me/ehpanda">
            <fa-icon :icon="['fab', 'telegram']" class="ml-4 plain-icon" />
        </a>
      </div>
  </nav>
  <section class="flex items-center w-screen h-screen overflow-hidden justify-evenly">
      <div class="flex flex-col items-center justify-center md:items-start">
          <img alt="appicon" class="w-48 h-48" id="img-appicon">
          <h1 class="pt-8 text-5xl font-medium text-black dark:text-white">EhPanda</h1>
          <h2 class="pb-10 font-light text-black dark:text-gray-300 app-desc">{{ $t("desc.app") }}</h2>
          <div class="flex flex-col w-60">
            <a href="https://github.com/tatsuz0u/EhPanda" class="button-container flex-grow">
                <fa-icon :icon="['fab', 'github']" class="button-icon" />
                <p class="button-label">GitHub</p>
            </a>
            <div class="flex mt-2">
                <a href="https://discord.gg/BSBE9FCBTq" class="button-container flex-grow">
                    <fa-icon :icon="['fab', 'discord']" class="button-icon" />
                    <p class="button-label">Discord</p>
                </a>
                <a href="https://t.me/ehpanda" class="ml-2 button-container flex-grow">
                    <fa-icon :icon="['fab', 'telegram']" class="button-icon" />
                    <p class="button-label">Telegram</p>
                </a>
            </div>
          </div>
          <p class="mt-2 text-gray-500 text-xs">{{ $t("desc.system") }}</p>
      </div>
      <div class="flex-row-reverse items-end hidden md:flex">
          <img alt="home-ipad" class="frontpage-ipad-img-size" id="img-home-ipad">
          <img alt="home" class="mb-5 lg:mb-8 frontpage-img-size -mr-28 lg:-mr-44" id="img-home">
      </div>
  </section>
  <section class="flex flex-col items-center justify-center w-screen min-h-screen bg-gray-200 dark:bg-gray-900">
      <div class="cat-section">
          <h1 class="cat-section-title text-purple-500">{{ $t("title.cat_browse") }}</h1>
          <div class="cat-section-element">
              <div class="cat-element-div-pr">
                  <p class="cat-element-title text-purple-500">{{ $t("title.cat_ele_category") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_category") }}</p>
              </div>
              <img alt="slideMenu" class="feature-img-size" id="img-slideMenu">
          </div>
          <div class="cat-section-element-reverse">
              <div class="cat-element-div-pl">
                  <p class="cat-element-title text-purple-500">{{ $t("title.cat_ele_detail") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_detail") }}</p>
              </div>
              <img alt="detail" class="feature-img-size" id="img-detail">
          </div>
          <div class="cat-section-element">
              <div class="cat-element-div-pr">
                  <p class="cat-element-title text-purple-500">{{ $t("title.cat_ele_comment") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_comment") }}</p>
              </div>
              <img alt="comment" class="feature-img-size" id="img-comment">
          </div>
      </div>
      <div class="separator"></div>
      <div class="cat-section">
          <h1 class="cat-section-title text-red-500">{{ $t("title.cat_retrieve") }}</h1>
          <div class="cat-section-element">
              <div class="cat-element-div-pr">
                  <p class="cat-element-title text-red-500">{{ $t("title.cat_ele_hath_archive") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_hath_archive") }}</p>
              </div>
              <img alt="archive" class="feature-img-size" id="img-archive">
          </div>
          <div class="cat-section-element-reverse">
              <div class="cat-element-div-pl">
                  <p class="cat-element-title text-red-500">{{ $t("title.cat_ele_torrent") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_torrent_s1") }}<br />{{ $t("desc.cat_ele_torrent_s2") }}</p>
              </div>
              <img alt="torrent" class="feature-img-size" id="img-torrent">
          </div>
      </div>
      <div class="separator"></div>
      <div class="cat-section">
          <h1 class="cat-section-title text-green-500">{{ $t("title.cat_customize") }}</h1>
          <div class="cat-section-element">
              <div class="cat-element-div-pr">
                  <p class="cat-element-title text-green-500">{{ $t("title.cat_ele_ehSetting") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_ehSetting") }}</p>
              </div>
              <img alt="ehSetting" class="feature-img-size" id="img-ehSetting">
          </div>
          <div class="cat-section-element-reverse">
              <div class="cat-element-div-pl">
                  <p class="cat-element-title text-green-500">{{ $t("title.cat_ele_filter") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_filter") }}</p>
              </div>
              <img alt="filter" class="feature-img-size" id="img-filter">
          </div>
          <div class="cat-section-element">
              <div class="cat-element-div-pr">
                  <p class="cat-element-title text-green-500">{{ $t("title.cat_ele_setting") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_setting") }}</p>
              </div>
              <img alt="setting" class="feature-img-size" id="img-setting">
          </div>
      </div>
      <div class="separator"></div>
      <div class="cat-section">
          <h1 class="cat-section-title text-blue-500">{{ $t("title.cat_network") }}</h1>
          <div class="cat-section-element">
              <div class="cat-element-div-pr">
                  <p class="cat-element-title text-blue-500">{{ $t("title.cat_ele_domainFronting") }}</p>
                  <p class="cat-element-desc">{{ $t("desc.cat_ele_domainFronting") }}</p>
              </div>
              <img alt="domainFronting" class="feature-img-size" id="img-domainFronting">
          </div>
      </div>
  </section>
  <section class="flex flex-col items-center w-screen h-screen bg-gradient-to-b from-teal-700 to-blue-900 justify-evenly">
      <div class="flex flex-col items-start p-6">
          <h1 class="text-5xl font-semibold text-white">{{ $t("title.swiftui") }}</h1>
          <h2 class="text-2xl text-gray-300">{{ $t("desc.swiftui") }}</h2>
      </div>
      <object data="/img/swiftui.svg" type="image/svg+xml" class="w-72 h-72">swiftui</object>
  </section>
  <footer class="flex items-center justify-between w-screen text-xs text-white bg-gray-800 h-14">
      <p class="ml-8 ">© 2021 荒木辰造. All rights reserved.</p>
      <a class="hidden mr-8 md:flex" href="mailto:kendellcarol@gmail.com">
          <fa-icon icon="envelope" size="md" class="mt-0.5 mr-1" />
          <p>kendellcarol@gmail.com</p>
      </a>
  </footer>
</template>

<script>
export default {
  mounted () {
    this.setImage()
    this.setNavBarVisibility()
    window.addEventListener('scroll', this.setNavBarVisibility)
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener("change", this.setImage)
  },
  unmounted () {
    window.removeEventListener('scroll', this.setNavBarVisibility)
    window.matchMedia('(prefers-color-scheme: dark)').removeEventListener("change", this.setImage)
  },
  methods: {
    getUserLang() {
        return (navigator.language || navigator.userLanguage)
    },
    isDarkModeOn() {
        return window.matchMedia('(prefers-color-scheme: dark)').matches
    },
    capitalize(string) {
        return string[0].toUpperCase() + string.slice(1)
    },
    setNavBarVisibility() {
      var currentScrollPos = window.pageYOffset
      var navBar = document.getElementsByTagName('nav')[0]

      if (currentScrollPos > screen.height / 2) {
          navBar.classList.add('nav-visible')
          navBar.classList.remove('nav-hidden')
      } else {
          navBar.classList.add('nav-hidden')
          navBar.classList.remove('nav-visible')
      }
    },
    setImage() {
        const imgPath = './img/'
        const appiconPath = imgPath + 'appicon/'
        const screenshotPath = imgPath + 'screenshot/'

        const userLang = this.getUserLang()
        var langParam = 'EN'
        if (userLang.split('-')[0] == 'de') {
            langParam = 'DE'
        } else if (userLang.split('-')[0] == 'ko') {
            langParam = 'KO'
        } else if (userLang.split('-')[0] == 'ja') {
            langParam = 'JA'
        } else if (userLang == 'zh-CN') {
            langParam = 'CHS'
        } else if (userLang.split('-')[0] == 'zh') {
            langParam = 'CHT'
        }
        const darkParam = this.isDarkModeOn() ? 'Dark' : 'Light'
        const nameParms = ['appicon','home','home-ipad','slideMenu','detail','comment','archive','torrent','ehSetting','filter','setting','domainFronting']
        
        nameParms.forEach((element) => {
            const id = 'img-' + element
            const appiconName = 'appicon-466'
            const filename = [this.capitalize(element), langParam, darkParam].join('_')
            const iPadFilename = [this.capitalize(element.split('-')[0]), langParam, darkParam,'iPad'].join('_')

            window.Modernizr.on('webp', function( result ) {
                const extension = result == true ? '.webp' : '.png'
                if (id.includes('appicon')) {
                    document.getElementById(id).src = appiconPath + appiconName + extension 
                } else if (id.includes('ipad')) {
                    document.getElementById(id).src = screenshotPath + iPadFilename + extension 
                } else {
                    document.getElementById(id).src = screenshotPath + filename + extension 
                }
            });
        })
    }
  }
}
</script>

<style>
  body {
    @apply overflow-x-hidden bg-white dark:bg-black
  }
</style>
<style scoped>
  .separator {
    @apply w-screen h-1 bg-white dark:bg-gray-800
  }
  .cat-section {
    @apply flex flex-col items-center justify-center py-20 space-y-20 md:space-y-0
  }
  .cat-section-title {
    @apply pb-5 text-4xl font-bold md:pb-10 md:text-6xl
  }
  .cat-section-element {
    @apply flex flex-col items-center justify-between space-y-4 md:flex-row
  }
  .cat-section-element-reverse {
    @apply flex flex-col items-center justify-between space-y-4 md:flex-row-reverse
  }
  .cat-element-div-pl {
    @apply flex flex-col md:pl-24
  }
  .cat-element-div-pr {
    @apply flex flex-col md:pr-24
  }
  .cat-element-title {
    @apply text-2xl font-semibold 
  }
  .cat-element-desc {
    @apply text-xl text-black w-64 dark:text-white
  }
  .button-container {
    @apply flex items-center justify-center h-10 bg-black rounded-2xl dark:bg-white
  }
  .button-icon {
    @apply text-lg text-white dark:text-black
  }
  .button-label {
    @apply ml-2 font-semibold text-white select-none dark:text-black
  }
  .plain-icon {
    @apply text-3xl text-black dark:text-white
  }
  .nav-hidden {
      opacity: 0;
      transition: transform 0.4s, opacity 0.3s;
  }
  .nav-visible {
      opacity: 1;
      transition: transform 0.4s, opacity 0.3s;
  }
  .frontpage-img-size {
      width: 150px;
      height: 266px;
  }
  .frontpage-ipad-img-size {
      width: 300px;
      height: 392px;
  }
  .feature-img-size {
      width: 243px;
      height: 432px;
  }
  @media(min-width:768px) {
      .feature-img-size {
          width: 294px;
          height: 522px;
      }
  }
  @media(min-width: 1024px) {
      .frontpage-img-size {
          width: 250px;
          height: 455px;
      }
      .frontpage-ipad-img-size {
          width: 500px;
          height: 654px;
      }
  }
  @media(min-width: 1280px) {
      .feature-img-size {
          width: 361px;
          height: 642px;
      }
  }
</style>
