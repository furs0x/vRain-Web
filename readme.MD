# vRain —— 兀雨中文古籍刻本风格直排电子书制作工具

[![Version](https://img.shields.io/badge/version-v1.5-blue.svg)](https://github.com/shanleiguang/vRain)
[![Language](https://img.shields.io/badge/language-Perl%205-brightgreen.svg)](https://www.perl.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey.svg)]()

vRain（兀雨）是一个 Perl 工具链，可将中文文本生成为古籍刻本风格的直排（竖排）PDF 电子书。支持木活字、竹简、棋谱等多种刻本风格，内置多字体补全策略确保生僻字正常显示，并支持字体度量微调保持版面视觉一致性。

[English Documentation](README_EN.md)
![image](https://github.com/shanleiguang/vRain/blob/main/cover.png)

[**运行环境**](https://github.com/shanleiguang/vRain/wiki/Runtime)  [**使用手册**](https://github.com/shanleiguang/vRain/wiki)   [**更多样例**](https://github.com/shanleiguang/vBooks)  [**更多开源项目**](https://github.com/shanleiguang/vRain/wiki/More)  

## 中文古籍数字复刻计划 
## Digital Reproduction Project of Chinese Ancient Books

- 古籍刻本扫描影像通常存在扫描变形、页面瑕疵、文件巨大等问题，且图像无法选中其文字从而不能查询生字生词，因而不便阅读
- 该计划目的是参照古籍刻本之原貌，复刻出文字版的电子书，支持圈注、查阅，方便存入电子阅读器随时阅读。通过古籍刻本古朴形式所带来的沉浸优雅之阅读体验，也许将吸引更多读者爱上古籍阅读
- Scanned images of ancient books often suffer from issues such as scanning distortion, page defects, and large file sizes, making it difficult to read since the text cannot be selected for searching dictionary.
- The goal of this project is to create ebook in text format that replicates the original appearance of the ancient books, supporting annotations and queries, making it convenient to store in ebook-readers for reading anytime. The elegant and immersive reading experience brought by the primitive form of ancient books may attract more readers to enjoy reading ancient literature.

## vRain is  

- vRain是该复刻计划的主要工具，此外还有古籍印章制作工具 [vYinn殷人](https://github.com/shanleiguang/vYinn) 、古棋谱制作工具 [vQi](https://github.com/shanleiguang/vQi) 、古籍扫描图像变形纠正工具[vModou墨斗](https://github.com/shanleiguang/vModou)以及其他传统文化文创工具，如天地人三才传统历法笔记本 [v3Cai](https://github.com/shanleiguang/v3CaiPreview)等
- vRain是一款面向读者的中文古籍刻本风格直排电子书制作工具
- 参考中文古籍雕版刻本制作过程，首先生成书叶背景图，根据行数、每行字数形成一个自右向左、自上而下的位置数组，然后把文本逐字打印到对应位置，打满一页、新建一页，直到所有文字处理完
- 文本编辑准备和自动排版生成分离，使用者将主要精力用在文本编辑准备
- 一个背景图对应一个配置文件。一本书对应一个配置文件
- 百万字书籍十几分钟生成
- 采用Perl语言开发，需安装Image::Magick和PDF::Builder等模块
- 作者小红书主页：兀雨书屋
- Apple Store：兀雨书屋

![image](https://github.com/shanleiguang/vRain/blob/main/images/019.png)

## Example

![image](https://github.com/shanleiguang/vBooks/blob/main/002.png)

![image](https://github.com/shanleiguang/vRain/blob/main/images/010.png)

![image](https://github.com/shanleiguang/vRain/blob/main/images/014.png)

![image](https://github.com/shanleiguang/vRain/blob/main/images/016.png)

## 基本功能  

- **书叶背景图**：书房名、尺寸、列数、框线粗细及颜色均可配置。支持单双、顺对、黑白鱼尾及装饰。可生成宣纸做旧风格、竹简风格背景图
- **正文与批注**：支持批注文字小字双排。正文、批注文字的字体、大小、颜色、位置可配置
- **标点替换**：标点替换规则、过滤规则可配置。标点符号可归一化为句号（**推荐**），仅用于句读。常用标点符号可设置为不占字符位置，页面文字更紧凑，贴近古籍刻本风格
- **标点微调**：正文文字、批注文字、标点符号的上、下、左、右位置均可微调以达到最佳呈现效果。书名号、单双引号直排旋转九十度。书名号可调整为侧边线
- **字体互补**：一主多辅字体，主字体不支持时自动采用辅字体补字。某字符主字体不支持时，可尝试简繁转换以改善支持情况，但可能产生与语境不符问题
- **字体度量微调**：自动测量各字体字形高度差异，微调字号保持视觉大小一致
- **回退字体加粗**：正文中回退到非主字体的字符可自动叠加描边模拟加粗效果
- **自动生成目录**：根据文本序号自动生成PDF目录，如第x回、卷x
- **特殊标记系统**：书名波浪线、圆角方框、圆形框、圈注/点注/线注、字体缩放等
- **PDF 压缩**：`-c` 使用 PDF::Builder 自带的 Flate 压缩，不必安装 Ghostscript
- **保留字符**：'@'代表空格，'【】'内代表双排批注文字，'%'代表换叶符，'$'代表换页符（半叶），'&'代表下行文字居叶末，文本行首'S+数字'代表整段缩几个字符（需indentxt脚本做预处理）,文本行首'T'代表段首字顶一格，'《》'代表左侧波浪线，'〔〕'代表圆角方框，'〈〉'代表圆形框，'（）'代表字体大小缩放，'｛｝'代表正文右侧圈注，'＜＞'代表正文右侧点注，'［］'代表正文右侧线注


## 下载即用

每个系统一个文件。下载后双击，本机浏览器会打开页面。不必解压，不必另装 Perl、字体、ImageMagick 或 Ghostscript。

| 系统 | 文件 |
|------|------|
| Windows x64 | `vRain-*-windows-x64.exe` |
| macOS Apple 芯片 | `vRain-*-macos-arm64.dmg` |
| macOS Intel | `vRain-*-macos-x64.dmg` |
| Linux x64 | `vRain-*-linux-x64` |

程序自带一份可移动的 Perl：Linux 与 macOS 使用 [relocatable-perl](https://github.com/skaji/relocatable-perl) 5.42，Windows 使用 [Strawberry Perl](https://github.com/StrawberryPerl/Perl-Dist-Strawberry) portable。外面是一个很小的启动程序：第一次运行时把运行环境解压到本机缓存（按内容校验），之后再次打开不再解压。`web/server.pl` 只用 Perl 核心模块听 `127.0.0.1:8787`（端口被占用时会往后试 20 个），通过网页收集书籍、书叶、字体和 `book.cfg` 里的设定，再调用原来的 `vrain.pl` 排版。排版引擎没有改写。`Font::FreeType` 在打包时静态链接 FreeType 2.13，因此不依赖系统里的 libfreetype。书叶背景 JPG 已经放进软件包；只有从源代码执行 `canvas/*.pl` 重绘背景时才需要 ImageMagick。PDF 压缩（`-c`）由 PDF::Builder 的 Flate 完成：压缩页面内容，不降低书叶图片质量。网页右上角的「退出」会关掉本机服务。

GitHub Actions 在 `ubuntu-24.04`、`windows-latest`、`macos-15`（Apple 芯片）和 `macos-15-intel` 上构建，并用 `books/sample` 做烟雾测试。产物在该次执行的 Artifacts。推送 `v*` 标签时，单文件和目录包都会挂到对应的 GitHub Release。Fork 之后若没有看到执行记录，到仓库的 Actions 页启用 Actions，第一次执行若被暂停，核准后才会开始。

### Windows

双击 `vRain-*-windows-x64.exe`。窗口不会闪一下控制台。没有购买代码签名证书时，SmartScreen 会提示「Windows 已保护你的电脑」。点「更多信息」，再点「仍要运行」。这是系统对未签名程序的提示，不必打开终端。

### macOS

打开 dmg，双击里面的 `vRain.app`。磁盘映像里的 app 已做 ad-hoc 签名。没有 Apple 公证证书时，从浏览器下载的文件第一次打开，系统仍可能说「无法打开，因为无法验证开发者」或「已损坏」。在 Finder 里对 `vRain.app` 按住 Control 再点（或按右键），选择「打开」，在对话框里再确认一次。之后这一份可以直接双击。不需要打开终端。

### Linux

在文件管理器里打开下载到的 `vRain-*-linux-x64`。浏览器保存文件时会去掉可执行权限，这是系统限制：在文件属性里允许把它作为程序执行，然后双击。需要 glibc 2.33 或更新（Ubuntu 22.04、Debian 12 以及之后的版本）。自动构建只包含 x64；在 arm64 机器上可以执行 `bash packaging/build.sh` 自行打包。

### 签名证书

没有证书时，上面两处系统提示会留下。把下面的 Secrets 加到仓库（Settings → Secrets and variables → Actions）后，同一次构建会自动签名；macOS 还会公证 dmg。缺任何一项时，该系统仍用未签名或 ad-hoc 签名，构建不会假装已经公证。

macOS（Developer ID Application 证书，以及 App Store Connect API 密钥）：

- `MACOS_CERTIFICATE_P12_BASE64`：Developer ID Application 的 `.p12` 做 base64
- `MACOS_CERTIFICATE_PASSWORD`：这个 `.p12` 的密码
- `APPLE_TEAM_ID`：10 位 Team ID
- `APPLE_API_KEY_ID`：API 密钥 ID
- `APPLE_API_ISSUER`：Issuer UUID
- `APPLE_API_KEY`：`AuthKey_XXXX.p8` 文件内容的 base64

Windows（Authenticode 代码签名证书）：

- `WINDOWS_CERTIFICATE_PFX_BASE64`：`.pfx` 做 base64
- `WINDOWS_CERTIFICATE_PASSWORD`：这个 `.pfx` 的密码

### 目录包

Actions 仍会附上解压即可查看文件的 `vRain-Web-*.zip` / `.tar.gz`。Windows 双击其中的 `START.bat`，macOS 双击 `start.command`，Linux 在终端执行 `./start.sh`。单文件是给直接打开用的。

网页默认简体中文，可切换繁体中文和英文。可以选择或新建书籍、上传文本、字体、封面和 JPEG 书叶，调整版面后生成，并在页面上看日志、预览和下载 PDF。一次只排一本。`books/sample` 是短文范例，`books/01` 是原来的《虞初新志》示例，这两本不能从网页删除。`vrain_mr.pl` 与 `books_mr/` 仍只走命令行。

从源代码开发时，`./start-web.sh` 会优先使用已经打好的 `runtime/perl`，否则使用系统 Perl（系统 Perl 需要已安装 `PDF::Builder` 与 `Font::FreeType` 才能真正排版）。自己打包：

```bash
bash packaging/build.sh
bash packaging/smoke.sh dist/vRain-Web-*.tar.gz
```

## 系统需求

- **Perl 5**（含核心模块）
- **PDF::Builder** — PDF 生成
- **Font::FreeType** — 字体字形检测与度量
- **Image::Magick** — 背景图生成（`canvas/*.pl` 指令码使用）
- **PDF::Builder 的 Flate** — PDF 压缩（`-c` 参数，不必另装 Ghostscript）

## 快速开始

```bash
# 基本用法
perl vrain.pl -b <书籍ID> [-f 起始文本序号] [-t 结束文本序号] [-z 测试页数] [-c] [-v]

# 范例：生成 book ID 为 00 的全部文本 PDF
perl vrain.pl -b 00 -f 1 -t 80

# 测试模式：仅输出 5 页用于调参，生成带 _test 标识的 PDF
perl vrain.pl -b 00 -f 1 -t 80 -z 5
```

### 生成背景图

```bash
# 在 canvas/ 目录下执行，根据 cfg 配置文件生成刻本背景图 JPG
cd canvas && perl vintage.pl -c vintage
cd canvas && perl bamboo.pl -c bamboo
```

## 命令行参数

| 参数 | 说明 |
|------|------|
| `-h` | 显示帮助资讯 |
| `-v` | 显示详细排版资讯（含字体选择、缩放因子等） |
| `-c` | 用内置 Flate 压缩 PDF，生成带 `_已压缩` 的文件 |
| `-z <页数>` | 测试模式，仅输出指定页数，生成带 `_test` 标识的 PDF |
| `-b <书籍ID>` | 书籍 ID，对应 `books/<ID>/` 目录 |
| `-f <序号>` | 文本起始序号（按文件名排序后的顺序序号，非文件名数字） |
| `-t <序号>` | 文本结束序号 |

## 项目目录结构

```
vRain/
├── vrain.pl                     ← 核心 PDF 排版指令码
├── books/
│   └── <ID>/
│       ├── book.cfg             ← 书籍排版设定（核心入口配置文件）
│       ├── text/                ← 源文本文件，按数字编号（001.txt, 002.txt ...）
│       │   ├── 000.txt           ← 可选：序言/前言
│       │   └── 999.txt           ← 可选：附录/后记
│       ├── cover.jpg             ← 可选：封面图片，不存在则自动生成简易封面
│       └── *.pdf                 ← 输出 PDF 储存于此目录
├── canvas/
│   ├── *.cfg                    ← 背景图设定（页尺寸、边距、列数、鱼尾等）
│   ├── *.jpg                    ← 生成的背景图
│   └── *.pl                     ← 背景图生成指令码（使用 Image::Magick）
├── fonts/                       ← TTF 字体文件
└── db/
    └── num2zh_jid.txt           ← 阿拉伯数字→中文数字映射（章回、页码用）
```

## 两级设定系统

### 画布级（`canvas/*.cfg`）—— 定义「纸」的样式

| 参数 | 说明 |
|------|------|
| `canvas_width` / `canvas_height` | 页面宽高（px） |
| `margins_top` / `margins_bottom` | 上下留白 |
| `margins_left` / `margins_right` | 左右留白 |
| `leaf_col` | 列数 |
| `leaf_center_width` | 版心宽度（中缝） |
| `outline_width` / `outline_color` | 外边框线宽/颜色 |
| `inline_width` / `inline_color` | 内边框线宽/颜色 |
| `outline_hmargin` / `outline_vmargin` | 边框水平/垂直边距 |
| `if_multirows` | 是否启用多栏模式 |
| `multirows_num` | 栏数 |
| `logo_text` | 书房名/Logo 文字 |

### 书籍级（`books/<ID>/book.cfg`）—— 定义「字」的排版

#### 基础设定

| 参数 | 说明 |
|------|------|
| `title` | 书名 |
| `author` | 作者 |
| `canvas_id` | 关联的背景图 ID |
| `row_num` | 每列字数 |
| `row_delta_y` | 列末字符到边框距离微调 |

#### 字体设定（最多 5 种）

| 参数 | 说明 |
|------|------|
| `font1` ~ `font5` | 字体文件名（存放于 `fonts/` 目录） |
| `font1_rotate` ~ `font5_rotate` | 各字体旋转角度微调 |
| `text_fonts_array` | 正文字体优先级阵列（如 `134` 表示依序尝试 font1、font3、font4） |
| `text_font1_size` ~ `text_font5_size` | 各字体正文字号 |
| `text_font_color` | 正文颜色 |
| `comment_fonts_array` | 批注字体优先级阵列 |
| `comment_font1_size` ~ `comment_font5_size` | 各字体批注字号 |
| `comment_font_color` | 批注颜色 |
| `if_font_metric_adjust` | 是否启用字体度量微调（`1` = 启用） |
| `if_fallback_bold` | 是否对正文回退字体字符模拟加粗（`1` = 启用） |
| `fallback_bold_stroke_width` | 模拟加粗描边宽度（pt），建议 0.5 ~ 2.0 |

#### 封面与版心

| 参数 | 说明 |
|------|------|
| `cover_title_font_size` / `cover_title_y` | 封面标题字号/位置 |
| `cover_author_font_size` / `cover_author_y` | 封面作者字号/位置 |
| `cover_font_color` | 封面字体颜色 |
| `title_font_size` / `title_font_color` / `title_y` | 版心标题字号/颜色/位置 |
| `title_ydis` | 标题字符纵向间距系数 |
| `title_postfix` | 标题后缀（`X` 自动替换为章回数字） |
| `title_directory` | 是否生成 PDF 书签目录 |
| `pager_font_size` / `pager_font_color` / `pager_y` | 页码字号/颜色/位置 |

#### 标点符号处理

| 参数 | 说明 |
|------|------|
| `exp_replace_comma` | 标点符号替换规则（`\|` 分隔） |
| `exp_replace_number` | 数字替换规则 |
| `exp_delete_comma` | 删除的标点符号 |
| `if_nocomma` / `exp_nocomma` | 无标点模式及过滤规则 |
| `if_onlyperiod` / `exp_onlyperiod` | 标点归一化为句号模式 |
| `text_comma_nop` | 正文不占字符位的标点 |
| `text_comma_nop_size` / `_x` / `_y` | 不占位标点大小/位置微调 |
| `text_comma_90` | 正文旋转 90 度的标点 |
| `text_comma_90_size` / `_x` / `_y` | 旋转标点大小/位置微调 |
| `comment_comma_nop` / `comment_comma_90` | 批注标点（同上结构） |

#### 特殊标记

| 参数 | 标记符号 | 说明 |
|------|---------|------|
| `if_tag_bookline` | `《》` | 书名号 → 转为文字左侧波浪线 |
| `if_tag_rectframe` | `〔〕` | 圆角方框 |
| `if_tag_circleframe` | `〈〉` | 圆形框 |
| `if_tag_textzoom` | `（）` | 字体大小缩放 |
| `if_tag_circlenote` | `｛｝` | 正文右侧圈注 |
| `if_tag_pointnote` | `＜＞` | 正文右侧点注 |
| `if_tag_linenote` | `［］` | 正文右侧线注 |

## 文本标记系统

源文本中使用特殊符号控制排版行为：

| 符号 | 作用 |
|------|------|
| `【批注】` | 批注文字（双排夹批），奇数个字自动补齐 |
| `《》` | 书名号 → 转为文字左侧波浪线 |
| `〔〕` | 为字符添加圆角方框 |
| `〈〉` | 为字符添加圆形框 |
| `（）` | 字体大小缩放 |
| `｛｝` | 正文右侧圈注 |
| `＜＞` | 正文右侧点注 |
| `［］` | 正文右侧线注 |
| `%` | 整叶分页符 |
| `$` | 半叶分页符 |
| `&` | 跳至当前页最后一列 |
| `@` | 空格 |
| `T` | 前进一字（前移一个字符位） |

## 核心排版机制

- **字位计数器** `$pcnt`：每页当前写入位置的标准字位指标，达到 `page_chars_num`（`col_num × row_num`）时触发换叶
- **座标预计算**：`@pos_l`（左侧）和 `@pos_r`（右侧，用于双排夹批）阵列在排版前预先计算
- **字体回退**：`get_font()` 使用 Font::FreeType 逐一检查字符是否存在于字体中，按优先级回退；字符无可用字体时显示 `□`
- **字体度量微调**：通过比较各字体与主字体的参考字符（**「国」**）字形高度，计算缩放因子，在 PDF 渲染时自动微调字号和居中位置
- **批注交叉处理**：遇到 `【】` 时提取批注内容，优先以双排位置列印，处理完后继续正文

## 版本历史

| 版本 | 日期 | 更新内容 |
|------|------|---------|
| v1.5 | 2025-05 | 新增字体度量微调功能、回退字体模拟加粗功能 |
| v1.4 | 2025-03 | 多栏模式、字体配置优化 |
| v1.3 | 2025-01 | 新增书名波浪线、圆角方框、标记系统 |
| v1.2 | 2024-12 | 夹批双排、标点符号处理优化 |
| v1.1 | 2024-11 | 多字体回退系统 |
| v1.0 | 2024-10 | 初始版本 |

## 授权

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 作者

- **GitHub**：[@shanleiguang](https://github.com/shanleiguang)
- **小红书**：@兀雨书屋
- **邮箱**：shanleiguang@gmail.com

## 赞助支持 Sponsorship

![image width=1024](https://github.com/shanleiguang/vRain/blob/main/sponsor_new.png)  

---

*兀雨——为中文古籍数位化提供专业的刻本风格排版工具。*
