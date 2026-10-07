# Databricks notebook source

# COMMAND ----------

# MAGIC %md
# MAGIC # Unity Catalog ABAC — HLS Payer Governance Demo
# MAGIC ### Attribute-Based Access Control for HIPAA-Governed Data
# MAGIC
# MAGIC **Catalog:** `serverless_stable_swv01_catalog` &nbsp;|&nbsp; **Schema:** `governance`
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## ⏱️ Two Demo Tracks
# MAGIC
# MAGIC | Track | Duration | Acts | Best For |
# MAGIC |-------|----------|------|----------|
# MAGIC | **30-Min Track** | 30 min | Acts 1–4, Act 6 (ABAC), Act 7 (Audit) | Executive briefing, governance team intro |
# MAGIC | **60-Min Track** | 60 min | All Acts 1–8 + Limitations deep dive | Hands-on technical workshop, full evaluation |
# MAGIC
# MAGIC **30-Min cells are marked:** 🟢 30-min&nbsp;&nbsp;&nbsp; **60-min extras:** 🔵 60-min only
# MAGIC
# MAGIC ---
# MAGIC
# MAGIC ## Pre-Demo Checklist
# MAGIC
# MAGIC **Option A — Single-user simulation (recommended, no setup needed):**
# MAGIC - [x] Notebook attached to Serverless compute (required for ABAC)
# MAGIC - [x] Run `05_governed_tags.sql` to create governed tags
# MAGIC - [x] Confirm tables exist: `SHOW TABLES IN serverless_stable_swv01_catalog.governance`
# MAGIC
# MAGIC **Option B — Multi-user real enforcement (setup required):**
# MAGIC - [ ] Create account groups: `phi_full_access`, `phi_partial_access` (see `08_pre_demo_setup.sql`)
# MAGIC - [ ] Assign 3 demo users (one per tier) to appropriate groups
# MAGIC - [ ] Grant SELECT on governance schema to each group
# MAGIC - [ ] Verify: each user runs `SELECT is_account_group_member('phi_full_access')` → confirm correct group

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # ARCHITECTURE OVERVIEW
# MAGIC *Slide 2: ABAC Visual Summary — Core Architecture*

# COMMAND ----------

displayHTML("""
<div style="text-align:center; padding:20px; background:#f8f9fa; border-radius:8px;">
  <img src="/files/Volumes/serverless_stable_swv01_catalog/governance/demo_assets/slide2.png"
       onerror="this.outerHTML='&lt;p style=&quot;font-family:sans-serif;color:#777&quot;&gt;[architecture slide unavailable — open governance/demo_assets/slide2.png]&lt;/p&gt;'"
       style="max-width:100%; border-radius:8px; box-shadow:0 4px 12px rgba(0,0,0,0.15);" />
</div>
""")

# COMMAND ----------

# MAGIC %md
# MAGIC ### Reading the Visual Summary
# MAGIC
# MAGIC The three pillars of ABAC:
# MAGIC
# MAGIC | Component | Role | In This Demo |
# MAGIC |-----------|------|--------------|
# MAGIC | **Governed Tags** | The attribute vocabulary — PHI, EU, Finance. Enforces allowed values at write time. | `sensitivity_level`, `masking_rule`, `hipaa_type` applied to 48 columns across 6 tables |
# MAGIC | **Policy** | Rules that say "MATCH columns WHERE tag = X, USING function Y". Defined ONCE at schema level. | `hash_phi_identifiers` covers 8 ID columns across 5 tables |
# MAGIC | **UDF** | The enforcement mechanism — executed at query time, invisible to the query author. | 14 masking functions: `mask_ssn`, `hash_identifier`, `mask_clinical_notes`, etc. |
# MAGIC
# MAGIC **Why it matters for architects:**
# MAGIC > "ABAC replaces thousands of GRANT statements with a handful of global policies. Policy explosion (one rule per table) becomes policy scalability (one rule per tag value)."

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC *Slide 3: ABAC Architecture — Governance Control Plane*

# COMMAND ----------

displayHTML("""
<div style="text-align:center; padding:20px; background:#f0f4ff; border-radius:8px;">
  <img src="/files/Volumes/serverless_stable_swv01_catalog/governance/demo_assets/slide3.png"
       onerror="this.outerHTML='&lt;p style=&quot;font-family:sans-serif;color:#777&quot;&gt;[architecture slide unavailable — open governance/demo_assets/slide3.png]&lt;/p&gt;'"
       style="max-width:100%; border-radius:8px; box-shadow:0 4px 12px rgba(0,0,0,0.15);" />
</div>
""")

# COMMAND ----------

# MAGIC %md
# MAGIC ### Reading the Architecture Diagram
# MAGIC
# MAGIC The flow for every query in this demo:
# MAGIC
# MAGIC ```
# MAGIC User runs SELECT            →  User Attributes Evaluation  →  ABAC Engine
# MAGIC (analyst, care mgr, rep)       (group membership check)       (tag match → UDF)
# MAGIC                                                                    ↓
# MAGIC Row-Level Filtering Applied  ←  Column-Masking Applied  ←  Query Plan Modified
# MAGIC (BH/SUD rows hidden)            (SSN → XXX-XX-XXXX)         (SecureView barrier)
# MAGIC ```
# MAGIC
# MAGIC **Governance Control Plane** drives:
# MAGIC - Governed Tag Policies (PHI, PII, Confidential, Finance, HR)
# MAGIC - Automated Data Classification (auto-tagging new tables)
# MAGIC - Data Lineage Integration (tracks which downstream tables inherit protection)
# MAGIC - Tag-based Cost Reporting (showback per business domain)

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🟢 ACT 1: THE PROBLEM — Unprotected PHI (Before State)
# MAGIC
# MAGIC **Talk track (2 min):**
# MAGIC > "Let me start with what your data looks like today — before any governance.
# MAGIC > Maria Rodriguez. SSN 423-55-6789. Date of birth March 14, 1958. Home address
# MAGIC > 1200 Wellness Blvd, Louisville, Kentucky.
# MAGIC >
# MAGIC > This is what ANY analyst with SELECT privilege on this table sees right now.
# MAGIC > That analyst could be writing a population health query, a STARS report, or
# MAGIC > an actuarial model — they all see the same raw PHI.
# MAGIC >
# MAGIC > Under HIPAA's minimum necessary standard, that's a compliance violation.
# MAGIC > Under your HITRUST CSF, it's an unresolved finding. Let me show you what
# MAGIC > we're going to fix."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- ACT 1: Before State — Raw PHI visible to all
# MAGIC -- Note: This is the 'before' query. After we apply ABAC, re-run this
# MAGIC -- and watch the output change based on your group membership.
# MAGIC SELECT
# MAGIC   member_id,
# MAGIC   first_name, last_name,
# MAGIC   ssn,
# MAGIC   date_of_birth,
# MAGIC   address_line1, city, state_code, zip_code,
# MAGIC   phone_mobile, email,
# MAGIC   medicare_beneficiary_id
# MAGIC FROM serverless_stable_swv01_catalog.governance.members
# MAGIC LIMIT 3;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Pharmacy: drug names as condition inference vectors
# MAGIC SELECT rx.member_id, rx.drug_name, rx.drug_class, rx.ndc_code, rx.fill_date
# MAGIC FROM serverless_stable_swv01_catalog.governance.pharmacy_claims rx
# MAGIC LIMIT 5;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Prior auth clinical notes — highest risk free-text PHI
# MAGIC SELECT pa.member_id, pa.auth_type, pa.clinical_notes
# MAGIC FROM serverless_stable_swv01_catalog.governance.prior_authorizations pa
# MAGIC WHERE pa.clinical_notes IS NOT NULL
# MAGIC LIMIT 2;

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🟢 ACT 2: DATA CLASSIFICATION — Tags as the Foundation
# MAGIC
# MAGIC **Talk track (8 min):**
# MAGIC > "Before we can enforce any policy, we need to answer: what is this data?
# MAGIC > That's classification — and in Databricks ABAC, classification is expressed
# MAGIC > as governed tags. These aren't just metadata labels. They're the inputs
# MAGIC > that ABAC policies evaluate at query time.
# MAGIC >
# MAGIC > We have tags at three levels. The schema inherits `compliance=hipaa`,
# MAGIC > so every table in this schema is automatically marked as HIPAA-governed —
# MAGIC > including tables added in the future.
# MAGIC >
# MAGIC > At the column level, we've tagged 48 columns across 6 tables. This is
# MAGIC > your PHI inventory. Run the query below and you've got an audit-ready
# MAGIC > dataset showing every identifier type across your entire data estate."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Schema-level tag (inherited by all 6 tables)
# MAGIC SELECT catalog_name, schema_name, tag_name, tag_value
# MAGIC FROM serverless_stable_swv01_catalog.information_schema.schema_tags
# MAGIC WHERE schema_name = 'governance';

# COMMAND ----------

# MAGIC %sql
# MAGIC -- HIPAA PHI Inventory — all columns by identifier type
# MAGIC -- This query is your audit artifact: "show me every PHI column and what type it is"
# MAGIC SELECT
# MAGIC   t.table_name,
# MAGIC   t.column_name,
# MAGIC   MAX(CASE WHEN t.tag_name = 'hipaa_type'       THEN t.tag_value END) AS hipaa_type,
# MAGIC   MAX(CASE WHEN t.tag_name = 'sensitivity_level'THEN t.tag_value END) AS sensitivity,
# MAGIC   MAX(CASE WHEN t.tag_name = 'masking_rule'     THEN t.tag_value END) AS masking_rule,
# MAGIC   MAX(CASE WHEN t.tag_name = 'contains_phi'     THEN t.tag_value END) AS is_phi
# MAGIC FROM serverless_stable_swv01_catalog.information_schema.column_tags t
# MAGIC WHERE t.schema_name = 'governance'
# MAGIC   AND t.tag_name IN ('hipaa_type','sensitivity_level','masking_rule','contains_phi')
# MAGIC GROUP BY t.table_name, t.column_name
# MAGIC HAVING MAX(CASE WHEN t.tag_name = 'sensitivity_level' THEN t.tag_value END) IS NOT NULL
# MAGIC ORDER BY t.table_name, sensitivity DESC, t.column_name;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- How many tagged columns per masking_rule? (shows ABAC policy coverage at a glance)
# MAGIC SELECT
# MAGIC   tag_value         AS masking_rule,
# MAGIC   COUNT(*)          AS columns_covered,
# MAGIC   COLLECT_LIST(CONCAT(table_name, '.', column_name)) AS columns
# MAGIC FROM serverless_stable_swv01_catalog.information_schema.column_tags
# MAGIC WHERE schema_name = 'governance' AND tag_name = 'masking_rule'
# MAGIC GROUP BY tag_value
# MAGIC ORDER BY columns_covered DESC;

# COMMAND ----------

# MAGIC %md
# MAGIC > **Key insight to land:** Tag values are CASE-SENSITIVE in ABAC policy matching.
# MAGIC > `'full_mask'` and `'Full_Mask'` are different values and only one will match
# MAGIC > the policy. This is why governed tags with enforced allowed values are
# MAGIC > essential — they prevent the typos that silently break policy coverage.

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🟢 ACT 3: MASKING FUNCTIONS — The Policy Enforcement UDFs
# MAGIC
# MAGIC **Talk track (4 min):**
# MAGIC > "ABAC policies execute User-Defined Functions at query time. These are standard
# MAGIC > SQL functions — no special syntax. The function takes the raw column value as
# MAGIC > input, checks the caller's group membership, and returns the appropriate
# MAGIC > representation. The query author never sees this happen; the masking is
# MAGIC > invisible in the query plan.
# MAGIC >
# MAGIC > We have 14 purpose-built masking functions covering every HIPAA identifier type.
# MAGIC > Let me show you three that demonstrate different masking strategies."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Strategy 1: Deterministic hashing (JOINable de-identification)
# MAGIC -- The hash is IDENTICAL for the same input, so de-identified datasets
# MAGIC -- can still be joined across tables.
# MAGIC SELECT
# MAGIC   serverless_stable_swv01_catalog.governance.hash_identifier('M-100001') AS hashed_id,
# MAGIC   serverless_stable_swv01_catalog.governance.hash_identifier('M-100001') AS same_input_same_hash,
# MAGIC   serverless_stable_swv01_catalog.governance.hash_identifier('M-100002') AS different_member;
# MAGIC -- You are currently: SELECT is_account_group_member('phi_full_access')
# MAGIC -- phi_full_access users see: M-100001 (original)
# MAGIC -- All others see:            HID-a3f8c91b2e7d04f2 (deterministic hash)

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Strategy 2: Generalization (safe harbor compliant)
# MAGIC -- HIPAA Safe Harbor: dates must be year-only for ages < 90
# MAGIC SELECT
# MAGIC   serverless_stable_swv01_catalog.governance.mask_date_of_birth(DATE '1958-03-14') AS date_result;
# MAGIC -- phi_full_access:    1958-03-14  (exact — for HEDIS, eligibility verification)
# MAGIC -- phi_partial_access: 1958-03     (year-month — for risk adjustment, age-band analytics)
# MAGIC -- all others:         1958-XX-XX  (year only — for cohort analysis, actuarial)

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Strategy 3: Clinical code truncation (ICD-10 specificity removal)
# MAGIC -- E11.65 = "Type 2 diabetes with hyperglycemia" → E11.x = "Type 2 diabetes"
# MAGIC -- Population health can count diabetes prevalence; nobody can infer specific complications.
# MAGIC SELECT
# MAGIC   serverless_stable_swv01_catalog.governance.mask_diagnosis_code('E11.65')  AS diabetes_example,
# MAGIC   serverless_stable_swv01_catalog.governance.mask_diagnosis_code('F32.1')   AS depression_example,
# MAGIC   serverless_stable_swv01_catalog.governance.mask_diagnosis_code('Z79.899') AS chronic_med_example;

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🟢 ACT 4: THREE-TIER SIMULATION (No User Switching Required)
# MAGIC
# MAGIC **Talk track (6 min):**
# MAGIC > "I'm going to show you all three access tiers simultaneously. In production,
# MAGIC > each user sees only their tier — they never see the comparison. But here I
# MAGIC > want you to see exactly what each role's data looks like side by side.
# MAGIC >
# MAGIC > Three roles: a care manager who needs full PHI for care coordination,
# MAGIC > a member services rep who needs partial information for identity verification,
# MAGIC > and an actuary who needs to analyze population trends without any PHI."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- THE KEY DEMO QUERY: All 3 tiers in one table
# MAGIC -- Care Manager | Member Services | Actuary — same member, three different views
# MAGIC SELECT
# MAGIC   'Care Manager'         AS role,
# MAGIC   'phi_full_access'      AS access_tier,
# MAGIC   first_name             AS first_name,
# MAGIC   last_name              AS last_name,
# MAGIC   ssn                    AS ssn,
# MAGIC   CAST(date_of_birth AS STRING) AS date_of_birth,
# MAGIC   member_id              AS member_id
# MAGIC FROM serverless_stable_swv01_catalog.governance.members WHERE member_id = 'M-100001'
# MAGIC
# MAGIC UNION ALL
# MAGIC
# MAGIC SELECT
# MAGIC   'Member Services Rep', 'phi_partial_access',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_name(first_name,    'phi_partial_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_name(last_name,     'phi_partial_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_ssn(ssn,            'phi_partial_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_dob(date_of_birth,  'phi_partial_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id,       'phi_partial_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.members WHERE member_id = 'M-100001'
# MAGIC
# MAGIC UNION ALL
# MAGIC
# MAGIC SELECT
# MAGIC   'Actuary / Data Scientist', 'no_phi_access',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_name(first_name,    'no_phi_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_name(last_name,     'no_phi_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_ssn(ssn,            'no_phi_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_dob(date_of_birth,  'no_phi_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id,       'no_phi_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.members WHERE member_id = 'M-100001';

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Claims: Clinical sensitivity + financial sensitivity in one query
# MAGIC -- Land the point: diagnosis specificity matters (E11.65 vs E11.x)
# MAGIC (SELECT
# MAGIC   'Clinical Reviewer (full)' AS role,
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'phi_full_access')    AS member_id,
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_dx(diagnosis_code_primary,  'phi_full_access')  AS primary_dx,
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_amount(paid_amount, 'phi_full_access') AS paid_amount
# MAGIC FROM serverless_stable_swv01_catalog.governance.claims WHERE claim_status = 'Paid' LIMIT 1)
# MAGIC UNION ALL
# MAGIC (SELECT
# MAGIC   'Pop Health Analyst (partial)',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'phi_partial_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_dx(diagnosis_code_primary, 'phi_partial_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_amount(paid_amount, 'phi_partial_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.claims WHERE claim_status = 'Paid' LIMIT 1)
# MAGIC UNION ALL
# MAGIC (SELECT
# MAGIC   'External Researcher (none)',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'no_phi_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_dx(diagnosis_code_primary, 'no_phi_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_amount(paid_amount, 'no_phi_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.claims WHERE claim_status = 'Paid' LIMIT 1);

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Pharmacy: Drug-as-condition-inference vector
# MAGIC -- "Pembrolizumab = cancer. Buprenorphine = OUD (42 CFR Part 2 protected)."
# MAGIC (SELECT
# MAGIC   'PBM Pharmacist (full)' AS role,
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'phi_full_access')      AS member_id,
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_drug(drug_name, 'phi_full_access')    AS drug_name,
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_drug(drug_class, 'phi_full_access')   AS drug_class
# MAGIC FROM serverless_stable_swv01_catalog.governance.pharmacy_claims LIMIT 3)
# MAGIC UNION ALL
# MAGIC (SELECT
# MAGIC   'UM Analyst (partial)',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'phi_partial_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_drug(drug_name, 'phi_partial_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_drug(drug_class, 'phi_partial_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.pharmacy_claims LIMIT 3)
# MAGIC UNION ALL
# MAGIC (SELECT
# MAGIC   'Actuary (none)',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'no_phi_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_drug(drug_name, 'no_phi_access'),
# MAGIC   serverless_stable_swv01_catalog.governance.demo_mask_drug(drug_class, 'no_phi_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.pharmacy_claims LIMIT 3);

# COMMAND ----------

# MAGIC %sql
# MAGIC -- THE JOINABILITY TEST: Prove de-identified data is still analytically useful
# MAGIC -- "The hash for M-100001 is identical across all 3 tables."
# MAGIC (SELECT
# MAGIC   'members'      AS source_table,
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'no_phi_access') AS hashed_member_id
# MAGIC FROM serverless_stable_swv01_catalog.governance.members WHERE member_id = 'M-100001')
# MAGIC UNION ALL
# MAGIC (SELECT 'claims',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'no_phi_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.claims WHERE member_id = 'M-100001' LIMIT 1)
# MAGIC UNION ALL
# MAGIC (SELECT 'eligibility',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'no_phi_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.eligibility WHERE member_id = 'M-100001' LIMIT 1)
# MAGIC UNION ALL
# MAGIC (SELECT 'pharmacy_claims',
# MAGIC   serverless_stable_swv01_catalog.governance.demo_hash_id(member_id, 'no_phi_access')
# MAGIC FROM serverless_stable_swv01_catalog.governance.pharmacy_claims WHERE member_id = 'M-100001' LIMIT 1);
# MAGIC -- All 4 rows show the same hash → JOIN still works across all tables

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🔵 ACT 5 (60-Min Only): Classic Column Masking — The Manual Approach
# MAGIC
# MAGIC **Talk track (5 min):**
# MAGIC > "Before I show you ABAC policies, let me show you the older approach to
# MAGIC > column masking — the one most teams start with. It works fine, but it
# MAGIC > has a scaling problem that ABAC solves.
# MAGIC >
# MAGIC > With classic column masking, you bind a function to a specific column
# MAGIC > on a specific table. One statement per column. We have 48 PHI columns
# MAGIC > across 6 tables. That's 48 ALTER TABLE statements — and when the data
# MAGIC > engineering team adds a new claims table next quarter, they need to
# MAGIC > remember to do it again. Or they forget, and you have a compliance gap."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Classic approach: bind masks directly to columns (table-scoped, manual)
# MAGIC ALTER TABLE serverless_stable_swv01_catalog.governance.members
# MAGIC   ALTER COLUMN ssn SET MASK serverless_stable_swv01_catalog.governance.mask_ssn;
# MAGIC
# MAGIC ALTER TABLE serverless_stable_swv01_catalog.governance.members
# MAGIC   ALTER COLUMN first_name SET MASK serverless_stable_swv01_catalog.governance.mask_name;
# MAGIC
# MAGIC ALTER TABLE serverless_stable_swv01_catalog.governance.members
# MAGIC   ALTER COLUMN member_id SET MASK serverless_stable_swv01_catalog.governance.hash_identifier;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Check: now query as yourself — you see masked output based on your group
# MAGIC SELECT member_id, first_name, ssn, date_of_birth
# MAGIC FROM serverless_stable_swv01_catalog.governance.members LIMIT 3;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Clean up classic masks before applying ABAC policies (avoid conflicts!)
# MAGIC -- ABAC policy + direct mask on same column = CONFLICT ERROR
# MAGIC -- NOTE: run this ONLY after the SET MASK cell above. DROP MASK has no
# MAGIC -- IF EXISTS and errors if the column has no mask — on the 30-min track
# MAGIC -- (which skips Act 5) do not run this cell.
# MAGIC ALTER TABLE serverless_stable_swv01_catalog.governance.members
# MAGIC   ALTER COLUMN ssn DROP MASK;
# MAGIC ALTER TABLE serverless_stable_swv01_catalog.governance.members
# MAGIC   ALTER COLUMN first_name DROP MASK;
# MAGIC ALTER TABLE serverless_stable_swv01_catalog.governance.members
# MAGIC   ALTER COLUMN member_id DROP MASK;

# COMMAND ----------

# MAGIC %md
# MAGIC > **Transition to ABAC:**
# MAGIC > "That's the classic approach: 3 statements for 3 columns, 1 table.
# MAGIC > We have 48 columns across 6 tables. Now let me show you how ABAC
# MAGIC > handles all of them with a fraction of the policy statements."

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🟢 ACT 6: ABAC POLICIES — The Differentiator
# MAGIC
# MAGIC **Talk track (12 min):**
# MAGIC > "This is the core of the ABAC value proposition. Instead of binding a mask
# MAGIC > to a column, I define a POLICY that fires based on what's tagged. The policy
# MAGIC > is defined ONCE at the schema level. It auto-applies to every column in
# MAGIC > every table in this schema that matches the tag condition.
# MAGIC >
# MAGIC > Let's start with the most powerful example: member identifiers."

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6A: Column Mask Policy — Hash PHI Identifiers (8 columns, 5 tables, 1 policy)

# COMMAND ----------

# MAGIC %sql
# MAGIC -- FIRST: Show how many columns this single policy will cover
# MAGIC SELECT table_name, column_name, tag_value AS masking_rule
# MAGIC FROM serverless_stable_swv01_catalog.information_schema.column_tags
# MAGIC WHERE schema_name = 'governance' AND tag_name = 'masking_rule' AND tag_value = 'hash'
# MAGIC ORDER BY table_name;
# MAGIC -- Talk track: "8 rows. 8 columns. 5 different tables. ONE policy statement."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- CREATE THE ABAC POLICY — schema-scoped, tag-driven (GA syntax)
# MAGIC -- Form: CREATE POLICY <name> ON SCHEMA <sch> COLUMN MASK <fn>
# MAGIC --       TO <principal> [EXCEPT <principal>] FOR TABLES
# MAGIC --       MATCH COLUMNS <tag_condition> AS col ON COLUMN col;
# MAGIC CREATE OR REPLACE POLICY hash_phi_identifiers
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.hash_identifier
# MAGIC   TO `account users`
# MAGIC   EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('masking_rule', 'hash') AS col
# MAGIC   ON COLUMN col;
# MAGIC -- No table names listed. No column names listed.
# MAGIC -- Any column in ANY table in this schema tagged masking_rule='hash' is now protected.

# COMMAND ----------

# MAGIC %sql
# MAGIC -- VERIFY: Policy is active across ALL 5 tables simultaneously
# MAGIC -- (parenthesize each branch: Spark SQL rejects LIMIT on a bare UNION ALL operand)
# MAGIC (SELECT m.member_id AS members_id FROM serverless_stable_swv01_catalog.governance.members m LIMIT 1)
# MAGIC UNION ALL
# MAGIC (SELECT c.member_id FROM serverless_stable_swv01_catalog.governance.claims c LIMIT 1)
# MAGIC UNION ALL
# MAGIC (SELECT e.member_id FROM serverless_stable_swv01_catalog.governance.eligibility e LIMIT 1)
# MAGIC UNION ALL
# MAGIC (SELECT p.member_id FROM serverless_stable_swv01_catalog.governance.pharmacy_claims p LIMIT 1)
# MAGIC UNION ALL
# MAGIC (SELECT pa.member_id FROM serverless_stable_swv01_catalog.governance.prior_authorizations pa LIMIT 1);
# MAGIC -- Non phi_full_access users see HID-xxxxxxxxxxxxxxxx in ALL 5 tables

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6B: Column Mask Policy — PHI Dates (7 columns, 4 tables, 1 policy)

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Show coverage BEFORE creating the policy
# MAGIC SELECT table_name, column_name
# MAGIC FROM serverless_stable_swv01_catalog.information_schema.column_tags
# MAGIC WHERE schema_name = 'governance' AND tag_name = 'hipaa_type' AND tag_value = 'date_element'
# MAGIC ORDER BY table_name;
# MAGIC -- 7 PHI date columns across members, claims, pharmacy_claims, prior_authorizations

# COMMAND ----------

# MAGIC %sql
# MAGIC CREATE OR REPLACE POLICY mask_phi_dates
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.mask_date_of_birth
# MAGIC   TO `account users`
# MAGIC   EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('hipaa_type', 'date_element') AS col
# MAGIC   ON COLUMN col;
# MAGIC -- mask_date_of_birth RETURNS DATE (must match the DATE column type):
# MAGIC -- phi_full_access:    exact date (HEDIS, care gap closure, eligibility verification)
# MAGIC -- phi_partial_access: first of month (risk adjustment, age-band analytics)
# MAGIC -- all others:         first of year (cohort analysis, actuarial modeling)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6C: Additional HIPAA-Type Policies (Names, SSN, Phone, Email, Clinical Notes)

# COMMAND ----------

# MAGIC %sql
# MAGIC -- All remaining PHI column mask policies — one per HIPAA identifier type
# MAGIC CREATE OR REPLACE POLICY mask_ssn_columns
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.mask_ssn
# MAGIC   TO `account users` EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('hipaa_type', 'ssn') AS col ON COLUMN col;
# MAGIC
# MAGIC CREATE OR REPLACE POLICY mask_name_columns
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.mask_name
# MAGIC   TO `account users` EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('hipaa_type', 'name') AS col ON COLUMN col;
# MAGIC
# MAGIC CREATE OR REPLACE POLICY mask_phone_columns
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.mask_phone
# MAGIC   TO `account users` EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('hipaa_type', 'telephone') AS col ON COLUMN col;
# MAGIC
# MAGIC CREATE OR REPLACE POLICY mask_email_columns
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.mask_email
# MAGIC   TO `account users` EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('hipaa_type', 'email_address') AS col ON COLUMN col;
# MAGIC
# MAGIC CREATE OR REPLACE POLICY mask_beneficiary_ids
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.mask_beneficiary_id
# MAGIC   TO `account users` EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('hipaa_type', 'health_plan_beneficiary') AS col ON COLUMN col;
# MAGIC
# MAGIC -- Clinical notes: highest risk — regex scrubbing for partial access
# MAGIC CREATE OR REPLACE POLICY mask_clinical_notes_columns
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.mask_clinical_notes
# MAGIC   TO `account users` EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('hipaa_type', 'medical_record') AS col ON COLUMN col;

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6D: AUTO-APPLY DEMO — New Table Gets Instant Protection
# MAGIC
# MAGIC **Talk track:**
# MAGIC > "Here's the 'write once, apply everywhere' promise in action. The data
# MAGIC > engineering team creates a new claims appeals table. They tag `member_id`
# MAGIC > with `masking_rule='hash'`. No call to the governance team. No ticket to
# MAGIC > security. No ALTER TABLE. The existing ABAC policy fires automatically."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Create a new table (simulates DE team adding a new domain table)
# MAGIC CREATE OR REPLACE TABLE serverless_stable_swv01_catalog.governance.appeals (
# MAGIC   appeal_id   STRING,
# MAGIC   member_id   STRING
# MAGIC     TAGS ('sensitivity_level' = 'critical', 'hipaa_type' = 'unique_identifier',
# MAGIC           'masking_rule' = 'hash', 'contains_phi' = 'true'),
# MAGIC   claim_id    STRING,
# MAGIC   reason      STRING,
# MAGIC   filed_date  DATE
# MAGIC );
# MAGIC
# MAGIC INSERT INTO serverless_stable_swv01_catalog.governance.appeals VALUES
# MAGIC   ('APL-001', 'M-100001', 'CLM-500001', 'Service not covered', '2025-03-15'),
# MAGIC   ('APL-002', 'M-100005', 'CLM-500002', 'Out-of-network provider', '2025-04-01');

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Query the new table — hash policy auto-applied, no extra SQL needed!
# MAGIC SELECT member_id, claim_id, reason FROM serverless_stable_swv01_catalog.governance.appeals;
# MAGIC -- Non phi_full_access users: member_id = HID-xxxxxxxxxxxxxxxx (auto-masked!)

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6E: EXCEPT Clause — Pipeline Service Principal Exemption
# MAGIC
# MAGIC **Talk track:**
# MAGIC > "One more real-world requirement. The nightly ETL pipeline needs to read
# MAGIC > the real member IDs to join across source systems. But analysts must always
# MAGIC > see hashed IDs. The EXCEPT clause exempts specific principals from a policy
# MAGIC > without creating a special unmasked view or bypassing Unity Catalog."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Demonstrate the EXCEPT clause for a pipeline exemption.
# MAGIC -- CREATE OR REPLACE updates the policy in place (no separate DROP needed).
# MAGIC -- NOTE: every EXCEPT principal must ALREADY EXIST or creation fails with
# MAGIC -- PRINCIPAL_DOES_NOT_EXIST. Replace the placeholder with a real service
# MAGIC -- principal in your account before running this cell (a group like
# MAGIC -- phi_full_access resolves lazily, but a named user/SP is validated now).
# MAGIC CREATE OR REPLACE POLICY hash_phi_identifiers
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   COLUMN MASK serverless_stable_swv01_catalog.governance.hash_identifier
# MAGIC   TO `account users`
# MAGIC   EXCEPT phi_full_access, `pipeline-svc@databricks.com`   -- ← replace with a real SP
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('masking_rule', 'hash') AS col
# MAGIC   ON COLUMN col;
# MAGIC -- pipeline-svc + phi_full_access see real member IDs; everyone else sees HID-...

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🟢 ACT 7: ROW FILTER ABAC POLICY — 42 CFR Part 2 Protection
# MAGIC
# MAGIC **Talk track (8 min):**
# MAGIC > "Column masking controls WHAT you see within a row. Row filtering controls
# MAGIC > WHICH rows you see. This distinction matters enormously for behavioral
# MAGIC > health and substance use disorder data.
# MAGIC >
# MAGIC > 42 CFR Part 2 is stricter than HIPAA. A patient's substance use disorder
# MAGIC > records require explicit written authorization to share — even with clinical
# MAGIC > staff who have general PHI access. A claims ops analyst with phi_partial_access
# MAGIC > should see zero rows for BH/SUD prior authorizations. Not redacted rows.
# MAGIC > Zero rows. They shouldn't even know those records exist."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- BEFORE: Show BH prior auths are visible to everyone
# MAGIC SELECT auth_id, auth_type, auth_status, diagnosis_code, clinical_notes
# MAGIC FROM serverless_stable_swv01_catalog.governance.prior_authorizations
# MAGIC WHERE auth_type IN ('Behavioral Health', 'Substance Use Disorder');

# COMMAND ----------

# MAGIC %sql
# MAGIC -- The row filter function — takes explicit column parameter
# MAGIC -- Databricks resolves column names at function creation time;
# MAGIC -- row filters must declare params that match the bound column names.
# MAGIC CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.filter_bh_sud_auths(auth_type_val STRING)
# MAGIC RETURNS BOOLEAN
# MAGIC COMMENT '42 CFR Part 2 row filter. BH/SUD records visible only to phi_full_access.'
# MAGIC RETURN
# MAGIC   CASE
# MAGIC     WHEN auth_type_val NOT IN ('Behavioral Health', 'Substance Use Disorder') THEN TRUE
# MAGIC     WHEN is_account_group_member('phi_full_access') THEN TRUE
# MAGIC     ELSE FALSE
# MAGIC   END;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- SCHEMA-SCOPED ROW FILTER POLICY (GA syntax)
# MAGIC -- MATCH COLUMNS locates the column tagged hipaa_type='auth_type'; USING COLUMNS
# MAGIC -- (alias) wires that column's value into the filter function argument.
# MAGIC -- (Requires 03_create_tags.sql, which tags prior_authorizations.auth_type.)
# MAGIC CREATE OR REPLACE POLICY bh_sud_auth_protection
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   ROW FILTER serverless_stable_swv01_catalog.governance.filter_bh_sud_auths
# MAGIC   TO `account users`
# MAGIC   EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   MATCH COLUMNS has_tag_value('hipaa_type', 'auth_type') AS auth_type_col
# MAGIC   USING COLUMNS (auth_type_col);

# COMMAND ----------

# MAGIC %sql
# MAGIC -- AFTER: Re-run same query — BH/SUD rows invisible to non-phi_full_access
# MAGIC SELECT auth_id, auth_type, auth_status, diagnosis_code
# MAGIC FROM serverless_stable_swv01_catalog.governance.prior_authorizations
# MAGIC WHERE auth_type IN ('Behavioral Health', 'Substance Use Disorder');
# MAGIC -- phi_full_access: sees rows
# MAGIC -- phi_partial_access, all others: 0 rows returned

# COMMAND ----------

# MAGIC %md
# MAGIC ## 🔵 7B (60-Min): Schema-Scoped Row Filter — WHEN + MATCH COLUMNS
# MAGIC
# MAGIC **Talk track:**
# MAGIC > "Just like column mask policies can be schema-scoped, row filter policies
# MAGIC > can be too — the WHEN clause scopes the policy to tables with a table-level
# MAGIC > tag. Any table in this schema tagged business_domain='eligibility'
# MAGIC > automatically gets this filter. A new Medicaid-only eligibility table added next month is protected
# MAGIC > from day one without touching a single policy."

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Schema-scoped ABAC row filter, scoped by WHEN to tables tagged business_domain='eligibility'.
# MAGIC -- MATCH COLUMNS locates the business_domain='lob' column; USING COLUMNS wires its value in.
# MAGIC CREATE OR REPLACE FUNCTION serverless_stable_swv01_catalog.governance.filter_eligibility_by_lob(lob_val STRING)
# MAGIC RETURNS BOOLEAN
# MAGIC COMMENT 'LOB-scoped eligibility filter. phi_full_access sees all LOBs. Others see Commercial and Medicare Advantage only.'
# MAGIC RETURN
# MAGIC   CASE
# MAGIC     WHEN is_account_group_member('phi_full_access') THEN TRUE
# MAGIC     WHEN lob_val IN ('Commercial', 'Medicare Advantage') THEN TRUE
# MAGIC     ELSE FALSE
# MAGIC   END;
# MAGIC
# MAGIC CREATE OR REPLACE POLICY eligibility_lob_filter
# MAGIC   ON SCHEMA serverless_stable_swv01_catalog.governance
# MAGIC   ROW FILTER serverless_stable_swv01_catalog.governance.filter_eligibility_by_lob
# MAGIC   TO `account users`
# MAGIC   EXCEPT phi_full_access
# MAGIC   FOR TABLES
# MAGIC   WHEN has_tag_value('business_domain', 'eligibility')
# MAGIC   MATCH COLUMNS has_tag_value('business_domain', 'lob') AS lob_col
# MAGIC   USING COLUMNS (lob_col);

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Test: Non-phi_full_access users see only Commercial + MA eligibility records
# MAGIC SELECT member_id, line_of_business, plan_code, effective_date
# MAGIC FROM serverless_stable_swv01_catalog.governance.eligibility
# MAGIC ORDER BY line_of_business;
# MAGIC -- phi_full_access: all 20 rows (Commercial, Medicare Advantage, Medicaid, Dual-Eligible)
# MAGIC -- others: only Commercial + MA rows

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🟢 ACT 8: AUDIT — SHOW EFFECTIVE POLICIES
# MAGIC
# MAGIC **Talk track (3 min):**
# MAGIC > "This is the compliance officer's command. Any time your HIPAA auditor
# MAGIC > asks 'prove that analysts can't see SSNs' — this is your answer.
# MAGIC > SHOW EFFECTIVE POLICIES tells you exactly which policies apply to
# MAGIC > which table for which principals, right now. No spreadsheet. No ticket.
# MAGIC > A single SQL statement that's always current."

# COMMAND ----------

# MAGIC %sql
# MAGIC SHOW EFFECTIVE POLICIES ON TABLE serverless_stable_swv01_catalog.governance.members;

# COMMAND ----------

# MAGIC %sql
# MAGIC SHOW EFFECTIVE POLICIES ON TABLE serverless_stable_swv01_catalog.governance.prior_authorizations;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Schema-level view: all policies scoped to the governance schema
# MAGIC SHOW EFFECTIVE POLICIES ON SCHEMA serverless_stable_swv01_catalog.governance;

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Full PHI coverage report: tagged columns vs columns with active policies
# MAGIC -- This answers: "Is every PHI column actually covered?"
# MAGIC SELECT
# MAGIC   t.table_name,
# MAGIC   COUNT(DISTINCT t.column_name)   AS phi_tagged_columns,
# MAGIC   COUNT(DISTINCT t.table_name)    AS tables_with_phi
# MAGIC FROM serverless_stable_swv01_catalog.information_schema.column_tags t
# MAGIC WHERE t.schema_name = 'governance'
# MAGIC   AND t.tag_name = 'contains_phi'
# MAGIC   AND t.tag_value = 'true'
# MAGIC GROUP BY t.table_name
# MAGIC ORDER BY phi_tagged_columns DESC;

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🔵 ABAC vs. Classic Row Filters / Column Masks — Decision Framework
# MAGIC
# MAGIC | Factor | ABAC Policies | Table-Level Filters/Masks |
# MAGIC |--------|---------------|--------------------------|
# MAGIC | **Scope** | All tables within scope — new tables auto-covered | Single table, manual per-table config |
# MAGIC | **Ownership** | Catalog/schema owner; table owners CANNOT remove | Table owner manages (can modify/remove) |
# MAGIC | **Scaling** | Grows with your data estate automatically | Linear cost — N tables = N ALTER statements |
# MAGIC | **Dynamic matching** | Yes — `has_tag()`, `has_tag_value()` at query time | No — bound to specific tables/columns at creation |
# MAGIC | **Time Travel** | Allowed via EXCEPT clause | Blocked (no workaround) |
# MAGIC | **Delta Sharing** | Allowed for share owners via EXCEPT | Blocked |
# MAGIC | **Audit** | `SHOW EFFECTIVE POLICIES` | `INFORMATION_SCHEMA.ROW_FILTERS` / `COLUMN_MASKS` |
# MAGIC | **View behavior** | Owner identity, not user session (important!) | Same |
# MAGIC | **Best for** | Consistent rules across many tables; growing estates | Per-table custom logic; stable small sets |
# MAGIC
# MAGIC ### When to use each
# MAGIC - **ABAC:** Your data estate is growing and you need policies that scale without operational overhead. You have separation of duties — different teams managing classification, policies, and consumption.
# MAGIC - **Classic:** Each table has unique logic that doesn't generalize. Table owners should manage their own protections. Small, stable set of tables.
# MAGIC - **Both:** Can coexist on the same table. Conflict resolution: only ONE distinct function per user per column — different functions = access denied.

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # ⚠️ LIMITATIONS
# MAGIC
# MAGIC *ABAC Visual Summary — reference for this section*

# COMMAND ----------

displayHTML("""
<div style="text-align:center; padding:10px; background:#fff8e1; border-radius:8px; border:2px solid #f9a825;">
  <h3 style="color:#e65100; font-family:sans-serif;">⚠️ ABAC Key Limitations</h3>
  <img src="/files/Volumes/serverless_stable_swv01_catalog/governance/demo_assets/slide2.png"
       onerror="this.outerHTML='&lt;p style=&quot;font-family:sans-serif;color:#777&quot;&gt;[limitations slide unavailable — open governance/demo_assets/slide2.png]&lt;/p&gt;'"
       style="max-width:90%; border-radius:6px;" />
  <p style="font-family:sans-serif; color:#555; font-size:0.9em;">
    Source: Databricks ABAC Visual Summary — Bottom-right: Conflict Resolution + View Behavior
  </p>
</div>
""")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Critical Limitations Reference
# MAGIC
# MAGIC | Limitation | Detail | Mitigation |
# MAGIC |-----------|--------|------------|
# MAGIC | **Compute requirement** | Standard/dedicated compute on DBR < 16.4 CANNOT access ABAC-secured tables — hard block | Use Serverless (default in this workspace); or DBR 16.4+ for classic compute |
# MAGIC | **One policy per user per column** | Only ONE distinct column mask resolves per user. Two policies with different functions → **access denied, not merged** | Design conflict-free policies; use `SHOW EFFECTIVE POLICIES` to detect before it breaks |
# MAGIC | **One row filter per user per table** | Same as above for row filters | Same — design schema so at most one row filter fires per user per table |
# MAGIC | **Column tags NOT inherited** | A table tag `sensitivity_level=critical` does NOT auto-tag its columns | Must apply column tags individually (this demo has 48 columns tagged) |
# MAGIC | **Governed tags required** | ABAC policies work ONLY with governed tags, not free-form tags | Create governed tags first (run `05_governed_tags.sql`) |
# MAGIC | **Tag propagation delay** | Tag changes take **several minutes** to propagate across the metastore | Don't change tags and immediately test policies in production; wait 5+ min |
# MAGIC | **Views** | ABAC policies cannot target views directly; view access uses **owner's identity** (not the query user's session) | Be explicit: don't rely on views to narrow down what policies see |
# MAGIC | **Materialized views / Streaming tables** | Pipeline refreshes use **pipeline owner identity** — data becomes permanently masked if that owner matches a policy | Exempt pipeline owners via EXCEPT clause |
# MAGIC | **Time travel (`@v1`)** | Fails on tables with active row filters / column masks — unless principal is in EXCEPT | Add pipeline/admin principals to EXCEPT clause when time travel is needed |
# MAGIC | **Delta Sharing** | Share owners must be in EXCEPT clause to share protected tables | Explicitly exempt share service principals |
# MAGIC | **Vector Search** | ABAC policies on source tables do NOT automatically apply to vector search indexes | Manage vector search access separately |
# MAGIC | **Max 3 conditions** | A `MATCH COLUMNS` tag condition supports max 3 tag predicates | Break complex conditions into separate policies |
# MAGIC | **Tag case sensitivity** | `'full_mask'` ≠ `'Full_Mask'` — case sensitive matching | Use governed tags with lowercase enforced allowed values |
# MAGIC | **Policy limits** | 10,000/metastore; 100/catalog or schema; 50/table | Monitor with REST API; consolidate policies proactively |
# MAGIC | **No information_schema for policies** | `information_schema` has no ABAC policy table — use REST API or `SHOW EFFECTIVE POLICIES` | Automate `SHOW EFFECTIVE POLICIES` runs in compliance reporting |

# COMMAND ----------

# MAGIC %sql
# MAGIC -- LIVE DEMO: Show conflict detection behavior
# MAGIC -- Run this to see what happens when two policies conflict
# MAGIC -- (will error if ABAC policy is active AND direct mask set on same column)
# MAGIC
# MAGIC -- Try applying a direct mask on top of an active ABAC policy:
# MAGIC -- ALTER TABLE serverless_stable_swv01_catalog.governance.members
# MAGIC --   ALTER COLUMN member_id SET MASK serverless_stable_swv01_catalog.governance.mask_name;
# MAGIC -- ↑ This will CONFLICT with the hash_phi_identifiers ABAC policy → error
# MAGIC
# MAGIC -- Show effective policies to diagnose conflicts:
# MAGIC SHOW EFFECTIVE POLICIES ON TABLE serverless_stable_swv01_catalog.governance.members;

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # ✅ BEST PRACTICES
# MAGIC
# MAGIC *From: [docs.databricks.com/abac/best-practices](https://docs.databricks.com/aws/en/data-governance/unity-catalog/abac/best-practices)*
# MAGIC
# MAGIC | Practice | Why | Applied in This Demo |
# MAGIC |----------|-----|----------------------|
# MAGIC | **Standardize tag naming** | Typos silently break policies; `'Critical'` ≠ `'critical'` | All tags are lowercase snake_case; governed tags enforce allowed values |
# MAGIC | **Control who sets tags** | Tagging is a security boundary — unauthorized tag changes can expose data | Only data stewards have TAG privilege on governed tags |
# MAGIC | **Fallback for unclassified data** | New tables without tags have no protection | Schema-level `compliance=hipaa` tag ensures all tables are visible in audit queries |
# MAGIC | **Define at highest scope** | Schema-level policies auto-cover new tables | All 8 column mask policies are schema-scoped, not table-scoped |
# MAGIC | **Avoid policy sprawl** | Too many narrow policies are hard to audit and maintain | One policy per HIPAA identifier type; not one per column |
# MAGIC | **Prefer EXCEPT for principal targeting** | Cleaner than `is_account_group_member()` inside UDF for pipeline exemptions | EXCEPT used for pipeline service principals |
# MAGIC | **Plan for query-time evaluation** | ABAC evaluates at every query — UDFs add latency if complex | UDFs use simple CASE/WHEN with built-in functions, no external calls |

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # ⚡ PERFORMANCE CONSIDERATIONS
# MAGIC
# MAGIC *From: [docs.databricks.com/abac/performance](https://docs.databricks.com/aws/en/data-governance/unity-catalog/abac/performance)*
# MAGIC
# MAGIC ### The SecureView Barrier
# MAGIC ABAC policies introduce a `SecureView` barrier in the query plan that:
# MAGIC - **Prevents** complex function predicates from crossing the barrier (disables partition pruning for those predicates)
# MAGIC - **Allows** simple equality predicates to still push down: `WHERE col = 'value'` still benefits from partition filtering
# MAGIC
# MAGIC ```sql
# MAGIC -- SLOW: Function predicate blocks partition pruning
# MAGIC SELECT * FROM members WHERE date_format(date_of_birth, 'yyyy') = '1958';
# MAGIC
# MAGIC -- FASTER: Equality predicate still pushes through SecureView
# MAGIC SELECT * FROM members WHERE member_id = 'M-100001';
# MAGIC ```
# MAGIC
# MAGIC ### UDF Performance Rules
# MAGIC 1. **Use SQL UDFs, not Python UDFs** — Python UDFs cannot be inlined by the query compiler and run per-row
# MAGIC 2. **Simple CASE/WHEN** — all 14 masking functions in this demo use simple conditional logic ✓
# MAGIC 3. **Deterministic functions** — SHA2 is deterministic; enables query optimizer caching ✓
# MAGIC 4. **No external API calls in UDFs** — would serialize every row through a REST call
# MAGIC 5. **Avoid regex on large text fields** — `mask_clinical_notes` uses regex; acceptable for small volumes; swap for NLP in production
# MAGIC 6. **Test on 1M+ rows** before deploying to production (see template below)

# COMMAND ----------

# Performance test template — run to measure policy overhead
import time

def time_query(query_label, sql):
    start = time.time()
    result = spark.sql(sql)
    count = result.count()
    elapsed = time.time() - start
    print(f"{query_label}: {count} rows in {elapsed:.2f}s")

# Baseline: no masking
time_query("Baseline (no mask)",
    "SELECT member_id FROM serverless_stable_swv01_catalog.governance.members")

# With ABAC hash policy active
time_query("With ABAC hash policy",
    "SELECT member_id FROM serverless_stable_swv01_catalog.governance.members")

# With multiple policies
time_query("Full query (all columns)",
    "SELECT member_id, first_name, ssn, date_of_birth, phone_mobile FROM serverless_stable_swv01_catalog.governance.members")

# COMMAND ----------

# MAGIC %md
# MAGIC ---
# MAGIC # 🧹 CLEANUP

# COMMAND ----------

# MAGIC %sql
# MAGIC -- Drop ABAC policies (run after demo if workspace will be reused).
# MAGIC -- NOTE: ABAC DROP POLICY has NO IF EXISTS; form is
# MAGIC --   DROP POLICY <name> ON SCHEMA <catalog>.<schema>;   (verified live 2026-10-07)
# MAGIC -- These are the 10 policies THIS notebook creates. (address/zip masks live
# MAGIC -- only in 07_abac_policies.sql, so they are not dropped here.)
# MAGIC DROP POLICY hash_phi_identifiers        ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY mask_phi_dates              ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY mask_ssn_columns            ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY mask_name_columns           ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY mask_phone_columns          ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY mask_email_columns          ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY mask_beneficiary_ids        ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY mask_clinical_notes_columns ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY bh_sud_auth_protection      ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP POLICY eligibility_lob_filter      ON SCHEMA serverless_stable_swv01_catalog.governance;
# MAGIC DROP TABLE IF EXISTS serverless_stable_swv01_catalog.governance.appeals;
