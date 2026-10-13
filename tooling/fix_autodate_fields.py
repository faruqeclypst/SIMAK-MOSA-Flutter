#!/usr/bin/env python3
"""Daftarkan field autodate created/updated ke fields JSON koleksi yang
dibuat manual via SQL, agar PB mengenalinya (sort/filter/return).
Idempoten. Jalankan di VPS, lalu restart pb-simak.service.
"""
import json
import random
import shutil
import sqlite3
import sys
import time

DB = '/opt/pb-simak/data/data.db'
TABLES = [
    'pengumuman', 'mapel', 'chat_rooms', 'chat_messages', 'chat_baca',
    'kejadian',
]


def autodate(name, on_create, on_update):
    return {
        'hidden': False,
        'id': f'autodate{random.randint(10**9, 10**10 - 1)}',
        'name': name,
        'onCreate': on_create,
        'onUpdate': on_update,
        'presentable': False,
        'system': False,
        'type': 'autodate',
    }


def main():
    bak = f'/tmp/pb-simak-data-bak-{int(time.time())}.db'
    shutil.copy2(DB, bak)
    print(f'backup: {bak}')
    con = sqlite3.connect(DB)
    cur = con.cursor()
    for t in TABLES:
        row = cur.execute(
            'SELECT fields FROM _collections WHERE name=?', (t,)
        ).fetchone()
        if not row:
            print(f'{t}: koleksi tidak ada, lewati')
            continue
        fields = json.loads(row[0])
        names = {f['name'] for f in fields}
        changed = False
        if 'created' not in names:
            fields.append(autodate('created', True, False))
            changed = True
        if 'updated' not in names:
            fields.append(autodate('updated', True, True))
            changed = True
        if changed:
            cur.execute(
                'UPDATE _collections SET fields=? WHERE name=?',
                (json.dumps(fields), t),
            )
            print(f'{t}: field created/updated didaftarkan')
        else:
            print(f'{t}: sudah lengkap')
    con.commit()
    con.close()
    print('OK — restart pb-simak.service setelah ini')


if __name__ == '__main__':
    sys.exit(main())
