from __future__ import annotations

import json
from decimal import Decimal
from typing import Any

from .config import AlipayConfig


class AlipaySdkError(RuntimeError):
    pass


def _money(cents: int) -> str:
    return format(Decimal(cents) / Decimal(100), ".2f")


class AlipaySdkClient:
    def __init__(self, config: AlipayConfig):
        self.config = config
        imports = self._imports()
        client_config = imports["AlipayClientConfig"]()
        client_config.server_url = config.gateway_url
        client_config.app_id = config.app_id
        client_config.app_private_key = config.app_private_key
        client_config.alipay_public_key = config.alipay_public_key
        client_config.charset = config.charset
        client_config.sign_type = config.sign_type
        self._client = imports["DefaultAlipayClient"](alipay_client_config=client_config)
        self._types = imports

    @staticmethod
    def _imports() -> dict[str, Any]:
        try:
            from alipay.aop.api.AlipayClientConfig import AlipayClientConfig
            from alipay.aop.api.DefaultAlipayClient import DefaultAlipayClient
            from alipay.aop.api.domain.AlipayDataDataserviceBillDownloadurlQueryModel import (
                AlipayDataDataserviceBillDownloadurlQueryModel,
            )
            from alipay.aop.api.domain.AlipayTradeCancelModel import AlipayTradeCancelModel
            from alipay.aop.api.domain.AlipayTradeCloseModel import AlipayTradeCloseModel
            from alipay.aop.api.domain.AlipayTradeFastpayRefundQueryModel import (
                AlipayTradeFastpayRefundQueryModel,
            )
            from alipay.aop.api.domain.AlipayTradePagePayModel import AlipayTradePagePayModel
            from alipay.aop.api.domain.AlipayTradeQueryModel import AlipayTradeQueryModel
            from alipay.aop.api.domain.AlipayTradeRefundModel import AlipayTradeRefundModel
            from alipay.aop.api.request.AlipayDataDataserviceBillDownloadurlQueryRequest import (
                AlipayDataDataserviceBillDownloadurlQueryRequest,
            )
            from alipay.aop.api.request.AlipayTradeCancelRequest import AlipayTradeCancelRequest
            from alipay.aop.api.request.AlipayTradeCloseRequest import AlipayTradeCloseRequest
            from alipay.aop.api.request.AlipayTradeFastpayRefundQueryRequest import (
                AlipayTradeFastpayRefundQueryRequest,
            )
            from alipay.aop.api.request.AlipayTradePagePayRequest import AlipayTradePagePayRequest
            from alipay.aop.api.request.AlipayTradeQueryRequest import AlipayTradeQueryRequest
            from alipay.aop.api.request.AlipayTradeRefundRequest import AlipayTradeRefundRequest
            from alipay.aop.api.util.SignatureUtils import verify_with_rsa
        except ImportError as exc:
            raise AlipaySdkError(
                "alipay-sdk-python is not installed; install the pinned project dependency"
            ) from exc
        return locals()

    @staticmethod
    def decode_response(payload: Any, wrapper: str) -> dict[str, Any]:
        if isinstance(payload, bytes):
            payload = payload.decode("utf-8")
        if isinstance(payload, str):
            try:
                payload = json.loads(payload)
            except json.JSONDecodeError as exc:
                raise AlipaySdkError("Alipay returned invalid JSON") from exc
        if not isinstance(payload, dict):
            raise AlipaySdkError("Alipay returned an unsupported response type")
        result = payload.get(wrapper) or payload
        if not isinstance(result, dict):
            raise AlipaySdkError("Alipay response body is not an object")
        if str(result.get("code") or "") != "10000":
            message = result.get("sub_msg") or result.get("msg") or "Alipay request failed"
            raise AlipaySdkError(str(message))
        return result

    def create_page_pay_html(
        self,
        *,
        out_trade_no: str,
        amount_cny_cents: int,
        subject: str,
    ) -> str:
        request = self._types["AlipayTradePagePayRequest"]()
        model = self._types["AlipayTradePagePayModel"]()
        model.out_trade_no = out_trade_no
        model.total_amount = _money(amount_cny_cents)
        model.subject = subject
        model.product_code = "FAST_INSTANT_TRADE_PAY"
        model.timeout_express = self.config.timeout_express
        request.biz_model = model
        request.return_url = self.config.return_url
        request.notify_url = self.config.notify_url
        payload = self._client.page_execute(request)
        if not isinstance(payload, str) or "<form" not in payload.lower():
            raise AlipaySdkError("Alipay page payment did not return an HTML form")
        return payload

    def query(self, out_trade_no: str) -> dict[str, Any]:
        request = self._types["AlipayTradeQueryRequest"]()
        model = self._types["AlipayTradeQueryModel"]()
        model.out_trade_no = out_trade_no
        request.biz_model = model
        return self.decode_response(
            self._client.execute(request),
            "alipay_trade_query_response",
        )

    def refund(
        self,
        *,
        out_trade_no: str,
        refund_cny_cents: int,
        out_request_no: str,
        reason: str,
    ) -> dict[str, Any]:
        request = self._types["AlipayTradeRefundRequest"]()
        model = self._types["AlipayTradeRefundModel"]()
        model.out_trade_no = out_trade_no
        model.refund_amount = _money(refund_cny_cents)
        model.out_request_no = out_request_no
        model.refund_reason = reason
        request.biz_model = model
        return self.decode_response(
            self._client.execute(request),
            "alipay_trade_refund_response",
        )

    def cancel(self, *, out_trade_no: str) -> dict[str, Any]:
        request = self._types["AlipayTradeCancelRequest"]()
        model = self._types["AlipayTradeCancelModel"]()
        model.out_trade_no = out_trade_no
        request.biz_model = model
        return self.decode_response(
            self._client.execute(request),
            "alipay_trade_cancel_response",
        )

    def close(self, *, out_trade_no: str) -> dict[str, Any]:
        request = self._types["AlipayTradeCloseRequest"]()
        model = self._types["AlipayTradeCloseModel"]()
        model.out_trade_no = out_trade_no
        request.biz_model = model
        return self.decode_response(
            self._client.execute(request),
            "alipay_trade_close_response",
        )

    def refund_query(
        self,
        *,
        out_trade_no: str,
        out_request_no: str,
    ) -> dict[str, Any]:
        request = self._types["AlipayTradeFastpayRefundQueryRequest"]()
        model = self._types["AlipayTradeFastpayRefundQueryModel"]()
        model.out_trade_no = out_trade_no
        model.out_request_no = out_request_no
        request.biz_model = model
        return self.decode_response(
            self._client.execute(request),
            "alipay_trade_fastpay_refund_query_response",
        )

    def bill_download_url(self, *, bill_date: str, bill_type: str = "trade") -> dict[str, Any]:
        request = self._types["AlipayDataDataserviceBillDownloadurlQueryRequest"]()
        model = self._types["AlipayDataDataserviceBillDownloadurlQueryModel"]()
        model.bill_type = bill_type
        model.bill_date = bill_date
        request.biz_model = model
        return self.decode_response(
            self._client.execute(request),
            "alipay_data_dataservice_bill_downloadurl_query_response",
        )

    def verify_notification(self, params: dict[str, Any]) -> bool:
        sign = str(params.get("sign") or "")
        if not sign:
            return False
        message_params = {
            key: value
            for key, value in params.items()
            if key not in {"sign", "sign_type"} and value not in ("", None)
        }
        canonical = "&".join(
            f"{key}={message_params[key]}" for key in sorted(message_params)
        )
        charset = str(params.get("charset") or self.config.charset).strip() or "utf-8"
        try:
            message_bytes = canonical.encode(charset)
            return bool(
                self._types["verify_with_rsa"](
                    self.config.alipay_public_key,
                    message_bytes,
                    sign,
                )
            )
        except (LookupError, UnicodeError, ValueError, TypeError, AssertionError):
            return False
