-- ============================================================================
-- HLS Payer Governance Demo — Optimized Tag Taxonomy & Assignments
-- Catalog: serverless_stable_swv01_catalog
-- Schema: governance
--
-- DESIGN PRINCIPLES (per Databricks internal best practices):
--   1. Only tag columns that require a governance action (masking, ABAC, audit)
--   2. Leverage hierarchy — schema-level tags for cross-cutting concerns
--   3. Lowercase snake_case values — case-sensitive matching in ABAC
--   4. Boolean pattern for PHI/PII — cleaner ABAC predicates
--   5. Absence of a tag = no special handling required
--
-- TAG TAXONOMY:
--   Schema level:  compliance (hipaa)
--   Table level:   business_domain, retention
--   Column level:  sensitivity_level, hipaa_type, masking_rule,
--                  contains_phi, contains_pii
--
-- GOVERNED TAG CREATION:
--   Governed tags are created via REST API or Terraform, NOT SQL.
--   API: POST /api/2.1/unity-catalog/tag-policies
--   Terraform: databricks_tag_policy resource
--   See appendix at end of file for examples.
-- ============================================================================


-- ============================================================
-- STEP 1: Schema-Level Tags (inherited for ABAC evaluation)
-- ============================================================
-- All tables in this schema are HIPAA-governed. Setting at schema level
-- eliminates redundant per-table tags and ensures new tables inherit.

ALTER SCHEMA serverless_stable_swv01_catalog.governance
  SET TAGS ('compliance' = 'hipaa');


-- ============================================================
-- STEP 2: Table-Level Tags (business_domain + retention)
-- ============================================================
-- business_domain: identifies owning LOB for data stewardship
-- retention: differs per domain (7yr HIPAA default, 10yr for claims/pharmacy per CMS)

ALTER TABLE serverless_stable_swv01_catalog.governance.members
  SET TAGS ('business_domain' = 'member', 'retention' = '7_year');

ALTER TABLE serverless_stable_swv01_catalog.governance.claims
  SET TAGS ('business_domain' = 'claims', 'retention' = '10_year');

ALTER TABLE serverless_stable_swv01_catalog.governance.providers
  SET TAGS ('business_domain' = 'provider', 'retention' = '7_year');

ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility
  SET TAGS ('business_domain' = 'eligibility', 'retention' = '7_year');

ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims
  SET TAGS ('business_domain' = 'pharmacy', 'retention' = '10_year');

ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations
  SET TAGS ('business_domain' = 'utilization_management', 'retention' = '7_year');


-- ============================================================
-- STEP 3: Column-Level Tags — MEMBERS
-- Only columns requiring masking or ABAC. Non-sensitive columns
-- (gender, plan_code, created_at, etc.) are intentionally untagged.
-- ============================================================

-- PHI identifiers — hashed for de-identified analytics
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN member_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier', 'masking_rule' = 'hash', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN subscriber_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier', 'masking_rule' = 'hash', 'contains_phi' = 'true');

-- PII names — full mask for non-privileged users
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN first_name SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'name', 'masking_rule' = 'full_mask', 'contains_pii' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN last_name SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'name', 'masking_rule' = 'full_mask', 'contains_pii' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN middle_initial SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'name', 'masking_rule' = 'full_mask', 'contains_pii' = 'true');

-- SSN and government ID — highest sensitivity
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN ssn SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'ssn', 'masking_rule' = 'full_mask', 'contains_pii' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN drivers_license SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'government_id', 'masking_rule' = 'full_mask', 'contains_pii' = 'true');

-- Date of birth — partial mask (year-month for partial, year for de-identified)
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN date_of_birth SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'date_element', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');

-- Geographic PHI — addresses, city, county, ZIP
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN address_line1 SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'geographic', 'masking_rule' = 'full_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN address_line2 SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'geographic', 'masking_rule' = 'full_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN city SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'geographic', 'masking_rule' = 'redact', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN county SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'geographic', 'masking_rule' = 'redact', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN zip_code SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'geographic', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');

-- Contact PHI — phone, email
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN phone_home SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'telephone', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN phone_mobile SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'telephone', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN email SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'email_address', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');

-- Health plan beneficiary IDs
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN medicare_beneficiary_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'health_plan_beneficiary', 'masking_rule' = 'full_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN medicaid_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'health_plan_beneficiary', 'masking_rule' = 'full_mask', 'contains_phi' = 'true');

-- Sensitive demographics — not HIPAA identifiers, but require redaction for equity analytics
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN race SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN ethnicity SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');


-- ============================================================
-- STEP 4: Column-Level Tags — CLAIMS
-- ============================================================

-- PHI identifiers
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN member_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier', 'masking_rule' = 'hash', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN subscriber_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier', 'masking_rule' = 'hash', 'contains_phi' = 'true');

-- PHI service dates
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN service_date_from SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'date_element', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN service_date_to SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'date_element', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN admission_date SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'date_element', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN discharge_date SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'date_element', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');

-- Clinically sensitive — diagnosis and procedure codes
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN diagnosis_code_primary SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN diagnosis_code_2 SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN diagnosis_code_3 SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN procedure_code SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN drg_code SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');

-- Financially sensitive — claim amounts
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN billed_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN allowed_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN paid_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN member_liability SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN copay_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN coinsurance_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN deductible_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');


-- ============================================================
-- STEP 5: Column-Level Tags — PROVIDERS (only 2 sensitive columns)
-- ============================================================

ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN tax_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'tax_id', 'masking_rule' = 'full_mask', 'contains_pii' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN dea_number SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'full_mask');


-- ============================================================
-- STEP 6: Column-Level Tags — ELIGIBILITY (only 4 sensitive columns)
-- ============================================================

ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN member_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier', 'masking_rule' = 'hash', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN subscriber_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier', 'masking_rule' = 'hash', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN premium_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN subsidy_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');


-- ============================================================
-- STEP 7: Column-Level Tags — PHARMACY CLAIMS
-- ============================================================

ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN member_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier', 'masking_rule' = 'hash', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN fill_date SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'date_element', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');

-- Clinically sensitive drug data
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN ndc_code SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN drug_name SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN drug_class SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');

-- Financially sensitive Rx costs
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN ingredient_cost SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN dispensing_fee SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN paid_amount SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN member_copay SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');


-- ============================================================
-- STEP 8: Column-Level Tags — PRIOR AUTHORIZATIONS
-- ============================================================

ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN member_id SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier', 'masking_rule' = 'hash', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN request_date SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'date_element', 'masking_rule' = 'partial_mask', 'contains_phi' = 'true');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN clinical_notes SET TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'medical_record', 'masking_rule' = 'full_mask', 'contains_phi' = 'true');

-- Clinically sensitive
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN diagnosis_code SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN procedure_code SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN denial_reason SET TAGS ('sensitivity_level' = 'high', 'masking_rule' = 'redact');


-- ============================================================
-- APPENDIX A: Governed Tag Creation (REST API / Terraform)
-- ============================================================
-- Governed tags are NOT created via SQL. Use the REST API or Terraform:
--
-- REST API:
--   POST /api/2.1/unity-catalog/tag-policies
--   {
--     "name": "sensitivity_level",
--     "allowed_values": ["critical", "high", "medium", "low"],
--     "comment": "Data sensitivity tier driving masking policy selection"
--   }
--
-- Terraform:
--   resource "databricks_tag_policy" "sensitivity_level" {
--     name           = "sensitivity_level"
--     allowed_values = ["critical", "high", "medium", "low"]
--     comment        = "Data sensitivity tier driving masking policy selection"
--   }
--
-- Recommended governed tags for this demo:
--   sensitivity_level: [critical, high, medium, low]
--   compliance:        [hipaa, hitech, pci_dss, sox, state_privacy]
--   retention:         [7_year, 10_year, 3_year, indefinite]
--   business_domain:   [member, claims, provider, eligibility, pharmacy, utilization_management]
--   masking_rule:      [full_mask, partial_mask, hash, redact, none]


-- ============================================================
-- APPENDIX B: Tag Audit Queries
-- ============================================================

-- B1: Tag count per table (limit: 50 tags per object)
-- SELECT table_name, count(DISTINCT tag_name) as tag_count
-- FROM serverless_stable_swv01_catalog.information_schema.table_tags
-- WHERE schema_name = 'governance'
-- GROUP BY table_name
-- HAVING count(DISTINCT tag_name) > 40
-- ORDER BY tag_count DESC;

-- B2: Column tags per table (limit: 1,000 across all columns)
-- SELECT table_name, count(*) as total_column_tags
-- FROM serverless_stable_swv01_catalog.information_schema.column_tags
-- WHERE schema_name = 'governance'
-- GROUP BY table_name
-- HAVING count(*) > 800
-- ORDER BY total_column_tags DESC;

-- B3: Tag value cardinality (>100 distinct values = review for deprecation)
-- SELECT tag_name, count(DISTINCT tag_value) as distinct_values
-- FROM serverless_stable_swv01_catalog.information_schema.column_tags
-- WHERE schema_name = 'governance'
-- GROUP BY tag_name
-- HAVING count(DISTINCT tag_value) > 50
-- ORDER BY distinct_values DESC;

-- B4: Case/character violations (should be empty if snake_case enforced)
-- SELECT DISTINCT tag_name
-- FROM serverless_stable_swv01_catalog.information_schema.column_tags
-- WHERE schema_name = 'governance'
--   AND NOT (tag_name RLIKE '^[a-z0-9_]+$');

-- B5: PHI inventory — all columns tagged as containing PHI
-- SELECT table_name, column_name, tag_value as hipaa_identifier_type
-- FROM serverless_stable_swv01_catalog.information_schema.column_tags
-- WHERE schema_name = 'governance'
--   AND tag_name = 'hipaa_type'
-- ORDER BY table_name, column_name;

-- B6: Columns requiring masking (non-none masking_rule)
-- SELECT table_name, column_name,
--   MAX(CASE WHEN tag_name = 'masking_rule' THEN tag_value END) as masking_rule,
--   MAX(CASE WHEN tag_name = 'sensitivity_level' THEN tag_value END) as sensitivity
-- FROM serverless_stable_swv01_catalog.information_schema.column_tags
-- WHERE schema_name = 'governance'
--   AND tag_name IN ('masking_rule', 'sensitivity_level')
-- GROUP BY table_name, column_name
-- ORDER BY sensitivity DESC, table_name;
