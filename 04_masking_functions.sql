-- ============================================================================
-- HLS Payer Governance Demo — Unity Catalog Masking Functions
-- 14 reusable masking functions implementing a three-tier access model
-- Catalog: serverless_stable_swv01_catalog
-- Schema: governance
--
-- ACCESS TIERS:
--   phi_full_access     — Unmasked. Care management, clinical quality, fraud.
--   phi_partial_access  — Partially masked. Provider ops, member services, claims ops.
--   All others          — Fully masked/redacted/hashed. Actuarial, pop health, sandbox.
-- ============================================================================


-- ============================================================================
-- 1. MASK_SSN
-- Purpose: Masks Social Security Numbers
-- Tags:    sensitivity_level=critical, hipaa_type=SSN, masking_rule=FULL_MASK
-- Columns: members.ssn, members.drivers_license
-- HIPAA:   45 CFR 164.514(b)(2)(i)(O) — Social Security numbers
--
-- Logic:
--   Full access   → 423-55-6789 (original)
--   Partial access → ***-**-6789 (last 4 for phone verification)
--   No access     → XXX-XX-XXXX (fully masked)
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_ssn(ssn_value STRING)
RETURNS STRING
COMMENT 'Masks Social Security Numbers using a three-tier access model. phi_full_access: Returns original SSN (e.g., 423-55-6789) for fraud investigation and care management. phi_partial_access: Returns last 4 digits (e.g., ***-**-6789) for member services phone verification. All others: Returns XXX-XX-XXXX. Tags: sensitivity_level=critical, hipaa_type=SSN, masking_rule=FULL_MASK. Columns: members.ssn, members.drivers_license. HIPAA 45 CFR 164.514(b)(2)(i)(O).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN ssn_value
    WHEN is_account_group_member('phi_partial_access') THEN CONCAT('***-**-', RIGHT(ssn_value, 4))
    ELSE 'XXX-XX-XXXX'
  END;


-- ============================================================================
-- 2. MASK_NAME
-- Purpose: Masks member names (first, last, middle initial)
-- Tags:    sensitivity_level=critical, hipaa_type=NAME, masking_rule=FULL_MASK
-- Columns: members.first_name, members.last_name, members.middle_initial
-- HIPAA:   45 CFR 164.514(b)(2)(i)(A) — Names
--
-- Logic:
--   Full access   → Maria (original)
--   Partial access → M**** (first initial for record matching)
--   No access     → REDACTED
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_name(name_value STRING)
RETURNS STRING
COMMENT 'Masks member names (first, last, middle) using three-tier access. phi_full_access: Returns full name (e.g., Maria) for care coordinators and clinical quality. phi_partial_access: Returns first initial + asterisks (e.g., M****) for claims ops record matching. All others: Returns REDACTED. Tags: sensitivity_level=critical, hipaa_type=NAME, masking_rule=FULL_MASK. Columns: members.first_name, last_name, middle_initial. HIPAA 45 CFR 164.514(b)(2)(i)(A).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN name_value
    WHEN is_account_group_member('phi_partial_access') THEN CONCAT(LEFT(name_value, 1), '****')
    ELSE 'REDACTED'
  END;


-- ============================================================================
-- 3. MASK_EMAIL
-- Purpose: Masks email addresses preserving domain for partial access
-- Tags:    sensitivity_level=critical, hipaa_type=EMAIL, masking_rule=PARTIAL_MASK
-- Columns: members.email
-- HIPAA:   45 CFR 164.514(b)(2)(i)(G) — Electronic mail addresses
--
-- Logic:
--   Full access   → maria.rodriguez@email.com (original)
--   Partial access → m***@email.com (first char + domain)
--   No access     → REDACTED
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_email(email_value STRING)
RETURNS STRING
COMMENT 'Masks email addresses preserving domain for partial access. phi_full_access: Returns full email (e.g., maria.rodriguez@email.com) for member outreach and correspondence. phi_partial_access: Returns first char + domain (e.g., m***@email.com) for member services confirmation. All others: Returns REDACTED. Tags: sensitivity_level=critical, hipaa_type=EMAIL, masking_rule=PARTIAL_MASK. Columns: members.email. HIPAA 45 CFR 164.514(b)(2)(i)(G).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN email_value
    WHEN is_account_group_member('phi_partial_access') THEN
      CONCAT(LEFT(SPLIT(email_value, '@')[0], 1), '***@', SPLIT(email_value, '@')[1])
    ELSE 'REDACTED'
  END;


-- ============================================================================
-- 4. MASK_PHONE
-- Purpose: Masks phone numbers preserving last 4 digits
-- Tags:    sensitivity_level=critical, hipaa_type=TELEPHONE, masking_rule=PARTIAL_MASK
-- Columns: members.phone_home, members.phone_mobile
-- HIPAA:   45 CFR 164.514(b)(2)(i)(F) — Telephone numbers
--
-- Logic:
--   Full access   → 502-555-0101 (original)
--   Partial access → (***) ***-0101 (last 4 for inbound call verification)
--   No access     → XXX-XXX-XXXX
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_phone(phone_value STRING)
RETURNS STRING
COMMENT 'Masks phone numbers preserving last 4 digits for verification. phi_full_access: Returns full phone (e.g., 502-555-0101) for member outreach and scheduling. phi_partial_access: Returns last 4 (e.g., (***) ***-0101) for member services inbound call verification. All others: Returns XXX-XXX-XXXX. Tags: sensitivity_level=critical, hipaa_type=TELEPHONE, masking_rule=PARTIAL_MASK. Columns: members.phone_home, phone_mobile. HIPAA 45 CFR 164.514(b)(2)(i)(F).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN phone_value
    WHEN is_account_group_member('phi_partial_access') THEN CONCAT('(***) ***-', RIGHT(REGEXP_REPLACE(phone_value, '[^0-9]', ''), 4))
    ELSE 'XXX-XXX-XXXX'
  END;


-- ============================================================================
-- 5. MASK_DATE_OF_BIRTH
-- Purpose: Generalizes dates of birth to progressively less granular levels
-- Tags:    sensitivity_level=critical, hipaa_type=DATE, masking_rule=PARTIAL_MASK
-- Columns: members.date_of_birth, claims.service_date_from/to,
--          claims.admission_date/discharge_date, pharmacy_claims.fill_date,
--          prior_authorizations.request_date
-- HIPAA:   45 CFR 164.514(b)(2)(i)(C) — Dates related to an individual
--
-- Logic:
--   Full access   → 1958-03-14 (exact date for HEDIS, eligibility verification)
--   Partial access → 1958-03 (year-month for age-band analytics, risk adjustment)
--   No access     → 1958-XX-XX (year only for cohort analysis, actuarial)
--
-- NOTE: HIPAA Safe Harbor requires aggregating ages 90+ to a single category.
--       Add a CASE WHEN for production use.
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_date_of_birth(dob DATE)
RETURNS STRING
COMMENT 'Generalizes dates of birth to progressively less granular levels. phi_full_access: Returns full date (e.g., 1958-03-14) for HEDIS measures, eligibility verification, care gap identification. phi_partial_access: Returns year-month (e.g., 1958-03) for age-band analytics and risk adjustment. All others: Returns year only (e.g., 1958-XX-XX) for cohort analysis and actuarial modeling. Note: HIPAA Safe Harbor requires aggregating ages 90+ -- add a CASE WHEN for production. Tags: sensitivity_level=critical, hipaa_type=DATE, masking_rule=PARTIAL_MASK. Columns: members.date_of_birth, claims.service_date_from/to, admission/discharge_date, pharmacy_claims.fill_date. HIPAA 45 CFR 164.514(b)(2)(i)(C).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN CAST(dob AS STRING)
    WHEN is_account_group_member('phi_partial_access') THEN DATE_FORMAT(dob, 'yyyy-MM')
    ELSE CONCAT(CAST(YEAR(dob) AS STRING), '-XX-XX')
  END;


-- ============================================================================
-- 6. MASK_ZIP_CODE
-- Purpose: Masks ZIP codes using HIPAA Safe Harbor geographic rules
-- Tags:    sensitivity_level=critical, hipaa_type=GEOGRAPHIC, masking_rule=PARTIAL_MASK
-- Columns: members.zip_code
-- HIPAA:   45 CFR 164.514(b)(2)(i)(B) — Geographic subdivisions < state
--
-- Logic:
--   Full access   → 40202 (full 5-digit for provider network, care coordination)
--   Partial access → 402** (3-digit prefix for regional/metro analytics)
--   No access     → XXXXX (fully masked)
--
-- NOTE: HIPAA Safe Harbor permits 3-digit ZIPs only if population >= 20,000.
--       Validate against CMS population tables for production use.
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_zip_code(zip_value STRING)
RETURNS STRING
COMMENT 'Masks ZIP codes using HIPAA Safe Harbor geographic rules. phi_full_access: Returns full 5-digit ZIP (e.g., 40202) for provider network assignment and care coordination. phi_partial_access: Returns 3-digit prefix (e.g., 402**) for regional analytics and network adequacy. Note: HIPAA permits 3-digit ZIPs only if population >= 20,000 -- validate against CMS tables for production. All others: Returns XXXXX. Tags: sensitivity_level=critical, hipaa_type=GEOGRAPHIC, masking_rule=PARTIAL_MASK. Columns: members.zip_code. HIPAA 45 CFR 164.514(b)(2)(i)(B).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN zip_value
    WHEN is_account_group_member('phi_partial_access') THEN CONCAT(LEFT(zip_value, 3), '**')
    ELSE 'XXXXX'
  END;


-- ============================================================================
-- 7. MASK_ADDRESS
-- Purpose: Masks street addresses, cities, and counties
-- Tags:    sensitivity_level=critical, hipaa_type=GEOGRAPHIC,
--          masking_rule=FULL_MASK or REDACT
-- Columns: members.address_line1, address_line2, city, county
-- HIPAA:   45 CFR 164.514(b)(2)(i)(B) — Street address, city, county
--
-- Logic:
--   Full access   → 1200 Wellness Blvd (for member correspondence, home health)
--   Partial access → *** REDACTED *** (confirms address exists on file)
--   No access     → REDACTED
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_address(address_value STRING)
RETURNS STRING
COMMENT 'Masks street addresses, cities, and counties -- geographic PHI below state level. phi_full_access: Returns full address (e.g., 1200 Wellness Blvd) for member correspondence, home health, and transportation benefits. phi_partial_access: Returns *** REDACTED *** placeholder for staff who need to know an address exists on file. All others: Returns REDACTED. Tags: sensitivity_level=critical, hipaa_type=GEOGRAPHIC, masking_rule=FULL_MASK/REDACT. Columns: members.address_line1, address_line2, city, county. HIPAA 45 CFR 164.514(b)(2)(i)(B).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN address_value
    WHEN is_account_group_member('phi_partial_access') THEN '*** REDACTED ***'
    ELSE 'REDACTED'
  END;


-- ============================================================================
-- 8. HASH_IDENTIFIER
-- Purpose: Deterministic salted SHA-256 hash for member/subscriber IDs
-- Tags:    sensitivity_level=critical, hipaa_type=UNIQUE_IDENTIFIER,
--          masking_rule=HASH
-- Columns: members.member_id, members.subscriber_id,
--          claims.member_id, claims.subscriber_id,
--          eligibility.member_id, eligibility.subscriber_id,
--          pharmacy_claims.member_id,
--          prior_authorizations.member_id
-- HIPAA:   45 CFR 164.514(b)(2)(i)(R) — Unique identifying numbers
--
-- Logic:
--   Full access → M-100001 (original ID for operational queries)
--   All others  → HID-a3f8c91b2e7d04f2 (deterministic hash)
--
-- The hash is deterministic (same input → same output), so de-identified
-- datasets can JOIN across all tables using the hashed ID — preserving
-- referential integrity without exposing real identifiers.
--
-- SALT: 'humana_salt_2025' prevents rainbow table attacks.
--       In production, rotate the salt annually and store in a secret scope.
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.hash_identifier(id_value STRING)
RETURNS STRING
COMMENT 'Deterministic salted SHA-256 hash for member/subscriber IDs preserving cross-table joinability. phi_full_access: Returns original ID (e.g., M-100001) for operational queries and claims adjudication. All others: Returns HID-prefixed truncated hash (e.g., HID-a3f8c91b2e7d04f2). The hash is deterministic so de-identified datasets can still JOIN across members, claims, eligibility, pharmacy, and prior auth tables. Salt (humana_salt_2025) prevents rainbow table attacks -- rotate annually in production. Tags: sensitivity_level=critical, hipaa_type=UNIQUE_IDENTIFIER, masking_rule=HASH. Columns: members.member_id/subscriber_id, claims.member_id/subscriber_id, eligibility.member_id/subscriber_id, pharmacy_claims.member_id, prior_authorizations.member_id. HIPAA 45 CFR 164.514(b)(2)(i)(R).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN id_value
    ELSE CONCAT('HID-', LEFT(SHA2(CONCAT(id_value, 'humana_salt_2025'), 256), 16))
  END;


-- ============================================================================
-- 9. MASK_FINANCIAL_AMOUNT
-- Purpose: Masks financial amounts by bucketing into ranges
-- Tags:    sensitivity_level=high, masking_rule=REDACT (financial columns)
-- Columns: claims.billed_amount, allowed_amount, paid_amount,
--          member_liability, copay_amount, coinsurance_amount, deductible_amount,
--          pharmacy_claims.ingredient_cost, dispensing_fee, paid_amount, member_copay,
--          eligibility.premium_amount, subsidy_amount
--
-- Logic:
--   Full access   → 45000.00 (exact for adjudication, payment, fraud)
--   Partial access → $10K-$50K (bucketed for cost trending, utilization mgmt)
--   No access     → REDACTED
--
-- WHY BUCKETING: Prevents reverse-engineering exact negotiated rates through
--   statistical analysis of rounded values. Ranges align with common payer
--   reporting tiers used in CMS and actuarial reports.
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_financial_amount(amount DECIMAL(12,2))
RETURNS STRING
COMMENT 'Masks financial amounts by bucketing into ranges for cost trend analytics. phi_full_access: Returns exact amount (e.g., 45000.00) for claims adjudication, provider payment, fraud investigation. phi_partial_access: Returns bucketed range ($0-$100, $100-$500, $500-$1K, $1K-$5K, $5K-$10K, $10K-$50K, $50K+) for utilization management and cost trending -- prevents reverse-engineering exact negotiated rates. All others: Returns REDACTED. Tags: sensitivity_level=high, masking_rule=REDACT (financial columns). Columns: claims.billed/allowed/paid_amount, member_liability, copay/coinsurance/deductible_amount; pharmacy_claims.ingredient_cost, dispensing_fee, paid_amount, member_copay; eligibility.premium_amount, subsidy_amount.'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN CAST(amount AS STRING)
    WHEN is_account_group_member('phi_partial_access') THEN
      CASE
        WHEN amount IS NULL THEN NULL
        WHEN amount < 100 THEN '$0-$100'
        WHEN amount < 500 THEN '$100-$500'
        WHEN amount < 1000 THEN '$500-$1K'
        WHEN amount < 5000 THEN '$1K-$5K'
        WHEN amount < 10000 THEN '$5K-$10K'
        WHEN amount < 50000 THEN '$10K-$50K'
        ELSE '$50K+'
      END
    ELSE 'REDACTED'
  END;


-- ============================================================================
-- 10. MASK_DIAGNOSIS_CODE
-- Purpose: Masks ICD-10 diagnosis codes by truncating to category level
-- Tags:    sensitivity_level=high, masking_rule=REDACT (clinical columns)
-- Columns: claims.diagnosis_code_primary, diagnosis_code_2, diagnosis_code_3,
--          claims.drg_code, prior_authorizations.diagnosis_code
--
-- Logic:
--   Full access   → E11.65 (full specificity for HEDIS, risk adjustment)
--   Partial access → E11.x (category only for population health analytics)
--   No access     → REDACTED
--
-- The partial mask truncates to the ICD-10 category (before the decimal),
-- replacing the specificity with .x. This preserves disease grouping
-- (e.g., "Type 2 diabetes") without revealing exact severity or
-- manifestation (e.g., "with hyperglycemia").
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_diagnosis_code(dx_code STRING)
RETURNS STRING
COMMENT 'Masks ICD-10 diagnosis codes by truncating to category level, hiding clinical specificity while preserving disease grouping. phi_full_access: Returns full code (e.g., E11.65 = Type 2 diabetes with hyperglycemia) for HEDIS/STARS, care gap identification, risk adjustment. phi_partial_access: Returns category only (e.g., E11.x = Type 2 diabetes, unspecified) for population health prevalence, utilization trending, network adequacy by specialty. All others: Returns REDACTED. Tags: sensitivity_level=high, masking_rule=REDACT (clinical columns). Columns: claims.diagnosis_code_primary/2/3, drg_code; prior_authorizations.diagnosis_code. Note: DRG codes should map to MDC for partial tier.'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN dx_code
    WHEN is_account_group_member('phi_partial_access') THEN
      CASE
        WHEN dx_code IS NULL THEN NULL
        ELSE CONCAT(LEFT(dx_code, POSITION('.' IN dx_code) - 1), '.x')
      END
    ELSE 'REDACTED'
  END;


-- ============================================================================
-- 11. MASK_DRUG_INFO
-- Purpose: Masks drug names, NDC codes, and drug classes
-- Tags:    sensitivity_level=high, masking_rule=REDACT (drug columns)
-- Columns: pharmacy_claims.ndc_code, drug_name, drug_class,
--          providers.dea_number
--
-- Logic:
--   Full access   → Pembrolizumab 100mg (original for PBM, PA review)
--   Partial access → [Therapeutic Class] (hides specific drug)
--   No access     → REDACTED
--
-- WHY THIS MATTERS: Medication data is one of the strongest
--   condition-inference vectors. A single drug name can reveal:
--   - Pembrolizumab → cancer
--   - Donepezil → Alzheimer's disease
--   - Buprenorphine → opioid use disorder (42 CFR Part 2 protected)
--   - Duloxetine → depression (state mental health privacy laws)
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_drug_info(drug_value STRING)
RETURNS STRING
COMMENT 'Masks drug names, NDC codes, and drug classes to prevent condition inference from medication data. phi_full_access: Returns full drug info (e.g., Pembrolizumab 100mg) for pharmacy benefit management, PA review, formulary management. phi_partial_access: Returns [Therapeutic Class] label -- specific drug hidden because medication data is a strong condition-inference vector (e.g., Pembrolizumab implies cancer, Donepezil implies Alzheimers). Additional privacy protections apply under 42 CFR Part 2 (substance use) and state mental health laws. All others: Returns REDACTED. Tags: sensitivity_level=high, masking_rule=REDACT (drug columns). Columns: pharmacy_claims.ndc_code, drug_name, drug_class; providers.dea_number.'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN drug_value
    WHEN is_account_group_member('phi_partial_access') THEN '[Therapeutic Class]'
    ELSE 'REDACTED'
  END;


-- ============================================================================
-- 12. MASK_CLINICAL_NOTES
-- Purpose: Masks free-text clinical notes using regex entity scrubbing
-- Tags:    sensitivity_level=critical, hipaa_type=MEDICAL_RECORD,
--          masking_rule=FULL_MASK
-- Columns: prior_authorizations.clinical_notes
--          (also applicable to case management notes, grievance narratives)
--
-- Logic:
--   Full access   → Full narrative (for UM nurses, peer reviewers, appeals)
--   Partial access → Regex-scrubbed text:
--                     - Person names (Cap Word Cap Word) → [NAME]
--                     - SSN patterns (XXX-XX-XXXX) → [SSN]
--                     - Phone patterns (XXX-XXX-XXXX) → [PHONE]
--                     Clinical content remains readable.
--   No access     → [CLINICAL NOTES REDACTED - REQUEST PHI ACCESS]
--
-- LIMITATIONS: Regex is best-effort. Misspelled names, unusual date formats,
--   MRNs, and other unstructured identifiers may pass through. For production,
--   integrate NLP de-identification (AWS Comprehend Medical, Azure Health).
--
-- Clinical notes are the HIGHEST-RISK data type for accidental PHI disclosure
-- because they can contain any of the 18 Safe Harbor identifiers in free text.
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_clinical_notes(notes STRING)
RETURNS STRING
COMMENT 'Masks free-text clinical notes using regex entity scrubbing for partial access. phi_full_access: Returns full narrative for UM nurses, peer reviewers, clinical appeals. phi_partial_access: Regex replaces person names ([NAME]), SSN patterns ([SSN]), phone patterns ([PHONE]) -- clinical content remains readable for QA and clinical analytics. LIMITATION: regex is best-effort; misspelled names, unusual formats, MRNs may pass through. For production, integrate NLP de-identification (AWS Comprehend Medical, Azure Health). All others: Returns [CLINICAL NOTES REDACTED - REQUEST PHI ACCESS]. Tags: sensitivity_level=critical, hipaa_type=MEDICAL_RECORD, masking_rule=FULL_MASK. Columns: prior_authorizations.clinical_notes. Highest-risk data type for accidental PHI disclosure.'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN notes
    WHEN is_account_group_member('phi_partial_access') THEN
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(notes, '[A-Z][a-z]+ [A-Z][a-z]+', '[NAME]'),
          '\\d{3}-\\d{2}-\\d{4}', '[SSN]'),
        '\\d{3}-\\d{3}-\\d{4}', '[PHONE]')
    ELSE '[CLINICAL NOTES REDACTED - REQUEST PHI ACCESS]'
  END;


-- ============================================================================
-- 13. MASK_TAX_ID
-- Purpose: Masks provider Tax Identification Numbers (EIN or SSN)
-- Tags:    sensitivity_level=critical, hipaa_type=TAX_ID, masking_rule=FULL_MASK
-- Columns: providers.tax_id
--
-- Logic:
--   Full access   → 61-1234567 (for credentialing, 1099, accounts payable)
--   Partial access → **-***4567 (last 4 for provider ops verification)
--   No access     → XX-XXXXXXX
--
-- NOTE: Sole practitioner Tax IDs may be individual SSNs, carrying the
--       same sensitivity as member SSNs.
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_tax_id(tax_id STRING)
RETURNS STRING
COMMENT 'Masks provider Tax Identification Numbers (EIN or individual SSN). phi_full_access: Returns full Tax ID (e.g., 61-1234567) for provider credentialing, 1099 reporting, contract management, accounts payable. phi_partial_access: Returns last 4 (e.g., **-***4567) for provider ops record matching and verification. All others: Returns XX-XXXXXXX. Note: sole practitioner Tax IDs may be individual SSNs -- same sensitivity as member SSNs. Tags: sensitivity_level=critical, hipaa_type=TAX_ID, masking_rule=FULL_MASK. Columns: providers.tax_id.'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN tax_id
    WHEN is_account_group_member('phi_partial_access') THEN CONCAT('**-***', RIGHT(tax_id, 4))
    ELSE 'XX-XXXXXXX'
  END;


-- ============================================================================
-- 14. MASK_BENEFICIARY_ID
-- Purpose: Masks Medicare Beneficiary Identifiers (MBI) and Medicaid IDs
-- Tags:    sensitivity_level=critical, hipaa_type=HEALTH_PLAN_BENEFICIARY,
--          masking_rule=FULL_MASK
-- Columns: members.medicare_beneficiary_id, members.medicaid_id
-- HIPAA:   45 CFR 164.514(b)(2)(i)(M) — Health plan beneficiary numbers
--
-- Logic:
--   Full access   → 1AB2CD3EF45 (for MA enrollment, CMS reporting)
--   Partial access → 1AB******** (first 3 for phone verification)
--   No access     → XXXXXXXXXXX
--
-- NOTE: MBI replaced the SSN-based HICN (Health Insurance Claim Number).
-- ============================================================================
CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.mask_beneficiary_id(ben_id STRING)
RETURNS STRING
COMMENT 'Masks Medicare Beneficiary Identifiers (MBI) and state Medicaid IDs. phi_full_access: Returns full ID (e.g., 1AB2CD3EF45 for MBI, KY-MC-90001 for Medicaid) for MA enrollment, Medicaid eligibility, CMS reporting, dual-eligible coordination. phi_partial_access: Returns first 3 chars + asterisks (e.g., 1AB********) for member services phone verification. All others: Returns XXXXXXXXXXX. MBI replaced the SSN-based HICN. Tags: sensitivity_level=critical, hipaa_type=HEALTH_PLAN_BENEFICIARY, masking_rule=FULL_MASK. Columns: members.medicare_beneficiary_id, medicaid_id. HIPAA 45 CFR 164.514(b)(2)(i)(M).'
RETURN
  CASE
    WHEN is_account_group_member('phi_full_access') THEN ben_id
    WHEN is_account_group_member('phi_partial_access') THEN CONCAT(LEFT(ben_id, 3), '********')
    ELSE 'XXXXXXXXXXX'
  END;


-- ============================================================================
-- APPLYING FUNCTIONS AS COLUMN MASKS
-- ============================================================================
-- Example: Bind masking functions to columns using ALTER TABLE SET MASK
--
-- ALTER TABLE serverless_stable_swv01_catalog.governance.members
--   ALTER COLUMN ssn SET MASK serverless_stable_swv01_catalog.governance.mask_ssn;
--
-- ALTER TABLE serverless_stable_swv01_catalog.governance.members
--   ALTER COLUMN first_name SET MASK serverless_stable_swv01_catalog.governance.mask_name;
--
-- ALTER TABLE serverless_stable_swv01_catalog.governance.claims
--   ALTER COLUMN member_id SET MASK serverless_stable_swv01_catalog.governance.hash_identifier;
--
-- ALTER TABLE serverless_stable_swv01_catalog.governance.claims
--   ALTER COLUMN diagnosis_code_primary SET MASK serverless_stable_swv01_catalog.governance.mask_diagnosis_code;
--
-- ALTER TABLE serverless_stable_swv01_catalog.governance.claims
--   ALTER COLUMN paid_amount SET MASK serverless_stable_swv01_catalog.governance.mask_financial_amount;
--
-- ALTER TABLE serverless_stable_swv01_catalog.governance.prior_authorizations
--   ALTER COLUMN clinical_notes SET MASK serverless_stable_swv01_catalog.governance.mask_clinical_notes;
-- ============================================================================
