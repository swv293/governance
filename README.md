# HLS Payer ABAC Governance Demo

Attribute-Based Access Control (ABAC) for HIPAA-governed data in Unity Catalog.
Shows how a handful of **schema-scoped policies** keyed off **governed tags**
replace thousands of per-table GRANT/MASK statements: tag a new column and it's
instantly protected, no `ALTER TABLE`.

- **Catalog.Schema:** `serverless_stable_swv01_catalog.governance`
- **Compute:** Serverless, or classic DBR 16.4+ (ABAC policies require it)

## Run order

| # | File | What it does |
|---|------|--------------|
| 01 | `01_create_schema_and_tables.sql` | Create the `governance` schema and 6 payer tables |
| 02 | `02_insert_data.sql` | Load synthetic member/claims/auth data |
| 03 | `03_create_tags.sql` | Column tags, incl. the row-filter key tags (`auth_type`, `line_of_business`) |
| 04 | `04_masking_functions.sql` | 14 masking UDFs (`mask_ssn`, `hash_identifier`, `mask_date_of_birth`, …) |
| 05 | `05_governed_tags.sql` | Governed tags — **required** for ABAC matching (run as Metastore/Account Admin) |
| 06 | `06_three_tier_simulation.sql` | See all three access tiers side-by-side (no user switching) |
| 07 | `07_abac_policies.sql` | Schema-scoped `COLUMN MASK` / `ROW FILTER` policies via `MATCH COLUMNS` |
| 08 | `08_pre_demo_setup.sql` | (Optional) groups + user assignment for real multi-user enforcement |

`ABAC_HLS_Payer_Demo.py` is the end-to-end presenter notebook (30- and 60-minute
tracks) that walks through the above with talk track and visuals.

## Retargeting to another catalog
Every script hard-codes `serverless_stable_swv01_catalog`. To run elsewhere,
find-and-replace that catalog name across all `.sql` files and the notebook
(the schema `governance` can stay).

## Row-filter policies — governed-tag prerequisite ⚠️
The two **row-filter** policies in `07` match on governed-tag *values* that must
already be allowed on the metastore:
- `bh_sud_auth_protection` → `hipaa_type = 'auth_type'`
- `eligibility_lob_filter` → `business_domain = 'lob'` (and table tag `'eligibility'`)

On a **fresh** metastore `05_governed_tags.sql` creates these with the right
allowed values and everything works. On an **existing** metastore `CREATE TAG IF
NOT EXISTS` will NOT add the values to a tag that already exists (see the footgun
note in `05`), and a generic tag like `business_domain` may already be owned by
another project with a different value list — matching then fails with
`UC_TAG_POLICY_VALUE_NOT_ALLOWED`. Add the values via an account-admin tag-policy
update (or point the row filters at demo-dedicated governed tags) before running
Act 7. The **column-mask** policies have no such dependency.

**Deployment status (FEVM `serverless_stable_swv01_catalog.governance`, verified 2026-10-07):**
all 10 column-mask policies are deployed and verified; the 2 row-filter policies
are **not** deployed pending the governed-tag values above.

## Access tiers
| Tier | Group | Sees |
|------|-------|------|
| Full PHI | `phi_full_access` | Unmasked identifiers and dates |
| Partial | `phi_partial_access` | Hashed IDs, generalized dates |
| None | (default `account users`) | Fully masked |
