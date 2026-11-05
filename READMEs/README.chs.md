<h1 align="center">EhPanda</h1>

<h4 align="center">iOS 版非官方 E-Hentai 应用</h4>

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

## 安装步骤
1. 从 [Releases](https://github.com/EhPanda-Team/EhPanda/releases) 下载 IPA 文件。
2. 用 [AltStore](https://altstore.io) 这类工具安装到你的设备。

<sub>需要 iOS / iPadOS 27.0 或以上版本。</sub>

## 社区
[![Twitter](https://img.shields.io/badge/Twitter-2CA5E0?style=for-the-badge&logo=twitter&logoColor=white)](https://twitter.com/ehpandaapp)
[![Discord](https://img.shields.io/badge/Discord-7289DA?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/BSBE9FCBTq)
[![Telegram](https://img.shields.io/badge/Telegram-858585?style=for-the-badge&logo=telegram&logoColor=white)](https://t.me/ehpanda)

## 免责声明
应用内的内容都来自 E-Hentai，由该站的用户上传。

**访问 E-Hentai 内容的风险由你自行承担。**

## 分析
EhPanda 会向 [TelemetryDeck](https://telemetrydeck.com) 发送匿名分析数据，让维护者了解有多少人使用本应用以及哪些功能重要。**分享多少由你在首次打开应用时选择，之后可以随时在“设置 → 通用 → 分析”中更改。在你做出选择之前，不会发送任何内容。** 共有三个级别：

- **最少**：仅发送 EhPanda 已安装的信息，以及应用的安装来源。
- **基本**：在“最少”的基础上，还会发送应用的使用频率、你使用的页面和功能、设备型号和应用版本等技术信息，以及出现的错误类型。
- **完整**：在“基本”的基础上，还会发送你的阅读和下载情况，以及主要设置。

无论哪个级别，数据中都绝不包含画廊的标识符、令牌或标题，任何画廊或页面链接，搜索关键词文本，标签的值，用户名，Cookie 或任何其他凭据，以及文件路径。

在“最少”级别下，EhPanda 每次安装只发送一次安装信号。其中只包含应用的安装来源（例如 App Store、TestFlight、其他应用市场或网页）和为本次安装生成的随机标识符，不包含任何设备信息。TelemetryDeck SDK 永远不会启动。

在“基本”级别下，EhPanda 发送同样的安装信号，启动 TelemetryDeck SDK，并额外发送：
- 应用的使用频率：SDK 自身的会话信号和统计数字，例如首次打开的日期、会话次数、使用过的天数和会话的时长；
- 你使用的页面和功能：打开的标签页和首页栏目、筛选和快速搜索面板、已保存的搜索、标签点按（仅发送标签的命名空间，绝不发送其值），以及以特征形式发送的搜索（字词数、是否使用标签语法、关键词长度、结果数量的大致范围），而非文本本身；
- 出现的错误类型，包括登录失败和 Cloudflare 验证；
- SDK 自动为每个事件附加的一组标准技术信息：设备型号与架构，屏幕尺寸、缩放比例和方向，操作系统版本，应用版本与构建号，是否为调试或模拟器构建，你的语言、地区、文字排列方向和时区，该事件发送时的日期与时刻，以及你的系统外观与辅助功能设置（浅色或深色模式、文字大小、粗体文本、减弱动态效果、降低透明度、反转颜色、增强对比度、不以颜色区分）。

在“完整”级别下，还会发送你打开的画廊（仅发送分类和各命名空间的标签数量，绝不发送画廊本身），以页数和时长区间表示的阅读记录，下载结果（例如完成或失败），以及随每个事件一同发送的五项应用设置的当前值：画廊网站、登录状态、阅读方向、双页模式和标签翻译。

在“基本”和“完整”级别下，事件会附带 TelemetryDeck 内置的匿名安装标识符，该标识符会在设备上完成哈希后才发送。此标识符不会关联到你本人，并会在 iOS 重新生成设备的供应商标识符时重置，也就是同一开发者的所有应用都被删除时。TelemetryDeck 不保留 IP 地址。数据的处理方式请参阅 [TelemetryDeck 隐私政策](https://telemetrydeck.com/privacy)。

官方发行版在构建时会包含分析凭据，由发布工作流从仓库密钥中获取，因此会发送你所选级别允许的内容。未包含这些凭据的构建不会发送任何内容，无论选择了哪个级别：从源码自行构建的版本以及 Fork 版本，都会因缺少凭据而关闭分析功能。
