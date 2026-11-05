# 元宝 OpenAI 兼容 API（yuanbao-openai-api）

把**腾讯元宝网页版**变成标准 **OpenAI 兼容 API** 的一键部署方案：零浏览器、零 npm 依赖、纯 Node 直连，支持流式对话、多模型、联网搜索、AI 生图。

> ⚠️ 研究学习用途，请遵守腾讯元宝服务条款；账号风险自负，勿商用。

---

## 一、这个项目是从哪来的（重要）

本项目**不是从零原创**，而是在以下开源项目成果基础上整理、验证、打包而成。特别感谢原作者，**本项目核心代码（QIMEI 签名搬迁、OpenAI 兼容层）均来自 `youyao666/yuanbao-pure-protocol`**。

### 主要参考 / 依赖的项目

| 项目 | 地址 | 本项目的使用方式 |
|---|---|---|
| **youyao666/yuanbao-pure-protocol** | https://github.com/youyao666/yuanbao-pure-protocol | **核心来源**。QIMEI 签名搬迁运行器（`qimei-standalone.js` + `qimei-modules.json`）、OpenAI 兼容服务（`yuanbao-server.js`）、登录器与探针均来自该项目（MIT License，Copyright (c) 2026 youyao666）。 |
| juzeon/yuanbao-chat2api | https://github.com/juzeon/yuanbao-chat2api | 早期「元宝网页转 API」的 Rust 实现，提供了两阶段调用流程（先 `conversation/create` 再 `chat/{id}`）与 SSE 解析思路的参考。 |
| 10020099/yuanbao2api | https://github.com/10020099/yuanbao2api | Go 语言实现，提供了 OpenAI/Anthropic 双兼容接口设计的参考。 |

### 从这些项目里学到的关键经验

1. **元宝 2.83 之后加了 QIMEI 签名**（`X-Uskey` / `X-Bus-Params-Md5` / `X-Timestamp`），只对 `/chat/` 和 `/conversation/create` 两个路径强制校验。
   - 直接裸发请求 → 返回 `401` 或 `服务繁忙，请稍后再试`。
   - 早期基于纯 HTTP 复刻的项目（Go 版、Rust 版）在新版元宝下都会卡在这里。
2. **签名函数 `getUSKeySync` 被 jsvmp 字节码虚拟机保护，无法静态逆向。**
   - youyao666 的巧妙解法是 **「整体搬迁」**：从元宝网页 dump 出全部 2524 个 webpack 模块，在 Node 里用迷你 webpack runtime + 浏览器环境桩原样跑起来，**签名产物与浏览器逐字节同源**。
3. **`X-Bus-Params-Md5 = md5("h38=<指纹>&timestamp=<毫秒>&platform=web")`**，是纯算法；`h38` 来自 QIMEI 本地生成的设备指纹（与账号身份解耦）。
4. **请求头必须整套**：网关会校验浏览器头完整性，缺 `x-requested-with` / `x-commit-tag` / `x-instance-id` 等会返回 `服务繁忙`（= 被风控拒绝）。
5. **身份只用 `hy_user` + `hy_token` 两个 cookie**（可浏览器扫码或手动粘贴），无需完整 `document.cookie`。

---

## 二、功能特性

- ✅ OpenAI 兼容：`/v1/chat/completions`（流式 + 非流式）、`/v1/models`
- ✅ 多模型：`hy4`（Hy4 preview，默认）、`hy3`、`deepseek` / `deepseek-v3` 等
- ✅ **联网搜索**：模型名加 `-search` 后缀即强制联网（如 `hy4-search`）
- ✅ **AI 生图**：`/v1/images/generations`（文生图）、`/v1/images/edits`（图生图）
- ✅ 工具调用（提示词注入式模拟，请求带 `tools` 自动启用）
- ✅ 零依赖：无需 npm install，无需常驻浏览器
- ✅ 纯 Node，Windows / Linux / macOS 通用

---

## 三、环境要求

- **Node.js ≥ 20**（用到原生 `fetch` / `WebSocket` / `TextDecoder`；实测 Node 24 正常）
- 无需任何 npm 依赖
- 首次登录需要一台带 Chrome/Edge 的电脑（扫码）；也可手动粘贴 cookie

---

## 四、快速开始

### 1. 获取凭据（二选一）

**方式 A（推荐）：自动扫码登录**
```bash
node yuanbao-login.js
```
浏览器弹出后扫码，日志出现「验证通过」即成功，自动生成 `yuanbao-cookie.json`。

**方式 B：手动粘贴 cookie**
浏览器登录 https://yuanbao.tencent.com 后按 F12，在 Network 里找任意 `/api/chat` 请求，复制 Request Headers 里的 `hy_user` 和 `hy_token` 两个值，手动创建 `yuanbao-cookie.json`：
```json
{
  "hy_user": "你的 hy_user",
  "hy_token": "你的 hy_token",
  "agentId": "naQivTmsDa"
}
```

### 2. 验证对话
```bash
node yuanbao-probe.js "你好"
# 指定模型：
node yuanbao-probe.js "你好" deep_seek_v3            # DeepSeek
node yuanbao-probe.js "你好" hunyuan_gpt_175B_0404   # Hy3
node yuanbao-probe.js "你好" hunyuan_omnipotent_hy4  # Hy4（默认）
```

### 3. 启动 OpenAI 兼容服务
```bash
node yuanbao-server.js
# 默认监听 http://127.0.0.1:8788/v1

# 或用便捷脚本（start/stop/restart/status）
bash start.sh
```

### 4. 客户端接入

在任何 OpenAI 兼容客户端（Cherry Studio / NextChat / Chatbox / 其他）里填写：

| 配置项 | 值 |
|---|---|
| API 地址 / Base URL | `http://127.0.0.1:8788/v1` |
| API Key | 留空即可（默认不校验） |
| 模型 | `hy4`（或 `hy3` / `deepseek` / `hy4-search`） |

> 需要鉴权时，启动前设置环境变量：`YUANBAO_API_KEY=sk-xxx node yuanbao-server.js`，客户端填同一个 Key。

---

## 五、生图用法

```bash
# 文生图（一次 4 张，自动下载到 images/）
node yuanbao-probe.js --image "画一只毛茸茸的小猫"

# 图生图
node yuanbao-probe.js --image2img 输入图.png "把这张图里的猫变成素描风格"
```

HTTP 端点：
```bash
curl http://127.0.0.1:8788/v1/images/generations \
  -H 'Content-Type: application/json' \
  -d '{"prompt":"画一只可爱的小狗","size":"1024x1024"}'
```

**生图双模式**（`start.sh` 切换，持久化）：
| 模式 | 命令 | 行为 |
|---|---|---|
| 预览（默认） | `bash start.sh preview` | 只返回图片 URL，客户端/对话里直接渲染，不落盘 |
| 保存 | `bash start.sh save` | 自动下载到 `/sdcard/Download/yuanbao-img/`，响应多带 `local_path` |

> 服务端也支持环境变量 `YUANBAO_IMG_SAVE=1`（保存）/ `0`（预览），`YUANBAO_IMG_DIR` 自定义保存目录。
> `local_path` 是服务端本机路径，方便在文件管理器直接找到图；`url` 始终可用，客户端用 url 渲染即可。


---

## 六、可用模型

| 模型名 | 说明 |
|---|---|
| `hy4` / `hunyuan_omnipotent_hy4` | Hy4 preview，最全能（默认） |
| `hy3` / `hunyuan_gpt_175B_0404` | Hy3，日常对话 |
| `deepseek` / `deep_seek_v3` | DeepSeek，深度推理 |
| `hunyuan-t1` | 深度思考 |
| 任意模型 + `-search` | 强制联网搜索（如 `hy4-search`） |

---

## 七、环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `YUANBAO_PORT` | `8788` | 服务端口 |
| `YUANBAO_API_KEY` | 空 | 设置后校验 `Authorization: Bearer <key>` |
| `YUANBAO_TOOLS` | 开 | `off` 关闭工具调用模拟 |
| `YUANBAO_WATERMARK_FREE` | 开 | `off` 关闭生图无水印换链 |
| `YUANBAO_IMG_SAVE` | 关 | `1` 生图自动下载到本地（配合 YUANBAO_IMG_DIR） |
| `YUANBAO_IMG_DIR` | `/sdcard/Download/yuanbao-img` | 生图保存目录 |
| `YUANBAO_NO_CLARIFY` | 关 | `on` 让搜索模式不反问 |

---

## 八、文件清单

| 文件 | 作用 |
|---|---|
| `qimei-standalone.js` | 核心：QIMEI SDK 搬迁运行器，导出 `createSigner()` |
| `qimei-modules.json` | 核心依赖：元宝网页 dump 的 2524 个 webpack 模块（约 10.6MB） |
| `yuanbao-server.js` | OpenAI 兼容服务（chat / models / images / files / vision） |
| `yuanbao-probe.js` | 探针：文本对话 + 生图 + SSE 解析 + 图片落盘 |
| `yuanbao-login.js` | 登录器：拉起 Chrome 扫码，自动抓凭据 |
| `start.sh` | 服务启动/停止/重启/状态脚本 |

运行后本地生成（**敏感，严禁提交**）：

| 文件 | 内容 |
|---|---|
| `yuanbao-cookie.json` | `hy_user` + `hy_token` 凭据 |
| `qimei-storage.json` | Node 环境 QIMEI 指纹（删除后自动重建） |

---

## 九、常见问题

| 现象 | 原因与解决 |
|---|---|
| `401` / `token_expired` | cookie 过期，重跑 `node yuanbao-login.js` |
| `服务繁忙，请稍后再试` | 签名失效或请求头不全；重新 dump `qimei-modules.json`（见下） |
| 生图只出文字 | 文生图要带绘画动词；图生图要 `plugin:""` |
| 签名失效（元宝改版后） | 需重新从元宝网页 dump 全部 webpack 模块，替换 `qimei-modules.json` |

**重新 dump 签名模块**（元宝改版后）：浏览器打开元宝 → 控制台执行 `webpackChunk_N_E.push([[tag],{},q=>window.__wr=q])` 钩出模块表 → 导出 `__wr.m` 全量源码合并为 `{modules:{id:source}}` JSON，覆盖 `qimei-modules.json`。入口模块 ID 会漂移（当前约为 77004）。

---

## 十、安全与合规

- `yuanbao-cookie.json` 等于你的元宝账号登录态，**严禁**提交 git / 分享 / 外传。
- 本项目仅供技术研究与学习，请勿商用；使用即视为自行承担账号风险。
- 核心代码版权归 `youyao666/yuanbao-pure-protocol` 作者（MIT License），本项目遵循 MIT 并保留原版权声明。

---

## 十一、致谢

感谢 [youyao666](https://github.com/youyao666/yuanbao-pure-protocol)（本项目核心实现）、以及 [juzeon](https://github.com/juzeon/yuanbao-chat2api)、[10020099](https://github.com/10020099/yuanbao2api) 在元宝协议逆向方向的先行探索。

---

## License

MIT License。核心代码 Copyright (c) 2026 youyao666；本项目整理与封装部分同以 MIT 发布。
