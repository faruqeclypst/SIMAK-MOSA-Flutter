#!/usr/bin/env python3
"""Daftarkan created/updated (kolom + field autodate) ke SEMUA koleksi base
agar sort/filter `created` tidak 400. Idempoten.
Jalankan di VPS, lalu restart pb-simak.service.
"""
import json
import random
import shutil
import sqlite3
import sys
import time

DB = '/opt/pb-simak/data/data.db'
TABLES = [
    'absensi', 'asrama', 'guru_berhalangan', 'izin_piket', 'jadwal',
    'jurnal', 'kelas', 'keterlambatan', 'siswa',
    # sudah diperbaiki sebelumnya, tapi idempoten:
    'pengumuman', 'mapel', 'chat_rooms', 'chat_messages', 'chat_baca',
    'kejadian',
]


def autodate(name, on_create, on_update):
    return {
        'hidden': False,
        'id': 'autodate%d' % random.randint(10 ** 9, 10 ** 10 - 1),
        'name': name,
        'onCreate': on_create,
        'onUpdate': on_update,
        'presentable': False,
        'system': False,
        'type': 'autodate',
    }


def main():
    bak = '/tmp/pb-simak-data-bak-%d.db' % int(time.time())
    shutil.copy2(DB, bak)
    print('backup: %s' % bak)
    con = sqlite3.connect(DB)
    cur = con.cursor()
    now = time.strftime('%Y-%m-%d %H:%M:%S.000Z')
    for t in TABLES:
        cols = [r[1] for r in cur.execute('PRAGMA table_info("%s")' % t)]
        for col in ('created', 'updated'):
            if col not in cols:
                cur.execute(
                    'ALTER TABLE "%s" ADD COLUMN `%s` '
                    "TEXT DEFAULT '' NOT NULL" % (t, col)
                )
        n = cur.execute(
            'UPDATE "%s" SET created=?, updated=? '
            "WHERE created='' OR updated=''" % t, (now, now),
        ).rowcount
        row = cur.execute(
            'SELECT fields FROM _collections WHERE name=?', (t,),
        ).fetchone()
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
        print('%s: %d baris backfill, fields %s'
              % (t, n, 'diperbarui' if changed else 'sudah lengkap'))
    con.commit()
    con.close()
    print('OK — restart pb-simak.service setelah ini')


if __name__ == '__main__':
    sys.exit(main())
