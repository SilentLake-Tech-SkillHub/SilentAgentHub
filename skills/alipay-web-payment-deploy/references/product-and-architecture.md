# 产品与架构基线

## 产品边界

本 Skill 只覆盖中国境内支付宝电脑网站支付：

- API：`alipay.trade.page.pay`
- 产品码：`FAST_INSTANT_TRADE_PAY`
- 服务端：Python 官方 SDK
- 币种：CNY
- 付款形态：浏览器跳转或二维码进入支付宝收银台

以下能力必须另行决策和签约：手机网站支付、APP 支付、JSAPI、小程序支付、周期扣款、Alipay Global、Alipay+、Visa/Mastercard 直连收单。

## 必须保持的数据流

```text
登录用户 -> 商户后端创建本地订单 -> SDK page_execute 生成 form
-> 浏览器提交至支付宝 -> 买家付款
-> 支付宝 notify_url -> 验签 -> 业务字段校验 -> 幂等账本 -> 用户额度
-> return_url -> 服务端 alipay.trade.query -> 查询兜底 -> 同一幂等账本
```

同步回跳和异步通知可以同时到达。两条路径必须进入同一个幂等处理函数，以支付宝 `trade_no` 和商户 `out_trade_no` 作为稳定标识。

## 项目适配接口

项目必须提供：

1. 已认证的服务端 `user_id`，禁止接受前端任意 user id。
2. `grant_credit(user_id, units, idempotency_key)`，并持久化去重 `idempotency_key`。
3. 创单 API 的登录、CSRF 和限流。
4. 公网 `return_url` 和 `notify_url`。
5. 管理员退款/关单/账单权限和审计。

## 推荐 API

| 方法 | 路径 | 鉴权 | 用途 |
|---|---|---|---|
| GET | `/api/alipay/config` | 可公开脱敏 | 环境、币种、固定金额、是否配置 |
| POST | `/api/alipay/orders` | 登录 + CSRF + 限流 | 创建本地订单和支付宝 form |
| GET | `/api/billing/alipay/return` | 无登录依赖 | 服务端查询后跳回 Dashboard |
| POST | `/api/billing/alipay/notify` | 无登录/CSRF | 支付宝 signed notify，返回纯文本 |

管理员退款、撤销和账单下载不要复用公开用户路由。
