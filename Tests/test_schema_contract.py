#!/usr/bin/env python3
"""Pruebas del contrato de catálogo basado en el esquema v0.1."""
from __future__ import annotations

import json
from pathlib import Path
import sqlite3
import sys
import unittest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "Tools"))

from build_catalog import assert_catalog_integrity, generate_catalog_script  # noqa: E402

SCHEMA = (ROOT / "Database" / "schema_v0_1.sql").read_text(encoding="utf-8")
SEED = (ROOT / "Database" / "seed_prototype.sql").read_text(encoding="utf-8")


class CatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.conn = sqlite3.connect(":memory:")
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript(SCHEMA)
        self.conn.executescript(SEED)
        self.conn.execute("PRAGMA foreign_keys=ON")

    def tearDown(self) -> None:
        self.conn.close()

    def test_schema_and_catalog_are_valid(self) -> None:
        assert_catalog_integrity(self.conn)
        tables = self.conn.execute(
            "SELECT COUNT(*) FROM sqlite_master WHERE type='table'"
        ).fetchone()[0]
        self.assertEqual(tables, 35)

    def test_prototype_counts(self) -> None:
        counts = {
            table: self.conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
            for table in (
                "title", "physical_format", "collection_slot_definition",
                "shelf_section", "initial_stock_rule"
            )
        }
        self.assertEqual(counts, {
            "title": 12,
            "physical_format": 7,
            "collection_slot_definition": 120,
            "shelf_section": 6,
            "initial_stock_rule": 6,
        })

    def test_exported_godot_catalog_preserves_identity(self) -> None:
        titles = [
            dict(row) for row in self.conn.execute(
                "SELECT t.code, t.name, p.code AS platform_code "
                "FROM title t JOIN platform p ON p.platform_id=t.platform_id "
                "ORDER BY t.title_id"
            )
        ]
        script = generate_catalog_script(titles)
        self.assertEqual(
            script,
            (ROOT / "Scripts" / "catalogo_juegos.gd").read_text(encoding="utf-8"),
        )
        export = json.loads(
            (ROOT / "Database" / "catalog_export.json").read_text(encoding="utf-8")
        )
        self.assertEqual(
            [(t["code"], t["name"], t["platform_code"]) for t in titles],
            [(t["code"], t["name"], t["platform_code"]) for t in export["titles"]],
        )

    def test_rejects_cross_platform_edition(self) -> None:
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute(
                "INSERT INTO title_edition(title_id,edition_type_id,physical_format_id) "
                "VALUES(1,3,2)"
            )

    def test_rejects_wrong_shelf_assignment(self) -> None:
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute(
                "INSERT INTO shelf_section(shelf_id,collection_id,section_index) "
                "VALUES(1,3,3)"
            )

    def test_copy_placement_identity_and_archive_transfer(self) -> None:
        self.conn.execute(
            "INSERT INTO save_game(save_id,save_uuid,save_version,catalog_version_id,generation_seed) "
            "VALUES(1,'save_test_1',1,1,2026)"
        )
        self.conn.execute(
            "INSERT INTO collection_slot_state(save_id,slot_id,current_title_edition_id) "
            "VALUES(1,1,1)"
        )
        self.conn.execute(
            "INSERT INTO location(location_id,save_id,location_kind) "
            "VALUES(101,1,'COLLECTION_SLOT'),(102,1,'ARCHIVE')"
        )
        self.conn.execute(
            "INSERT INTO collection_slot_location(save_id,slot_id,location_id) "
            "VALUES(1,1,101)"
        )
        self.conn.execute(
            "INSERT INTO archive_location(save_id,archive_index,location_id) "
            "VALUES(1,1,102)"
        )
        self.conn.execute(
            "INSERT INTO physical_copy(copy_uuid,save_id,title_edition_id,condition,source_type_id,current_location_id) "
            "VALUES('copy_test_a',1,1,72,1,101)"
        )
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute(
                "INSERT INTO physical_copy(copy_uuid,save_id,title_edition_id,condition,source_type_id,current_location_id) "
                "VALUES('copy_test_duplicate_location',1,1,94,1,101)"
            )
        self.assertEqual(
            self.conn.execute(
                "SELECT occupied_slots FROM v_collection_progress "
                "WHERE save_id=1 AND collection_id=1"
            ).fetchone()[0],
            1,
        )
        self.conn.execute(
            "UPDATE physical_copy SET current_location_id=102 "
            "WHERE copy_uuid='copy_test_a'"
        )
        self.assertEqual(
            self.conn.execute(
                "SELECT location_kind FROM v_copy_resolved WHERE copy_uuid='copy_test_a'"
            ).fetchone()[0],
            "ARCHIVE",
        )
        self.assertEqual(
            self.conn.execute(
                "SELECT occupied_slots FROM v_collection_progress "
                "WHERE save_id=1 AND collection_id=1"
            ).fetchone()[0],
            0,
        )
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute(
                "INSERT INTO physical_copy(copy_uuid,save_id,title_edition_id,condition,source_type_id,current_location_id) "
                "VALUES('copy_wrong_edition',1,2,80,1,101)"
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
