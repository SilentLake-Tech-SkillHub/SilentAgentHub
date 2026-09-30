from __future__ import annotations

import os
import stat
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse


SANDBOX_GATEWAY = "https://openapi-sandbox.dl.alipaydev.com/gateway.do"
LIVE_GATEWAY = "https://openapi.alipay.com/gateway.do"
ALLOWED_GATEWAY_HOSTS = {
    "openapi.alipay.com",
    "openapi-sandbox.dl.alipaydev.com",
}


class ConfigError(RuntimeError):
    pass


def _positive_int(name: str, raw: str) -> int:
    try:
        value = int(raw)
    except (TypeError, ValueError) as exc:
        raise ConfigError(f"{name} must be an integer") from exc
    if value <= 0:
        raise ConfigError(f"{name} must be greater than zero")
    return value


def _load_value_or_file(value_name: str, file_name: str, *, live: bool, private: bool) -> str:
    inline_value = os.getenv(value_name, "").strip()
    file_value = os.getenv(file_name, "").strip()
    if inline_value and file_value:
        raise ConfigError(f"Configure only one of {value_name} and {file_name}")
    if live and private and inline_value:
        raise ConfigError(f"{value_name} inline injection is forbidden in live; use {file_name}")
    if inline_value:
        return inline_value
    if not file_value:
        return ""
    path = Path(file_value).expanduser()
    if not path.is_file():
        raise ConfigError(f"{file_name} does not point to a readable file")
    if live and private and os.name == "posix":
        mode = stat.S_IMODE(path.stat().st_mode)
        if mode & 0o077:
            raise ConfigError(f"{file_name} must not be readable by group or others")
    return path.read_text(encoding="utf-8").strip()


def _validate_url(name: str, value: str, *, https_required: bool) -> str:
    parsed = urlparse(value)
    if parsed.scheme not in ({"https"} if https_required else {"http", "https"}) or not parsed.netloc:
        protocol = "HTTPS" if https_required else "HTTP(S)"
        raise ConfigError(f"{name} must be an absolute {protocol} URL")
    return value


@dataclass(frozen=True)
class AlipayConfig:
    environment: str
    app_id: str
    seller_id: str
    app_private_key: str
    alipay_public_key: str
    gateway_url: str
    return_url: str
    notify_url: str
    order_amount_cny_cents: int
    credit_units: int
    order_subject: str
    timeout_express: str = "30m"
    charset: str = "utf-8"
    sign_type: str = "RSA2"

    @property
    def live(self) -> bool:
        return self.environment == "live"

    @classmethod
    def from_env(cls) -> "AlipayConfig":
        environment = os.getenv("ALIPAY_ENV", "sandbox").strip().lower()
        if environment not in {"sandbox", "live"}:
            raise ConfigError("ALIPAY_ENV must be sandbox or live")
        live = environment == "live"
        gateway = os.getenv("ALIPAY_GATEWAY_URL", "").strip() or (
            LIVE_GATEWAY if live else SANDBOX_GATEWAY
        )
        parsed_gateway = urlparse(_validate_url("ALIPAY_GATEWAY_URL", gateway, https_required=True))
        if parsed_gateway.hostname not in ALLOWED_GATEWAY_HOSTS:
            raise ConfigError("ALIPAY_GATEWAY_URL must use an official Alipay gateway host")

        app_id = os.getenv("ALIPAY_APP_ID", "").strip()
        seller_id = os.getenv("ALIPAY_SELLER_ID", "").strip()
        if not app_id:
            raise ConfigError("ALIPAY_APP_ID is required")
        if live and not seller_id:
            raise ConfigError("ALIPAY_SELLER_ID is required in live")

        private_key = _load_value_or_file(
            "ALIPAY_APP_PRIVATE_KEY",
            "ALIPAY_APP_PRIVATE_KEY_FILE",
            live=live,
            private=True,
        )
        public_key = _load_value_or_file(
            "ALIPAY_PUBLIC_KEY",
            "ALIPAY_PUBLIC_KEY_FILE",
            live=live,
            private=False,
        )
        if not private_key or not public_key:
            raise ConfigError("Both the application private key and Alipay public key are required")

        return cls(
            environment=environment,
            app_id=app_id,
            seller_id=seller_id,
            app_private_key=private_key,
            alipay_public_key=public_key,
            gateway_url=gateway,
            return_url=_validate_url(
                "ALIPAY_RETURN_URL",
                os.getenv("ALIPAY_RETURN_URL", "").strip(),
                https_required=live,
            ),
            notify_url=_validate_url(
                "ALIPAY_NOTIFY_URL",
                os.getenv("ALIPAY_NOTIFY_URL", "").strip(),
                https_required=True,
            ),
            order_amount_cny_cents=_positive_int(
                "ALIPAY_ORDER_AMOUNT_CNY_CENTS",
                os.getenv("ALIPAY_ORDER_AMOUNT_CNY_CENTS", ""),
            ),
            credit_units=_positive_int(
                "ALIPAY_CREDIT_UNITS",
                os.getenv("ALIPAY_CREDIT_UNITS", ""),
            ),
            order_subject=os.getenv("ALIPAY_ORDER_SUBJECT", "Account usage credit").strip()
            or "Account usage credit",
            timeout_express=os.getenv("ALIPAY_TIMEOUT_EXPRESS", "30m").strip() or "30m",
        )
