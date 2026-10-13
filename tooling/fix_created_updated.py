#!/usr/bin/env python3
"""Tambah kolom created/updated (TEXT DEFAULT '' NOT NULL, spt tabel users)
ke tabel koleksi yang dibuat manual via SQL, agar sort/filter `created`
tidak 400. Idempoten. Jalankan di VPS, lalu restart pb-simak.service.
"""
import shutil
import sqlite3
import sys
import time

DB = '/opt/pb-simak/data/data.db'
TABLES = [
    'pengumuman', 'mapel', 'chat_rooms', 'chat_messages', 'chat_baca',
    'kejadian',
]


def cols(cur, t):
    return [r[1] for r in cur.execute(f'PRAGMA table_info("{t}")')]


def main():
    bak = f'/tmp/pb-simak-data-bak-{int(time.time())}.db'
    shutil.copy2(DB, bak)
    print(f'backup: {bak}')
    con = sqlite3.connect(DB)
    cur = con.cursor()
    now = time.strftime('%Y-%m-%d %H:%M:%S.000Z')
    for t in TABLES:
        c = cols(cur, t)
        for col in ('created', 'updated'):
            if col not in c:
                cur.execute(
                    f'ALTER TABLE "{t}" ADD COLUMN `{col}` '
                    "TEXT DEFAULT '' NOT NULL"
                )
                print(f'{t}: kolom {col} ditambahkan')
        # backfill baris lama yang masih kosong
        n = cur.execute(
            f'UPDATE "{t}" SET created=?, updated=? '
            "WHERE created='' OR updated=''",
            (now, now),
        ).rowcount
        if n:
            print(f'{t}: {n} baris di-backfill')
    con.commit()

    # sinkronkan waktu_terakhir room seed agar konsisten
    cur.execute(
        "UPDATE chat_rooms SET created=waktu_terakhir, updated=waktu_terakhir "
        "WHERE waktu_terakhir != ''"
    )
    con.commit()
    con.close()
    print('OK — restart pb-simak.service setelah ini')


if __name__ == '__main__':
    sys.exit(main())
