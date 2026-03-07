#!/bin/bash
# feishu-attendance — 查询飞书考勤打卡记录与统计汇总
# 将 YOUR_APP_ID / YOUR_APP_SECRET 替换为实际值

APP_ID="YOUR_APP_ID"
APP_SECRET="YOUR_APP_SECRET"

# 目标用户 open_id（可传多个）
USER_IDS='["ou_xxxxxxxx"]'

# 日期范围（整数 YYYYMMDD）
DATE_FROM=20260301
DATE_TO=20260307

# ── 1. 获取 tenant_access_token ──────────────────────────────────────────────
TOKEN=$(curl -s -X POST \
  'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' \
  -H 'Content-Type: application/json' \
  -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant_access_token'])")

echo "Token: ${TOKEN:0:20}..."

# ── 2. 获取考勤组列表 ────────────────────────────────────────────────────────
echo ""
echo "=== 考勤组列表 ==="
curl -s \
  'https://open.feishu.cn/open-apis/attendance/v1/groups?page_size=10' \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
for g in d['data'].get('group_list',[]):
    print(f\"{g['group_name']} | id={g['group_id']}\")
"

# ── 3. 查询打卡明细 ──────────────────────────────────────────────────────────
echo ""
echo "=== 打卡明细（$DATE_FROM ~ $DATE_TO）==="
curl -s -X POST \
  'https://open.feishu.cn/open-apis/attendance/v1/user_tasks/query' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"locale\": \"zh\",
    \"staff_type\": 1,
    \"include_terminated_user\": false,
    \"user_ids\": $USER_IDS,
    \"check_date_from\": $DATE_FROM,
    \"check_date_to\": $DATE_TO,
    \"user_id_type\": \"open_id\"
  }" \
  | python3 -c "
import sys,json
d=json.load(sys.stdin)
tasks=d['data'].get('user_task_results',[])
if not tasks:
    print('无打卡记录')
for t in tasks:
    date=t.get('check_date','')
    checkin=t.get('user_check_time','')
    status=t.get('check_result','')
    print(f\"日期={date} | 打卡时间={checkin} | 状态={status}\")
"

# ── 4. 查询月度统计 ──────────────────────────────────────────────────────────
echo ""
echo "=== 月度统计（2026-03）==="
curl -s -X POST \
  'https://open.feishu.cn/open-apis/attendance/v1/user_stats_datas/query' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d "{
    \"locale\": \"zh\",
    \"stats_type\": \"month\",
    \"start_date\": 20260301,
    \"end_date\": 20260331,
    \"user_ids\": $USER_IDS,
    \"user_id_type\": \"open_id\"
  }" \
  | python3 -m json.tool
