#!/bin/bash
# 飞书电子表格：创建表格 + 写入数据 + 读取数据
# 用法: bash sheets.sh

APP_ID="YOUR_APP_ID"
APP_SECRET="YOUR_APP_SECRET"
TITLE="${TITLE:-数据报表}"

# Step 1: 获取 tenant_access_token
TOKEN=$(curl -s -X POST \
  "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal" \
  -H "Content-Type: application/json" \
  -d "{\"app_id\":\"$APP_ID\",\"app_secret\":\"$APP_SECRET\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tenant_access_token'])")

echo "Token 获取成功"

# Step 2: 创建电子表格
RESP=$(curl -s -X POST \
  "https://open.feishu.cn/open-apis/sheets/v3/spreadsheets" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"$TITLE\"}")

SPREAD=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['spreadsheet']['spreadsheet_token'])")
URL=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['spreadsheet']['url'])")
echo "表格创建成功: $URL"
echo "spreadsheet_token: $SPREAD"

# Step 3: 获取 sheet_id
SHEET_ID=$(curl -s \
  "https://open.feishu.cn/open-apis/sheets/v3/spreadsheets/$SPREAD/sheets/query" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['sheets'][0]['sheet_id'])")

echo "sheet_id: $SHEET_ID"

# Step 4: 写入数据
curl -s -X PUT \
  "https://open.feishu.cn/open-apis/sheets/v2/spreadsheets/$SPREAD/values" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"valueRange\":{\"range\":\"${SHEET_ID}!A1:C4\",\"values\":[
    [\"姓名\",\"部门\",\"入职日期\"],
    [\"张三\",\"技术部\",\"2026-01-01\"],
    [\"李四\",\"市场部\",\"2026-02-01\"],
    [\"王五\",\"运营部\",\"2026-03-01\"]
  ]}}" > /dev/null

echo "数据写入成功"

# Step 5: 读取数据验证
echo "读取数据:"
curl -s \
  "https://open.feishu.cn/open-apis/sheets/v2/spreadsheets/$SPREAD/values/${SHEET_ID}!A1:C4" \
  -H "Authorization: Bearer $TOKEN" \
  | python3 -c "
import sys, json
d = json.load(sys.stdin)
rows = d['data']['valueRange']['values']
for row in rows:
    print(' | '.join(str(c) for c in row))
"

echo ""
echo "表格链接: $URL"
