import sqlite3, json

con = sqlite3.connect('/opt/pb-simak/data/data.db')
cur = con.cursor()
for r in cur.execute("SELECT name, fields FROM _collections").fetchall():
    fields = [f.get('name') for f in json.loads(r[1])]
    print(f"{r[0]}: {fields}")
