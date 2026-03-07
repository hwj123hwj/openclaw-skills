#!/bin/bash
# feishu-contacts — 通讯录查询脚本
# 将 YOUR_APP_ID / YOUR_APP_SECRET / OPEN_ID 替换为实际值

APP_ID="YOUR_APP_ID"
APP_SECRET="YOUR_APP_SECRET"

# ── 1. 获取 tenant_access_token ──────────────────────────────────────────────
TOKEN=$(curl -s -X POST \
  'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' \
  -H 'Content-Type: application/json' \
  -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant_access_token'])")

echo "Token: ${TOKEN:0:20}..."

# ── 2. 查询单个用户信息 ──────────────────────────────────────────────────────
OPEN_ID="ou_xxxxxxxx"

curl -s \
  "https://open.feishu.cn/open-apis/contact/v3/users/$OPEN_ID?user_id_type=open_id" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)['data']['user']
print(f\"姓名: {d['name']}\")
print(f\"邮箱: {d.get('email','无')}\")
print(f\"部门: {d.get('department_ids','无')}\")
"

# ── 3. 获取 Bot 可见范围内的所有用户 ────────────────────────────────────────
curl -s \
  'https://open.feishu.cn/open-apis/contact/v3/scopes' \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print('可见用户数:', len(d['data'].get('user_ids',[])))"

# ── 4. 按部门查询成员（需 contact:department.base:readonly）─────────────────
# DEPT_ID="od_xxxxxxxx"
# curl -s \
#   "https://open.feishu.cn/open-apis/contact/v3/departments/$DEPT_ID/members?user_id_type=open_id&page_size=50" \
#   -H "Authorization: Bearer $TOKEN" \
#   | python3 -c "
# import sys,json
# d=json.load(sys.stdin)
# members=d['data']['items']
# for m in members:
#     print(m['user_id'], m['name'])
# "
