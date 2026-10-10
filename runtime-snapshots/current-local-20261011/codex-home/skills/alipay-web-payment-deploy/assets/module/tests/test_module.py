from __future__ import annotations

import json
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from alipay_web_payment import AlipayConfig, AlipayPaymentService, ConfigError, SQLitePaymentStore
from alipay_web_payment.sdk import AlipaySdkClient, AlipaySdkError


def make_config(**overrides):
    values = {
        "environment": "sandbox",
        "app_id": "test-app",
        "seller_id": "test-seller",
        "app_private_key": "private",
        "alipay_public_key": "public",
        "gateway_url": "https://openapi-sandbox.dl.alipaydev.com/gateway.do",
        "return_url": "http://127.0.0.1/return",
        "notify_url": "https://example.com/notify",
        "order_amount_cny_cents": 730,
        "credit_units": 500000,
        "order_subject": "Usage credit",
    }
    values.update(overrides)
    return AlipayConfig(**values)


class FakeSdk:
    def __init__(self):
        self.verified = True
        self.query_result = {}

    def create_page_pay_html(self, **kwargs):
        return '<form method="post" action="https://openapi.alipay.com/gateway.do"></form>'

    def verify_notification(self, params):
        return self.verified

    def query(self, out_trade_no):
        return dict(self.query_result)


class ConfigTests(unittest.TestCase):
    def test_sandbox_configuration_accepts_inline_test_keys(self):
        env = {
            "ALIPAY_ENV": "sandbox",
            "ALIPAY_APP_ID": "sandbox-app",
            "ALIPAY_SELLER_ID": "sandbox-seller",
            "ALIPAY_APP_PRIVATE_KEY": "private",
            "ALIPAY_PUBLIC_KEY": "public",
            "ALIPAY_RETURN_URL": "http://127.0.0.1:8080/return",
            "ALIPAY_NOTIFY_URL": "https://example.com/notify",
            "ALIPAY_ORDER_AMOUNT_CNY_CENTS": "730",
            "ALIPAY_CREDIT_UNITS": "500000",
        }
        with patch.dict(os.environ, env, clear=True):
            config = AlipayConfig.from_env()
        self.assertEqual(config.environment, "sandbox")
        self.assertIn("sandbox", config.gateway_url)

    def test_live_rejects_inline_private_key(self):
        env = {
            "ALIPAY_ENV": "live",
            "ALIPAY_APP_ID": "live-app",
            "ALIPAY_SELLER_ID": "live-seller",
            "ALIPAY_APP_PRIVATE_KEY": "private",
            "ALIPAY_PUBLIC_KEY": "public",
            "ALIPAY_RETURN_URL": "https://example.com/return",
            "ALIPAY_NOTIFY_URL": "https://example.com/notify",
            "ALIPAY_ORDER_AMOUNT_CNY_CENTS": "730",
            "ALIPAY_CREDIT_UNITS": "500000",
        }
        with patch.dict(os.environ, env, clear=True):
            with self.assertRaises(ConfigError):
                AlipayConfig.from_env()

    def test_live_accepts_private_file_with_0600_permissions(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            private_path = Path(temp_dir) / "private.txt"
            public_path = Path(temp_dir) / "public.txt"
            private_path.write_text("private", encoding="utf-8")
            public_path.write_text("public", encoding="utf-8")
            private_path.chmod(0o600)
            env = {
                "ALIPAY_ENV": "live",
                "ALIPAY_APP_ID": "live-app",
                "ALIPAY_SELLER_ID": "live-seller",
                "ALIPAY_APP_PRIVATE_KEY_FILE": str(private_path),
                "ALIPAY_PUBLIC_KEY_FILE": str(public_path),
                "ALIPAY_RETURN_URL": "https://example.com/return",
                "ALIPAY_NOTIFY_URL": "https://example.com/notify",
                "ALIPAY_ORDER_AMOUNT_CNY_CENTS": "730",
                "ALIPAY_CREDIT_UNITS": "500000",
            }
            with patch.dict(os.environ, env, clear=True):
                config = AlipayConfig.from_env()
            self.assertTrue(config.live)


class SdkResponseTests(unittest.TestCase):
    def test_decodes_nested_and_top_level_response(self):
        nested = json.dumps({"alipay_trade_query_response": {"code": "10000", "trade_no": "1"}})
        self.assertEqual(
            AlipaySdkClient.decode_response(nested, "alipay_trade_query_response")["trade_no"],
            "1",
        )
        self.assertEqual(
            AlipaySdkClient.decode_response({"code": "10000", "trade_no": "2"}, "missing")[
                "trade_no"
            ],
            "2",
        )

    def test_preserves_provider_error_message(self):
        with self.assertRaisesRegex(AlipaySdkError, "交易不存在"):
            AlipaySdkClient.decode_response(
                {"alipay_trade_query_response": {"code": "40004", "sub_msg": "交易不存在"}},
                "alipay_trade_query_response",
            )


class PaymentFlowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.db_path = Path(self.temp.name) / "payments.sqlite3"
        self.store = SQLitePaymentStore(self.db_path)
        self.store.initialize()
        self.sdk = FakeSdk()
        self.credits = {}

        def credit(user_id, units, key):
            if key not in self.credits:
                self.credits[key] = (user_id, units)

        self.service = AlipayPaymentService(
            config=make_config(),
            sdk=self.sdk,
            store=self.store,
            credit_callback=credit,
        )

    def tearDown(self):
        self.temp.cleanup()

    def test_create_checkout_persists_order_and_returns_form(self):
        result = self.service.create_checkout("user-1")
        order = self.store.get_order(result["out_trade_no"])
        self.assertEqual(order["status"], "CREATED")
        self.assertEqual(order["amount_cents"], 730)
        self.assertIn("<form", result["payment_html"])

    def test_signed_notification_credits_exactly_once(self):
        checkout = self.service.create_checkout("user-1")
        params = {
            "notify_id": "notify-1",
            "app_id": "test-app",
            "seller_id": "test-seller",
            "out_trade_no": checkout["out_trade_no"],
            "trade_no": "trade-1",
            "trade_status": "TRADE_SUCCESS",
            "total_amount": "7.30",
            "sign": "signed",
            "sign_type": "RSA2",
            "charset": "utf-8",
        }
        self.assertEqual(self.service.handle_notification(params), "success")
        self.assertEqual(self.service.handle_notification(params), "success")
        self.assertEqual(len(self.credits), 1)
        self.assertEqual(self.store.get_order(checkout["out_trade_no"])["status"], "TRADE_SUCCESS")
        conn = sqlite3.connect(self.db_path)
        try:
            self.assertEqual(conn.execute("SELECT COUNT(*) FROM alipay_credit_ledger").fetchone()[0], 1)
        finally:
            conn.close()

    def test_invalid_signature_fails_closed(self):
        checkout = self.service.create_checkout("user-1")
        self.sdk.verified = False
        response = self.service.handle_notification(
            {
                "notify_id": "notify-bad",
                "out_trade_no": checkout["out_trade_no"],
                "trade_status": "TRADE_SUCCESS",
                "sign": "bad",
            }
        )
        self.assertEqual(response, "fail")
        self.assertFalse(self.credits)

    def test_return_uses_server_query_not_return_parameters(self):
        checkout = self.service.create_checkout("user-1")
        self.sdk.query_result = {
            "trade_status": "TRADE_SUCCESS",
            "trade_no": "trade-query",
            "total_amount": "7.30",
        }
        result = self.service.handle_return(checkout["out_trade_no"])
        self.assertFalse(result.already_credited)
        self.assertEqual(len(self.credits), 1)

    def test_amount_mismatch_does_not_credit(self):
        checkout = self.service.create_checkout("user-1")
        self.sdk.query_result = {
            "trade_status": "TRADE_SUCCESS",
            "trade_no": "trade-wrong-amount",
            "total_amount": "7.31",
        }
        with self.assertRaisesRegex(RuntimeError, "amount mismatch"):
            self.service.handle_return(checkout["out_trade_no"])
        self.assertFalse(self.credits)

    def test_refund_depositback_event_is_idempotent(self):
        checkout = self.service.create_checkout("user-1")
        self.sdk.query_result = {
            "trade_status": "TRADE_SUCCESS",
            "trade_no": "trade-refund",
            "total_amount": "7.30",
        }
        self.service.handle_return(checkout["out_trade_no"])
        content = {
            "trade_no": "trade-refund",
            "out_trade_no": checkout["out_trade_no"],
            "out_request_no": "refund-1",
            "dback_status": "S",
            "dback_amount": "7.30",
        }
        params = {
            "notify_id": "refund-notify-1",
            "msg_method": "alipay.trade.refund.depositback.completed",
            "app_id": "test-app",
            "biz_content": json.dumps(content),
            "sign": "signed",
        }
        self.assertEqual(self.service.handle_notification(params), "success")
        self.assertEqual(self.service.handle_notification(params), "success")
        conn = sqlite3.connect(self.db_path)
        try:
            count = conn.execute(
                "SELECT COUNT(*) FROM alipay_refund_depositback_events"
            ).fetchone()[0]
            self.assertEqual(count, 1)
        finally:
            conn.close()


if __name__ == "__main__":
    unittest.main()
