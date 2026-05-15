from flask import Flask, jsonify, request, render_template
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from datetime import datetime, timedelta
import sqlite3
import os
import time

app = Flask(__name__)

DB_PATH = os.environ.get("DB_PATH", "medicine.db")

# -----------------------------
# Prometheus Metrics
# -----------------------------

REQUEST_COUNT = Counter(
    "http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "http_status"]
)

REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["endpoint"]
)

DRUG_TOTAL = Gauge(
    "drug_total",
    "Total number of drugs"
)

EXPIRING_DRUG_TOTAL = Gauge(
    "expiring_drug_total",
    "Total number of expiring drugs"
)

LOW_STOCK_DRUG_TOTAL = Gauge(
    "low_stock_drug_total",
    "Total number of low stock drugs"
)

MEDICINE_STOCK_QUANTITY = Gauge(
    "medicine_stock_quantity",
    "Current stock quantity of each medicine",
    ["drug_name", "lot_number", "category", "expiry_date"]
)

MEDICINE_DAYS_TO_EXPIRY = Gauge(
    "medicine_days_to_expiry",
    "Days remaining until medicine expiry date",
    ["drug_name", "lot_number", "category", "expiry_date"]
)

MEDICINE_LOW_STOCK_STATUS = Gauge(
    "medicine_low_stock_status",
    "Low stock status of each medicine, 1 means low stock",
    ["drug_name", "lot_number", "category", "expiry_date"]
)

MEDICINE_EXPIRING_STATUS = Gauge(
    "medicine_expiring_status",
    "Expiring status of each medicine, 1 means expiring soon",
    ["drug_name", "lot_number", "category", "expiry_date"]
)


# -----------------------------
# Database
# -----------------------------

def get_connection():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS drugs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            drug_name TEXT NOT NULL,
            category TEXT NOT NULL,
            lot_number TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            min_stock INTEGER NOT NULL,
            expiry_date TEXT NOT NULL,
            created_at TEXT NOT NULL
        )
    """)

    conn.commit()
    conn.close()


def update_business_metrics():
    conn = get_connection()
    cursor = conn.cursor()

    today = datetime.now().date()
    warning_date = today + timedelta(days=180)

    cursor.execute("SELECT COUNT(*) FROM drugs")
    total = cursor.fetchone()[0]

    cursor.execute("""
        SELECT COUNT(*) FROM drugs
        WHERE date(expiry_date) <= date(?)
    """, (warning_date.isoformat(),))
    expiring = cursor.fetchone()[0]

    cursor.execute("""
        SELECT COUNT(*) FROM drugs
        WHERE quantity <= min_stock
    """)
    low_stock = cursor.fetchone()[0]

    DRUG_TOTAL.set(total)
    EXPIRING_DRUG_TOTAL.set(expiring)
    LOW_STOCK_DRUG_TOTAL.set(low_stock)

    cursor.execute("SELECT * FROM drugs")
    medicine_rows = cursor.fetchall()

    for row in medicine_rows:
        drug_name = row["drug_name"]
        lot_number = row["lot_number"]
        category = row["category"]
        expiry_date_text = row["expiry_date"]
        quantity = row["quantity"]
        min_stock = row["min_stock"]

        try:
            expiry_date = datetime.strptime(expiry_date_text, "%Y-%m-%d").date()
        except ValueError:
            continue

        days_to_expiry = (expiry_date - today).days
        is_low_stock = 1 if quantity <= min_stock else 0
        is_expiring = 1 if expiry_date <= warning_date else 0

        MEDICINE_STOCK_QUANTITY.labels(
            drug_name=drug_name,
            lot_number=lot_number,
            category=category,
            expiry_date=expiry_date_text
        ).set(quantity)

        MEDICINE_DAYS_TO_EXPIRY.labels(
            drug_name=drug_name,
            lot_number=lot_number,
            category=category,
            expiry_date=expiry_date_text
        ).set(days_to_expiry)

        MEDICINE_LOW_STOCK_STATUS.labels(
            drug_name=drug_name,
            lot_number=lot_number,
            category=category,
            expiry_date=expiry_date_text
        ).set(is_low_stock)

        MEDICINE_EXPIRING_STATUS.labels(
            drug_name=drug_name,
            lot_number=lot_number,
            category=category,
            expiry_date=expiry_date_text
        ).set(is_expiring)

    conn.close()


# -----------------------------
# Request Monitoring
# -----------------------------

@app.before_request
def before_request():
    request.start_time = time.time()


@app.after_request
def after_request(response):
    latency = time.time() - request.start_time
    endpoint = request.path

    REQUEST_LATENCY.labels(endpoint=endpoint).observe(latency)
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=endpoint,
        http_status=response.status_code
    ).inc()

    return response


# -----------------------------
# Routes
# -----------------------------

@app.route("/", methods=["GET"])
def home():
    return jsonify({
        "message": "Medicine Stock and Expiry Monitoring API",
        "status": "running",
        "version": "1.0.0"
    }), 200


@app.route("/drugs", methods=["GET"])
def get_drugs():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM drugs ORDER BY id DESC")
    rows = cursor.fetchall()

    drugs = [dict(row) for row in rows]

    conn.close()

    return jsonify({
        "count": len(drugs),
        "data": drugs
    }), 200


@app.route("/drugs", methods=["POST"])
def create_drug():
    data = request.get_json()

    required_fields = [
        "drug_name",
        "category",
        "lot_number",
        "quantity",
        "min_stock",
        "expiry_date"
    ]

    for field in required_fields:
        if field not in data:
            return jsonify({
                "error": f"Missing required field: {field}"
            }), 400

    try:
        datetime.strptime(data["expiry_date"], "%Y-%m-%d")
    except ValueError:
        return jsonify({
            "error": "expiry_date must be in YYYY-MM-DD format"
        }), 400

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO drugs (
            drug_name,
            category,
            lot_number,
            quantity,
            min_stock,
            expiry_date,
            created_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        data["drug_name"],
        data["category"],
        data["lot_number"],
        int(data["quantity"]),
        int(data["min_stock"]),
        data["expiry_date"],
        datetime.now().isoformat()
    ))

    conn.commit()
    drug_id = cursor.lastrowid
    conn.close()

    update_business_metrics()

    return jsonify({
        "message": "Drug created successfully",
        "id": drug_id
    }), 201


@app.route("/drugs/<int:drug_id>", methods=["PUT"])
def update_drug(drug_id):
    data = request.get_json()

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM drugs WHERE id = ?", (drug_id,))
    existing = cursor.fetchone()

    if existing is None:
        conn.close()
        return jsonify({
            "error": "Drug not found"
        }), 404

    drug_name = data.get("drug_name", existing["drug_name"])
    category = data.get("category", existing["category"])
    lot_number = data.get("lot_number", existing["lot_number"])
    quantity = data.get("quantity", existing["quantity"])
    min_stock = data.get("min_stock", existing["min_stock"])
    expiry_date = data.get("expiry_date", existing["expiry_date"])

    try:
        datetime.strptime(expiry_date, "%Y-%m-%d")
    except ValueError:
        conn.close()
        return jsonify({
            "error": "expiry_date must be in YYYY-MM-DD format"
        }), 400

    cursor.execute("""
        UPDATE drugs
        SET drug_name = ?,
            category = ?,
            lot_number = ?,
            quantity = ?,
            min_stock = ?,
            expiry_date = ?
        WHERE id = ?
    """, (
        drug_name,
        category,
        lot_number,
        int(quantity),
        int(min_stock),
        expiry_date,
        drug_id
    ))

    conn.commit()
    conn.close()

    update_business_metrics()

    return jsonify({
        "message": "Drug updated successfully"
    }), 200


@app.route("/drugs/<int:drug_id>", methods=["DELETE"])
def delete_drug(drug_id):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM drugs WHERE id = ?", (drug_id,))
    existing = cursor.fetchone()

    if existing is None:
        conn.close()
        return jsonify({
            "error": "Drug not found"
        }), 404

    cursor.execute("DELETE FROM drugs WHERE id = ?", (drug_id,))
    conn.commit()
    conn.close()

    update_business_metrics()

    return jsonify({
        "message": "Drug deleted successfully"
    }), 200


@app.route("/drugs/expiring-soon", methods=["GET"])
def get_expiring_drugs():
    days = int(request.args.get("days", 180))

    today = datetime.now().date()
    warning_date = today + timedelta(days=days)

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT * FROM drugs
        WHERE date(expiry_date) <= date(?)
        ORDER BY expiry_date ASC
    """, (warning_date.isoformat(),))

    rows = cursor.fetchall()
    drugs = [dict(row) for row in rows]

    conn.close()

    return jsonify({
        "days": days,
        "count": len(drugs),
        "data": drugs
    }), 200


@app.route("/drugs/low-stock", methods=["GET"])
def get_low_stock_drugs():
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT * FROM drugs
        WHERE quantity <= min_stock
        ORDER BY quantity ASC
    """)

    rows = cursor.fetchall()
    drugs = [dict(row) for row in rows]

    conn.close()

    return jsonify({
        "count": len(drugs),
        "data": drugs
    }), 200


@app.route("/metrics", methods=["GET"])
def metrics():
    update_business_metrics()
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}


@app.route("/drugs-ui", methods=["GET"])
def drugs_ui():
    return render_template("drugs_table.html")


if __name__ == "__main__":
    init_db()
    update_business_metrics()
    app.run(host="0.0.0.0", port=5000)