-- ============================================================================
-- HLS Payer Governance Demo — Tag Taxonomy & Tag Assignments
-- Creates sensitivity classification tags and applies them to all columns
-- ============================================================================

-- ============================================================
-- STEP 1: Create Tag Keys (taxonomy)
-- ============================================================

-- Sensitivity level tag — master classification
CREATE TAG IF NOT EXISTS serverless_stable_swv01_catalog.governance.sensitivity_level
COMMENT 'Master data sensitivity classification tier. Values: PHI, PII, Sensitive, Internal, Public. Drives masking policy selection.';

-- HIPAA identifier type — for PHI columns
CREATE TAG IF NOT EXISTS serverless_stable_swv01_catalog.governance.hipaa_identifier
COMMENT 'Specific HIPAA Safe Harbor identifier type per 45 CFR 164.514(b)(2). Values map to the 18 Safe Harbor identifiers.';

-- Data domain tag — business domain
CREATE TAG IF NOT EXISTS serverless_stable_swv01_catalog.governance.data_domain
COMMENT 'Business data domain classification. Values: Member, Claims, Provider, Eligibility, Pharmacy, Utilization_Management, Financial, Clinical, Administrative.';

-- Compliance framework tag
CREATE TAG IF NOT EXISTS serverless_stable_swv01_catalog.governance.compliance_framework
COMMENT 'Applicable regulatory compliance framework. Values: HIPAA, HITECH, PCI_DSS, SOX, State_Privacy.';

-- Data quality tier
CREATE TAG IF NOT EXISTS serverless_stable_swv01_catalog.governance.quality_tier
COMMENT 'Data quality tier for governance reporting. Values: Gold (curated), Silver (cleansed), Bronze (raw).';

-- Masking policy recommendation
CREATE TAG IF NOT EXISTS serverless_stable_swv01_catalog.governance.masking_policy
COMMENT 'Recommended masking treatment. Values: FULL_MASK, PARTIAL_MASK, HASH, REDACT, NONE.';

-- Retention policy
CREATE TAG IF NOT EXISTS serverless_stable_swv01_catalog.governance.retention_policy
COMMENT 'Data retention policy category. Values: 7_YEAR (HIPAA), 10_YEAR (claims), INDEFINITE, 3_YEAR.';

-- ============================================================
-- STEP 2: Apply Tags — MEMBERS table
-- ============================================================

-- Table-level tags
ALTER TABLE serverless_stable_swv01_catalog.governance.members
  SET TAGS ('serverless_stable_swv01_catalog.governance.data_domain' = 'Member',
            'serverless_stable_swv01_catalog.governance.compliance_framework' = 'HIPAA',
            'serverless_stable_swv01_catalog.governance.quality_tier' = 'Gold',
            'serverless_stable_swv01_catalog.governance.retention_policy' = '7_YEAR');

-- PHI / PII columns
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN member_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'UNIQUE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'HASH');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN subscriber_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'UNIQUE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'HASH');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN first_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PII', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'NAME', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN last_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PII', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'NAME', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN middle_initial SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PII', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'NAME', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN date_of_birth SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'DATE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN ssn SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PII', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'SSN', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN drivers_license SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PII', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'VEHICLE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN address_line1 SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'GEOGRAPHIC', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN address_line2 SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'GEOGRAPHIC', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN city SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'GEOGRAPHIC', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN zip_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'GEOGRAPHIC', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN county SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'GEOGRAPHIC', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN phone_home SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'TELEPHONE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN phone_mobile SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'TELEPHONE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN email SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'EMAIL', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN medicare_beneficiary_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'HEALTH_PLAN_BENEFICIARY', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN medicaid_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'HEALTH_PLAN_BENEFICIARY', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');

-- Non-sensitive member columns
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN gender SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN state_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN preferred_language SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN race SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN ethnicity SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN marital_status SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN pcp_npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN group_number SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN plan_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN effective_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN termination_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN is_active SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN created_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN updated_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.members ALTER COLUMN source_system SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');

-- ============================================================
-- STEP 3: Apply Tags — CLAIMS table
-- ============================================================
ALTER TABLE serverless_stable_swv01_catalog.governance.claims
  SET TAGS ('serverless_stable_swv01_catalog.governance.data_domain' = 'Claims',
            'serverless_stable_swv01_catalog.governance.compliance_framework' = 'HIPAA',
            'serverless_stable_swv01_catalog.governance.quality_tier' = 'Gold',
            'serverless_stable_swv01_catalog.governance.retention_policy' = '10_YEAR');

ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN claim_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN member_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'UNIQUE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'HASH');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN subscriber_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'UNIQUE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'HASH');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN claim_type SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN claim_status SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN service_date_from SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'DATE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN service_date_to SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'DATE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN admission_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'DATE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN discharge_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'DATE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN diagnosis_code_primary SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN diagnosis_code_2 SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN diagnosis_code_3 SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN procedure_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN procedure_modifier SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN revenue_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN place_of_service SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN rendering_provider_npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN billing_provider_npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN referring_provider_npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN facility_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN billed_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN allowed_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN paid_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN member_liability SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN copay_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN coinsurance_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN deductible_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN drg_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN authorization_number SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN received_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN adjudicated_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN paid_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN created_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.claims ALTER COLUMN updated_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');

-- ============================================================
-- STEP 4: Apply Tags — PROVIDERS table
-- ============================================================
ALTER TABLE serverless_stable_swv01_catalog.governance.providers
  SET TAGS ('serverless_stable_swv01_catalog.governance.data_domain' = 'Provider',
            'serverless_stable_swv01_catalog.governance.compliance_framework' = 'HIPAA',
            'serverless_stable_swv01_catalog.governance.quality_tier' = 'Gold',
            'serverless_stable_swv01_catalog.governance.retention_policy' = '7_YEAR');

ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN provider_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN tax_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PII', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN first_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN last_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN organization_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN specialty_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN specialty_desc SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN provider_type SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN network_status SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN credential SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN dea_number SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN license_number SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN license_state SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN address_line1 SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN city SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN state_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN zip_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN phone SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN fax SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN accepting_patients SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN effective_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN termination_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN created_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.providers ALTER COLUMN updated_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');

-- ============================================================
-- STEP 5: Apply Tags — ELIGIBILITY table
-- ============================================================
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility
  SET TAGS ('serverless_stable_swv01_catalog.governance.data_domain' = 'Eligibility',
            'serverless_stable_swv01_catalog.governance.compliance_framework' = 'HIPAA',
            'serverless_stable_swv01_catalog.governance.quality_tier' = 'Gold',
            'serverless_stable_swv01_catalog.governance.retention_policy' = '7_YEAR');

ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN eligibility_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN member_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'UNIQUE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'HASH');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN subscriber_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'UNIQUE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'HASH');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN plan_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN plan_description SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN line_of_business SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN coverage_type SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN benefit_package SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN effective_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN termination_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN termination_reason SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN group_number SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN group_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN cobra_flag SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN exchange_flag SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN premium_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN subsidy_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN created_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.eligibility ALTER COLUMN updated_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');

-- ============================================================
-- STEP 6: Apply Tags — PHARMACY_CLAIMS table
-- ============================================================
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims
  SET TAGS ('serverless_stable_swv01_catalog.governance.data_domain' = 'Pharmacy',
            'serverless_stable_swv01_catalog.governance.compliance_framework' = 'HIPAA',
            'serverless_stable_swv01_catalog.governance.quality_tier' = 'Gold',
            'serverless_stable_swv01_catalog.governance.retention_policy' = '10_YEAR');

ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN rx_claim_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN member_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'UNIQUE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'HASH');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN fill_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'DATE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN ndc_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN drug_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN drug_class SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN quantity_dispensed SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN days_supply SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN refill_number SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN prescriber_npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN pharmacy_npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN pharmacy_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN formulary_tier SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN daw_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN ingredient_cost SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN dispensing_fee SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN paid_amount SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN member_copay SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN prior_auth_required SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN specialty_drug_flag SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN created_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims ALTER COLUMN updated_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');

-- ============================================================
-- STEP 7: Apply Tags — PRIOR_AUTHORIZATIONS table
-- ============================================================
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations
  SET TAGS ('serverless_stable_swv01_catalog.governance.data_domain' = 'Utilization_Management',
            'serverless_stable_swv01_catalog.governance.compliance_framework' = 'HIPAA',
            'serverless_stable_swv01_catalog.governance.quality_tier' = 'Gold',
            'serverless_stable_swv01_catalog.governance.retention_policy' = '7_YEAR');

ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN auth_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN member_id SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'UNIQUE_IDENTIFIER', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'HASH');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN auth_type SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN auth_status SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN request_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'DATE', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'PARTIAL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN decision_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN effective_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN expiration_date SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN diagnosis_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN procedure_code SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN requesting_provider_npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN servicing_provider_npi SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN facility_name SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Public', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN units_requested SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN units_approved SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN denial_reason SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Sensitive', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'REDACT');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN clinical_notes SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'PHI', 'serverless_stable_swv01_catalog.governance.hipaa_identifier' = 'MEDICAL_RECORD', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'FULL_MASK');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN peer_reviewer SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN urgency SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN created_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations ALTER COLUMN updated_at SET TAGS ('serverless_stable_swv01_catalog.governance.sensitivity_level' = 'Internal', 'serverless_stable_swv01_catalog.governance.masking_policy' = 'NONE');
