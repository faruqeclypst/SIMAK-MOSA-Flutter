#!/usr/bin/env python3
"""Buat koleksi `mapel` di PocketBase pb-simak + seed 23 mapel.

Jalankan di VPS 43.134.175.87 sebagai user yang bisa baca/tulis
/opt/pb-simak/data/data.db. Backup otomatis ke /tmp dulu.
"""
import json
import random
import shutil
import sqlite3
import sys
import time

DB = '/opt/pb-simak/data/data.db'


def fid(prefix):
    return f'{prefix}{random.randint(10**9, 10**10 - 1)}'


MAPEL = [
    ('Pendidikan Agama Islam', 'PAI', 'Wajib'),
    ('Pendidikan Pancasila', 'PPKn', 'Wajib'),
    ('Bahasa Indonesia', 'BIND', 'Wajib'),
    ('Matematika', 'MTK', 'Wajib'),
    ('Sejarah Indonesia', 'SEJ', 'Wajib'),
    ('Bahasa Inggris', 'BING', 'Wajib'),
    ('PJOK', 'PJOK', 'Wajib'),
    ('Informatika', 'INF', 'Wajib'),
    ('Seni Budaya', 'SB', 'Wajib'),
    ('Prakarya dan Kewirausahaan', 'PKWU', 'Wajib'),
    ('Fisika', 'FIS', 'Peminatan'),
    ('Kimia', 'KIM', 'Peminatan'),
    ('Biologi', 'BIO', 'Peminatan'),
    ('Ekonomi', 'EKO', 'Peminatan'),
    ('Geografi', 'GEO', 'Peminatan'),
    ('Sosiologi', 'SOS', 'Peminatan'),
    ('Sejarah Peminatan', 'SEJP', 'Peminatan'),
    ('Antropologi', 'ANT', 'Peminatan'),
    ('Bahasa Arab', 'BAR', 'Peminatan'),
    ('Matematika Peminatan', 'MTKP', 'Peminatan'),
    ('Koding dan Kecerdasan Artifisial', 'KKA', 'Muatan Lokal'),
    ('Bahasa Aceh', 'BACEH', 'Muatan Lokal'),
    ('Tahfidz Al-Qur\u2019an', 'TAH', 'Muatan Lokal'),
]

FIELDS = [
    {
        'autogeneratePattern': '[a-z0-9]{15}',
        'help': '',
        'hidden': False,
        'id': fid('text'),
        'max': 15,
        'min': 15,
        'name': 'id',
        'pattern': '^[a-z0-9]+$',
        'presentable': False,
        'primaryKey': True,
        'required': True,
        'system': True,
        'type': 'text',
    },
    {
        'autogeneratePattern': '',
        'help': '',
        'hidden': False,
        'id': fid('text'),
        'max': 0,
        'min': 0,
        'name': 'nama',
        'pattern': '',
        'presentable': False,
        'primaryKey': False,
        'required': True,
        'system': False,
        'type': 'text',
    },
    {
        'autogeneratePattern': '',
        'help': '',
        'hidden': False,
        'id': fid('text'),
        'max': 0,
        'min': 0,
        'name': 'kode',
        'pattern': '',
        'presentable': False,
        'primaryKey': False,
        'required': False,
        'system': False,
        'type': 'text',
    },
    {
        'help': '',
        'hidden': False,
        'id': fid('select'),
        'maxSelect': 1,
        'name': 'kelompok',
        'presentable': False,
        'required': True,
        'system': False,
        'type': 'select',
        'values': ['Wajib', 'Peminatan', 'Muatan Lokal'],
    },
    # WAJIB didaftarkan agar PB mengenal created/updated (bug 2026-10-13)
    {
        'hidden': False, 'id': fid('autodate'), 'name': 'created',
        'onCreate': True, 'onUpdate': False, 'presentable': False,
        'system': False, 'type': 'autodate',
    },
    {
        'hidden': False, 'id': fid('autodate'), 'name': 'updated',
        'onCreate': True, 'onUpdate': True, 'presentable': False,
        'system': False, 'type': 'autodate',
    },
]


def main():
    bak = f'/tmp/pb-simak-data-bak-{int(time.time())}.db'
    shutil.copy2(DB, bak)
    print(f'backup: {bak}')

    con = sqlite3.connect(DB)
    cur = con.cursor()
    exists = cur.execute(
        "SELECT COUNT(*) FROM _collections WHERE name='mapel'"
    ).fetchone()[0]
    if exists:
        print('koleksi mapel sudah ada, skip pembuatan.')
    else:
        cur.execute(
            """INSERT INTO _collections
               (system, type, name, fields, indexes,
                listRule, viewRule, createRule, updateRule, deleteRule, options)
               VALUES (0, 'base', 'mapel', ?, '[]',
                '@request.auth.id != ""', '@request.auth.id != ""',
                '@request.auth.peran = "admin"', '@request.auth.peran = "admin"',
                '@request.auth.peran = "admin"', '{}')""",
            (json.dumps(FIELDS),),
        )
        cur.execute(
            """CREATE TABLE `mapel` (
                 `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
                 `nama` TEXT DEFAULT '' NOT NULL,
                 `kode` TEXT DEFAULT '' NOT NULL,
                 `kelompok` TEXT DEFAULT '' NOT NULL,
                 `created` TEXT DEFAULT '' NOT NULL,
                 `updated` TEXT DEFAULT '' NOT NULL
               )"""
        )
        print('koleksi mapel dibuat.')

    n = cur.execute('SELECT COUNT(*) FROM mapel').fetchone()[0]
    if n == 0:
        cur.executemany(
            'INSERT INTO mapel (nama, kode, kelompok) VALUES (?,?,?)', MAPEL
        )
        print(f'seed {len(MAPEL)} mapel.')
    else:
        print(f'mapel sudah terisi ({n} baris), skip seed.')

    con.commit()
    total = cur.execute('SELECT COUNT(*) FROM mapel').fetchone()[0]
    cols = [r[1] for r in cur.execute('PRAGMA table_info(mapel)').fetchall()]
    con.close()
    print(f'OK total={total} kolom={cols}')


if __name__ == '__main__':
    sys.exit(main())
