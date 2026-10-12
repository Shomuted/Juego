#!/usr/bin/env python3
"""Genera la base de contenido SQLite y el catálogo compatible con Godot 4.

Uso desde la raíz del proyecto:
    python3 Tools/build_catalog.py

Requiere únicamente Python 3 y sqlite3 de la biblioteca estándar.
No toca SaveManager.gd ni las partidas almacenadas en user://.
"""
from __future__ import annotations

import json
import os
from pathlib import Path
import sqlite3
import tempfile

ROOT = Path(__file__).resolve().parent.parent
DB_DIR = ROOT / "Database"
SCHEMA = DB_DIR / "schema_v0_1.sql"
SEED = DB_DIR / "seed_prototype.sql"
OUTPUT_DB = DB_DIR / "tlps_catalog_prototype.db"
OUTPUT_JSON = DB_DIR / "catalog_export.json"
OUTPUT_GD = ROOT / "Scripts" / "catalogo_juegos.gd"


def generate_catalog_script(titles: list[dict]) -> str:
    rows: list[str] = []
    for entry in titles:
        code = json.dumps(entry["code"], ensure_ascii=False)
        name = json.dumps(entry["name"], ensure_ascii=False)
        console = json.dumps(entry["platform_code"], ensure_ascii=False)
        rows.append(f'\t{code}: {{"titulo": {name}, "consola": {console}}}')
    mapping = ",\n".join(rows)
    return (
        "extends RefCounted\n"
        "class_name CatalogoJuegos\n\n"
        "# Archivo generado por Tools/build_catalog.py desde SQLite.\n"
        "# Se conservan los nombres de métodos del proyecto para compatibilidad.\n"
        "const JUEGOS: Dictionary = {\n"
        f"{mapping}\n"
        "}\n\n\n"
        "static func obtener_juego(id_juego: String) -> Dictionary:\n"
        "\tif not JUEGOS.has(id_juego):\n"
        "\t\tpush_warning(\"ID de juego desconocido: \" + id_juego)\n"
        "\t\treturn {}\n\n"
        "\treturn JUEGOS[id_juego].duplicate(true)\n\n\n"
        "static func obtener_ids() -> Array[String]:\n"
        "\tvar ids: Array[String] = []\n"
        "\tfor id_juego: String in JUEGOS.keys():\n"
        "\t\tids.append(id_juego)\n"
        "\treturn ids\n\n\n"
        "static func existe(id_juego: String) -> bool:\n"
        "\treturn JUEGOS.has(id_juego)\n"
    )


def fetch_all(conn: sqlite3.Connection, query: str) -> list[dict]:
    return [dict(row) for row in conn.execute(query).fetchall()]


def assert_catalog_integrity(conn: sqlite3.Connection) -> None:
    errors = conn.execute("PRAGMA foreign_key_check").fetchall()
    if errors:
        raise ValueError(f"Foreign key violations: {errors}")

    errors = conn.execute("PRAGMA integrity_check").fetchone()
    if errors is None or errors[0] != "ok":
        raise ValueError(f"SQLite integrity_check: {errors}")

    default_mismatch = conn.execute(
        "SELECT p.code FROM platform p "
        "WHERE NOT EXISTS ("
        "  SELECT 1 FROM physical_format f "
        "  WHERE f.platform_id = p.platform_id AND f.is_default = 1"
        ")"
    ).fetchall()
    if default_mismatch:
        raise ValueError(f"Platforms without default physical format: {default_mismatch}")

    slot_mismatch = conn.execute(
        "SELECT cd.collection_id, COUNT(csd.slot_id) AS total "
        "FROM collection_definition cd "
        "LEFT JOIN collection_slot_definition csd ON csd.collection_id = cd.collection_id "
        "GROUP BY cd.collection_id HAVING total != 10"
    ).fetchall()
    if slot_mismatch:
        raise ValueError(f"Collections with incorrect slot count: {slot_mismatch}")

    wrong_shelves = conn.execute(
        "SELECT s.code FROM shelf s "
        "JOIN shelf_section ss ON ss.shelf_id = s.shelf_id "
        "JOIN collection_definition cd ON cd.collection_id = ss.collection_id "
        "JOIN title t ON t.title_id = cd.title_id "
        "WHERE t.platform_id != s.platform_id"
    ).fetchall()
    if wrong_shelves:
        raise ValueError(f"Incorrect shelf platform: {wrong_shelves}")


def build() -> None:
    DB_DIR.mkdir(exist_ok=True)
    conn = sqlite3.connect(":memory:")
    conn.row_factory = sqlite3.Row
    try:
        conn.executescript(SCHEMA.read_text(encoding="utf-8"))
        conn.executescript(SEED.read_text(encoding="utf-8"))
        assert_catalog_integrity(conn)
        titles = fetch_all(
            conn,
            "SELECT t.title_id, t.code, t.name, p.code AS platform_code, "
            "t.is_active FROM title t JOIN platform p ON p.platform_id = t.platform_id "
            "ORDER BY t.title_id",
        )
        formats = fetch_all(
            conn,
            "SELECT p.code AS platform_code, f.code AS format_code, "
            "f.width_mm, f.height_mm, f.depth_mm, f.mass_g, "
            "f.friction, f.restitution, f.model_key, f.is_default "
            "FROM physical_format f JOIN platform p ON p.platform_id=f.platform_id "
            "ORDER BY p.platform_id, f.physical_format_id",
        )
        shelves = fetch_all(
            conn,
            "SELECT s.code AS shelf_code, p.code AS platform_code, "
            "ss.section_index, t.code AS title_code "
            "FROM shelf_section ss "
            "JOIN shelf s ON s.shelf_id=ss.shelf_id "
            "JOIN platform p ON p.platform_id=s.platform_id "
            "JOIN collection_definition cd ON cd.collection_id=ss.collection_id "
            "JOIN title t ON t.title_id=cd.title_id "
            "ORDER BY s.shelf_id,ss.section_index",
        )
        export = {
            "catalog_version": "0.1-prototipo",
            "titles": titles,
            "physical_formats": formats,
            "shelf_sections": shelves,
        }
        gd_content = generate_catalog_script(titles)
        json_content = json.dumps(export, indent=2, ensure_ascii=False) + "\n"

        with tempfile.NamedTemporaryFile(
            prefix="tlps_build_", suffix=".db", dir=DB_DIR, delete=False
        ) as f:
            temp_path = Path(f.name)
        try:
            db = sqlite3.connect(str(temp_path))
            try:
                conn.backup(db)
                db.commit()
            finally:
                db.close()
            os.replace(temp_path, OUTPUT_DB)
        finally:
            if temp_path.exists():
                temp_path.unlink()

        OUTPUT_JSON.write_text(json_content, encoding="utf-8")
        OUTPUT_GD.write_text(gd_content, encoding="utf-8")
        print(f"SQLite catalog: {OUTPUT_DB}")
        print(f"Godot catalog:  {OUTPUT_GD}")
        print(f"JSON export:    {OUTPUT_JSON}")
        print(
            f"Validated: {len(titles)} titles, {len(formats)} physical formats, "
            f"{len(shelves)} configured shelf sections"
        )
    finally:
        conn.close()


if __name__ == "__main__":
    build()
