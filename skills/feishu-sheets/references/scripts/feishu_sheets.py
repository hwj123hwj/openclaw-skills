"""
飞书电子表格 Python 封装
支持：创建表格、获取 sheet_id、写入数据、读取数据、追加数据
"""
import json
import subprocess


def _curl_json(method, url, token=None, body=None):
    cmd = ['curl', '-s', '-X', method, url]
    if token:
        cmd += ['-H', f'Authorization: Bearer {token}']
    if body:
        cmd += ['-H', 'Content-Type: application/json', '-d', json.dumps(body)]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(r.stdout)


def get_token(app_id, app_secret):
    """获取 tenant_access_token"""
    cmd = ['curl', '-s', '-X', 'POST',
           'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal',
           '-H', 'Content-Type: application/json',
           '-d', json.dumps({'app_id': app_id, 'app_secret': app_secret})]
    r = subprocess.run(cmd, capture_output=True, text=True)
    return json.loads(r.stdout)['tenant_access_token']


def create_spreadsheet(token, title, folder_token=''):
    """
    创建电子表格
    返回 dict: { spreadsheet_token, url, title }
    """
    d = _curl_json('POST',
                   'https://open.feishu.cn/open-apis/sheets/v3/spreadsheets',
                   token=token,
                   body={'title': title, 'folder_token': folder_token})
    ss = d['data']['spreadsheet']
    return {
        'spreadsheet_token': ss['spreadsheet_token'],
        'url': ss['url'],
        'title': ss['title']
    }


def get_sheet_id(token, spreadsheet_token, index=0):
    """
    获取指定 index 的 sheet_id（默认第一个工作表）
    """
    d = _curl_json('GET',
                   f'https://open.feishu.cn/open-apis/sheets/v3/spreadsheets/{spreadsheet_token}/sheets/query',
                   token=token)
    sheets = d['data']['sheets']
    return sheets[index]['sheet_id']


def write_values(token, spreadsheet_token, sheet_id, start_cell, values):
    """
    写入数据（覆盖）
    values: 二维列表，如 [["姓名","部门"], ["张三","技术部"]]
    start_cell: 起始单元格，如 "A1"
    自动计算结束单元格
    """
    rows = len(values)
    cols = max(len(r) for r in values)
    end_col = chr(ord('A') + cols - 1)
    end_cell = f'{end_col}{rows}'
    range_str = f'{sheet_id}!{start_cell}:{end_cell}'

    d = _curl_json('PUT',
                   f'https://open.feishu.cn/open-apis/sheets/v2/spreadsheets/{spreadsheet_token}/values',
                   token=token,
                   body={'valueRange': {'range': range_str, 'values': values}})
    return d


def read_values(token, spreadsheet_token, range_str):
    """
    读取数据
    range_str: 如 "SheetId!A1:C10"
    返回二维列表
    """
    url = f'https://open.feishu.cn/open-apis/sheets/v2/spreadsheets/{spreadsheet_token}/values/{range_str}'
    d = _curl_json('GET', url, token=token)
    return d['data']['valueRange']['values']


def append_values(token, spreadsheet_token, sheet_id, values):
    """
    追加数据（不覆盖现有内容，自动追加到末尾）
    """
    range_str = f'{sheet_id}!A1'
    d = _curl_json('POST',
                   f'https://open.feishu.cn/open-apis/sheets/v2/spreadsheets/{spreadsheet_token}/values_append',
                   token=token,
                   body={'valueRange': {'range': range_str, 'values': values}})
    return d


# ---- 使用示例 ----
if __name__ == '__main__':
    APP_ID = 'YOUR_APP_ID'
    APP_SECRET = 'YOUR_APP_SECRET'

    token = get_token(APP_ID, APP_SECRET)

    # 创建表格
    ss = create_spreadsheet(token, '员工数据报表')
    print(f"表格链接: {ss['url']}")

    # 获取 sheet_id
    sheet_id = get_sheet_id(token, ss['spreadsheet_token'])
    print(f"sheet_id: {sheet_id}")

    # 写入数据
    data = [
        ['姓名', '部门', '入职日期'],
        ['张三', '技术部', '2026-01-01'],
        ['李四', '市场部', '2026-02-01'],
    ]
    write_values(token, ss['spreadsheet_token'], sheet_id, 'A1', data)
    print("数据写入完成")

    # 读取验证
    rows = read_values(token, ss['spreadsheet_token'], f'{sheet_id}!A1:C3')
    for row in rows:
        print(' | '.join(str(c) for c in row))

    # 追加一行
    append_values(token, ss['spreadsheet_token'], sheet_id, [['王五', '运营部', '2026-03-01']])
    print("追加完成")
