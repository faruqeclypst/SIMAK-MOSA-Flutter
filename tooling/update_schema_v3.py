#!/usr/bin/env python3
"""Pembaruan Skema PocketBase v3 untuk SIMAK-MOSA:

Perbaikan & Fitur Baru:
1. `jurnal`:
   - Tambah kolom/field: `mapel` (text) agar jurnal mencatat mata pelajaran secara spesifik.
2. `izin_keluar` (Tiket Perizinan Keluar-Masuk Gerbang Sekolah Berasrama / Gate Pass):
   - Kolom:
     - `nomor_tiket` (text, e.g. TKT-20261017-001 / IB-20261017-005)
     - `siswa` (relation to siswa)
     - `jenis` (select: Izin Keluar Kampus, Izin Pulang (IB/Bermalam), Izin Berobat/Medis, Izin Lomba/Dinas)
     - `keterangan` (text)
     - `penyetuju` (text)
     - `penjemput` (text: nama orang tua/wali)
     - `waktu_keluar` (text/date rencana keluar)
     - `waktu_kembali` (text/date rencana kembali)
     - `jam_keluar_aktual` (text jam tap keluar gerbang oleh satpam)
     - `jam_kembali_aktual` (text jam tap kembali gerbang oleh satpam)
     - `status` (select: Menunggu Keluar, Di Luar Kampus, Sudah Kembali, Terlambat)
     - `satpam_petugas` (relation to users)

Jalankan di server/VPS:
    python3 tooling/update_schema_v3.py
"""
import json
import os
import random
import shutil
import sqlite3
import sys
import time

DB_PATHS = [
    '/opt/pb-simak/data/data.db',
    'pb_data/data.db',
    '../pb_data/data.db',
    'data.db',
]

USERS_COLL = '_pb_users_auth_'
AUTH = '@request.auth.id != ""'
ADMIN = '@request.auth.peran = "admin"'


def fid(prefix):
    return f'{prefix}{random.randint(10**9, 10**10 - 1)}'


def cari_db():
    for p in DB_PATHS:
        if os.path.exists(p):
            return p
    return None


def main():
    db_path = cari_db()
    if not db_path:
        print("PERINGATAN: Database SQLite PocketBase tidak ditemukan pada path standar.")
        if len(sys.argv) > 1 and os.path.exists(sys.argv[1]):
            db_path = sys.argv[1]
        else:
            return 0

    print(f"Menggunakan database: {db_path}")
    bak = f"{db_path}.bak-{int(time.time())}"
    try:
        shutil.copy2(db_path, bak)
        print(f"Cadangan database tersimpan: {bak}")
    except Exception as e:
        print(f"Catatan backup: {e}")

    con = sqlite3.connect(db_path)
    cur = con.cursor()

    # 1. Tambah field mapel ke jurnal jika belum ada
    cur.execute("SELECT id, fields FROM _collections WHERE name='jurnal'")
    j_row = cur.fetchone()
    if j_row:
        j_id, fields_raw = j_row
        fields = json.loads(fields_raw)
        field_names = {f.get('name') for f in fields}
        if 'mapel' not in field_names:
            fields.append({
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'mapel',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'text',
            })
            cur.execute("UPDATE _collections SET fields=? WHERE id=?", (json.dumps(fields), j_id))
            print("Field 'mapel' ditambahkan ke koleksi jurnal.")

        cur.execute("PRAGMA table_info(jurnal)")
        cols = {r[1] for r in cur.fetchall()}
        if 'mapel' not in cols:
            cur.execute("ALTER TABLE jurnal ADD COLUMN `mapel` TEXT DEFAULT '' NOT NULL")
            print("Kolom `mapel` ditambahkan ke tabel SQLite jurnal.")

    # 2. Buat koleksi izin_keluar (Tiket Gate Pass & Boarding Pass)
    cur.execute("SELECT id FROM _collections WHERE name='izin_keluar'")
    ik_row = cur.fetchone()
    if not ik_row:
        cur.execute("SELECT id FROM _collections WHERE name='siswa'")
        siswa_coll_id = cur.fetchone()[0]

        ik_fields = [
            {
                'autogeneratePattern': '[a-z0-9]{15}', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 15, 'min': 15, 'name': 'id',
                'pattern': '^[a-z0-9]+$', 'presentable': False, 'primaryKey': True,
                'required': True, 'system': True, 'type': 'text',
            },
            {
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'nomor_tiket',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': True, 'system': False, 'type': 'text',
            },
            {
                'cascadeDelete': False, 'collectionId': siswa_coll_id, 'help': '',
                'hidden': False, 'id': fid('relation'), 'maxSelect': 1, 'minSelect': 1,
                'name': 'siswa', 'presentable': False, 'required': True,
                'system': False, 'type': 'relation',
            },
            {
                'help': '', 'hidden': False, 'id': fid('select'), 'maxSelect': 1,
                'name': 'jenis', 'presentable': False, 'required': True,
                'system': False, 'type': 'select',
                'values': [
                    'Izin Pulang (IB/Bermalam)',
                    'Izin Keluar Kampus',
                    'Izin Berobat/Medis',
                    'Izin Lomba/Dinas',
                    'Lainnya',
                ],
            },
            {
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'keterangan',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'text',
            },
            {
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'penyetuju',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'text',
            },
            {
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'penjemput',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'text',
            },
            {
                'help': '', 'hidden': False, 'id': fid('date'), 'max': '', 'min': '',
                'name': 'waktu_keluar', 'presentable': False, 'required': False,
                'system': False, 'type': 'date',
            },
            {
                'help': '', 'hidden': False, 'id': fid('date'), 'max': '', 'min': '',
                'name': 'waktu_kembali', 'presentable': False, 'required': False,
                'system': False, 'type': 'date',
            },
            {
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'jam_keluar_aktual',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'text',
            },
            {
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'jam_kembali_aktual',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'text',
            },
            {
                'help': '', 'hidden': False, 'id': fid('select'), 'maxSelect': 1,
                'name': 'status', 'presentable': False, 'required': True,
                'system': False, 'type': 'select',
                'values': [
                    'Menunggu Keluar',
                    'Di Luar Kampus',
                    'Sudah Kembali',
                    'Terlambat',
                    'Dibatalkan',
                ],
            },
            {
                'cascadeDelete': False, 'collectionId': USERS_COLL, 'help': '',
                'hidden': False, 'id': fid('relation'), 'maxSelect': 1, 'minSelect': 0,
                'name': 'satpam_petugas', 'presentable': False, 'required': False,
                'system': False, 'type': 'relation',
            },
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

        cur.execute(
            """INSERT INTO _collections
               (system, type, name, fields, indexes,
                listRule, viewRule, createRule, updateRule, deleteRule, options)
               VALUES (0, 'base', 'izin_keluar', ?, '[]', ?, ?, ?, ?, ?, '{}')""",
            (json.dumps(ik_fields), AUTH, AUTH, AUTH, AUTH, ADMIN)
        )
        cur.execute(
            """CREATE TABLE `izin_keluar` (
                 `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
                 `nomor_tiket` TEXT DEFAULT '' NOT NULL,
                 `siswa` TEXT DEFAULT '' NOT NULL,
                 `jenis` TEXT DEFAULT '' NOT NULL,
                 `keterangan` TEXT DEFAULT '' NOT NULL,
                 `penyetuju` TEXT DEFAULT '' NOT NULL,
                 `penjemput` TEXT DEFAULT '' NOT NULL,
                 `waktu_keluar` TEXT DEFAULT '' NOT NULL,
                 `waktu_kembali` TEXT DEFAULT '' NOT NULL,
                 `jam_keluar_aktual` TEXT DEFAULT '' NOT NULL,
                 `jam_kembali_aktual` TEXT DEFAULT '' NOT NULL,
                 `status` TEXT DEFAULT 'Menunggu Keluar' NOT NULL,
                 `satpam_petugas` TEXT DEFAULT '' NOT NULL,
                 `created` TEXT DEFAULT '' NOT NULL,
                 `updated` TEXT DEFAULT '' NOT NULL)"""
        )
        print("Koleksi `izin_keluar` (Gate Pass Satpam & Asrama) berhasil dibuat.")

        # Seed contoh tiket perizinan gerbang
        cur.execute("SELECT id FROM siswa LIMIT 3")
        siswa_rows = cur.fetchall()
        if siswa_rows:
            now_str = time.strftime('%Y-%m-%d %H:%M:%S')
            tgl_hari = time.strftime('%Y-%m-%d')
            samples = [
                ('IB-20261017-001', siswa_rows[0][0], 'Izin Pulang (IB/Bermalam)', 'Izin bermalam di rumah keluarga (Pekan IB)', 'Ust. Zulkifli, S.Pd (Pembina Asrama)', 'Bpk. Ridwan (Ayah)', f'{tgl_hari} 15:00:00', f'{tgl_hari} 20:00:00', '', '', 'Menunggu Keluar'),
                ('TKT-20261017-002', siswa_rows[1][0] if len(siswa_rows)>1 else siswa_rows[0][0], 'Izin Keluar Kampus', 'Membeli buku referensi & perlengkapan praktikum', 'Drs. Hasan (Guru Piket)', '-', f'{tgl_hari} 10:30:00', f'{tgl_hari} 14:00:00', f'{tgl_hari} 10:35:12', '', 'Di Luar Kampus'),
            ]
            for s in samples:
                cur.execute(
                    """INSERT INTO `izin_keluar`
                       (nomor_tiket, siswa, jenis, keterangan, penyetuju, penjemput, waktu_keluar, waktu_kembali, jam_keluar_aktual, jam_kembali_aktual, status, created, updated)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (*s, now_str, now_str)
                )
            print(f"Seed {len(samples)} data contoh tiket perizinan gerbang.")

    con.commit()
    con.close()
    print("Selesai memperbarui skema PocketBase v3.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
