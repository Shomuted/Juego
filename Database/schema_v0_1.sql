PRAGMA foreign_keys = ON;

-- =========================================================
-- THE LAST PHYSICAL STORE - Relational schema v0.1
-- Target dialect: SQLite 3
-- =========================================================

BEGIN;

CREATE TABLE catalog_version (
    catalog_version_id INTEGER PRIMARY KEY,
    version_code TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    notes TEXT
);

CREATE TABLE platform (
    platform_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    introduced_catalog_version_id INTEGER,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    FOREIGN KEY (introduced_catalog_version_id)
        REFERENCES catalog_version(catalog_version_id)
);

CREATE TABLE physical_format (
    physical_format_id INTEGER PRIMARY KEY,
    platform_id INTEGER NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    width_mm REAL NOT NULL CHECK (width_mm > 0),
    height_mm REAL NOT NULL CHECK (height_mm > 0),
    depth_mm REAL NOT NULL CHECK (depth_mm > 0),
    mass_g REAL NOT NULL CHECK (mass_g > 0),
    friction REAL,
    restitution REAL,
    model_key TEXT,
    pickup_sound_key TEXT,
    place_sound_key TEXT,
    is_default INTEGER NOT NULL DEFAULT 0 CHECK (is_default IN (0,1)),
    UNIQUE (platform_id, code),
    FOREIGN KEY (platform_id)
        REFERENCES platform(platform_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE UNIQUE INDEX ux_physical_format_one_default
ON physical_format(platform_id)
WHERE is_default = 1;

CREATE TABLE saga (
    saga_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);

CREATE TABLE title (
    title_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    platform_id INTEGER NOT NULL,
    saga_id INTEGER,
    name TEXT NOT NULL,
    introduced_catalog_version_id INTEGER,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    FOREIGN KEY (platform_id)
        REFERENCES platform(platform_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (saga_id)
        REFERENCES saga(saga_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY (introduced_catalog_version_id)
        REFERENCES catalog_version(catalog_version_id)
);

CREATE TABLE edition_type (
    edition_type_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    is_special INTEGER NOT NULL DEFAULT 0 CHECK (is_special IN (0,1))
);

CREATE TABLE title_edition (
    title_edition_id INTEGER PRIMARY KEY,
    title_id INTEGER NOT NULL,
    edition_type_id INTEGER NOT NULL,
    physical_format_id INTEGER,
    max_display_slots INTEGER CHECK (max_display_slots IS NULL OR max_display_slots > 0),
    cover_front_key TEXT,
    cover_back_key TEXT,
    spine_key TEXT,
    interior_visual_key TEXT,
    introduced_catalog_version_id INTEGER,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    UNIQUE (title_id, edition_type_id),
    FOREIGN KEY (title_id)
        REFERENCES title(title_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (edition_type_id)
        REFERENCES edition_type(edition_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (physical_format_id)
        REFERENCES physical_format(physical_format_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (introduced_catalog_version_id)
        REFERENCES catalog_version(catalog_version_id)
);

CREATE TRIGGER trg_title_edition_format_platform_ins
BEFORE INSERT ON title_edition
WHEN NEW.physical_format_id IS NOT NULL
BEGIN
    SELECT CASE
        WHEN (
            SELECT pf.platform_id
            FROM physical_format pf
            WHERE pf.physical_format_id = NEW.physical_format_id
        ) <> (
            SELECT t.platform_id
            FROM title t
            WHERE t.title_id = NEW.title_id
        )
        THEN RAISE(ABORT, 'title_edition physical format belongs to another platform')
    END;
END;

CREATE TRIGGER trg_title_edition_format_platform_upd
BEFORE UPDATE OF title_id, physical_format_id ON title_edition
WHEN NEW.physical_format_id IS NOT NULL
BEGIN
    SELECT CASE
        WHEN (
            SELECT pf.platform_id
            FROM physical_format pf
            WHERE pf.physical_format_id = NEW.physical_format_id
        ) <> (
            SELECT t.platform_id
            FROM title t
            WHERE t.title_id = NEW.title_id
        )
        THEN RAISE(ABORT, 'title_edition physical format belongs to another platform')
    END;
END;

CREATE TABLE collection_definition (
    collection_id INTEGER PRIMARY KEY,
    title_id INTEGER NOT NULL UNIQUE,
    FOREIGN KEY (title_id)
        REFERENCES title(title_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE collection_slot_definition (
    slot_id INTEGER PRIMARY KEY,
    collection_id INTEGER NOT NULL,
    slot_index INTEGER NOT NULL CHECK (slot_index > 0),
    base_title_edition_id INTEGER NOT NULL,
    UNIQUE (collection_id, slot_index),
    FOREIGN KEY (collection_id)
        REFERENCES collection_definition(collection_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (base_title_edition_id)
        REFERENCES title_edition(title_edition_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TRIGGER trg_slot_definition_title_ins
BEFORE INSERT ON collection_slot_definition
BEGIN
    SELECT CASE
        WHEN (
            SELECT te.title_id
            FROM title_edition te
            WHERE te.title_edition_id = NEW.base_title_edition_id
        ) <> (
            SELECT cd.title_id
            FROM collection_definition cd
            WHERE cd.collection_id = NEW.collection_id
        )
        THEN RAISE(ABORT, 'slot base edition belongs to another title')
    END;
END;

CREATE TRIGGER trg_slot_definition_title_upd
BEFORE UPDATE OF collection_id, base_title_edition_id ON collection_slot_definition
BEGIN
    SELECT CASE
        WHEN (
            SELECT te.title_id
            FROM title_edition te
            WHERE te.title_edition_id = NEW.base_title_edition_id
        ) <> (
            SELECT cd.title_id
            FROM collection_definition cd
            WHERE cd.collection_id = NEW.collection_id
        )
        THEN RAISE(ABORT, 'slot base edition belongs to another title')
    END;
END;

CREATE TABLE shelf (
    shelf_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    platform_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    display_order INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (platform_id)
        REFERENCES platform(platform_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE shelf_section (
    section_id INTEGER PRIMARY KEY,
    shelf_id INTEGER NOT NULL,
    collection_id INTEGER NOT NULL UNIQUE,
    section_index INTEGER NOT NULL CHECK (section_index > 0),
    UNIQUE (shelf_id, section_index),
    FOREIGN KEY (shelf_id)
        REFERENCES shelf(shelf_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (collection_id)
        REFERENCES collection_definition(collection_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TRIGGER trg_shelf_section_platform_ins
BEFORE INSERT ON shelf_section
BEGIN
    SELECT CASE
        WHEN (
            SELECT s.platform_id
            FROM shelf s
            WHERE s.shelf_id = NEW.shelf_id
        ) <> (
            SELECT t.platform_id
            FROM collection_definition cd
            JOIN title t ON t.title_id = cd.title_id
            WHERE cd.collection_id = NEW.collection_id
        )
        THEN RAISE(ABORT, 'collection assigned to shelf of another platform')
    END;
END;

CREATE TRIGGER trg_shelf_section_platform_upd
BEFORE UPDATE OF shelf_id, collection_id ON shelf_section
BEGIN
    SELECT CASE
        WHEN (
            SELECT s.platform_id
            FROM shelf s
            WHERE s.shelf_id = NEW.shelf_id
        ) <> (
            SELECT t.platform_id
            FROM collection_definition cd
            JOIN title t ON t.title_id = cd.title_id
            WHERE cd.collection_id = NEW.collection_id
        )
        THEN RAISE(ABORT, 'collection assigned to shelf of another platform')
    END;
END;

-- -------------------------
-- Generation configuration
-- -------------------------

CREATE TABLE condition_profile (
    condition_profile_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);

CREATE TABLE condition_band (
    condition_profile_id INTEGER NOT NULL,
    band_index INTEGER NOT NULL CHECK (band_index > 0),
    min_condition INTEGER NOT NULL CHECK (min_condition BETWEEN 0 AND 100),
    max_condition INTEGER NOT NULL CHECK (max_condition BETWEEN 0 AND 100),
    weight REAL NOT NULL CHECK (weight > 0),
    PRIMARY KEY (condition_profile_id, band_index),
    CHECK (min_condition <= max_condition),
    FOREIGN KEY (condition_profile_id)
        REFERENCES condition_profile(condition_profile_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE initial_stock_rule (
    title_id INTEGER PRIMARY KEY,
    total_copies INTEGER NOT NULL CHECK (total_copies > 0),
    condition_profile_id INTEGER NOT NULL,
    FOREIGN KEY (title_id)
        REFERENCES title(title_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (condition_profile_id)
        REFERENCES condition_profile(condition_profile_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE initial_stock_edition_rule (
    title_edition_id INTEGER PRIMARY KEY,
    weight REAL NOT NULL CHECK (weight >= 0),
    min_count INTEGER NOT NULL DEFAULT 0 CHECK (min_count >= 0),
    max_count INTEGER CHECK (max_count IS NULL OR max_count >= min_count),
    FOREIGN KEY (title_edition_id)
        REFERENCES title_edition(title_edition_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE lot_type (
    lot_type_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    copy_count INTEGER NOT NULL CHECK (copy_count > 0),
    price_cents INTEGER NOT NULL CHECK (price_cents >= 0),
    condition_profile_id INTEGER NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0,1)),
    FOREIGN KEY (condition_profile_id)
        REFERENCES condition_profile(condition_profile_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE lot_title_pool (
    lot_type_id INTEGER NOT NULL,
    title_id INTEGER NOT NULL,
    weight REAL NOT NULL CHECK (weight > 0),
    PRIMARY KEY (lot_type_id, title_id),
    FOREIGN KEY (lot_type_id)
        REFERENCES lot_type(lot_type_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (title_id)
        REFERENCES title(title_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE lot_edition_weight (
    lot_type_id INTEGER NOT NULL,
    edition_type_id INTEGER NOT NULL,
    weight REAL NOT NULL CHECK (weight >= 0),
    PRIMARY KEY (lot_type_id, edition_type_id),
    FOREIGN KEY (lot_type_id)
        REFERENCES lot_type(lot_type_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (edition_type_id)
        REFERENCES edition_type(edition_type_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- -------------------------
-- Save / campaign state
-- -------------------------

CREATE TABLE save_game (
    save_id INTEGER PRIMARY KEY,
    save_uuid TEXT NOT NULL UNIQUE,
    save_version INTEGER NOT NULL CHECK (save_version > 0),
    catalog_version_id INTEGER NOT NULL,
    generation_seed INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_saved_at TEXT,
    campaign_completed_day INTEGER CHECK (campaign_completed_day IS NULL OR campaign_completed_day > 0),
    FOREIGN KEY (catalog_version_id)
        REFERENCES catalog_version(catalog_version_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE player_state (
    save_id INTEGER PRIMARY KEY,
    money_cents INTEGER NOT NULL DEFAULT 0 CHECK (money_cents >= 0),
    xp INTEGER NOT NULL DEFAULT 0 CHECK (xp >= 0),
    inventory_capacity INTEGER NOT NULL DEFAULT 5 CHECK (inventory_capacity >= 0),
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE world_state (
    save_id INTEGER PRIMARY KEY,
    current_day INTEGER NOT NULL DEFAULT 1 CHECK (current_day > 0),
    day_phase TEXT NOT NULL DEFAULT 'DAY' CHECK (day_phase IN ('DAY','NIGHT')),
    phase_elapsed_seconds REAL NOT NULL DEFAULT 0 CHECK (phase_elapsed_seconds >= 0),
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE copy_source_type (
    source_type_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL
);

CREATE TABLE generated_lot (
    lot_id INTEGER PRIMARY KEY,
    save_id INTEGER NOT NULL,
    lot_type_id INTEGER NOT NULL,
    generation_seed INTEGER NOT NULL,
    requested_day INTEGER NOT NULL CHECK (requested_day > 0),
    price_paid_cents INTEGER NOT NULL CHECK (price_paid_cents >= 0),
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (lot_type_id)
        REFERENCES lot_type(lot_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -------------------------
-- Logical locations
-- -------------------------

CREATE TABLE location (
    location_id INTEGER PRIMARY KEY,
    save_id INTEGER NOT NULL,
    location_kind TEXT NOT NULL CHECK (
        location_kind IN ('WAREHOUSE','INVENTORY','COLLECTION_SLOT','ARCHIVE')
    ),
    UNIQUE (save_id, location_id),
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE warehouse_location (
    location_id INTEGER PRIMARY KEY,
    save_id INTEGER NOT NULL,
    zone_code TEXT,
    pos_x REAL NOT NULL,
    pos_y REAL NOT NULL,
    pos_z REAL NOT NULL,
    rot_x REAL NOT NULL DEFAULT 0,
    rot_y REAL NOT NULL DEFAULT 0,
    rot_z REAL NOT NULL DEFAULT 0,
    FOREIGN KEY (save_id, location_id)
        REFERENCES location(save_id, location_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE inventory_location (
    save_id INTEGER NOT NULL,
    slot_index INTEGER NOT NULL CHECK (slot_index > 0),
    location_id INTEGER NOT NULL UNIQUE,
    PRIMARY KEY (save_id, slot_index),
    FOREIGN KEY (save_id, location_id)
        REFERENCES location(save_id, location_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE collection_slot_location (
    save_id INTEGER NOT NULL,
    slot_id INTEGER NOT NULL,
    location_id INTEGER NOT NULL UNIQUE,
    PRIMARY KEY (save_id, slot_id),
    FOREIGN KEY (save_id, location_id)
        REFERENCES location(save_id, location_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (slot_id)
        REFERENCES collection_slot_definition(slot_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE archive_location (
    save_id INTEGER NOT NULL,
    archive_index INTEGER NOT NULL CHECK (archive_index > 0),
    location_id INTEGER NOT NULL UNIQUE,
    PRIMARY KEY (save_id, archive_index),
    FOREIGN KEY (save_id, location_id)
        REFERENCES location(save_id, location_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TRIGGER trg_warehouse_location_kind
BEFORE INSERT ON warehouse_location
BEGIN
    SELECT CASE
        WHEN (
            SELECT location_kind FROM location
            WHERE location_id = NEW.location_id AND save_id = NEW.save_id
        ) <> 'WAREHOUSE'
        THEN RAISE(ABORT, 'warehouse_location requires WAREHOUSE location kind')
    END;
END;

CREATE TRIGGER trg_inventory_location_kind
BEFORE INSERT ON inventory_location
BEGIN
    SELECT CASE
        WHEN (
            SELECT location_kind FROM location
            WHERE location_id = NEW.location_id AND save_id = NEW.save_id
        ) <> 'INVENTORY'
        THEN RAISE(ABORT, 'inventory_location requires INVENTORY location kind')
    END;
END;

CREATE TRIGGER trg_collection_location_kind
BEFORE INSERT ON collection_slot_location
BEGIN
    SELECT CASE
        WHEN (
            SELECT location_kind FROM location
            WHERE location_id = NEW.location_id AND save_id = NEW.save_id
        ) <> 'COLLECTION_SLOT'
        THEN RAISE(ABORT, 'collection_slot_location requires COLLECTION_SLOT location kind')
    END;
END;

CREATE TRIGGER trg_archive_location_kind
BEFORE INSERT ON archive_location
BEGIN
    SELECT CASE
        WHEN (
            SELECT location_kind FROM location
            WHERE location_id = NEW.location_id AND save_id = NEW.save_id
        ) <> 'ARCHIVE'
        THEN RAISE(ABORT, 'archive_location requires ARCHIVE location kind')
    END;
END;

-- -------------------------
-- Physical copies
-- -------------------------

CREATE TABLE physical_copy (
    copy_id INTEGER PRIMARY KEY,
    copy_uuid TEXT NOT NULL UNIQUE,
    save_id INTEGER NOT NULL,
    title_edition_id INTEGER NOT NULL,
    condition INTEGER NOT NULL CHECK (condition BETWEEN 0 AND 100),
    source_type_id INTEGER NOT NULL,
    lot_id INTEGER,
    current_location_id INTEGER NOT NULL,
    generated_at_day INTEGER NOT NULL DEFAULT 1 CHECK (generated_at_day > 0),
    UNIQUE (save_id, current_location_id),
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (title_edition_id)
        REFERENCES title_edition(title_edition_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (source_type_id)
        REFERENCES copy_source_type(source_type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (lot_id)
        REFERENCES generated_lot(lot_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (save_id, current_location_id)
        REFERENCES location(save_id, location_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TRIGGER trg_copy_origin_insert
BEFORE INSERT ON physical_copy
BEGIN
    SELECT CASE
        WHEN (
            SELECT code FROM copy_source_type
            WHERE source_type_id = NEW.source_type_id
        ) = 'INITIAL_CAMPAIGN'
        AND NEW.lot_id IS NOT NULL
        THEN RAISE(ABORT, 'initial campaign copy cannot reference a generated lot')
    END;

    SELECT CASE
        WHEN (
            SELECT code FROM copy_source_type
            WHERE source_type_id = NEW.source_type_id
        ) = 'POSTCAMPAIGN_LOT'
        AND NEW.lot_id IS NULL
        THEN RAISE(ABORT, 'postcampaign lot copy must reference a generated lot')
    END;

    SELECT CASE
        WHEN NEW.lot_id IS NOT NULL
        AND (
            SELECT save_id FROM generated_lot WHERE lot_id = NEW.lot_id
        ) <> NEW.save_id
        THEN RAISE(ABORT, 'copy lot belongs to another save')
    END;
END;

CREATE TRIGGER trg_copy_origin_update
BEFORE UPDATE OF source_type_id, lot_id, save_id ON physical_copy
BEGIN
    SELECT CASE
        WHEN (
            SELECT code FROM copy_source_type
            WHERE source_type_id = NEW.source_type_id
        ) = 'INITIAL_CAMPAIGN'
        AND NEW.lot_id IS NOT NULL
        THEN RAISE(ABORT, 'initial campaign copy cannot reference a generated lot')
    END;

    SELECT CASE
        WHEN (
            SELECT code FROM copy_source_type
            WHERE source_type_id = NEW.source_type_id
        ) = 'POSTCAMPAIGN_LOT'
        AND NEW.lot_id IS NULL
        THEN RAISE(ABORT, 'postcampaign lot copy must reference a generated lot')
    END;

    SELECT CASE
        WHEN NEW.lot_id IS NOT NULL
        AND (
            SELECT save_id FROM generated_lot WHERE lot_id = NEW.lot_id
        ) <> NEW.save_id
        THEN RAISE(ABORT, 'copy lot belongs to another save')
    END;
END;

-- -------------------------
-- Per-save collection state
-- -------------------------

CREATE TABLE collection_slot_state (
    save_id INTEGER NOT NULL,
    slot_id INTEGER NOT NULL,
    current_title_edition_id INTEGER NOT NULL,
    PRIMARY KEY (save_id, slot_id),
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (slot_id)
        REFERENCES collection_slot_definition(slot_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (current_title_edition_id)
        REFERENCES title_edition(title_edition_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TRIGGER trg_slot_state_title_ins
BEFORE INSERT ON collection_slot_state
BEGIN
    SELECT CASE
        WHEN (
            SELECT te.title_id
            FROM title_edition te
            WHERE te.title_edition_id = NEW.current_title_edition_id
        ) <> (
            SELECT cd.title_id
            FROM collection_slot_definition csd
            JOIN collection_definition cd
              ON cd.collection_id = csd.collection_id
            WHERE csd.slot_id = NEW.slot_id
        )
        THEN RAISE(ABORT, 'slot state edition belongs to another title')
    END;

    SELECT CASE
        WHEN (
            SELECT te.max_display_slots
            FROM title_edition te
            WHERE te.title_edition_id = NEW.current_title_edition_id
        ) IS NOT NULL
        AND (
            SELECT COUNT(*)
            FROM collection_slot_state css
            WHERE css.save_id = NEW.save_id
              AND css.current_title_edition_id = NEW.current_title_edition_id
        ) >= (
            SELECT te.max_display_slots
            FROM title_edition te
            WHERE te.title_edition_id = NEW.current_title_edition_id
        )
        THEN RAISE(ABORT, 'max display slots exceeded for edition')
    END;
END;

CREATE TRIGGER trg_slot_state_title_upd
BEFORE UPDATE OF current_title_edition_id, slot_id, save_id ON collection_slot_state
BEGIN
    SELECT CASE
        WHEN (
            SELECT te.title_id
            FROM title_edition te
            WHERE te.title_edition_id = NEW.current_title_edition_id
        ) <> (
            SELECT cd.title_id
            FROM collection_slot_definition csd
            JOIN collection_definition cd
              ON cd.collection_id = csd.collection_id
            WHERE csd.slot_id = NEW.slot_id
        )
        THEN RAISE(ABORT, 'slot state edition belongs to another title')
    END;

    SELECT CASE
        WHEN (
            SELECT te.max_display_slots
            FROM title_edition te
            WHERE te.title_edition_id = NEW.current_title_edition_id
        ) IS NOT NULL
        AND (
            SELECT COUNT(*)
            FROM collection_slot_state css
            WHERE css.save_id = NEW.save_id
              AND css.current_title_edition_id = NEW.current_title_edition_id
              AND NOT (css.save_id = OLD.save_id AND css.slot_id = OLD.slot_id)
        ) >= (
            SELECT te.max_display_slots
            FROM title_edition te
            WHERE te.title_edition_id = NEW.current_title_edition_id
        )
        THEN RAISE(ABORT, 'max display slots exceeded for edition')
    END;
END;

CREATE TABLE collection_state (
    save_id INTEGER NOT NULL,
    collection_id INTEGER NOT NULL,
    first_completed_day INTEGER CHECK (first_completed_day IS NULL OR first_completed_day > 0),
    PRIMARY KEY (save_id, collection_id),
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (collection_id)
        REFERENCES collection_definition(collection_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

CREATE TABLE edition_discovery (
    save_id INTEGER NOT NULL,
    title_edition_id INTEGER NOT NULL,
    discovery_state TEXT NOT NULL DEFAULT 'UNKNOWN'
        CHECK (discovery_state IN ('UNKNOWN','HINTED','DISCOVERED')),
    discovered_day INTEGER CHECK (discovered_day IS NULL OR discovered_day > 0),
    discovered_copy_id INTEGER,
    PRIMARY KEY (save_id, title_edition_id),
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (title_edition_id)
        REFERENCES title_edition(title_edition_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (discovered_copy_id)
        REFERENCES physical_copy(copy_id)
        ON UPDATE CASCADE ON DELETE SET NULL
);

CREATE TRIGGER trg_discovery_copy_consistency_ins
BEFORE INSERT ON edition_discovery
WHEN NEW.discovered_copy_id IS NOT NULL
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM physical_copy pc
            WHERE pc.copy_id = NEW.discovered_copy_id
              AND pc.save_id = NEW.save_id
              AND pc.title_edition_id = NEW.title_edition_id
        )
        THEN RAISE(ABORT, 'discovery copy does not match save/title edition')
    END;
END;

CREATE TRIGGER trg_discovery_copy_consistency_upd
BEFORE UPDATE OF discovered_copy_id, save_id, title_edition_id ON edition_discovery
WHEN NEW.discovered_copy_id IS NOT NULL
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM physical_copy pc
            WHERE pc.copy_id = NEW.discovered_copy_id
              AND pc.save_id = NEW.save_id
              AND pc.title_edition_id = NEW.title_edition_id
        )
        THEN RAISE(ABORT, 'discovery copy does not match save/title edition')
    END;
END;

-- Tracks campaign processing without defining the exact gameplay event yet.
CREATE TABLE campaign_copy_state (
    copy_id INTEGER PRIMARY KEY,
    processed_day INTEGER CHECK (processed_day IS NULL OR processed_day > 0),
    FOREIGN KEY (copy_id)
        REFERENCES physical_copy(copy_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TRIGGER trg_campaign_copy_only_initial
BEFORE INSERT ON campaign_copy_state
BEGIN
    SELECT CASE
        WHEN (
            SELECT cst.code
            FROM physical_copy pc
            JOIN copy_source_type cst ON cst.source_type_id = pc.source_type_id
            WHERE pc.copy_id = NEW.copy_id
        ) <> 'INITIAL_CAMPAIGN'
        THEN RAISE(ABORT, 'campaign_copy_state only applies to initial campaign copies')
    END;
END;

-- Placement validation: incompatible copy remains out of the collection slot.
CREATE TRIGGER trg_copy_collection_placement_ins
BEFORE INSERT ON physical_copy
WHEN (
    SELECT location_kind
    FROM location
    WHERE location_id = NEW.current_location_id
) = 'COLLECTION_SLOT'
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM collection_slot_location csl
            JOIN collection_slot_state css
              ON css.save_id = csl.save_id
             AND css.slot_id = csl.slot_id
            WHERE csl.save_id = NEW.save_id
              AND csl.location_id = NEW.current_location_id
              AND css.current_title_edition_id = NEW.title_edition_id
        )
        THEN RAISE(ABORT, 'copy edition is incompatible with collection slot')
    END;
END;

CREATE TRIGGER trg_copy_collection_placement_upd
BEFORE UPDATE OF current_location_id, title_edition_id, save_id ON physical_copy
WHEN (
    SELECT location_kind
    FROM location
    WHERE location_id = NEW.current_location_id
) = 'COLLECTION_SLOT'
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM collection_slot_location csl
            JOIN collection_slot_state css
              ON css.save_id = csl.save_id
             AND css.slot_id = csl.slot_id
            WHERE csl.save_id = NEW.save_id
              AND csl.location_id = NEW.current_location_id
              AND css.current_title_edition_id = NEW.title_edition_id
        )
        THEN RAISE(ABORT, 'copy edition is incompatible with collection slot')
    END;
END;

-- -------------------------
-- Upgrades (minimal data-driven base)
-- -------------------------

CREATE TABLE upgrade_definition (
    upgrade_id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    category TEXT NOT NULL CHECK (category IN ('PLAYER','STORE')),
    name TEXT NOT NULL,
    max_level INTEGER NOT NULL DEFAULT 1 CHECK (max_level > 0),
    effect_key TEXT
);

CREATE TABLE save_upgrade (
    save_id INTEGER NOT NULL,
    upgrade_id INTEGER NOT NULL,
    level INTEGER NOT NULL CHECK (level > 0),
    PRIMARY KEY (save_id, upgrade_id),
    FOREIGN KEY (save_id)
        REFERENCES save_game(save_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    FOREIGN KEY (upgrade_id)
        REFERENCES upgrade_definition(upgrade_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -------------------------
-- Useful views
-- -------------------------

CREATE VIEW v_copy_resolved AS
SELECT
    pc.copy_id,
    pc.copy_uuid,
    pc.save_id,
    p.code AS platform_code,
    p.name AS platform_name,
    t.code AS title_code,
    t.name AS title_name,
    et.code AS edition_code,
    et.name AS edition_name,
    pc.condition,
    cst.code AS source_code,
    l.location_kind,
    pc.current_location_id
FROM physical_copy pc
JOIN title_edition te ON te.title_edition_id = pc.title_edition_id
JOIN title t ON t.title_id = te.title_id
JOIN platform p ON p.platform_id = t.platform_id
JOIN edition_type et ON et.edition_type_id = te.edition_type_id
JOIN copy_source_type cst ON cst.source_type_id = pc.source_type_id
JOIN location l ON l.location_id = pc.current_location_id;

CREATE VIEW v_collection_progress AS
SELECT
    sg.save_id,
    cd.collection_id,
    t.title_id,
    t.name AS title_name,
    COUNT(csd.slot_id) AS total_slots,
    COUNT(pc.copy_id) AS occupied_slots,
    ROUND(AVG(pc.condition), 2) AS average_condition,
    CASE
        WHEN COUNT(csd.slot_id) > 0
         AND COUNT(pc.copy_id) = COUNT(csd.slot_id)
        THEN 1 ELSE 0
    END AS is_currently_complete,
    CASE WHEN cs.first_completed_day IS NOT NULL THEN 1 ELSE 0 END AS was_completed_before
FROM save_game sg
CROSS JOIN collection_definition cd
JOIN title t ON t.title_id = cd.title_id
JOIN collection_slot_definition csd ON csd.collection_id = cd.collection_id
LEFT JOIN collection_slot_location csl
       ON csl.save_id = sg.save_id
      AND csl.slot_id = csd.slot_id
LEFT JOIN physical_copy pc
       ON pc.save_id = sg.save_id
      AND pc.current_location_id = csl.location_id
LEFT JOIN collection_state cs
       ON cs.save_id = sg.save_id
      AND cs.collection_id = cd.collection_id
GROUP BY
    sg.save_id,
    cd.collection_id,
    t.title_id,
    t.name,
    cs.first_completed_day;

CREATE VIEW v_campaign_progress AS
SELECT
    sg.save_id,
    SUM(CASE WHEN cst.code = 'INITIAL_CAMPAIGN' THEN 1 ELSE 0 END) AS initial_copy_count,
    SUM(CASE WHEN cst.code = 'INITIAL_CAMPAIGN' AND ccs.processed_day IS NOT NULL THEN 1 ELSE 0 END) AS processed_initial_copies
FROM save_game sg
LEFT JOIN physical_copy pc
       ON pc.save_id = sg.save_id
LEFT JOIN copy_source_type cst
       ON cst.source_type_id = pc.source_type_id
LEFT JOIN campaign_copy_state ccs
       ON ccs.copy_id = pc.copy_id
GROUP BY sg.save_id;

-- -------------------------
-- Base lookup data
-- -------------------------

INSERT INTO edition_type (edition_type_id, code, name, is_special) VALUES
    (1, 'STANDARD', 'Standard', 0),
    (2, 'GOTY', 'Game of the Year', 1),
    (3, 'COLLECTOR', 'Collector', 1);

INSERT INTO copy_source_type (source_type_id, code, name) VALUES
    (1, 'INITIAL_CAMPAIGN', 'Initial campaign stock'),
    (2, 'POSTCAMPAIGN_LOT', 'Post-campaign lot');

COMMIT;
