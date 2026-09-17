-- ตารางเก็บหลักฐาน (Evidence)
CREATE TABLE IF NOT EXISTS evidence_assets (
    id TEXT PRIMARY KEY,
    evidence_type TEXT NOT NULL,
    title TEXT,
    file_name TEXT,
    file_uri TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ตารางเก็บกิจกรรม (Activities) - ปรับให้ตรงกับโค้ด
CREATE TABLE IF NOT EXISTS activity_instances (
    id TEXT PRIMARY KEY,
    subject TEXT,
    activity_date DATE,
    description_raw TEXT,
    location_text TEXT,
    participant_count INTEGER,
    activity_type_code TEXT,
    extracted_entities TEXT,
    evidence_asset_id TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (evidence_asset_id) REFERENCES evidence_assets(id)
);

-- ตารางเก็บผู้เข้าร่วม (Participants)
CREATE TABLE IF NOT EXISTS activity_participants (
    id TEXT PRIMARY KEY,
    activity_instance_id TEXT,
    participant_name TEXT,
    organization_label TEXT,
    role TEXT,
    FOREIGN KEY (activity_instance_id) REFERENCES activity_instances(id)
);

-- ตารางเก็บทรัพยากร (Resources)
CREATE TABLE IF NOT EXISTS activity_resources (
    id TEXT PRIMARY KEY,
    activity_instance_id TEXT,
    item_name TEXT,
    quantity REAL,
    unit TEXT,
    action_type TEXT,
    FOREIGN KEY (activity_instance_id) REFERENCES activity_instances(id)
);