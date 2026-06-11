-- Seed data for lab: simulates a database tier with mock sensitive records
CREATE TABLE IF NOT EXISTS customer_records (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    account_number VARCHAR(20)
);

INSERT INTO customer_records (name, email, phone, account_number) VALUES
    ('Alice Johnson', 'alice@example.lab', '555-0101', 'ACC-00001'),
    ('Bob Smith',     'bob@example.lab',   '555-0102', 'ACC-00002'),
    ('Carol Lee',     'carol@example.lab', '555-0103', 'ACC-00003');

CREATE TABLE IF NOT EXISTS internal_secrets (
    id SERIAL PRIMARY KEY,
    key_name VARCHAR(100),
    value TEXT
);

INSERT INTO internal_secrets (key_name, value) VALUES
    ('api_key_staging', 'LAB-KEY-STAGING-DO-NOT-USE'),
    ('db_backup_path',  '/backup/labdb');
