# 浮光 —— 纯安卓本地运行的跨平台个性化内容推荐应用 —— 纯安卓本地运行的跨平台个性化内容推荐 Agent

> **纯本地运行的个性化内容推荐应用。** 无需服务器，核心数据保存在设备本机，LLM 能力使用你自行配置的服务商 API Key。

## 最新版本

当前正式版本为 **1.0.5**。可在 [GitHub Releases](https://github.com/ZYJ882/fuguang/releases/tag/v1.0.5) 下载 Android APK；仓库内的 [发布目录](releases/v1.0.5/) 同步保留安装包、对应源码、校验文件和安装说明。

| 文件 | 用途 |
|---|---|
| `fuguang-1.0.5.apk` | Android 安装包。 |
| `fuguang-1.0.5-source.zip` | 与该版本一致的完整源码。 |
| `SHA256SUMS.txt` | 发布文件的 SHA-256 校验值。 |

## 项目简介

浮光是一个纯本地运行的个性化内容推荐应用。画像引擎、推荐引擎、对话系统与内容来源适配均直接在安卓设备运行，数据存储在本机 SQLite 中。

### 核心特性

- **🧠 五层灵魂画像** —— 事件→偏好→觉察→洞察→灵魂，从行为中深度理解用户
- **🔮 主动探索推荐** —— 基于心理学桥接逻辑，猜测用户可能感兴趣的新领域
- **📱 跨平台内容** —— B站、小红书、抖音、知乎、通用网页等多来源聚合
- **💬 对话调教** —— 像朋友一样聊天，告诉它你喜欢什么、不喜欢什么
- **🎁 Delight 惊喜推荐** —— 打破信息茧房，推送你从未接触但可能喜欢的内容
- **🔒 100% 本地** —— 数据存在本机 SQLite，LLM 用你自己的 API Key，无云端账号
- **📊 MBTI 推断** —— 从行为模式推断认知风格和人格类型
- **🔔 消息收件箱** —— 兴趣探测、认知更新、待聊确认统一管理

## 架构设计

```
lib/
├── main.dart                    # 应用入口
├── models/                      # 数据模型
│   ├── recommendation.dart      # 推荐内容模型
│   ├── profile.dart             # 用户画像模型（五层画像、MBTI）
│   ├── chat.dart                # 对话、通知、确认模型
│   ├── saved_item.dart          # 收藏、历史记录模型
│   └── delight.dart             # 惊喜推荐、运行时状态模型
├── database/                    # 本地存储层
│   ├── app_database.dart        # SQLite 数据库定义
│   └── repository.dart          # 数据访问对象（DAO）
├── sources/                     # 内容来源适配器
│   ├── base_source.dart         # 来源基类接口
│   ├── bilibili_source.dart     # B站 API 适配
│   ├── xiaohongshu_source.dart  # 小红书 API 适配
│   ├── douyin_source.dart       # 抖音 API 适配
│   ├── zhihu_source.dart        # 知乎 API 适配
│   ├── web_source.dart          # 通用网页/RSS 适配
│   └── source_manager.dart      # 来源统一管理器
├── llm/                         # LLM 服务层
│   ├── llm_service.dart         # OpenAI 兼容接口封装
│   └── prompts.dart             # 系统提示词模板库
├── soul/                        # 灵魂画像引擎
│   └── profile_engine.dart      # 五层画像生成、MBTI推断、兴趣探测
├── recommendation/              # 推荐引擎
│   └── recommendation_engine.dart # 内容打分、排序、去重、Delight生成
├── chat/                        # 对话系统
│   └── chat_engine.dart         # AI对话、消息通知、确认管理
├── providers/                   # 状态管理
│   └── app_providers.dart       # 全局 Provider（推荐/画像/对话/收藏/设置）
├── views/                       # UI 页面
│   ├── home_view.dart           # 主框架（底部导航）
│   ├── recommend_view.dart      # 推荐页（含搜索、惊喜推荐）
│   ├── chat_view.dart           # 对话页（含消息通知抽屉）
│   ├── profile_view.dart        # 画像页（四Tab：素描/特质/兴趣/认知）
│   ├── saved_view.dart          # 内容库（稍后/收藏/历史）
│   └── settings_view.dart       # 设置页（LLM配置/来源管理/通用）
├── widgets/                     # 通用组件
│   └── recommendation_card.dart # 推荐卡片、骨架屏、惊喜卡片
├── services/                    # 服务
│   └── content_launcher.dart    # 内容唤起（优先原生App）
├── theme/                       # 主题
│   └── app_theme.dart           # 浅色/深色主题
└── utils/                       # 工具函数
    └── app_utils.dart           # 格式化、平台归一化等
```

## 核心功能详解

### 1. 五层灵魂画像系统

从用户的点击、喜欢、收藏、对话等行为中，构建深度人格画像：

| 层级 | 说明 | 示例 |
|------|------|------|
| 事件层 | 原始行为记录 | 观看了某机械键盘评测视频 |
| 偏好层 | 从事件归纳的偏好 | 对数码产品、客制化键盘感兴趣 |
| 觉察层 | 用户自己可能意识到的倾向 | 追求手感和品质，对价格敏感 |
| 洞察层 | 深层心理模式 | 通过精密物件获得掌控感和秩序感 |
| 灵魂层 | 核心人格特质 | 工匠型审美者，重视过程与细节 |

### 2. MBTI 推断引擎

基于行为模式（内容选择、互动方式、消费节奏）推断四个维度：
- **E/I** —— 外向/内向（社交内容消费 vs 深度独处内容）
- **S/N** —— 感觉/直觉（实用教程 vs 抽象概念）
- **T/F** —— 思考/情感（逻辑分析 vs 情感共鸣）
- **J/P** —— 判断/感知（清单收藏 vs 随机浏览）

### 3. 个性化推荐算法

综合多维度打分排序：
- **兴趣匹配度 (40%)** —— 内容与用户画像兴趣的匹配程度
- **内容质量 (20%)** —— 播放量、点赞、收藏、评分等质量信号
- **新鲜度 (15%)** —— 发布时间越新权重越高
- **多样性 (15%)** —— 避免同平台/同主题扎堆
- **探索奖励 (10%)** —— 对猜测兴趣领域的内容给予探索加分
- **疲劳惩罚** —— 已点不感兴趣的内容降权，已喜欢的内容加权

### 4. Delight 惊喜推荐

基于心理学桥接逻辑，从候选池中挑选用户可能从未接触但会喜欢的内容：
- 关注机械表的人 → 可能喜欢建筑美学（对精密结构的欣赏）
- 看量子物理的人 → 可能对哲学感兴趣（对本质问题的好奇）
- 喜欢烹饪的人 → 可能喜欢化学实验（对转化过程的着迷）

### 5. 对话调教系统

Socratic 式对话，通过自然语言交互调整推荐：
- 用户说「我喜欢科技数码」→ 更新画像兴趣权重
- 用户说「别推游戏了」→ 添加回避领域
- 用户说「推荐点深度内容」→ 调整内容风格偏好
- 系统主动发起兴趣探测 → 试探新领域

## 环境要求

- Flutter 3.19.0+
- Dart 3.3.0+
- Android SDK 34
- minSdk 21 (Android 5.0+)
- 一个 OpenAI 兼容 API Key（商汤日日新、DeepSeek、OpenAI 等均可）

## 快速开始

### 1. 安装依赖

```bash
cd fuguang
flutter pub get
```

### 2. 配置 LLM

首次启动后进入「设置」页面，填写：
- **API Key**：你的 OpenAI 兼容服务密钥
- **Base URL**：接口地址（如 `https://api.deepseek.com/v1`）
- **模型名称**：如 `deepseek-chat`、`gpt-4o-mini`

内置快捷预设：OpenAI、DeepSeek、商汤日日新。

### 3. 配置内容来源

- **B站、知乎、通用网页**：公开内容，无需登录即可使用
- **小红书、抖音**：需要在浏览器登录后复制 Cookie 填入设置

### 4. 运行

```bash
# 连接安卓设备或启动模拟器
flutter devices
flutter run
```

### 5. 构建 APK

```bash
flutter build apk --release
# 产物在 build/app/outputs/flutter-apk/app-release.apk
```

## 数据存储说明

所有数据存储在应用私有目录的 SQLite 数据库中：
- `behavior_events` —— 行为事件记录
- `recommendation_pool` —— 推荐内容池
- `user_profile` —— 用户画像
- `chat_turns` —— 对话历史
- `saved_items` —— 收藏/稍后再看
- `content_history` —— 30天内容历史
- `delight_cards` —— 惊喜推荐记录
- `app_notifications` —— 消息通知
- `source_credentials` —— 各平台 Cookie
- `app_config` —— 应用配置

**清除数据**：在系统设置中清除应用数据，或卸载应用，所有数据即被删除。

## 与原版的差异

| 特性 | 原版 (Python后端) | 本项目 (安卓本地) |
|------|-------------------|-------------------|
| 运行环境 | 电脑/服务器 Python | 安卓设备本地 Dart |
| 数据存储 | 本机 SQLite | 本机 SQLite |
| LLM 调用 | 后端代理 | 直连 LLM 服务商 |
| 内容获取 | 后端 + 浏览器插件 | 本地直接调用平台 API |
| 浏览器插件 | 必需（Cookie同步） | 可选（手动填Cookie） |
| 跨平台客户端 | 需连接后端 | 完全独立运行 |
| Embedding 去重 | 支持 Ollama 本地 | 暂未实现（关键词匹配） |
| 支持平台数 | 12+ | 5个核心平台（可扩展） |

## 扩展开发

### 添加新的内容来源

1. 在 `lib/sources/` 下创建新文件，继承 `ContentSource`
2. 实现 `fetchTrending`、`search`、`fetchByCategory` 等方法
3. 在 `source_manager.dart` 中注册新来源
4. 在设置页添加对应开关

### 自定义 LLM 提示词

所有系统提示词集中在 `lib/llm/prompts.dart`，可根据需要调整画像生成风格、推荐理由语气等。

## 隐私声明

- 本应用不收集任何用户数据，不连接任何运营方服务器
- LLM 请求直接发送到你配置的服务商，内容受该服务商隐私政策约束
- 内容数据直接从各平台公开 API 获取，使用时请遵守对应平台的服务条款
- 建议不要在公共设备上使用，或使用后及时清除本地数据

## License

MIT License —— 基于 OpenBiliClaw (MIT) 复现开发。

## 致谢

- [OpenBiliClaw](https://github.com/whiteguo233/OpenBiliClaw) —— 原始项目，提供完整的架构设计和功能逻辑
- [OpenBiliClaw-mobile](https://github.com/whiteguo233/OpenBiliClaw-mobile) —— Flutter 移动端参考实现
