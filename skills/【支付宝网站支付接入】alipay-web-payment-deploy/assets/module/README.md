# Alipay Web Payment Module 1.0.0

该代码包用于中国境内支付宝电脑网站支付，核心接口为 `alipay.trade.page.pay`。它不是 Alipay Global、Alipay+、银行卡直连收单或自动续费模块。

## 包含能力

- 从文件或环境变量加载配置，生产环境强制 HTTPS、正式网关和私钥文件权限。
- 使用官方 `alipay-sdk-python==3.7.1160` 的 `page_execute()` 生成支付 HTML form。
- 服务端 `alipay.trade.query` 查询兜底，兼容 SDK 返回 JSON 字符串、顶层对象或标准 wrapper。
- RSA2 通知验签；canonical 原文按通知 charset 编码为 bytes 后调用 SDK。
- 校验 `app_id`、`seller_id`、订单、金额、交易状态和支付宝交易号。
- SQLite 参考订单、事件、账本和退款冲退消息表。
- 额度回调使用稳定幂等键 `alipay:{trade_no}`。
- 浏览器端只复制支付宝 form 字段并提交到官方 HTTPS 域名，不执行响应中的 script。
- 提供退款、退款查询、撤销、关单和账单下载 SDK 方法；这些方法必须由项目自行放在管理员权限与审计之后。

## 快速接入

1. 将本目录安装为 Python 包，或把 `src/alipay_web_payment` 复制到项目后端。
2. 安装 `alipay-sdk-python==3.7.1160`。
3. 复制 `.env.example`，把密钥放入 Git 外的 secret 文件。
4. 实现幂等的 `grant_credit_idempotently(user_id, credit_units, idempotency_key)`。
5. 参考 `examples/flask_adapter.py` 绑定三个接口：创单、同步回跳、异步通知。
6. 在前端加载 `frontend/alipay-checkout.js`，登录后调用 `AlipayCheckout.start()`。
7. 先跑沙箱，再做正式不扣款连通性检查，最后经授权执行异账号小额实付。

```html
<script src="/assets/alipay-checkout.js"></script>
<button id="alipay-pay" type="button">支付宝支付</button>
<script>
document.getElementById('alipay-pay').addEventListener('click', async () => {
  await AlipayCheckout.start({
    orderEndpoint: '/api/alipay/orders',
    headers: { 'X-CSRF-Token': window.csrfToken }
  });
});
</script>
```

## 必须由项目实现

- 登录态、CSRF、创单限流和用户身份绑定。
- 额度/钱包服务的幂等写入；不得只靠前端余额更新。
- 管理员退款审批、退款查询、退款账本、额度回收策略、撤销、关单和账单下载权限。
- 日对账、异常告警、密钥轮换、证书/产品状态巡检。
- 生产域名 HTTPS、回调无重定向、数据库备份和发布回滚。

## 安全红线

- 应用私钥只在服务端 secret 文件或 secret manager 中保存，生产文件权限不得开放给 group/others。
- 不把私钥、公钥正文、沙箱账号密码、Cookie、生产 `.env` 写进 Git、日志、截图或对话。
- 同步回跳参数不能直接触发入账，必须服务端查询支付宝。
- 异步通知必须先验签，再校验业务字段；无论失败原因均返回纯文本 `fail`。
- 退款、关单和账单下载不是公开用户 API。

## 测试

```bash
PYTHONPATH=src python3 -m unittest discover -s tests -v
node --check frontend/alipay-checkout.js
```
