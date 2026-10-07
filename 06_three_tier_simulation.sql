-- ============================================================================
-- HLS Payer ABAC Demo — 3-Tier Access Simulation
-- Shows all three access tiers SIDE BY SIDE without switching users.
-- USE CASE: Demo presenter sees all three tiers simultaneously.
--
-- OPTION A (this file): Demo simulation using explicit tier-parameter UDFs.
--   → No user setup required. Perfect for live demos.
--   → Limitations: bypasses is_account_group_member(); for illustration only.
--
-- OPTION B (see 08_pre_demo_setup.sql): Real groups + real user assignment.
--   → Requires pre-demo setup. Shows actual ABAC enforcement.
--   → Query as each user to see their filtered/masked view.
-- ============================================================================

USE CATALOG serverless_stable_swv01_catalog;
USE SCHEMA governance;


-- ============================================================================
-- SECTION 1: Demo Simulation UDFs (take explicit tier, no group check)
-- ============================================================================

-- demo_mask_name: shows what each tier sees for name columns
CREATE OR REPLACE FUNCTION governance.demo_mask_name(v STRING, tier STRING)
RETURNS STRING
COMMENT 'DEMO USE ONLY — explicit tier simulation for governance walkthrough. prod: use mask_name().'
RETURN CASE tier
  WHEN 'phi_full_access'    THEN v
  WHEN 'phi_partial_access' THEN CONCAT(LEFT(v, 1), '****')
  ELSE 'REDACTED'
END;

-- demo_mask_ssn
CREATE OR REPLACE FUNCTION governance.demo_mask_ssn(v STRING, tier STRING)
RETURNS STRING
COMMENT 'DEMO USE ONLY.'
RETURN CASE tier
  WHEN 'phi_full_access'    THEN v
  WHEN 'phi_partial_access' THEN CONCAT('***-**-', RIGHT(REGEXP_REPLACE(v,'[^0-9]',''), 4))
  ELSE 'XXX-XX-XXXX'
END;

-- demo_mask_dob: date → string (generalization)
CREATE OR REPLACE FUNCTION governance.demo_mask_dob(v DATE, tier STRING)
RETURNS STRING
COMMENT 'DEMO USE ONLY. HIPAA Safe Harbor: age 90+ must be grouped in production.'
RETURN CASE tier
  WHEN 'phi_full_access'    THEN CAST(v AS STRING)
  WHEN 'phi_partial_access' THEN DATE_FORMAT(v, 'yyyy-MM')
  ELSE CONCAT(CAST(YEAR(v) AS STRING), '-XX-XX')
END;

-- demo_hash_id: deterministic SHA-256 (same output for same input = JOINable)
CREATE OR REPLACE FUNCTION governance.demo_hash_id(v STRING, tier STRING)
RETURNS STRING
COMMENT 'DEMO USE ONLY. Hash is deterministic — de-identified datasets remain JOINable across tables.'
RETURN CASE tier
  WHEN 'phi_full_access' THEN v
  ELSE CONCAT('HID-', LEFT(SHA2(CONCAT(v, 'humana_salt_2025'), 256), 16))
END;

-- demo_mask_dx: ICD-10 category truncation (E11.65 → E11.x)
CREATE OR REPLACE FUNCTION governance.demo_mask_dx(v STRING, tier STRING)
RETURNS STRING
COMMENT 'DEMO USE ONLY. Partial = category only (E11.x). Hides specificity, preserves disease group.'
RETURN CASE tier
  WHEN 'phi_full_access'    THEN v
  WHEN 'phi_partial_access' THEN
    CASE WHEN v IS NULL THEN NULL
         ELSE CONCAT(LEFT(v, POSITION('.' IN v) - 1), '.x')
    END
  ELSE 'REDACTED'
END;

-- demo_mask_amount: financial bucketing (prevents rate-inference attacks)
CREATE OR REPLACE FUNCTION governance.demo_mask_amount(v DECIMAL(12,2), tier STRING)
RETURNS STRING
COMMENT 'DEMO USE ONLY. Bucketed ranges prevent reverse-engineering exact negotiated rates.'
RETURN CASE tier
  WHEN 'phi_full_access'    THEN CAST(v AS STRING)
  WHEN 'phi_partial_access' THEN
    CASE WHEN v IS NULL THEN NULL
         WHEN v < 100    THEN '$0-$100'
         WHEN v < 500    THEN '$100-$500'
         WHEN v < 1000   THEN '$500-$1K'
         WHEN v < 5000   THEN '$1K-$5K'
         WHEN v < 10000  THEN '$5K-$10K'
         WHEN v < 50000  THEN '$10K-$50K'
         ELSE '$50K+'
    END
  ELSE 'REDACTED'
END;

-- demo_mask_drug: medication → therapeutic class (condition-inference protection)
CREATE OR REPLACE FUNCTION governance.demo_mask_drug(v STRING, tier STRING)
RETURNS STRING
COMMENT 'DEMO USE ONLY. Pembrolizumab→cancer, Donepezil→Alzheimers, Buprenorphine→OUD (42 CFR Part 2).'
RETURN CASE tier
  WHEN 'phi_full_access'    THEN v
  WHEN 'phi_partial_access' THEN '[Therapeutic Class]'
  ELSE 'REDACTED'
END;


-- ============================================================================
-- SECTION 2: THE KEY DEMO QUERIES
-- Run each of these to show the audience the governance in action.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DEMO QUERY 1: Member Identity — PHI Tier Comparison
-- Talk track: "Maria Rodriguez. SSN 423-55-6789. Date of birth March 14, 1958.
--   Home address 1200 Wellness Blvd, Louisville KY. This is what any analyst
--   can see today without governance. Let me show you what three different
--   roles will see after we apply ABAC."
-- ----------------------------------------------------------------------------
SELECT
  'Care Manager'        AS role,
  'phi_full_access'     AS access_tier,
  demo_mask_name(first_name, 'phi_full_access')      AS first_name,
  demo_mask_name(last_name, 'phi_full_access')       AS last_name,
  demo_mask_ssn(ssn, 'phi_full_access')              AS ssn,
  demo_mask_dob(date_of_birth, 'phi_full_access')    AS date_of_birth,
  demo_hash_id(member_id, 'phi_full_access')         AS member_id
FROM governance.members WHERE member_id = 'M-100001'
UNION ALL
SELECT
  'Member Services Rep', 'phi_partial_access',
  demo_mask_name(first_name, 'phi_partial_access'),
  demo_mask_name(last_name, 'phi_partial_access'),
  demo_mask_ssn(ssn, 'phi_partial_access'),
  demo_mask_dob(date_of_birth, 'phi_partial_access'),
  demo_hash_id(member_id, 'phi_partial_access')
FROM governance.members WHERE member_id = 'M-100001'
UNION ALL
SELECT
  'Actuary / Data Scientist', 'no_phi_access',
  demo_mask_name(first_name, 'no_phi_access'),
  demo_mask_name(last_name, 'no_phi_access'),
  demo_mask_ssn(ssn, 'no_phi_access'),
  demo_mask_dob(date_of_birth, 'no_phi_access'),
  demo_hash_id(member_id, 'no_phi_access')
FROM governance.members WHERE member_id = 'M-100001';


-- ----------------------------------------------------------------------------
-- DEMO QUERY 2: Claims — Clinical + Financial Sensitivity
-- Talk track: "Claims data is doubly sensitive: the diagnosis codes reveal
--   health conditions, and the financial amounts reveal negotiated rates.
--   Note how partial access gets ICD-10 category (E11.x) not specificity
--   (E11.65 = Type 2 diabetes with hyperglycemia) — enough for population
--   health analytics without revealing exact diagnoses."
-- ----------------------------------------------------------------------------
SELECT
  'Clinical Reviewer'   AS role,
  'phi_full_access'     AS tier,
  demo_hash_id(c.member_id, 'phi_full_access')       AS member_id,
  demo_mask_dx(c.diagnosis_code_primary, 'phi_full_access')  AS primary_dx,
  demo_mask_amount(c.paid_amount, 'phi_full_access')         AS paid_amount
FROM governance.claims c
WHERE c.claim_status = 'Paid' LIMIT 1
UNION ALL
SELECT
  'Pop Health Analyst', 'phi_partial_access',
  demo_hash_id(c.member_id, 'phi_partial_access'),
  demo_mask_dx(c.diagnosis_code_primary, 'phi_partial_access'),
  demo_mask_amount(c.paid_amount, 'phi_partial_access')
FROM governance.claims c
WHERE c.claim_status = 'Paid' LIMIT 1
UNION ALL
SELECT
  'External Researcher', 'no_phi_access',
  demo_hash_id(c.member_id, 'no_phi_access'),
  demo_mask_dx(c.diagnosis_code_primary, 'no_phi_access'),
  demo_mask_amount(c.paid_amount, 'no_phi_access')
FROM governance.claims c
WHERE c.claim_status = 'Paid' LIMIT 1;


-- ----------------------------------------------------------------------------
-- DEMO QUERY 3: Pharmacy — Drug-as-Condition-Inference Vector
-- Talk track: "A single drug name can reveal more about a patient than their
--   diagnosis code. Pembrolizumab tells you it's cancer. Buprenorphine tells
--   you it's opioid use disorder — which has separate protections under
--   42 CFR Part 2. For partial access, we surface the therapeutic class
--   without revealing the specific drug."
-- ----------------------------------------------------------------------------
SELECT
  'PBM Pharmacist'   AS role,
  'phi_full_access'  AS tier,
  demo_hash_id(rx.member_id, 'phi_full_access')    AS member_id,
  demo_mask_drug(rx.drug_name, 'phi_full_access')  AS drug_name,
  demo_mask_drug(rx.drug_class, 'phi_full_access') AS drug_class
FROM governance.pharmacy_claims rx LIMIT 3
UNION ALL
SELECT
  'Utilization Mgmt', 'phi_partial_access',
  demo_hash_id(rx.member_id, 'phi_partial_access'),
  demo_mask_drug(rx.drug_name, 'phi_partial_access'),
  demo_mask_drug(rx.drug_class, 'phi_partial_access')
FROM governance.pharmacy_claims rx LIMIT 3
UNION ALL
SELECT
  'Actuarial Analyst', 'no_phi_access',
  demo_hash_id(rx.member_id, 'no_phi_access'),
  demo_mask_drug(rx.drug_name, 'no_phi_access'),
  demo_mask_drug(rx.drug_class, 'no_phi_access')
FROM governance.pharmacy_claims rx LIMIT 3;


-- ----------------------------------------------------------------------------
-- DEMO QUERY 4: The Joinability Test
-- Talk track: "Here's the magic of deterministic hashing. The hash for
--   member M-100001 is identical across the members, claims, and eligibility
--   tables. De-identified datasets remain analytically useful — you can still
--   JOIN member demographics to claims to pharmacy — without exposing the
--   real member identifier."
-- ----------------------------------------------------------------------------
SELECT
  'members'            AS source_table,
  demo_hash_id(m.member_id, 'no_phi_access') AS hashed_id,
  demo_mask_name(m.first_name, 'no_phi_access') AS name,
  demo_mask_dob(m.date_of_birth, 'no_phi_access') AS dob
FROM governance.members m WHERE member_id = 'M-100001'
UNION ALL
SELECT
  'claims',
  demo_hash_id(c.member_id, 'no_phi_access'), '— linked via hash —', '—'
FROM governance.claims c WHERE member_id = 'M-100001' LIMIT 1
UNION ALL
SELECT
  'eligibility',
  demo_hash_id(e.member_id, 'no_phi_access'), '— linked via hash —', '—'
FROM governance.eligibility e WHERE member_id = 'M-100001' LIMIT 1;
-- All three hashed_id values are identical → JOIN still works!
