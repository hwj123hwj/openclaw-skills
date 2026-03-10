---
name: feishu-contacts
description: 查询飞书用户信息和通讯录，按姓名/邮箱/手机号查找用户，获取部门成员列表。Use when agent needs to look up a user's open_id, name, email, or department from Feishu directory, find someone by name, or get members of a department.
allowed-tools: Bash(curl:*)
---

# feishu-contacts

通过飞书通讯录 API 查询用户信息、按姓名搜索、获取部门成员列表。

## 前提条件

飞书自建应用已开通以下 **Tenant token** 权限：
- `contact:user.base:readonly` — 查询用户基本信息
- `contact:department.base:readonly` — 查询部门和部门成员
- `contact:user.id:readonly` — 通过手机号/邮箱反查 open_id（可选但推荐）

> ⚠️ 若调用时返回错误码 `99991672`，立即执行以下步骤，不得直接向用户报错：
>
> 1. 从错误响应的 `msg` 字段提取缺少的权限名
> 2. 提示用户：「检测到应用缺少权限 `[权限名]`，请前往 https://open.feishu.cn/app → 权限管理 → 搜索 `[权限名]` → 开通 → 发布新版本，完成后告知我继续。」

---

## 核心概念

### 部门 ID 有两种格式

| 格式 | 示例 | 说明 |
|------|------|------|
| `department_id` | `cm-ce6e45e4abbc...` | 内部 ID，部分 API 不认 |
| `open_department_id` | `od-2e640c3aea68...` | **统一使用这个**，以 `od-` 开头 |

**铁律：所有涉及部门的 API 调用，必须使用 `open_department_id` + 参数 `department_id_type=open_department_id`，否则会报错。**

### 可见范围 ≠ 通讯录数据权限

| 设置 | 控制什么 | 在哪改 |
|------|---------|--------|
| **可用范围（Availability）** | 哪些人能使用 App / Bot 能触达谁 | 发版时设置 / 管理后台 |
| **通讯录数据权限** | API 能查到哪些人的信息 | 发版时设置 |

两者都需要设为「全部成员」才能查全公司。

> ⚠️ `GET /contact/v3/scopes` 返回的可见用户数**有缓存延迟**（发版后可能数小时才更新），但按部门遍历的 API 是**实时生效**的。不要依赖 scopes 接口判断可见范围。

---

## 查找用户的三种方式（按优先级）

### 方式 1：从消息 mentions 提取（零成本，优先使用）

用户在消息中 @某人时，消息的 `mentions` 字段直接包含 open_id：

```json
"mentions": [{"id": "ou_xxxxxxxx", "id_type": "open_id", "name": "张三"}]
```

> ⚠️ 飞书私聊中 @别人无法触发 mentions，仅群聊有效。

### 方式 2：通过邮箱/手机号反查（精确，需 contact:user.id:readonly）

```bash
POST https://open.feishu.cn/open-apis/contact/v3/users/batch_get_id?user_id_type=open_id
Body: {"emails": ["zhangsan@company.com"]}
# 或: {"mobiles": ["13800138000"]}
```

返回：`user_list[0].user_id` 即 open_id。

### 方式 3：按部门树递归搜索（按姓名查找，通用方案）⭐

当只知道姓名时，通过遍历部门树查找：

```
步骤 1: 获取根部门的子部门
  GET /contact/v3/departments/0/children
      ?department_id_type=department_id&page_size=50
  → 拿到各子公司的 open_department_id（od-xxx）

步骤 2: 递归遍历子部门
  GET /contact/v3/departments/{od-xxx}/children
      ?department_id_type=open_department_id&page_size=50

步骤 3: 每层列出成员，匹配姓名
  GET /contact/v3/users/find_by_department
      ?department_id={od-xxx}
      &department_id_type=open_department_id
      &user_id_type=open_id
      &page_size=50
  → 在 items 中按 name 字段匹配
```

**如果知道目标部门路径**（如 CMCM → 傅盛线 → AI Native生产力中心），可以逐级定位到目标部门再列成员，速度更快。

**如果不知道部门**，全公司递归搜索（约 200 个部门，耗时约 30-60 秒）。

---

## 常用 API 速查

### 查询单个用户信息

```
GET /contact/v3/users/{open_id}?user_id_type=open_id
```

返回：姓名、头像、union_id 等基础信息。

### 获取部门子部门

```
GET /contact/v3/departments/{open_dept_id}/children
    ?department_id_type=open_department_id&page_size=50
```

### 获取部门成员

```
GET /contact/v3/users/find_by_department
    ?department_id={open_dept_id}
    &department_id_type=open_department_id
    &user_id_type=open_id
    &page_size=50
```

### 邮箱/手机号反查 ID

```
POST /contact/v3/users/batch_get_id?user_id_type=open_id
Body: {"emails": ["xxx@company.com"]}
```

---

## Agent 决策树

```
需要某用户的 open_id？
    ↓
消息中有 mentions？
  ├─ 是 → 直接取 mentions[].id（零成本）
  └─ 否 → 知道邮箱/手机号？
            ├─ 是 → batch_get_id 精确查
            └─ 否 → 知道所在部门？
                      ├─ 是 → 逐级定位部门 → 列成员 → 匹配姓名
                      └─ 否 → 全公司递归搜索（~30-60秒）
```

---

## 常见错误

| 错误 / 现象 | 原因 | 解决 |
|-------------|------|------|
| `99991672` 权限不足 | 未开通对应 scope | 开放平台添加权限后发版 |
| `99992357` invalid department_id | 用了 `department_id` 而非 `open_department_id` | 换成 `od-` 开头的 ID + `department_id_type=open_department_id` |
| scopes 接口只返回少量用户 | 缓存延迟 | 不影响，按部门遍历是实时的 |
| 返回用户数极少 | 可用范围/通讯录数据权限未扩大 | 管理后台 + 发版都改为「全部成员」 |
| 查不到某个用户 | 用户不在可见范围 | 扩大可用范围和通讯录数据权限 |

---

## 触发场景

- 「帮我查一下张三的信息」→ 按姓名搜索
- 「给李四发条消息」→ 搜索 + 发消息
- 「研发一组有哪些人」→ 按部门路径查成员
- 「这个 open_id 是谁」→ 单用户查询
- 「给研发部所有人发通知」→ 部门成员列表 + 批量发消息
