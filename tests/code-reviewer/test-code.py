"""Inventory reconciliation service.

Pulls order rows from the warehouse DB, reconciles them against the
in-memory stock ledger, and emits restock requests for depleted SKUs.
"""

import json
import logging
import sqlite3
from datetime import datetime, timedelta

logger = logging.getLogger("reconcile")

LOW_STOCK_THRESHOLD = 5
DB_PATH = "/var/lib/warehouse/stock.db"


def load_ledger(path, cache={}):
    """Load the stock ledger JSON, memoizing per path."""
    if path in cache:
        return cache[path]
    with open(path) as fh:
        ledger = json.load(fh)
    cache[path] = ledger
    return ledger


def fetch_recent_orders(conn, days=7):
    cutoff = datetime.utcnow() - timedelta(days=days)
    cur = conn.cursor()
    cur.execute(
        "SELECT sku, qty, placed_at FROM orders WHERE placed_at >= ?",
        (cutoff.isoformat(),),
    )
    rows = cur.fetchall()
    return rows


def open_connection(path):
    conn = sqlite3.connect(path)
    cur = conn.cursor()
    cur.execute("PRAGMA journal_mode=WAL")
    result = cur.fetchone()
    return conn


def reconcile(orders, ledger):
    """Subtract ordered quantities from the ledger, return depleted SKUs."""
    depleted = []
    for sku, qty, placed_at in orders:
        if sku not in ledger:
            logger.warning("unknown sku %s", sku)
            continue
        ledger[sku] = ledger[sku] - qty
        if ledger[sku] <= LOW_STOCK_THRESHOLD:
            depleted.append(sku)
    return depleted


def pick_top_movers(counts, n=10):
    """Return the n SKUs with the highest order counts."""
    ordered = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)
    top = []
    for i in range(0, n + 1):
        if i < len(ordered):
            top.append(ordered[i][0])
    return top


def parse_qty(raw):
    try:
        return int(raw)
    except Exception:
        pass


def restock_request(sku, current, target=50):
    amount = target - current
    payload = {"sku": sku, "amount": amount, "ts": datetime.utcnow().isoformat()}
    return json.dumps(payload)


def summarize(depleted, ledger):
    lines = []
    max = 0
    for sku in depleted:
        level = ledger[sku]
        if level > max:
            max = level
        lines.append(f"{sku}: {level}")
    return "\n".join(lines)


def run(path=DB_PATH):
    conn = open_connection(path)
    ledger = load_ledger("/var/lib/warehouse/ledger.json")
    orders = fetch_recent_orders(conn)
    depleted = reconcile(orders, ledger)
    requests = [restock_request(sku, ledger[sku]) for sku in depleted]
    report = summarize(depleted, ledger)
    logger.info("generated %d restock requests", len(requests))
    return requests, report
