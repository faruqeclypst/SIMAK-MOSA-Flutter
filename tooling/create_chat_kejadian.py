#!/usr/bin/env python3
"""Koleksi chat ala WA + cap-on-spot (kejadian) untuk SIMAK-MOSA.

- chat_rooms: nama, tipe (grup/direct), anggota (multi-relation users),
  deskripsi, pesan_terakhir, waktu_terakhir
- chat_messages: room, pengirim, pesan
- chat_baca: room, user, terakhir (untuk badge unread)
- kejadian: judul, deskripsi, kategori, foto, pelapor, tanggal
Jalankan di VPS sebagai user yang bisa tulis /opt/pb-simak/data/data.db.
Idempoten: lewati yang sudah ada.
"""
import json
import random
import shutil
import sqlite3
import sys
import time

DB = '/opt/pb-simak/data/data.db'
USERS_COLL = '_pb_users_auth_'
AUTH = '@request.auth.id != ""'
ADMIN = '@request.auth.peran = "admin"'


def fid(prefix):
    return f'{prefix}{random.randint(10**9, 10**10 - 1)}'


def f_id():
    return {
        'autogeneratePattern': '[a-z0-9]{15}', 'help': '', 'hidden': False,
        'id': fid('text'), 'max': 15, 'min': 15, 'name': 'id',
        'pattern': '^[a-z0-9]+$', 'presentable': False, 'primaryKey': True,
        'required': True, 'system': True, 'type': 'text',
    }


def f_text(name, required=False):
    return {
        'autogeneratePattern': '', 'help': '', 'hidden': False,
        'id': fid('text'), 'max': 0, 'min': 0, 'name': name, 'pattern': '',
        'presentable': False, 'primaryKey': False, 'required': required,
        'system': False, 'type': 'text',
    }


def f_select(name, values, required=False):
    return {
        'help': '', 'hidden': False, 'id': fid('select'), 'maxSelect': 1,
        'name': name, 'presentable': False, 'required': required,
        'system': False, 'type': 'select', 'values': values,
    }


def f_relation(name, coll_id, multiple=False, required=False):
    return {
        'cascadeDelete': False, 'collectionId': coll_id, 'help': '',
        'hidden': False, 'id': fid('relation'),
        # maxSelect=0 dianggap SINGLE oleh PB (bug 2026-10-13) -> pakai 100
        'maxSelect': 100 if multiple else 1,
        'minSelect': 1 if required else 0,
        'name': name, 'presentable': False, 'required': required,
        'system': False, 'type': 'relation',
    }


def f_date(name, required=False):
    return {
        'help': '', 'hidden': False, 'id': fid('date'), 'max': '', 'min': '',
        'name': name, 'presentable': False, 'required': required,
        'system': False, 'type': 'date',
    }


def f_file(name):
    return {
        'help': '', 'hidden': False, 'id': fid('file'), 'maxSelect': 1,
        'maxSize': 5242880,
        'mimeTypes': ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
        'name': name, 'presentable': False, 'protected': False,
        'required': False, 'system': False, 'thumbs': [], 'type': 'file',
    }


def f_autodate(name, on_create, on_update):
    # WAJIB didaftarkan agar PB mengenal created/updated (bug 2026-10-13:
    # sort/filter `created` 400 kalau field tidak terdaftar)
    return {
        'hidden': False, 'id': fid('autodate'), 'name': name,
        'onCreate': on_create, 'onUpdate': on_update, 'presentable': False,
        'system': False, 'type': 'autodate',
    }


AUTODATE_FIELDS = [f_autodate('created', True, False),
                   f_autodate('updated', True, True)]


def ensure_collection(cur, name, fields, rules, table_sql):
    n = cur.execute(
        'SELECT id FROM _collections WHERE name=?', (name,)
    ).fetchone()
    if n:
        print(f'koleksi {name} sudah ada.')
        return n[0]
    cur.execute(
        """INSERT INTO _collections
           (system, type, name, fields, indexes,
            listRule, viewRule, createRule, updateRule, deleteRule, options)
           VALUES (0, 'base', ?, ?, '[]', ?, ?, ?, ?, ?, '{}')""",
        (name, json.dumps(fields), *rules),
    )
    coll_id = cur.execute(
        'SELECT id FROM _collections WHERE name=?', (name,)
    ).fetchone()[0]
    cur.execute(table_sql)
    print(f'koleksi {name} dibuat.')
    return coll_id


def main():
    bak = f'/tmp/pb-simak-data-bak-{int(time.time())}.db'
    shutil.copy2(DB, bak)
    print(f'backup: {bak}')
    con = sqlite3.connect(DB)
    cur = con.cursor()

    rooms_id = ensure_collection(
        cur, 'chat_rooms',
        [f_id(), f_text('nama', True),
         f_select('tipe', ['grup', 'direct'], True),
         f_relation('anggota', USERS_COLL, multiple=True, required=True),
         f_text('deskripsi'), f_text('pesan_terakhir'), f_date('waktu_terakhir')] + AUTODATE_FIELDS,
        (AUTH, AUTH, AUTH, AUTH, ADMIN),
        """CREATE TABLE `chat_rooms` (
             `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
             `nama` TEXT DEFAULT '' NOT NULL, `tipe` TEXT DEFAULT '' NOT NULL,
             `anggota` TEXT DEFAULT '' NOT NULL, `deskripsi` TEXT DEFAULT '' NOT NULL,
             `pesan_terakhir` TEXT DEFAULT '' NOT NULL,
             `waktu_terakhir` TEXT DEFAULT '' NOT NULL,
             `created` TEXT DEFAULT '' NOT NULL,
             `updated` TEXT DEFAULT '' NOT NULL)""",
    )
    ensure_collection(
        cur, 'chat_messages',
        [f_id(), f_relation('room', rooms_id, required=True),
         f_relation('pengirim', USERS_COLL, required=True),
         f_text('pesan', True)] + AUTODATE_FIELDS,
        (AUTH, AUTH, AUTH, '', ADMIN),
        """CREATE TABLE `chat_messages` (
             `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
             `room` TEXT DEFAULT '' NOT NULL, `pengirim` TEXT DEFAULT '' NOT NULL,
             `pesan` TEXT DEFAULT '' NOT NULL,
             `created` TEXT DEFAULT '' NOT NULL,
             `updated` TEXT DEFAULT '' NOT NULL)""",
    )
    ensure_collection(
        cur, 'chat_baca',
        [f_id(), f_relation('room', rooms_id, required=True),
         f_relation('user', USERS_COLL, required=True),
         f_date('terakhir', True)] + AUTODATE_FIELDS,
        (AUTH, AUTH, AUTH, AUTH, AUTH),
        """CREATE TABLE `chat_baca` (
             `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
             `room` TEXT DEFAULT '' NOT NULL, `user` TEXT DEFAULT '' NOT NULL,
             `terakhir` TEXT DEFAULT '' NOT NULL,
             `created` TEXT DEFAULT '' NOT NULL,
             `updated` TEXT DEFAULT '' NOT NULL)""",
    )
    ensure_collection(
        cur, 'kejadian',
        [f_id(), f_text('judul', True), f_text('deskripsi'),
         f_select('kategori',
                  ['Pelanggaran', 'Anomali', 'Peristiwa', 'Lainnya'], True),
         f_file('foto'), f_relation('pelapor', USERS_COLL, required=True),
         f_date('tanggal', True)] + AUTODATE_FIELDS,
        (AUTH, AUTH, AUTH, ADMIN, ADMIN),
        """CREATE TABLE `kejadian` (
             `id` TEXT PRIMARY KEY DEFAULT ('r'||lower(hex(randomblob(7)))) NOT NULL,
             `judul` TEXT DEFAULT '' NOT NULL, `deskripsi` TEXT DEFAULT '' NOT NULL,
             `kategori` TEXT DEFAULT '' NOT NULL, `foto` TEXT DEFAULT '' NOT NULL,
             `pelapor` TEXT DEFAULT '' NOT NULL, `tanggal` TEXT DEFAULT '' NOT NULL,
             `created` TEXT DEFAULT '' NOT NULL,
             `updated` TEXT DEFAULT '' NOT NULL)""",
    )

    # Seed grup koordinasi: semua staf (bukan guru biasa)
    n_room = cur.execute(
        "SELECT COUNT(*) FROM chat_rooms WHERE nama='Koordinasi Sekolah'"
    ).fetchone()[0]
    if n_room == 0:
        staf = cur.execute(
            """SELECT id FROM users WHERE peran IN
               ('admin','waka','kurikulum','piket','asrama','satpam')"""
        ).fetchall()
        ids = [r[0] for r in staf]
        if ids:
            admin = cur.execute(
                "SELECT id FROM users WHERE peran='admin' LIMIT 1"
            ).fetchone()
            now = time.strftime('%Y-%m-%d %H:%M:%S')
            cur.execute(
                """INSERT INTO chat_rooms
                   (nama, tipe, anggota, deskripsi, pesan_terakhir, waktu_terakhir)
                   VALUES ('Koordinasi Sekolah','grup',?,?,?,?)""",
                (json.dumps(ids), 'Grup koordinasi piket, guru, dan waka',
                 'Selamat datang di grup Koordinasi Sekolah!', now),
            )
            room_id = cur.execute(
                "SELECT id FROM chat_rooms WHERE nama='Koordinasi Sekolah'"
            ).fetchone()[0]
            cur.execute(
                """INSERT INTO chat_messages (room, pengirim, pesan)
                   VALUES (?,?,?)""",
                (room_id, admin[0] if admin else ids[0],
                 'Selamat datang di grup Koordinasi Sekolah! '
                 'Gunakan grup ini untuk komunikasi antar piket, guru, dan waka.'),
            )
            print(f'seed grup Koordinasi Sekolah ({len(ids)} anggota).')
    con.commit()
    for t in ('chat_rooms', 'chat_messages', 'chat_baca', 'kejadian'):
        n = cur.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0]
        print(f'{t}: {n} baris')
    con.close()
    print('OK')


if __name__ == '__main__':
    sys.exit(main())
