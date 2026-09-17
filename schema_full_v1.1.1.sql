-- =========================================================
-- NIEMS Schema Full v1.1.1-action_today (Consolidated)
-- Concept: Raw-first + Evidence-first + No-hallucination
-- =========================================================

-- ========== CORE INFRASTRUCTURE ==========

CREATE TABLE IF NOT EXISTS data_source_systems (
    id TEXT PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    system_type TEXT, 
    refresh_frequency TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS ingest_runs (
    id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL UNIQUE,
    mode TEXT,
    started_at DATETIME NOT NULL,
    ended_at DATETIME,
    cursor_start TEXT,
    cursor_next TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ========== EVIDENCE LAYER ==========

CREATE TABLE IF NOT EXISTS evidence_assets (
    id TEXT PRIMARY KEY,
    evidence_type TEXT NOT NULL, -- enum: document|image|dataset|minute|certificate|receipt|other
    classification TEXT NOT NULL DEFAULT 'internal',
    title TEXT,
    file_name TEXT,
    storage_system TEXT,
    file_uri TEXT,
    checksum_sha256 TEXT,
    retention_until DATE,
    owner_org_unit_id TEXT,
    source_system_id TEXT,
    source_ref TEXT,
    ingest_run_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS evidence_chain (
    id TEXT PRIMARY KEY,
    evidence_asset_id TEXT NOT NULL,
    linked_entity_type TEXT NOT NULL,
    linked_entity_id TEXT NOT NULL,
    anchor TEXT,
    notes TEXT,
    ingest_run_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (evidence_asset_id) REFERENCES evidence_assets(id)
);

-- ========== ORGANIZATION & GEOGRAPHY ==========

CREATE TABLE IF NOT EXISTS health_zones (
    id TEXT PRIMARY KEY,
    zone_code TEXT NOT NULL UNIQUE,
    zone_name TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS provinces (
    id TEXT PRIMARY KEY,
    province_code TEXT UNIQUE,
    province_name_th TEXT NOT NULL,
    health_zone_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (health_zone_id) REFERENCES health_zones(id)
);

CREATE TABLE IF NOT EXISTS organizations (
    id TEXT PRIMARY KEY,
    org_code TEXT NOT NULL UNIQUE,
    org_name_th TEXT NOT NULL,
    org_name_en TEXT,
    organization_type TEXT NOT NULL, -- internal|external
    org_level TEXT,
    org_category TEXT,
    stakeholder_group_code TEXT,
    admin_level TEXT,
    province_id TEXT,
    parent_organization_id TEXT,
    evidence_asset_id TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (province_id) REFERENCES provinces(id)
);

CREATE TABLE IF NOT EXISTS org_units (
    id TEXT PRIMARY KEY,
    organization_id TEXT NOT NULL,
    org_unit_code TEXT NOT NULL UNIQUE,
    org_unit_name TEXT NOT NULL,
    org_unit_type TEXT NOT NULL,
    parent_org_unit_id TEXT,
    admin_level TEXT,
    effective_from DATE,
    effective_to DATE,
    status TEXT NOT NULL DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (organization_id) REFERENCES organizations(id)
);

CREATE TABLE IF NOT EXISTS org_unit_aliases (
    id TEXT PRIMARY KEY,
    org_unit_id TEXT NOT NULL,
    alias TEXT NOT NULL,
    alias_type TEXT NOT NULL,
    is_primary INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (org_unit_id) REFERENCES org_units(id)
);

CREATE TABLE IF NOT EXISTS org_unit_functions (
    id TEXT PRIMARY KEY,
    function_code TEXT NOT NULL UNIQUE,
    function_name TEXT NOT NULL,
    description TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS bridge_org_unit_functions (
    id TEXT PRIMARY KEY,
    org_unit_id TEXT NOT NULL,
    function_id TEXT NOT NULL,
    strength TEXT NOT NULL DEFAULT 'supporting',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(org_unit_id, function_id),
    FOREIGN KEY (org_unit_id) REFERENCES org_units(id),
    FOREIGN KEY (function_id) REFERENCES org_unit_functions(id)
);

CREATE TABLE IF NOT EXISTS bridge_org_unit_health_zones (
    id TEXT PRIMARY KEY,
    org_unit_id TEXT NOT NULL,
    health_zone_id TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(org_unit_id, health_zone_id),
    FOREIGN KEY (org_unit_id) REFERENCES org_units(id),
    FOREIGN KEY (health_zone_id) REFERENCES health_zones(id)
);

-- ========== PROJECTS LAYER (ADDED) ==========

CREATE TABLE IF NOT EXISTS projects (
    id TEXT PRIMARY KEY,
    project_code TEXT NOT NULL UNIQUE,
    project_name TEXT NOT NULL,
    owner_org_unit_id TEXT,
    province_id TEXT,
    start_date DATE,
    end_date DATE,
    status TEXT NOT NULL DEFAULT 'active',
    evidence_asset_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_org_unit_id) REFERENCES org_units(id),
    FOREIGN KEY (province_id) REFERENCES provinces(id),
    FOREIGN KEY (evidence_asset_id) REFERENCES evidence_assets(id)
);

-- ========== PERIOD & REPORTING ==========

CREATE TABLE IF NOT EXISTS reporting_periods (
    period_key TEXT PRIMARY KEY,
    period_type TEXT NOT NULL,
    fiscal_year INTEGER NOT NULL,
    fiscal_year_start_month INTEGER DEFAULT 10,
    period_start_date DATE NOT NULL,
    period_end_date DATE NOT NULL,
    close_status TEXT NOT NULL DEFAULT 'open',
    due_dates TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS reporting_obligation_instances (
    id TEXT PRIMARY KEY,
    reporting_obligation_id TEXT NOT NULL,
    period_key TEXT NOT NULL,
    due_date DATE,
    owner_org_unit_id TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    report_snapshot_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (period_key) REFERENCES reporting_periods(period_key)
);

-- ========== ACTIVITY LAYER (UPDATED with AI Fields) ==========

CREATE TABLE IF NOT EXISTS activity_instances (
    id TEXT PRIMARY KEY,
    activity_code TEXT UNIQUE,
    subject TEXT,
    activity_date DATE,
    activity_start_datetime DATETIME,
    activity_end_datetime DATETIME,
    description_raw TEXT, -- Raw text from LINE/Doc
    location_text TEXT,
    location_mode TEXT,
    participant_count INTEGER,
    activity_type_code TEXT, -- meeting|training|field_visit|etc
    
    -- AI & Matching Fields (ADDED)
    text_fingerprint TEXT, -- Hash keywords for matching
    extracted_entities TEXT, -- JSON structure extracted by AI
    
    -- Links
    owner_org_unit_id TEXT,
    period_key TEXT,
    evidence_asset_id TEXT, -- Evidence-first link
    
    -- Audit
    evidence_strength TEXT DEFAULT 'unknown',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    updated_at DATETIME,
    updated_by TEXT,
    source_system_id TEXT,
    row_sha256 TEXT,
    
    FOREIGN KEY (owner_org_unit_id) REFERENCES org_units(id),
    FOREIGN KEY (period_key) REFERENCES reporting_periods(period_key),
    FOREIGN KEY (evidence_asset_id) REFERENCES evidence_assets(id)
);

CREATE TABLE IF NOT EXISTS activity_participants (
    id TEXT PRIMARY KEY,
    activity_instance_id TEXT NOT NULL,
    participant_org_unit_id TEXT,
    participant_organization_id TEXT,
    participant_name TEXT,
    role TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (activity_instance_id) REFERENCES activity_instances(id)
);

CREATE TABLE IF NOT EXISTS activity_topics (
    id TEXT PRIMARY KEY,
    activity_instance_id TEXT NOT NULL,
    topic_order INTEGER,
    topic_text TEXT NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (activity_instance_id) REFERENCES activity_instances(id)
);

-- ========== FINANCE LAYER (ADDED) ==========

CREATE TABLE IF NOT EXISTS financial_transactions (
    id TEXT PRIMARY KEY,
    project_id TEXT,
    transaction_date DATE,
    amount_total DECIMAL(15,2),
    description TEXT,
    doc_no TEXT, -- Hard Key
    text_fingerprint TEXT, -- For Matching
    evidence_asset_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id),
    FOREIGN KEY (evidence_asset_id) REFERENCES evidence_assets(id)
);

-- Bridge Table for Matching (ADDED)
CREATE TABLE IF NOT EXISTS bridge_activity_financial_transactions (
    id TEXT PRIMARY KEY,
    activity_instance_id TEXT NOT NULL,
    financial_transaction_id TEXT NOT NULL,
    match_method TEXT NOT NULL, -- exact|window|keyword
    confidence_score REAL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (activity_instance_id) REFERENCES activity_instances(id),
    FOREIGN KEY (financial_transaction_id) REFERENCES financial_transactions(id)
);

-- ========== COMMITTEE & MEETINGS ==========

CREATE TABLE IF NOT EXISTS committees (
    id TEXT PRIMARY KEY,
    committee_code TEXT NOT NULL UNIQUE,
    committee_name TEXT NOT NULL,
    owner_org_unit_id TEXT,
    status TEXT NOT NULL DEFAULT 'active',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (owner_org_unit_id) REFERENCES org_units(id)
);

CREATE TABLE IF NOT EXISTS committee_meetings (
    id TEXT PRIMARY KEY,
    committee_id TEXT NOT NULL,
    meeting_no TEXT,
    meeting_date DATE,
    location TEXT,
    evidence_asset_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (committee_id) REFERENCES committees(id),
    FOREIGN KEY (evidence_asset_id) REFERENCES evidence_assets(id)
);

CREATE TABLE IF NOT EXISTS meeting_agenda_items (
    id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL,
    agenda_no TEXT,
    agenda_type TEXT,
    agenda_title TEXT NOT NULL,
    presenter_org_unit_id TEXT,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (meeting_id) REFERENCES committee_meetings(id)
);

CREATE TABLE IF NOT EXISTS meeting_resolutions (
    id TEXT PRIMARY KEY,
    meeting_id TEXT NOT NULL,
    agenda_item_id TEXT,
    resolution_type TEXT,
    resolution_text TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'open',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (meeting_id) REFERENCES committee_meetings(id)
);

CREATE TABLE IF NOT EXISTS action_items (
    id TEXT PRIMARY KEY,
    resolution_id TEXT,
    activity_instance_id TEXT,
    action_description TEXT NOT NULL,
    assignee_org_unit_id TEXT,
    due_date DATE,
    status TEXT NOT NULL DEFAULT 'open',
    completed_at DATETIME,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (resolution_id) REFERENCES meeting_resolutions(id),
    FOREIGN KEY (activity_instance_id) REFERENCES activity_instances(id)
);

-- ========== DATA QUALITY & ANTI-GUESS ==========

CREATE TABLE IF NOT EXISTS dq_signals (
    id TEXT PRIMARY KEY,
    signal_type TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'warn',
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    field_name TEXT,
    detected_value TEXT,
    expected_pattern TEXT,
    message TEXT,
    ingest_run_id TEXT,
    resolved_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS open_questions (
    id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    question_text TEXT NOT NULL,
    context TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    answer_text TEXT,
    answered_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    ingest_run_id TEXT
);

CREATE TABLE IF NOT EXISTS conflict_register (
    id TEXT PRIMARY KEY,
    conflict_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_a_id TEXT NOT NULL,
    entity_b_id TEXT,
    field_name TEXT,
    value_a TEXT,
    value_b TEXT,
    status TEXT NOT NULL DEFAULT 'open',
    resolution_note TEXT,
    resolved_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ========== MATCH RUN LEDGER ==========

CREATE TABLE IF NOT EXISTS match_runs (
    id TEXT PRIMARY KEY,
    run_id TEXT NOT NULL UNIQUE,
    algorithm_name TEXT NOT NULL,
    algorithm_version TEXT,
    window_days INTEGER,
    input_entity_types TEXT,
    started_at DATETIME NOT NULL,
    ended_at DATETIME,
    notes TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS match_candidates (
    id TEXT PRIMARY KEY,
    match_run_id TEXT NOT NULL,
    entity_a_type TEXT NOT NULL,
    entity_a_id TEXT NOT NULL,
    entity_b_type TEXT NOT NULL,
    entity_b_id TEXT NOT NULL,
    confidence_score REAL,
    match_features TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    reviewed_by TEXT,
    reviewed_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (match_run_id) REFERENCES match_runs(id)
);