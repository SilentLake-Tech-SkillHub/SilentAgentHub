# 环境变量与密钥规则

## 变量表

| 变量 | 必填 | 敏感 | 说明 |
|---|---|---|---|
| `ALIPAY_ENV` | 是 | 否 | `sandbox` 或 `live` |
| `ALIPAY_APP_ID` | 是 | 标识符 | 当前应用 APP ID |
| `ALIPAY_SELLER_ID` | live 必填 | 标识符 | 商户 PID |
| `ALIPAY_APP_PRIVATE_KEY_FILE` | 是 | 路径 | 应用私钥文件，生产必须使用文件/secret manager |
| `ALIPAY_PUBLIC_KEY_FILE` | 是 | 路径 | 支付宝公钥文件，不是应用公钥 |
| `ALIPAY_GATEWAY_URL` | 否 | 否 | 留空使用 sandbox/live 默认官方网关 |
| `ALIPAY_RETURN_URL` | 是 | 否 | 浏览器同步回跳，live 必须 HTTPS |
| `ALIPAY_NOTIFY_URL` | 是 | 否 | 支付宝异步通知，必须公网 HTTPS |
| `ALIPAY_ORDER_AMOUNT_CNY_CENTS` | 是 | 否 | 订单人民币分 |
| `ALIPAY_CREDIT_UNITS` | 是 | 否 | 项目内部额度，不是汇率 |
| `ALIPAY_ORDER_SUBJECT` | 是 | 否 | 收银台商品标题 |
| `ALIPAY_TIMEOUT_EXPRESS` | 否 | 否 | 默认 `30m` |
| `ALIPAY_DB_PATH` | 是 | 路径 | 参考订单/账本 SQLite 路径 |

## 存储

- 仓库只提交 `.env.example`，不得提交 `.env`、私钥、公钥正文、买家账号密码或生产 Cookie。
- 生产私钥建议路径 `/data/<service>/secrets/alipay-app-private-key.txt`，权限 `0600`。
- Docker 以只读方式挂载到 `/run/secrets/alipay-app-private-key.txt`。
- 支付宝公钥可以同样文件化管理，避免换行和转义错误。
- 备份密钥时使用受控密码库或云 secret manager，不放普通网盘和聊天记录。

## 轮换

1. 备份旧密钥和当前生产配置，记录 APP ID/PID。
2. 在隔离环境验证新应用公私钥匹配。
3. 上传新应用公钥并取得对应支付宝公钥。
4. 更新服务器 secret 文件，保持 `0600`，只重建支付后端。
5. 先做不存在订单的签名查询，再做经授权的小额实付和通知验签。
6. 保留旧订单查询/退款能力，确认迁移窗口结束后再销毁旧私钥。

验证脚本只输出“是否存在”和 URL host，不打印密钥：

```bash
python3 scripts/validate_env.py --env-file /secure/path/alipay.env
```
