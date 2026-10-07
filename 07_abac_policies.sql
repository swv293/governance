-- ============================================================================
-- HLS Payer ABAC Demo — ABAC Policies (Correct GA Syntax)
-- Catalog: serverless_stable_swv01_catalog | Schema: governance
-- Compute: Serverless or DBR 16.4+ (REQUIRED)
--
-- CORRECT SYNTAX (per docs.databricks.com/…/abac/policies):
--
--   CREATE [OR REPLACE] POLICY name
--   ON SCHEMA schema
--   COLUMN MASK function_name          ← function goes here, not in USING
--   TO principal [EXCEPT principal]
--   FOR TABLES
--   [WHEN table_condition]
--   MATCH COLUMNS col_condition AS alias
--   ON COLUMN alias;                   ← required for column masks
--
--   CREATE [OR REPLACE] POLICY name
--   ON SCHEMA schema
--   ROW FILTER function_name
--   TO principal [EXCEPT principal]
--   FOR TABLES
--   [WHEN table_condition]
--   MATCH COLUMNS col_condition AS alias
--   USING COLUMNS (alias);             ← passes column value to filter fn
--
-- PREREQUISITES (run in order):
--   1. 05_governed_tags.sql   — governed tags (required for ABAC matching)
--   2. 03_create_tags.sql     — column-level tags including row filter keys
--   3. 04_masking_functions.sql — UDFs used by these policies
-- ============================================================================

USE CATALOG serverless_stable_swv01_catalog;
USE SCHEMA governance;


-- ============================================================================
-- PART 1: COLUMN MASK POLICIES — SCHEMA-SCOPED
-- ONE policy auto-covers every matching column across ALL tables in schema.
-- New tables get protection the moment their columns are tagged — no ALTER TABLE.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- POLICY 1: hash_phi_identifiers
-- Matches: masking_rule = 'hash'
-- Covers:  member_id + subscriber_id across 5 tables (8 columns total)
-- UDF:     hash_identifier — deterministic salted SHA-256, JOINable across tables
--
-- Talk track: "8 identifier columns across 5 tables. Classic masking = 8 ALTER
--   TABLE statements. This single ABAC policy covers all of them. Tag a new
--   column masking_rule='hash' and it's instantly protected — zero extra SQL."
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY hash_phi_identifiers
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.hash_identifier
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('masking_rule', 'hash') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 2: mask_phi_dates
-- Matches: hipaa_type = 'date_element'
-- Covers:  date_of_birth + service/admit/discharge dates (7 cols, 4 tables)
-- UDF:     mask_date_of_birth — full date / year-month / year-only
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_phi_dates
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_date_of_birth
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'date_element') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 3: mask_ssn_columns
-- Matches: hipaa_type = 'ssn'
-- Covers:  members.ssn
-- UDF:     mask_ssn — full / last-4 / XXX-XX-XXXX
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_ssn_columns
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_ssn
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'ssn') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 4: mask_name_columns
-- Matches: hipaa_type = 'name'
-- Covers:  members.first_name, last_name, middle_initial
-- UDF:     mask_name — full / first-initial / REDACTED
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_name_columns
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_name
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'name') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 5: mask_phone_columns
-- Matches: hipaa_type = 'telephone'
-- Covers:  members.phone_home, phone_mobile
-- UDF:     mask_phone — full / (***) ***-XXXX / XXX-XXX-XXXX
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_phone_columns
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_phone
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'telephone') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 6: mask_email_columns
-- Matches: hipaa_type = 'email_address'
-- Covers:  members.email
-- UDF:     mask_email — full / first-char+domain / REDACTED
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_email_columns
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_email
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'email_address') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 7: mask_beneficiary_ids
-- Matches: hipaa_type = 'health_plan_beneficiary'
-- Covers:  members.medicare_beneficiary_id, medicaid_id
-- UDF:     mask_beneficiary_id — full / first-3-chars / XXXXXXXXXXX
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_beneficiary_ids
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_beneficiary_id
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'health_plan_beneficiary') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 8: mask_clinical_notes_columns
-- Matches: hipaa_type = 'medical_record'
-- Covers:  prior_authorizations.clinical_notes
-- UDF:     mask_clinical_notes — full / regex-scrubbed / [REDACTED]
--
-- Talk track: "Clinical notes are the highest-risk data type — free text that
--   can contain any of the 18 HIPAA identifiers. For partial access we use
--   regex scrubbing to strip SSN/phone patterns while leaving clinical narrative
--   readable. In production, replace with AWS Comprehend Medical or Azure Health."
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_clinical_notes_columns
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_clinical_notes
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'medical_record') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 9: mask_address_columns
-- Matches: hipaa_type = 'geographic' AND masking_rule = 'full_mask'
-- Covers:  members.address_line1, address_line2, city, county
-- UDF:     mask_address — full / *** REDACTED *** / REDACTED
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_address_columns
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_address
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'geographic')
          AND has_tag_value('masking_rule', 'full_mask') AS col
ON COLUMN col;


-- ----------------------------------------------------------------------------
-- POLICY 10: mask_zip_columns
-- Matches: hipaa_type = 'geographic' AND masking_rule = 'partial_mask'
-- Covers:  members.zip_code — 3-digit truncation (HIPAA Safe Harbor)
-- UDF:     mask_zip_code — full / 3-digit prefix / 00000
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY mask_zip_columns
ON SCHEMA serverless_stable_swv01_catalog.governance
COLUMN MASK serverless_stable_swv01_catalog.governance.mask_zip_code
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'geographic')
          AND has_tag_value('masking_rule', 'partial_mask') AS col
ON COLUMN col;


-- ============================================================================
-- PART 2: ROW FILTER FUNCTIONS
-- Explicit column parameters — Databricks resolves column names at creation
-- time, so parameters must be declared; they cannot reference table columns
-- implicitly inside the function body.
-- ============================================================================

CREATE OR REPLACE FUNCTION governance.filter_bh_sud_auths(auth_type_val STRING)
RETURNS BOOLEAN
COMMENT '42 CFR Part 2 row filter. BH/SUD prior auths visible only to phi_full_access. Bound via ABAC policy bh_sud_auth_protection on auth_type column.'
RETURN
  CASE
    WHEN auth_type_val NOT IN ('Behavioral Health', 'Substance Use Disorder') THEN TRUE
    WHEN is_account_group_member('phi_full_access') THEN TRUE
    ELSE FALSE
  END;


CREATE OR REPLACE FUNCTION governance.filter_eligibility_by_lob(lob_val STRING)
RETURNS BOOLEAN
COMMENT 'LOB row filter. phi_full_access sees all LOBs; others see Commercial + Medicare Advantage. Bound via ABAC policy eligibility_lob_filter on line_of_business column.'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN TRUE
    WHEN lob_val IN ('Commercial', 'Medicare Advantage') THEN TRUE
    ELSE FALSE
  END;


-- ============================================================================
-- PART 3: ROW FILTER POLICIES — SCHEMA-SCOPED
--
-- MATCH COLUMNS finds the column whose value is passed into the filter function.
-- USING COLUMNS (alias) wires the matched column value into the function arg.
-- WHEN scopes the policy to tables matching a table-level tag condition.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- POLICY RF-1: bh_sud_auth_protection
-- Scope: any table in schema with a column tagged hipaa_type='auth_type'
--        (currently only prior_authorizations.auth_type)
-- Rule:  42 CFR Part 2 — BH/SUD records require explicit authorization even
--        beyond general PHI access. phi_partial_access and analytics users
--        see zero BH/SUD rows. phi_full_access is exempt.
--
-- Talk track: "42 CFR Part 2 is STRICTER than HIPAA. A claims analyst with
--   phi_partial_access cannot see a single behavioral health authorization —
--   they don't even know those rows exist. When you add a new BH appeals
--   table and tag its auth_type column, this policy protects it automatically."
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY bh_sud_auth_protection
ON SCHEMA serverless_stable_swv01_catalog.governance
ROW FILTER serverless_stable_swv01_catalog.governance.filter_bh_sud_auths
TO account users
EXCEPT phi_full_access
FOR TABLES
MATCH COLUMNS has_tag_value('hipaa_type', 'auth_type') AS auth_type_col
USING COLUMNS (auth_type_col);


-- ----------------------------------------------------------------------------
-- POLICY RF-2: eligibility_lob_filter
-- Scope: tables tagged business_domain='eligibility' (WHEN condition)
--        with a column tagged business_domain='lob'
-- Rule:  Actuaries and analysts only see Commercial + Medicare Advantage rows.
--        phi_full_access (care managers, UM) sees all lines of business.
--
-- Talk track: "Any future eligibility table we add — Medicaid expansion,
--   CHIP, dual-eligibles — automatically gets this filter the moment it's
--   tagged business_domain='eligibility'. Zero additional policy work."
-- ----------------------------------------------------------------------------
CREATE OR REPLACE POLICY eligibility_lob_filter
ON SCHEMA serverless_stable_swv01_catalog.governance
ROW FILTER serverless_stable_swv01_catalog.governance.filter_eligibility_by_lob
TO account users
EXCEPT phi_full_access
FOR TABLES
WHEN has_tag_value('business_domain', 'eligibility')
MATCH COLUMNS has_tag_value('business_domain', 'lob') AS lob_col
USING COLUMNS (lob_col);


-- ============================================================================
-- PART 4: AUDIT — SHOW EFFECTIVE POLICIES
-- The compliance officer's command: proves exactly which policies apply to
-- which objects for which principals. One SQL statement per audit question.
-- ============================================================================

SHOW EFFECTIVE POLICIES ON TABLE serverless_stable_swv01_catalog.governance.members;

SHOW EFFECTIVE POLICIES ON TABLE serverless_stable_swv01_catalog.governance.prior_authorizations;

SHOW EFFECTIVE POLICIES ON TABLE serverless_stable_swv01_catalog.governance.claims;

SHOW EFFECTIVE POLICIES ON SCHEMA serverless_stable_swv01_catalog.governance;


-- ============================================================================
-- PART 5: AUTO-APPLY DEMO — new table protected instantly
-- Create a table, tag the member_id column, query it — hash policy fires.
-- No ALTER TABLE SET MASK. No policy update. Tags drive everything.
-- ============================================================================

CREATE OR REPLACE TABLE governance.appeals (
  appeal_id  STRING  COMMENT 'Appeal case identifier.',
  member_id  STRING  COMMENT 'Member identifier. PHI.'
    TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier',
          'masking_rule' = 'hash', 'contains_phi' = 'true'),
  claim_id   STRING  COMMENT 'Linked claim reference.',
  reason     STRING  COMMENT 'Appeal reason description.',
  filed_date DATE
);

INSERT INTO governance.appeals VALUES
  ('APL-001', 'M-100001', 'CLM-500001', 'Service not covered', '2025-03-15'),
  ('APL-002', 'M-100005', 'CLM-500002', 'Out-of-network provider', '2025-04-01');

-- Query as yourself — hash_phi_identifiers policy fires automatically on member_id
SELECT member_id, claim_id, reason FROM governance.appeals;
-- Expected (non phi_full_access): member_id shows as HID-xxxxxxxxxxxxxxxx
-- Expected (phi_full_access):     member_id shows as M-100001 (raw)


-- ============================================================================
-- PART 6: CONFLICT DETECTION
-- ABAC allows exactly ONE column mask and ONE row filter per user per object.
-- Different functions resolving to the same user = access denied (not silent).
-- This is the safe behavior — forces conflict-free policy design.
-- ============================================================================

-- To check for conflicts before they cause query failures:
SHOW EFFECTIVE POLICIES ON TABLE serverless_stable_swv01_catalog.governance.members;
-- Two COLUMN MASK entries for the same column = conflict risk.

-- Example conflict (do NOT run during demo — shown as illustration only):
-- ALTER TABLE governance.members ALTER COLUMN member_id
--   SET MASK governance.hash_identifier;  ← would conflict with hash_phi_identifiers policy!


-- ============================================================================
-- CLEANUP (uncomment to tear down after demo)
-- ============================================================================
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.hash_phi_identifiers;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_phi_dates;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_ssn_columns;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_name_columns;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_phone_columns;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_email_columns;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_beneficiary_ids;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_clinical_notes_columns;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_address_columns;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.mask_zip_columns;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.bh_sud_auth_protection;
-- DROP POLICY IF EXISTS serverless_stable_swv01_catalog.governance.eligibility_lob_filter;
-- DROP TABLE IF EXISTS serverless_stable_swv01_catalog.governance.appeals;
