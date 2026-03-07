# 飞书云文档操作 API 速查

## 获取 tenant_access_token

```
POST https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal
Body: {"app_id": "YOUR_APP_ID", "app_secret": "YOUR_APP_SECRET"}
返回: tenant_access_token（2 小时有效）
```

## 创建文档

```
POST https://open.feishu.cn/open-apis/docx/v1/documents
Header: Authorization: Bearer {tenant_access_token}
Body: {"title": "文档标题"}
返回: document_id
```

## 写入内容块

```
POST https://open.feishu.cn/open-apis/docx/v1/documents/{doc_id}/blocks/{doc_id}/children
Header: Authorization: Bearer {tenant_access_token}
Body: {"children": [...blocks], "index": 0}
```

### Block 类型速查

| block_type | 说明 |
|------------|------|
| 2 | 文本/标题（`style.headingLevel=1/2/3`） |
| 3 | 有序列表 |
| 4 | 无序列表 |
| 14 | 代码块（`style.language`: 1=Go, 2=Python, 3=Shell） |

## 读取文档内容

```
GET https://open.feishu.cn/open-apis/docx/v1/documents/{doc_id}/blocks?page_size=200
Header: Authorization: Bearer {tenant_access_token}
```

## 删除内容块

```
DELETE https://open.feishu.cn/open-apis/docx/v1/documents/{doc_id}/blocks/{doc_id}/children/batch_delete
Body: {"start_index": 0, "end_index": N}
```

## 访问文档

文档链接格式：`https://bytedance.larkoffice.com/docx/{document_id}`

## 发送图片消息（用于二维码发送）

```
# 上传图片
POST https://open.feishu.cn/open-apis/im/v1/images
Header: Authorization: Bearer {tenant_access_token}
Form: image_type=message, image=@/path/to/image.png
返回: image_key

# 发送图片消息
POST https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id
Header: Authorization: Bearer {tenant_access_token}
Body: {
  "receive_id": "ou_xxx",
  "msg_type": "image",
  "content": "{\"image_key\": \"img_xxx\"}"
}
```
