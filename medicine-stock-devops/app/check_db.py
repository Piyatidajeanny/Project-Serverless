import sqlite3
p=r"c:\Users\comho\Project-Serverless\medicine-stock-devops\app\medicine.db"
conn=sqlite3.connect(p)
c=conn.cursor()
print('Total rows:', c.execute('SELECT COUNT(*) FROM drugs').fetchone()[0])
for row in c.execute('SELECT lot_number, drug_name, COUNT(*) as cnt FROM drugs GROUP BY lot_number,drug_name ORDER BY cnt DESC'):
    print(row)
conn.close()
