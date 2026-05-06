import json
import sqlite3
from datetime import datetime
import os

DB_PATH = os.environ.get("DB_PATH", "medicine.db")
DATASET_PATH = "data/medicine_dataset.json"


def seed_data():
    conn = sqlite3.connect(DB_PATH)
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

    with open(DATASET_PATH, "r", encoding="utf-8") as file:
        medicines = json.load(file)

    for medicine in medicines:
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
            medicine["drug_name"],
            medicine["category"],
            medicine["lot_number"],
            int(medicine["quantity"]),
            int(medicine["min_stock"]),
            medicine["expiry_date"],
            datetime.now().isoformat()
        ))

    conn.commit()
    conn.close()

    print(f"Imported {len(medicines)} medicines successfully.")


if __name__ == "__main__":
    seed_data()