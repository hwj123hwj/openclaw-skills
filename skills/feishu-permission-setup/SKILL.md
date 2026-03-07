---
name: feishu-permission-setup
description: 通过浏览器自动化为飞书自建应用申请并发布新的 Tenant token 权限，解锁飞书 API 能力（如云文档创建、编辑等）。Use when: (1) a Feishu API call fails with error code 99991672 (permission denied / 应用尚未开通所需的应用身份权限), (2) user asks to enable/add a Feishu app permission or scope, (3) user asks why a Feishu API is returning a permission error. Requires one human QR code scan for login (human-in-the-loop). After permissions are granted, can also create and write Feishu documents via API.
---

# feishu-permission-setup

通过浏览器自动化操控飞书开放平台，完成权限申请与版本发布，从而解锁飞书 API 能力。

> ⚠️ 飞书开放平台强制二维码扫码登录，无账号密码接口。**唯一需要人介入的步骤**：截图二维码发给管理员扫码。

## 触发场景

- 飞书 API 返回错误码 `99991672`
- 用户说「开通飞书 XXX 权限」「给飞书 App 申请文档读写权限」
- 「为什么我的 API 没有权限」

## 前置条件

1. 持有目标飞书 App 的 Owner 或 Administrator 权限
2. 已安装 `agent-browser`（或使用 `browser` 工具）
3. 已知目标 App ID（`YOUR_APP_ID`）
4. 从 API 报错 `msg` 中提取需要开通的权限名称（如 `docx:document:create`）

## 核心流程

### Step 1：从报错精准定位权限名

直接调用目标 API，从错误响应中提取缺少的权限：

```
错误码: 99991672
msg: 应用尚未开通所需的应用身份权限：[docx:document:create]
→ 提取: SCOPE="docx:document:create"
```

### Step 2：打开飞书开放平台，截图二维码发给管理员

```bash
agent-browser open "https://open.feishu.cn/app/YOUR_APP_ID/auth"
agent-browser screenshot /tmp/qr.png
# 通过飞书消息 API 上传图片并发送给管理员
curl -X POST https://open.feishu.cn/open-apis/im/v1/images \
  -H "Authorization: Bearer {tenant_access_token}" \
  -F "image_type=message" -F "image=@/tmp/qr.png"
# 发送图片消息给管理员，等待扫码完成
```

扫码完成后，管理员确认即可继续。

### Step 3：在 Tenant token scopes 标签页添加权限

> ⚠️ 关键：**必须在「Tenant token scopes」标签页**添加，而非「User token scopes」

```bash
# 确认已登录并在权限页
agent-browser get url

# 点击 Add permission scopes to app
agent-browser snapshot -i | grep "Add permission"
agent-browser click @eXX

# 关闭说明弹窗（如有）
agent-browser find text "Got It" click 2>/dev/null || true

# 在搜索框输入权限名
agent-browser snapshot -i | grep textbox
agent-browser click @eXX      # 搜索框
agent-browser fill @eXX "$SCOPE"

# 勾选 Tenant token 版本的权限 → 点击 Add Scopes
agent-browser check @eXX
agent-browser eval "document.querySelectorAll('button').find(b=>b.textContent.trim()==='Add Scopes')?.click()"
```

### Step 4：发布新版本使权限生效

权限变更**必须发布新版本**才生效，不是实时的。

```bash
# 点击 Create Version
agent-browser eval "document.querySelectorAll('button').find(b=>b.textContent.trim()==='Create Version')?.click()"

# 填写版本号和说明（React 输入框需用原生 setter）
agent-browser eval "
(() => {
  const iS = Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype, 'value').set;
  const tS = Object.getOwnPropertyDescriptor(window.HTMLTextAreaElement.prototype, 'value').set;
  const v = document.querySelectorAll('input')[0];
  const t = document.querySelector('textarea');
  iS.call(v, '1.0.1');
  v.dispatchEvent(new Event('input',{bubbles:true}));
  tS.call(t, 'Add $SCOPE');
  t.dispatchEvent(new Event('input',{bubbles:true}));
})()
"

# Save → Publish
agent-browser eval "document.querySelectorAll('button')[6].click()"  # Save
agent-browser eval "document.querySelectorAll('button').find(b=>b.textContent.trim()==='Publish')?.click()"
```

企业内部 App 通常无需审核，Publish 后立即 Released。

### Step 5：验证权限

重新调用之前失败的 API，确认不再返回 `99991672` 错误。

## 关键注意事项

- **Tenant vs User token 不可混用**：用 `tenant_access_token` 调用的 API 必须开 Tenant token 类型权限
- **批量开通**：可用「Batch import/export scopes」一次性添加多个权限（JSON 格式）
- **版本发布延迟**：权限变更必须发布新版本才生效
- **session 超时**：操作前先 `agent-browser get url` 确认 session 有效
- **React 输入框**：版本号和说明的 input 需要用原生 setter 注入，不能直接赋值

## 飞书文档相关 Tenant token 权限速查

| 权限名 | 说明 |
|--------|------|
| `docx:document:create` | 创建文档 |
| `docx:document:write_only` | 写入/编辑内容 |
| `docx:document:readonly` | 读取文档内容 |

详细的文档操作 API 和 Block 类型速查，参见 [references/feishu-doc-api.md](references/feishu-doc-api.md)
