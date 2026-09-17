-- คำสั่งลบตารางเก่าทิ้ง (เพื่อให้สร้างใหม่แบบสะอาดๆ)
DROP TABLE IF EXISTS activity_instances;
DROP TABLE IF EXISTS evidence_assets;
DROP TABLE IF EXISTS org_units;
DROP TABLE IF EXISTS organizations;
DROP TABLE IF EXISTS projects;
DROP TABLE IF EXISTS financial_transactions;
DROP TABLE IF EXISTS reporting_periods;
-- ลบตารางอื่นๆ ที่อาจค้างอยู่
DROP TABLE IF EXISTS evidence_chain;
DROP TABLE IF EXISTS bridge_activity_financial_transactions;