-- ============================================================================
-- HLS Payer ABAC Demo — Pre-Demo Setup: Groups & User Assignment
-- Run BEFORE the demo session if you want real ABAC enforcement with actual
-- user switching (Option B). For side-by-side simulation without switching
-- users, use 06_three_tier_simulation.sql (Option A) instead.
--
-- OPTION A vs OPTION B:
--   Option A (06_three_tier_simulation.sql):
--     - No setup required
--     - Run as yourself — shows all 3 tiers in one query
--     - Best for: live demo, remote sessions, quick walkthrough
--
--   Option B (this file):
--     - Requires: account admin, test user emails for each tier
--     - Best for: hands-on lab, full enforcement validation
--     - Run queries as different users to see real masking
--
-- STEP-BY-STEP SETUP (Option B):
--   1. Run SECTION 1 as Metastore Admin to create groups
--   2. Run SECTION 2 to assign demo users to each group
--   3. Verify in Catalog Explorer → Permissions
--   4. Grant SELECT on governance schema to each group
--   5. Test: log in as each demo user and run the queries in Section 4
-- ============================================================================

USE CATALOG serverless_stable_swv01_catalog;


-- ============================================================================
-- SECTION 1: CREATE ACCOUNT-LEVEL GROUPS
-- These are Unity Catalog account groups (not workspace groups).
-- Account groups propagate to all workspaces in the metastore.
-- Run in the account console OR via API (see appendix).
-- ============================================================================

-- Note: CREATE GROUP is an account-level operation.
-- Run via: databricks groups create --display-name "phi_full_access" --profile=<account-profile>
-- OR via Databricks Account Console → User Management → Groups

-- Group 1: phi_full_access
--   Persona:   Care management nurses, clinical quality, fraud investigators
--   Access:    Unmasked PHI. Full SSN, full names, real dates, exact amounts.
--   Real-world equivalent: "Need-to-Know" clinical users under BAA

-- Group 2: phi_partial_access
--   Persona:   Member services reps, claims operations, provider network ops
--   Access:    Partially masked. Last-4 SSN, initial+asterisk names, year-month DOB
--   Real-world equivalent: "Minimum Necessary" operational users

-- Default (no group): phi_no_access
--   Persona:   Actuaries, data scientists, population health analysts, external researchers
--   Access:    Fully masked/redacted/hashed. Analytically useful, zero PHI.
--   Real-world equivalent: De-identified dataset consumers


-- ============================================================================
-- SECTION 2: ASSIGN DEMO USERS TO GROUPS
-- Replace with actual demo user email addresses before running.
-- ============================================================================

-- Option A: CLI commands (run in terminal before demo)
-- databricks groups add-member phi_full_access    --member "care.manager@payer.com"     --profile=fe-vm-fevm-serverless-stable-swv01
-- databricks groups add-member phi_partial_access --member "claims.analyst@payer.com"   --profile=fe-vm-fevm-serverless-stable-swv01
-- (no group assignment needed for the "all others" tier user)

-- Option B: Account Console → User Management → Groups → phi_full_access → Add Member


-- ============================================================================
-- SECTION 3: GRANT SCHEMA ACCESS TO GROUPS
-- Groups need SELECT privilege on the schema to run demo queries.
-- ABAC policies apply ON TOP of existing grants — they restrict, never grant.
-- ============================================================================
GRANT USE CATALOG ON CATALOG serverless_stable_swv01_catalog TO phi_full_access;
GRANT USE CATALOG ON CATALOG serverless_stable_swv01_catalog TO phi_partial_access;

GRANT USE SCHEMA ON SCHEMA serverless_stable_swv01_catalog.governance TO phi_full_access;
GRANT USE SCHEMA ON SCHEMA serverless_stable_swv01_catalog.governance TO phi_partial_access;

GRANT SELECT ON ALL TABLES IN SCHEMA serverless_stable_swv01_catalog.governance TO phi_full_access;
GRANT SELECT ON ALL TABLES IN SCHEMA serverless_stable_swv01_catalog.governance TO phi_partial_access;
-- Note: For "all others" demo user — grant SELECT without group membership.


-- ============================================================================
-- SECTION 4: VALIDATION QUERIES
-- Run these AS EACH DEMO USER to confirm ABAC is enforcing correctly.
-- ============================================================================

-- Test 1: Members table — should show different SSN and name based on group
SELECT member_id, first_name, last_name, ssn, date_of_birth
FROM serverless_stable_swv01_catalog.governance.members
WHERE member_id = 'M-100001';
-- phi_full_access:    M-100001 | Maria | Rodriguez | 423-55-6789 | 1958-03-14
-- phi_partial_access: HID-...  | M**** | R******** | ***-**-6789 | 1958-03
-- no group:           HID-...  | REDACTED | REDACTED | XXX-XX-XXXX | 1958-XX-XX

-- Test 2: Prior auths — BH records should be invisible to non-phi_full_access
SELECT auth_id, auth_type, auth_status, diagnosis_code
FROM serverless_stable_swv01_catalog.governance.prior_authorizations
WHERE auth_type = 'Behavioral Health';
-- phi_full_access:    rows returned
-- phi_partial_access: 0 rows (row filter fires)
-- no group:           0 rows (row filter fires)

-- Test 3: SHOW EFFECTIVE POLICIES — confirms policies are active
SHOW EFFECTIVE POLICIES ON TABLE serverless_stable_swv01_catalog.governance.members;

-- Test 4: Verify current user and group membership (useful for troubleshooting)
SELECT current_user() AS current_user,
       is_account_group_member('phi_full_access')    AS in_phi_full,
       is_account_group_member('phi_partial_access') AS in_phi_partial;


-- ============================================================================
-- SECTION 5: SYSTEM TABLES — Group Membership Audit
-- ============================================================================
-- Check group memberships via system tables (requires system table access)
-- SELECT * FROM system.access.group_memberships
-- WHERE group_name IN ('phi_full_access', 'phi_partial_access');


-- ============================================================================
-- APPENDIX: CLI Commands for Group Management
-- ============================================================================
-- Create account-level groups:
--   databricks groups create --display-name "phi_full_access"    --profile=one-env-admin-aws
--   databricks groups create --display-name "phi_partial_access" --profile=one-env-admin-aws
--
-- List groups:
--   databricks groups list --profile=one-env-admin-aws
--
-- Add a user to a group:
--   GROUP_ID=$(databricks groups list --profile=one-env-admin-aws --output=json | \
--     python3 -c "import json,sys; gs=json.load(sys.stdin); \
--     print(next(g['id'] for g in gs['Resources'] if g['displayName']=='phi_full_access'))")
--   USER_ID=$(databricks users list --profile=one-env-admin-aws --output=json | \
--     python3 -c "import json,sys; us=json.load(sys.stdin); \
--     print(next(u['id'] for u in us['Resources'] if u['userName']=='user@email.com'))")
--   databricks groups patch $GROUP_ID --add-member user:$USER_ID --profile=one-env-admin-aws
-- ============================================================================
