---
name: feishu-permission-setup
description: >-
  通过浏览器自动化为飞书自建应用申请并发布新的 Tenant token 权限。
  Use when a Feishu API call fails with error 99991672 (permission denied).
  Requires human QR scan once for login.
allowed-tools: browser, message, exec
---

# feishu-permission-setup

通过浏览器自动化操控飞书开放平台，完成权限申请与版本发布，从而解锁飞书 API 能力。

## 核心挑战

飞书开放平台（open.feishu.cn）**强制二维码扫码登录**，没有账号密码接口，Agent 无法完全自主完成。

**解决方案：Human-in-the-loop（人机协作）**

1. Agent 用浏览器自动化工具打开登录页
2. 截图二维码，通过飞书消息发给负责人
3. 负责人用手机扫码，登录完成
4. Agent 继续后续自动化操作

## 触发场景

- 飞书 API 返回错误码 `99991672`
- 用户说「开通飞书 XXX 权限」「给飞书 App 申请文档读写权限」
- 「为什么我的 API 没有权限」

## 前置条件

1. 持有目标飞书 App 的 Owner 或 Administrator 权限
2. 已知目标 App ID（`YOUR_APP_ID`）
3. 从 API 报错 `msg` 中提取需要开通的权限名称（如 `docx:document:create`）

## 核心流程

### Step 1：从报错精准定位权限名

直接调用目标 API，飞书会在错误响应中明确告知缺少哪个权限：

```
错误码: 99991672
msg: 应用尚未开通所需的应用身份权限：[docx:document:create]
→ 提取: SCOPE="docx:document:create"
```

这比猜权限名称高效得多。

### Step 2：截图二维码发给负责人

使用 `browser` 工具打开飞书开放平台登录页，截图后通过飞书消息发送给管理员扫码。

```
# 打开飞书开放平台权限页（会跳转到登录页）
browser action=navigate url="https://open.feishu.cn/app/YOUR_APP_ID/auth"

# 截图二维码
browser action=screenshot path="/tmp/qr.png"

# 通过 message 工具发送二维码给管理员
message action=send media="/tmp/qr.png" message="请扫码登录飞书开放平台"
```

等待管理员确认扫码完成后继续。

### Step 3：在 Tenant token scopes 标签页添加权限

登录后进入：Developer Console → 目标 App → Permissions & Scopes → Add permission scopes to app

> ⚠️ 关键：**必须在「Tenant token scopes」标签页**下添加，而非「User token scopes」
>
> - Tenant token = 应用自身身份，适用于大多数后台 API 调用
> - User token = 代表已登录用户，两者不可混用

操作步骤：

```
# 确认已登录并在权限页
browser action=snapshot

# 点击「Add permission scopes to app」
browser action=act request={kind: "click", ref: "<Add permission scopes to app 按钮的 ref>"}

# 关闭说明弹窗（如有 "Got It" 按钮）
browser action=act request={kind: "click", ref: "<Got It 按钮的 ref>"}

# 切换到「Tenant token scopes」标签（如果不在该标签下）
browser action=act request={kind: "click", ref: "<Tenant token scopes 标签的 ref>"}

# 在搜索框输入权限名
browser action=act request={kind: "fill", ref: "<搜索框的 ref>", text: "$SCOPE"}

# 勾选搜索结果中的权限
browser action=act request={kind: "click", ref: "<权限 checkbox 的 ref>"}

# 点击 Add Scopes
browser action=act request={kind: "click", ref: "<Add Scopes 按钮的 ref>"}
```

> 💡 每一步操作前先 `browser action=snapshot` 获取当前页面元素的 ref，再精准操作。

### Step 4：发布新版本使权限生效

权限变更**不是实时生效**的，**必须发布新版本**。

操作路径：页面顶部黄色提示 → Create Version → 填写版本号 → Save → Publish

```
# 点击 Create Version
browser action=act request={kind: "click", ref: "<Create Version 按钮的 ref>"}

# 填写版本号（React 输入框需用 evaluate 注入）
browser action=act request={kind: "evaluate", fn: "() => { const s = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set; const v = document.querySelectorAll('input')[0]; s.call(v, '1.0.1'); v.dispatchEvent(new Event('input', {bubbles:true})); }"}

# 填写版本说明
browser action=act request={kind: "evaluate", fn: "() => { const s = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set; const t = document.querySelector('textarea'); s.call(t, 'Add SCOPE_NAME'); t.dispatchEvent(new Event('input', {bubbles:true})); }"}

# Save
browser action=act request={kind: "click", ref: "<Save 按钮的 ref>"}

# Publish
browser action=act request={kind: "click", ref: "<Publish 按钮的 ref>"}
```

企业内部 App 通常无需管理员审核，Publish 后立即 Released。

### Step 5：验证权限

重新调用之前失败的 API，确认不再返回 `99991672` 错误。

## 关键注意事项

- **Tenant vs User token 不可混用**：用 `tenant_access_token` 调用的 API 必须开 Tenant token 类型权限
- **批量开通**：可用「Batch import/export scopes」一次性添加多个权限（JSON 格式）
- **版本发布延迟**：权限变更必须发布新版本才生效，不是实时的
- **session 超时**：浏览器 session 会断开，操作前先 `browser action=snapshot` 确认状态
- **React 输入框**：版本号和说明的 input 需要用原生 setter 注入，不能直接 fill

## 飞书文档相关 Tenant token 权限速查

| 权限名 | 说明 |
|--------|------|
| `docx:document:create` | 创建文档 |
| `docx:document:write_only` | 写入/编辑内容 |
| `docx:document:readonly` | 读取文档内容 |

详细的文档操作 API 和 Block 类型速查，参见 [references/feishu-doc-api.md](references/feishu-doc-api.md)
