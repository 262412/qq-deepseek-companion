# QQ + DeepSeek Companion

一个面向 Windows 的个人 QQ AI 陪伴桥接程序。通过 NapCat 的 OneBot v11 接收和发送消息，直接调用 DeepSeek API；不需要安装或运行 DeepSeek Harness（DSH）。项目不包含 QQ 或 NapCat，请用户自行从上游安装。

这是非腾讯官方的个人 QQ 接入方式。QQ 协议端、QQ 账号和 API 服务各自有独立的使用规则与风险。

## 功能

- 私聊 QQ 白名单、群聊白名单；白名单群内新消息无需 @ 即可触发，每日最多回复 100 轮。
- 可编辑角色卡、私聊长期记忆、按会话隔离的近期上下文。
- 图片理解、语音转写、按需合成语音和生成图片；文本对话由 DeepSeek 处理，媒体能力可选配置 OpenAI API Key。
- 可选联网搜索与网页抓取，默认关闭。
- 引用消息读取、近期消息与群成员查询、戳一戳和表情内容。
- 仅监听本机地址的健康检查与精简控制台。

## 系统要求

- Windows 10/11。
- Node.js 22.21.0 或更高版本。
- NapCat 和可登录的 QQ 账号，单独安装和运行。
- DeepSeek API Key；OpenAI API Key 仅用于相应媒体功能。

桥接使用 Node.js 内置模块，只有 GPT-Live 语音输出依赖 ws。当前启动与设置界面面向 Windows，其他操作系统尚未作为支持环境。

## 安装与启动

1. 安装 Node.js，然后克隆或下载本项目。
2. 在项目目录安装依赖并生成本机配置：

       npm install
       npm run init

   init 会生成 config.local.json，并随机生成两个本机连接令牌。该文件不要上传或发送给别人。
3. 双击 setup.bat，填写 DeepSeek API Key、可选的 OpenAI API Key，以及允许私聊的 QQ 号和允许群聊的群号。Key 使用当前 Windows 用户的 DPAPI 加密保存。普通克隆默认保存到当前用户的 %LOCALAPPDATA%\QQDeepSeekCompanion\work。使用 GPT-Live 自定义声线时，在本机 config.local.json 中填写 openAiVoiceId。
4. 启动并登录 NapCat。在 NapCat 的 OneBot 配置中建立两条本机连接：
   - HTTP 服务器：监听 127.0.0.1:3000，Token 与 config.local.json 中 napcat.accessToken 一致。
   - HTTP 客户端：向 http://127.0.0.1:8787/onebot/event 推送事件，Token 与 config.local.json 中 listener.eventToken 一致；上报格式使用 array，并关闭上报自身消息。
   如果修改了 config.local.json 中的端口或路径，NapCat 连接地址也要同步修改。NapCat 官方配置说明见 https://napneko.github.io/config/basic。
5. 复制 persona/role.example.md 为 persona/role.md，再按自己的设定替换角色名、主人名和主人 QQ 号。角色卡模板里的占位符需要先修改。
6. 双击 start-companion.bat 启动桥接。NapCat 和桥接程序都要保持运行。访问 http://127.0.0.1:8787/health 检查桥接是否启动。

### 开始群聊

1. 把 AI QQ 账号邀请进目标群。
2. 在 setup.bat 的群聊白名单中填入群号并保存。
3. 重启桥接。在白名单群里直接发消息即可触发，不需要 @；机器人回复会 @ 发言者。

### 可选联网搜索

搜索默认关闭。需要时在 config.local.json 顶层设置 webSearch.enabled 为 true 后重启。程序仅在用户明确要求查找或问题依赖当前信息时搜索；每轮最多搜索一次、抓取一个搜索结果。

## 角色卡与记忆

persona/role.example.md 是可公开的角色卡模板。项目会优先读取本机的 persona/role.md；该文件已加入忽略列表，适合放个人化内容。没有本机角色卡时，程序读取示例模板。

私聊的事实、习惯、话题和待续事项保存在 state/people.json。聊天流水保存在 state/turns.jsonl，最多保留 800 条记录。群聊只共享该群近期上下文，不读取或整理成员的私聊记忆。每 5 条普通私聊用户消息会额外调用一次 DeepSeek 尝试提炼长期记忆；可在 config.local.json 中将 memory.extractEveryUserTurns 设为 0 关闭。

## 本地数据与 API 传输

config.local.json、state/、work/、voice.local.txt 和 persona/role.md 不应提交到 Git。当前 .gitignore 已排除这些本机数据。

私聊或白名单群消息及必要上下文会发送到 DeepSeek API；收到的图片会以 Base64 随当前轮发送，不长期保存。启用联网搜索后，搜索词和被抓取的网址会发送到 DeepSeek Search & Fetch API。收到的语音会先经 OpenAI 转写；明确要求合成语音或生图时，相关文本会发送给 OpenAI。媒体生成失败时不会发送文字兜底。OpenAI API 单独计费。

对话、图片和语音处理结果保存在本机 state/；控制台令牌也保存在 state/console-token。请勿上传 state/ 或 NapCat 登录目录。控制台只绑定 127.0.0.1，不显示聊天正文和 API Key。

## 开源来源

角色卡模板改编自 Deep Whisper 的角色与中文提示词文件，来源和许可说明见 THIRD_PARTY_NOTICES.md。项目采用 MIT License，详见 LICENSE。
