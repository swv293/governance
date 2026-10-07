-- ============================================================================
-- HLS Payer ABAC Demo — Governed Tags
-- ABAC policies REQUIRE governed tags (not free-form tags).
-- Run as: Metastore Admin or Account Admin
-- Platform requirement: Unity Catalog, DBR 15.4+ or Serverless
--
-- WHY GOVERNED TAGS:
--   Free-form tags have no value enforcement — a typo ('Critical' vs 'critical')
--   silently breaks ABAC policy matching. Governed tags enforce an allowed-value
--   list at write time, making the tag taxonomy a security boundary.
--   Tag matching in ABAC is CASE-SENSITIVE: 'full_mask' != 'Full_Mask'
--
-- CREATION OPTIONS:
--   Option A — SQL DDL (DBR 15.4+, shown below)
--   Option B — REST API (see appendix)
--   Option C — Terraform (databricks_tag_policy resource)
-- ============================================================================

USE CATALOG serverless_stable_swv01_catalog;

-- --------------------------------------------------------------------------
-- 1. sensitivity_level
--    Drives masking tier selection for ABAC column mask policies.
--    'critical' = 18 HIPAA Safe Harbor identifiers + SSN + government IDs.
--    'high'     = clinical codes, financial amounts, drug data.
-- --------------------------------------------------------------------------
CREATE TAG IF NOT EXISTS sensitivity_level
  ALLOWED VALUES 'critical', 'high', 'medium', 'low'
  COMMENT 'Data sensitivity tier. Drives masking policy selection. critical=HIPAA identifiers. high=clinical/financial. medium=derived/aggregate. low=non-sensitive.';

-- --------------------------------------------------------------------------
-- 2. masking_rule
--    The ABAC column mask policies match on this tag value to auto-select UDF.
--    ONE governed tag → drives WHICH masking function fires across ALL tables.
-- --------------------------------------------------------------------------
CREATE TAG IF NOT EXISTS masking_rule
  ALLOWED VALUES 'full_mask', 'partial_mask', 'hash', 'redact', 'none'
  COMMENT 'Masking function selector matched by ABAC column mask policies. ABAC key: ONE policy per value auto-applies across entire schema.';

-- --------------------------------------------------------------------------
-- 3. hipaa_type
--    18 HIPAA Safe Harbor identifier categories per 45 CFR 164.514(b)(2)(i).
--    Enables per-type ABAC policies (mask_ssn vs mask_name vs mask_phone).
-- --------------------------------------------------------------------------
CREATE TAG IF NOT EXISTS hipaa_type
  ALLOWED VALUES
    'name',                   -- 164.514(b)(2)(i)(A) — first, last, middle names
    'geographic',             -- 164.514(b)(2)(i)(B) — address, city, county, ZIP
    'date_element',           -- 164.514(b)(2)(i)(C) — DOB, service dates, admit/discharge
    'telephone',              -- 164.514(b)(2)(i)(F) — phone numbers
    'fax',                    -- 164.514(b)(2)(i)(E) — fax numbers
    'email_address',          -- 164.514(b)(2)(i)(G) — email
    'ssn',                    -- 164.514(b)(2)(i)(O) — Social Security Numbers
    'mrn',                    -- 164.514(b)(2)(i)(D) — medical record numbers
    'health_plan_beneficiary',-- 164.514(b)(2)(i)(M) — MBI, Medicaid IDs
    'account_number',         -- 164.514(b)(2)(i)(K) — account numbers
    'unique_identifier',      -- 164.514(b)(2)(i)(R) — member IDs, subscriber IDs
    'tax_id',                 -- EIN / sole-practitioner SSN
    'government_id',          -- driver license, state ID
    'dea_number',             -- DEA registration (controlled substances)
    'medical_record',         -- free-text clinical notes
    'auth_type'               -- authorization type column — row filter binding for 42 CFR Part 2
  COMMENT 'HIPAA Safe Harbor identifier type. Used for per-type ABAC column mask policy binding. Maps to 45 CFR 164.514(b)(2)(i).';

-- --------------------------------------------------------------------------
-- 4. compliance — regulatory framework tag (schema-level, inherited by tables)
-- --------------------------------------------------------------------------
CREATE TAG IF NOT EXISTS compliance
  ALLOWED VALUES 'hipaa', 'hitech', 'pci_dss', 'sox', 'state_privacy', 'none'
  COMMENT 'Applicable regulatory compliance framework. Set at schema level for inheritance down to tables.';

-- --------------------------------------------------------------------------
-- 5. business_domain — owning LOB for stewardship and row-filter scoping
-- --------------------------------------------------------------------------
CREATE TAG IF NOT EXISTS business_domain
  ALLOWED VALUES 'member', 'claims', 'provider', 'eligibility', 'pharmacy',
    'utilization_management', 'finance', 'operations', 'lob'
    -- 'lob' marks the line_of_business column for eligibility row filter binding
  COMMENT 'Business domain for data stewardship assignment and row-filter policy scoping.';

-- --------------------------------------------------------------------------
-- 6. retention — data retention policy
-- --------------------------------------------------------------------------
CREATE TAG IF NOT EXISTS retention
  ALLOWED VALUES '3_year', '7_year', '10_year', 'indefinite'
  COMMENT '7yr=HIPAA minimum. 10yr=CMS Medicare Advantage. Drives automated purge policies.';

-- --------------------------------------------------------------------------
-- 7. contains_phi / contains_pii — boolean PHI/PII flags
-- --------------------------------------------------------------------------
CREATE TAG IF NOT EXISTS contains_phi
  ALLOWED VALUES 'true', 'false'
  COMMENT 'Column or table contains HIPAA Protected Health Information.';

CREATE TAG IF NOT EXISTS contains_pii
  ALLOWED VALUES 'true', 'false'
  COMMENT 'Column contains Personally Identifiable Information.';

-- ============================================================================
-- VERIFICATION
-- ============================================================================
-- SHOW TAGS IN CATALOG serverless_stable_swv01_catalog;

-- ============================================================================
-- APPENDIX: REST API Alternative (for older runtimes or programmatic creation)
-- ============================================================================
-- Run from CLI: databricks api post /api/2.1/unity-catalog/tag-policies \
--   --profile=fe-vm-fevm-serverless-stable-swv01 \
--   --json='{
--     "name": "sensitivity_level",
--     "allowed_values": ["critical","high","medium","low"],
--     "comment": "Data sensitivity tier driving masking policy selection"
--   }'
--
-- Repeat for each tag: masking_rule, hipaa_type, compliance, business_domain,
--   retention, contains_phi, contains_pii
-- ============================================================================
