#!/bin/bash
# feishu-calendar — 完整 Shell 脚本
# 用途：获取 token → 获取日历 → 创建日程
# 使用前将 YOUR_APP_ID / YOUR_APP_SECRET 替换为实际值

APP_ID="YOUR_APP_ID"
APP_SECRET="YOUR_APP_SECRET"

# ── 1. 获取 tenant_access_token ──────────────────────────────────────────────
TOKEN=$(curl -s -X POST \
  "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant_access_token'])")

echo "Token: ${TOKEN:0:20}..."

# ── 2. 获取日历 ID ───────────────────────────────────────────────────────────
CAL_ID=$(curl -s \
  "https://open.feishu.cn/open-apis/calendar/v4/calendars" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['calendar_list'][0]['calendar_id'])")

echo "Calendar ID: $CAL_ID"

# ── 3. 创建日程 ──────────────────────────────────────────────────────────────
EVENT_ID=$(curl -s -X POST \
  "https://open.feishu.cn/open-apis/calendar/v4/calendars/$CAL_ID/events" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "summary": "AI项目周会",
    "description": "本周进展同步",
    "start_time": {
      "date_time": "2026-03-09T10:00:00+08:00",
      "timezone": "Asia/Shanghai"
    },
    "end_time": {
      "date_time": "2026-03-09T11:00:00+08:00",
      "timezone": "Asia/Shanghai"
    },
    "visibility": "default",
    "attendee_ability": "can_invite_others"
  }' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['event']['event_id'])")

echo "日程已创建: $EVENT_ID"

# ── 4. 邀请参会人（可选）────────────────────────────────────────────────────
# ATTENDEE_ID="ou_xxx"
# curl -s -X POST \
#   "https://open.feishu.cn/open-apis/calendar/v4/calendars/$CAL_ID/events/$EVENT_ID/attendees" \
#   -H "Authorization: Bearer $TOKEN" \
#   -H "Content-Type: application/json" \
#   -d "{\"attendees\":[{\"type\":\"user\",\"user_id\":\"$ATTENDEE_ID\"}],\"user_id_type\":\"open_id\"}"

# ── 5. 查询忙闲（可选）──────────────────────────────────────────────────────
# curl -s -X POST \
#   "https://open.feishu.cn/open-apis/calendar/v4/freebusy/batch_get" \
#   -H "Authorization: Bearer $TOKEN" \
#   -H "Content-Type: application/json" \
#   -d '{
#     "time_min": "2026-03-09T09:00:00+08:00",
#     "time_max": "2026-03-09T18:00:00+08:00",
#     "user_id_list": ["ou_xxx"],
#     "user_id_type": "open_id"
#   }'
