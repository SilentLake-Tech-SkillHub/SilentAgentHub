from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable


CreditCallback = Callable[[str, int, str], None]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


SCHEMA = """
CREATE TABLE IF NOT EXISTS alipay_payment_orders (
    out_trade_no TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    amount_cents INTEGER NOT NULL CHECK (amount_cents > 0),
    currency TEXT NOT NULL DEFAULT 'CNY',
    credit_units INTEGER NOT NULL CHECK (credit_units > 0),
    subject TEXT NOT NULL,
    status TEXT NOT NULL,
    trade_no TEXT UNIQUE,
    raw_json TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    credited_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_alipay_orders_user_created
ON alipay_payment_orders(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS alipay_provider_events (
    event_id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    out_trade_no TEXT,
    verified INTEGER NOT NULL DEFAULT 0,
    processed INTEGER NOT NULL DEFAULT 0,
    error TEXT,
    raw_json TEXT NOT NULL,
    received_at TEXT NOT NULL,
    processed_at TEXT
);

CREATE TABLE IF NOT EXISTS alipay_credit_ledger (
    ledger_id INTEGER PRIMARY KEY AUTOINCREMENT,
    out_trade_no TEXT NOT NULL UNIQUE,
    trade_no TEXT NOT NULL UNIQUE,
    user_id TEXT NOT NULL,
    amount_cents INTEGER NOT NULL,
    currency TEXT NOT NULL,
    credit_units INTEGER NOT NULL,
    source TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS alipay_refund_depositback_events (
    notify_id TEXT PRIMARY KEY,
    out_trade_no TEXT NOT NULL,
    trade_no TEXT NOT NULL,
    out_request_no TEXT NOT NULL,
    dback_status TEXT NOT NULL,
    dback_amount_cents INTEGER,
    bank_ack_time TEXT,
    est_bank_receipt_time TEXT,
    raw_json TEXT NOT NULL,
    received_at TEXT NOT NULL
);
"""


class SQLitePaymentStore:
    def __init__(self, path: str | Path):
        self.path = str(path)

    def connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.path)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        conn.execute("PRAGMA busy_timeout = 5000")
        return conn

    def initialize(self) -> None:
        conn = self.connect()
        try:
            conn.executescript(SCHEMA)
            conn.commit()
        finally:
            conn.close()

    def create_order(
        self,
        *,
        out_trade_no: str,
        user_id: str,
        amount_cents: int,
        credit_units: int,
        subject: str,
    ) -> None:
        ts = utc_now()
        conn = self.connect()
        try:
            conn.execute(
                """
                INSERT INTO alipay_payment_orders (
                    out_trade_no, user_id, amount_cents, currency, credit_units,
                    subject, status, created_at, updated_at
                ) VALUES (?, ?, ?, 'CNY', ?, ?, 'CREATED', ?, ?)
                """,
                (out_trade_no, user_id, amount_cents, credit_units, subject, ts, ts),
            )
            conn.commit()
        finally:
            conn.close()

    def get_order(self, out_trade_no: str) -> dict[str, Any] | None:
        conn = self.connect()
        try:
            row = conn.execute(
                "SELECT * FROM alipay_payment_orders WHERE out_trade_no = ?",
                (out_trade_no,),
            ).fetchone()
            return dict(row) if row else None
        finally:
            conn.close()

    def record_event(
        self,
        *,
        event_id: str,
        event_type: str,
        out_trade_no: str,
        payload: dict[str, Any],
    ) -> None:
        conn = self.connect()
        try:
            conn.execute(
                """
                INSERT OR IGNORE INTO alipay_provider_events (
                    event_id, event_type, out_trade_no, raw_json, received_at
                ) VALUES (?, ?, ?, ?, ?)
                """,
                (
                    event_id,
                    event_type,
                    out_trade_no,
                    json.dumps(payload, ensure_ascii=False, sort_keys=True),
                    utc_now(),
                ),
            )
            conn.commit()
        finally:
            conn.close()

    def finish_event(self, event_id: str, *, verified: bool, processed: bool, error: str = "") -> None:
        conn = self.connect()
        try:
            conn.execute(
                """
                UPDATE alipay_provider_events
                SET verified = ?, processed = ?, error = ?, processed_at = ?
                WHERE event_id = ?
                """,
                (int(verified), int(processed), error[:1000], utc_now(), event_id),
            )
            conn.commit()
        finally:
            conn.close()

    def update_status(self, out_trade_no: str, status: str, payload: dict[str, Any]) -> None:
        conn = self.connect()
        try:
            conn.execute(
                """
                UPDATE alipay_payment_orders
                SET status = ?, raw_json = ?, updated_at = ?
                WHERE out_trade_no = ?
                """,
                (
                    status or "NOTIFIED",
                    json.dumps(payload, ensure_ascii=False, sort_keys=True),
                    utc_now(),
                    out_trade_no,
                ),
            )
            conn.commit()
        finally:
            conn.close()

    def apply_paid_order(
        self,
        *,
        out_trade_no: str,
        trade_no: str,
        amount_cents: int,
        status: str,
        source: str,
        payload: dict[str, Any],
        credit_callback: CreditCallback,
    ) -> dict[str, Any]:
        conn = self.connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            order = conn.execute(
                "SELECT * FROM alipay_payment_orders WHERE out_trade_no = ?",
                (out_trade_no,),
            ).fetchone()
            if not order:
                raise RuntimeError("Alipay order is unknown")
            if order["credited_at"]:
                conn.commit()
                return {
                    "already_credited": True,
                    "credit_units": int(order["credit_units"]),
                }
            if int(order["amount_cents"]) != amount_cents:
                raise RuntimeError("Alipay amount mismatch")

            ts = utc_now()
            conn.execute(
                """
                INSERT INTO alipay_credit_ledger (
                    out_trade_no, trade_no, user_id, amount_cents, currency,
                    credit_units, source, created_at
                ) VALUES (?, ?, ?, ?, 'CNY', ?, ?, ?)
                """,
                (
                    out_trade_no,
                    trade_no,
                    order["user_id"],
                    amount_cents,
                    int(order["credit_units"]),
                    source,
                    ts,
                ),
            )

            # The external credit system must deduplicate this stable key.
            credit_callback(
                str(order["user_id"]),
                int(order["credit_units"]),
                f"alipay:{trade_no}",
            )
            conn.execute(
                """
                UPDATE alipay_payment_orders
                SET status = ?, trade_no = ?, raw_json = ?, updated_at = ?, credited_at = ?
                WHERE out_trade_no = ?
                """,
                (
                    status,
                    trade_no,
                    json.dumps(payload, ensure_ascii=False, sort_keys=True),
                    ts,
                    ts,
                    out_trade_no,
                ),
            )
            conn.commit()
            return {
                "already_credited": False,
                "credit_units": int(order["credit_units"]),
            }
        except sqlite3.IntegrityError:
            conn.rollback()
            order = self.get_order(out_trade_no)
            if order and order.get("credited_at"):
                return {
                    "already_credited": True,
                    "credit_units": int(order["credit_units"]),
                }
            raise
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def record_refund_depositback(
        self,
        *,
        notify_id: str,
        content: dict[str, Any],
        dback_amount_cents: int | None,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        out_trade_no = str(content["out_trade_no"])
        trade_no = str(content["trade_no"])
        conn = self.connect()
        try:
            conn.execute("BEGIN IMMEDIATE")
            order = conn.execute(
                "SELECT trade_no FROM alipay_payment_orders WHERE out_trade_no = ?",
                (out_trade_no,),
            ).fetchone()
            if not order:
                raise RuntimeError("Alipay refund order is unknown")
            if not order["trade_no"] or str(order["trade_no"]) != trade_no:
                raise RuntimeError("Alipay refund trade_no mismatch")
            existing = conn.execute(
                "SELECT notify_id FROM alipay_refund_depositback_events WHERE notify_id = ?",
                (notify_id,),
            ).fetchone()
            if existing:
                conn.commit()
                return {"already_processed": True, "out_trade_no": out_trade_no}
            conn.execute(
                """
                INSERT INTO alipay_refund_depositback_events (
                    notify_id, out_trade_no, trade_no, out_request_no, dback_status,
                    dback_amount_cents, bank_ack_time, est_bank_receipt_time,
                    raw_json, received_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    notify_id,
                    out_trade_no,
                    trade_no,
                    str(content["out_request_no"]),
                    str(content["dback_status"]),
                    dback_amount_cents,
                    str(content.get("bank_ack_time") or ""),
                    str(content.get("est_bank_receipt_time") or ""),
                    json.dumps(payload, ensure_ascii=False, sort_keys=True),
                    utc_now(),
                ),
            )
            status = (
                "REFUND_DEPOSITBACK_BANK_SUCCESS"
                if str(content["dback_status"]) == "S"
                else "REFUND_DEPOSITBACK_ALIPAY_BALANCE"
            )
            conn.execute(
                "UPDATE alipay_payment_orders SET status = ?, updated_at = ? WHERE out_trade_no = ?",
                (status, utc_now(), out_trade_no),
            )
            conn.commit()
            return {"already_processed": False, "out_trade_no": out_trade_no}
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()
