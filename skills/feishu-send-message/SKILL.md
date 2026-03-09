---
name: feishu-send-message
description: 通过飞书 API 向指定用户或群组发送消息。Use when user asks to send a Feishu message, notify someone on Feishu, send a report/image/file via Feishu bot. 支持文本、图片、文件、富文本（post）、交互卡片等消息类型。全自动，无需人工介入。App ID 和 App Secret 自动从配置读取。
---

# feishu-send-message

通过飞书 Bot 向用户或群组发送消息，全自动，无需人工介入。

## 前提条件

- **飞书 App ID / Secret**：自动从系统配置（如 `openclaw.json`）中读取，无需用户提供。
- **权限**：已开通 Tenant token 权限 `im:message:send_as_bot` 并发布版本。

> ⚠️ 若调用时返回错误码 `99991672`，立即执行以下步骤，不得直接向用户报错：
>
> 1. 从错误响应的 `msg` 字段提取缺少的权限名
> 2. 向用户询问：「检测到应用缺少权限 `[权限名]`，有两种处理方式：A. 帮我自动开通（推荐，需扫码一次）；B. 我自己去设置。请选择？」
> 3. **用户选 A** → 读取并执行 `feishu-permission-setup` 技能，完成后重新调用原 API
> 4. **用户选 B** → 回复：「请前往 https://open.feishu.cn/app → 权限管理 → 搜索 `[权限名]` → 开通 → 发布新版本，完成后告知我继续。」

- **接收方的 ID**（open_id / user_id / union_id / email / chat_id 之一）

## 如何获取接收方 ID（优化版决策树）

### 发给用户（open_id）

用户只提供姓名时，按以下**优先级**处理：

```
只有姓名，没有 ID？
    ↓
1. 查本地缓存（memory/contacts.md）
    ↓ 找到了？→ 直接用，零延迟
    没找到？
    ↓
2. 消息 mentions 里有这个人吗？
    ↓ 是 → 直接从 mentions[].id 取（零成本）
    否
    ↓
3. 当前是群聊吗？
    ↓ 是 → 调用 /chats/{chat_id}/members 获取群成员列表
         → 查询用户信息补全姓名 → 缓存到本地
    否
    ↓
4. 用户提供了邮箱/手机号？
    ↓ 是 → 调用 batch_get_id 精确查询
    否
    ↓
5. 读取并执行 feishu-contacts 技能，按部门树递归搜索姓名
    ↓
    搜到了 → 拿到 open_id，缓存到本地，继续发消息
    搜不到 → 问用户要 open_id 或手机号/邮箱
```

> ⚠️ **常见误区**：`contact:user.id:readonly` 的用途是「通过手机号或邮箱查 open_id」，不是按姓名搜索。按姓名查人要用 feishu-contacts 技能的「按部门树递归搜索」方案。

### 缓存联系人信息

找到联系人后，自动保存到 `memory/contacts.md`：

```markdown
| 姓名 | open_id | 来源 | 更新时间 |
|------|---------|------|----------|
| 张三 | ou_xxx | 群聊 oc_xxx | 2025-03-09 |
```

### 获取群成员列表（快速方案）

在群聊中发消息时，优先使用此 API：

```bash
# 1. 获取群成员 open_id 列表
curl -s -G "https://open.feishu.cn/open-apis/im/v1/chats/{chat_id}/members" \
    --data-urlencode "member_id_type=open_id" \
    --data-urlencode "page_size=100" \
    -H "Authorization: Bearer $TOKEN"

# 2. 查询用户信息获取姓名
curl -s -G "https://open.feishu.cn/open-apis/contact/v3/users/{open_id}" \
    --data-urlencode "user_id_type=open_id" \
    -H "Authorization: Bearer $TOKEN"
```

需要权限：`im:chat:readonly` 和 `contact:user.base:readonly`

### 发给群组（chat_id）

用户只提供群名时，调用以下 API 搜索群：

```bash
curl -s -G "https://open.feishu.cn/open-apis/im/v1/chats" \
  --data-urlencode "search_key=群名关键词" \
  --data-urlencode "page_size=20" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
for c in d.get('data',{}).get('items',[]):
    print(c['chat_id'], c['name'])
"
```

需要权限 `im:chat:readonly`。找到 chat_id 后，发消息时 `receive_id_type=chat_id`。

## 核心流程

### Step 1 — 获取 tenant_access_token

```bash
# $APP_ID 和 $APP_SECRET 自动从配置获取
TOKEN=$(curl -s -X POST \
  "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant_access_token'])")
```

### Step 2 — 发送消息

```bash
curl -s -X POST \
  "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"receive_id\":\"$RECEIVER_ID\",\"msg_type\":\"text\",\"content\":\"{\\\"text\\\":\\\"Hello!\\\"}\"}"
```

`receive_id_type` 可选：`open_id` / `user_id` / `union_id` / `email` / `chat_id`（发群组用 `chat_id`）

## 消息类型速查

| msg_type | content 格式 | 说明 |
|----------|-------------|------|
| `text` | `{"text": "内容"}` | 纯文本 |
| `image` | `{"image_key": "img_xxx"}` | 图片（需先上传） |
| `file` | `{"file_key": "file_xxx"}` | 文件（需先上传） |
| `post` | 见下方示例 | 富文本，支持链接/@人/加粗 |
| `interactive` | 卡片 JSON | 交互卡片，支持按钮/表单 |

### 富文本（post）content 示例

```python
import json
content = json.dumps({
    "zh_cn": {
        "title": "通知标题",
        "content": [
            [{"tag": "text", "text": "这是正文内容"}],
            [{"tag": "a", "text": "点击查看", "href": "https://example.com"}],
            [{"tag": "at", "user_id": "ou_xxx", "user_name": "张三"}]
        ]
    }
})
```

## 上传图片 / 文件

发送图片或文件前，需先上传获取 key：

```bash
# 上传图片
IMG_KEY=$(curl -s -X POST \
  "https://open.feishu.cn/open-apis/im/v1/images" \
  -H "Authorization: Bearer $TOKEN" \
  -F "image_type=message" \
  -F "image=@/path/to/image.png" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['image_key'])")

# 上传文件
FILE_KEY=$(curl -s -X POST \
  "https://open.feishu.cn/open-apis/im/v1/files" \
  -H "Authorization: Bearer $TOKEN" \
  -F "file_type=stream" \
  -F "file_name=report.pdf" \
  -F "file=@/path/to/report.pdf" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['file_key'])")
```

## 常见错误

| 错误码 / 现象 | 原因 | 解决方法 |
|-------------|------|---------|
| 230013 | Bot 对该用户不可用（用户不在 Bot 可用范围内） | 见下方「处理 230013」 |
| 99991672 | 权限不足 | 检查是否开通权限并发布新版本 |
| 99991663 | token 过期 | 重新获取 token |

## 处理 230013：Bot 对目标用户不可用

遇到 230013 时，**引导用户手动处理**，不要自动调用 API 添加用户到 Bot 可用范围。

### 处理步骤

向用户说明情况并提供解决方案：

> 「目标用户不在 Bot 的可用范围内，无法发送消息。有两种解决方式：
> 
> **A. 扩大 Bot 可用范围（推荐）**
> 请前往 https://open.feishu.cn/app → 点击你的应用 → 凭证与基础信息 → 应用发布 → 可用范围 → 改为「全部成员」→ 发布新版本
>
> **B. 单独添加该用户**
> 请前往 https://open.feishu.cn/app → 点击你的应用 → 凭证与基础信息 → 应用发布 → 可用范围 → 添加指定用户 → 搜索并添加目标用户 → 发布新版本
>
> 完成后告知我，我会重新尝试发送消息。」

### 用户处理完成后

用户确认已修改可用范围并发布新版本后，重新尝试发送消息。

> ⚠️ 注意：发布新版本后可能需要等待几分钟生效。

## 参考资料

- 完整 Shell 脚本（文本+图片+文件）：`references/shell-script.md`
