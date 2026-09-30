from __future__ import annotations

import hashlib
import json
import secrets
from dataclasses import dataclass
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any

from .config import AlipayConfig
from .sdk import AlipaySdkClient
from .store import CreditCallback, SQLitePaymentStore


PAID_STATUSES = {"TRADE_SUCCESS", "TRADE_FINISHED"}
REFUND_MESSAGE = "alipay.trade.refund.depositback.completed"


def money_to_cents(value: Any) -> int:
    try:
        amount = Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
    except (InvalidOperation, ValueError, TypeError) as exc:
        raise RuntimeError("Alipay amount is invalid") from exc
    cents = int(amount * 100)
    if cents <= 0:
        raise RuntimeError("Alipay amount must be positive")
    return cents


def new_order_no(prefix: str = "ap") -> str:
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d%H%M%S")
    return f"{prefix}{stamp}{secrets.token_hex(6)}"


def sanitized_payload(params: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in params.items() if key not in {"sign", "sign_type"}}


@dataclass(frozen=True)
class PaymentResult:
    out_trade_no: str
    trade_no: str
    status: str
    already_credited: bool
    credit_units: int


class AlipayPaymentService:
    def __init__(
        self,
        *,
        config: AlipayConfig,
        sdk: AlipaySdkClient,
        store: SQLitePaymentStore,
        credit_callback: CreditCallback,
    ):
        self.config = config
        self.sdk = sdk
        self.store = store
        self.credit_callback = credit_callback

    def create_checkout(self, user_id: str) -> dict[str, Any]:
        if not str(user_id).strip():
            raise RuntimeError("Authenticated user_id is required")
        out_trade_no = new_order_no()
        self.store.create_order(
            out_trade_no=out_trade_no,
            user_id=str(user_id),
            amount_cents=self.config.order_amount_cny_cents,
            credit_units=self.config.credit_units,
            subject=self.config.order_subject,
        )
        try:
            payment_html = self.sdk.create_page_pay_html(
                out_trade_no=out_trade_no,
                amount_cny_cents=self.config.order_amount_cny_cents,
                subject=self.config.order_subject,
            )
        except Exception:
            self.store.update_status(out_trade_no, "CREATE_FAILED", {})
            raise
        return {
            "out_trade_no": out_trade_no,
            "amount_cents": self.config.order_amount_cny_cents,
            "currency": "CNY",
            "credit_units": self.config.credit_units,
            "payment_html": payment_html,
        }

    def handle_return(self, out_trade_no: str) -> PaymentResult:
        if not out_trade_no:
            raise RuntimeError("out_trade_no is required")
        # Never credit from return_url query parameters. Query Alipay server-to-server.
        payment_data = self.sdk.query(out_trade_no)
        return self._apply_paid(out_trade_no, payment_data, source="return_query")

    def handle_notification(self, params: dict[str, Any]) -> str:
        safe_payload = sanitized_payload(params)
        event_id = str(params.get("notify_id") or "") or hashlib.sha256(
            json.dumps(safe_payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
        ).hexdigest()
        event_type = str(
            params.get("msg_method")
            or params.get("notify_type")
            or params.get("trade_status")
            or "unknown"
        )
        out_trade_no = str(params.get("out_trade_no") or "")
        self.store.record_event(
            event_id=event_id,
            event_type=event_type,
            out_trade_no=out_trade_no,
            payload=safe_payload,
        )
        verified = False
        try:
            verified = self.sdk.verify_notification(params)
            if not verified:
                raise RuntimeError("Alipay notification verification failed")
            msg_method = str(params.get("msg_method") or "")
            if msg_method == REFUND_MESSAGE:
                self._handle_refund_depositback(params, safe_payload)
            elif msg_method:
                raise RuntimeError("Unsupported Alipay message method")
            else:
                status = str(params.get("trade_status") or "")
                if status in PAID_STATUSES:
                    self._apply_paid(out_trade_no, params, source="notify")
                else:
                    self.store.update_status(out_trade_no, status or "NOTIFIED", safe_payload)
            self.store.finish_event(event_id, verified=True, processed=True)
            return "success"
        except Exception as exc:
            self.store.finish_event(
                event_id,
                verified=verified,
                processed=False,
                error=str(exc),
            )
            return "fail"

    def _apply_paid(
        self,
        out_trade_no: str,
        payment_data: dict[str, Any],
        *,
        source: str,
    ) -> PaymentResult:
        status = str(payment_data.get("trade_status") or "")
        if status not in PAID_STATUSES:
            raise RuntimeError("Alipay trade is not paid")
        trade_no = str(payment_data.get("trade_no") or "")
        if not trade_no:
            raise RuntimeError("Alipay trade_no is missing")
        if payment_data.get("app_id") and str(payment_data["app_id"]) != self.config.app_id:
            raise RuntimeError("Alipay app_id mismatch")
        if (
            self.config.seller_id
            and payment_data.get("seller_id")
            and str(payment_data["seller_id"]) != self.config.seller_id
        ):
            raise RuntimeError("Alipay seller_id mismatch")
        amount_cents = money_to_cents(payment_data.get("total_amount"))
        result = self.store.apply_paid_order(
            out_trade_no=out_trade_no,
            trade_no=trade_no,
            amount_cents=amount_cents,
            status=status,
            source=source,
            payload=sanitized_payload(payment_data),
            credit_callback=self.credit_callback,
        )
        return PaymentResult(
            out_trade_no=out_trade_no,
            trade_no=trade_no,
            status=status,
            already_credited=bool(result["already_credited"]),
            credit_units=int(result["credit_units"]),
        )

    def _handle_refund_depositback(
        self,
        params: dict[str, Any],
        safe_payload: dict[str, Any],
    ) -> None:
        if str(params.get("app_id") or "") != self.config.app_id:
            raise RuntimeError("Alipay app_id mismatch")
        notify_id = str(params.get("notify_id") or "")
        if not notify_id:
            raise RuntimeError("Alipay notify_id is missing")
        try:
            content = json.loads(str(params.get("biz_content") or "{}"))
        except json.JSONDecodeError as exc:
            raise RuntimeError("Alipay refund event biz_content is invalid") from exc
        if not isinstance(content, dict):
            raise RuntimeError("Alipay refund event biz_content must be an object")
        required = ("trade_no", "out_trade_no", "out_request_no", "dback_status")
        missing = [name for name in required if not str(content.get(name) or "")]
        if missing:
            raise RuntimeError("Alipay refund event missing: " + ", ".join(missing))
        dback_status = str(content["dback_status"])
        if dback_status not in {"S", "F"}:
            raise RuntimeError("Alipay refund dback_status is invalid")
        dback_amount_cents = None
        if content.get("dback_amount") not in (None, ""):
            dback_amount_cents = money_to_cents(content["dback_amount"])
        if dback_status == "S" and dback_amount_cents is None:
            raise RuntimeError("Alipay refund dback_amount is missing")
        self.store.record_refund_depositback(
            notify_id=notify_id,
            content=content,
            dback_amount_cents=dback_amount_cents,
            payload=safe_payload,
        )
