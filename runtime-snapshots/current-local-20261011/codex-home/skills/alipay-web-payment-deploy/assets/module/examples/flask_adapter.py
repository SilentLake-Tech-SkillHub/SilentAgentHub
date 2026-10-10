"""Reference adapter. Add authentication, rate limits, CSRF protection and admin RBAC."""

import os

from flask import Flask, jsonify, redirect, request

from alipay_web_payment import (
    AlipayConfig,
    AlipayPaymentService,
    AlipaySdkClient,
    SQLitePaymentStore,
)


app = Flask(__name__)
config = AlipayConfig.from_env()
store = SQLitePaymentStore(os.environ["ALIPAY_DB_PATH"])
store.initialize()
sdk = AlipaySdkClient(config)


def grant_credit_idempotently(user_id: str, credit_units: int, idempotency_key: str) -> None:
    """Replace with the project's quota/wallet service.

    The target service must persist idempotency_key and return successfully for repeats.
    """
    raise NotImplementedError("Connect the project credit service before enabling payment")


service = AlipayPaymentService(
    config=config,
    sdk=sdk,
    store=store,
    credit_callback=grant_credit_idempotently,
)


@app.post("/api/alipay/orders")
def create_order():
    # Replace this header example with the project's authenticated server-side user id.
    user_id = request.headers.get("X-Authenticated-User-Id", "")
    if not user_id:
        return jsonify({"error": "Not authenticated"}), 401
    return jsonify(service.create_checkout(user_id))


@app.get("/api/billing/alipay/return")
def payment_return():
    out_trade_no = request.args.get("out_trade_no", "")
    result = service.handle_return(out_trade_no)
    return redirect(f"/dashboard?payment=success&order={result.out_trade_no}", code=303)


@app.post("/api/billing/alipay/notify")
def payment_notify():
    # This endpoint must not require a browser login or CSRF token.
    body = service.handle_notification(request.form.to_dict())
    return body, 200, {"Content-Type": "text/plain; charset=utf-8"}


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=8080)
