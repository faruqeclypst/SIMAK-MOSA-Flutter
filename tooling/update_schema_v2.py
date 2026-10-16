#!/usr/bin/env python3
"""Pembaruan Skema PocketBase v2 untuk SIMAK-MOSA:

Perbaikan & Penyempurnaan:
1. `chat_messages`:
   - Tambah kolom/field: `foto` (file), `diterima_oleh` (json/text), `dibaca_oleh` (json/text), `balasan_id` (text).
   - Update `updateRule`: '@request.auth.id != ""' (memungkinkan penandaan deliver & read receipt).
   - Update `deleteRule`: '@request.auth.peran = "admin" || @request.auth.id = pengirim.id' (pengirim & admin bisa hapus pesan).

2. `kejadian`:
   - Update `deleteRule`: '@request.auth.peran = "admin" || @request.auth.id = pelapor.id' (pembuat CAP & admin bisa hapus).

Jalankan di server/VPS:
    python3 tooling/update_schema_v2.py
"""
import json
import os
import random
import shutil
import sqlite3
import sys
import time

# Lokasi DB default di VPS atau local
DB_PATHS = [
    '/opt/pb-simak/data/data.db',
    'pb_data/data.db',
    '../pb_data/data.db',
    'data.db',
]


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
        print("Silakan tentukan path database jika dijalankan manual: python3 update_schema_v2.py <path_to_data.db>")
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

    # 1. Update skema chat_messages
    cur.execute("SELECT id, fields, updateRule, deleteRule FROM _collections WHERE name='chat_messages'")
    cm = cur.fetchone()
    if cm:
        coll_id, fields_raw, cur_update, cur_delete = cm
        fields = json.loads(fields_raw)
        field_names = {f.get('name') for f in fields}

        changed = False
        if 'foto' not in field_names:
            fields.append({
                'help': '', 'hidden': False, 'id': fid('file'), 'maxSelect': 1,
                'maxSize': 5242880,
                'mimeTypes': ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
                'name': 'foto', 'presentable': False, 'protected': False,
                'required': False, 'system': False, 'thumbs': [], 'type': 'file',
            })
            changed = True
        if 'diterima_oleh' not in field_names:
            fields.append({
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'diterima_oleh',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'json',
            })
            changed = True
        if 'dibaca_oleh' not in field_names:
            fields.append({
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'dibaca_oleh',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'json',
            })
            changed = True
        if 'balasan_id' not in field_names:
            fields.append({
                'autogeneratePattern': '', 'help': '', 'hidden': False,
                'id': fid('text'), 'max': 0, 'min': 0, 'name': 'balasan_id',
                'pattern': '', 'presentable': False, 'primaryKey': False,
                'required': False, 'system': False, 'type': 'text',
            })
            changed = True

        new_update = '@request.auth.id != ""'
        new_delete = '@request.auth.peran = "admin" || @request.auth.id = pengirim.id'

        cur.execute(
            "UPDATE _collections SET fields=?, updateRule=?, deleteRule=? WHERE id=?",
            (json.dumps(fields), new_update, new_delete, coll_id)
        )
        print("Koleksi chat_messages berhasil diperbarui (rules & fields).")

        # Cek kolom SQLite chat_messages
        cur.execute("PRAGMA table_info(chat_messages)")
        cols = {row[1] for row in cur.fetchall()}
        if 'foto' not in cols:
            cur.execute("ALTER TABLE chat_messages ADD COLUMN `foto` TEXT DEFAULT '' NOT NULL")
        if 'diterima_oleh' not in cols:
            cur.execute("ALTER TABLE chat_messages ADD COLUMN `diterima_oleh` TEXT DEFAULT '[]' NOT NULL")
        if 'dibaca_oleh' not in cols:
            cur.execute("ALTER TABLE chat_messages ADD COLUMN `dibaca_oleh` TEXT DEFAULT '[]' NOT NULL")
        if 'balasan_id' not in cols:
            cur.execute("ALTER TABLE chat_messages ADD COLUMN `balasan_id` TEXT DEFAULT '' NOT NULL")

    # 2. Update skema kejadian
    cur.execute("SELECT id, deleteRule FROM _collections WHERE name='kejadian'")
    kj = cur.fetchone()
    if kj:
        coll_id, cur_del = kj
        new_del = '@request.auth.peran = "admin" || @request.auth.id = pelapor.id'
        cur.execute("UPDATE _collections SET deleteRule=? WHERE id=?", (new_del, coll_id))
        print("Koleksi kejadian berhasil diperbarui: deleteRule mengizinkan pembuat & admin.")

    con.commit()
    con.close()
    print("Selesai memperbarui skema PocketBase.")
    return 0


if __name__ == '__main__':
    sys.exit(main())
