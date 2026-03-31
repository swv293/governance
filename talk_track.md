# Databricks Data Governance for HLS Payers — Talk Track

**Audience:** Governance Admin at Humana
**Duration:** 10–15 minutes
**Workspace:** fevm-serverless-stable-swv01
**Schema:** serverless_stable_swv01_catalog.governance

---

## 1. Set the Context (2 min)

> "Thanks for joining. Today I want to walk you through how Databricks helps you solve one of the hardest problems in payer data governance — knowing exactly where your PHI and PII lives, proving it's protected, and enforcing that protection consistently across every team that touches the data.

> At a payer like Humana, you've got PHI spread everywhere — member demographics, claims, pharmacy, eligibility, prior auth, care management, provider credentialing. Every one of those domains has columns that fall under HIPAA Safe Harbor, and your governance team is responsible for proving to auditors, to CMS, and to your own compliance office that you know where it is and who can see it.

> The challenge isn't that you don't have policies — it's that enforcing them consistently across hundreds of tables, thousands of columns, and dozens of analytics teams is manual, error-prone, and always lagging behind the data.

> What I'm going to show you is how Databricks turns that into an automated, continuous process: **discover, label, enforce, audit** — all from one control plane in Unity Catalog. This isn't another scanner you bolt on. It's built into the platform your data teams are already using."

---

## 2. Show the Data Landscape (2 min)

*Navigate to Catalog Explorer > serverless_stable_swv01_catalog > governance*

> "Let me show you what we're working with. I've set up a governance schema that mirrors what you'd see in a real payer environment. We've got six core tables:"

*Click through each table briefly*

> "**Members** — your core member/subscriber record. 32 columns. This is where the densest concentration of PHI lives: names, SSNs, dates of birth, addresses, phone numbers, emails, Medicare Beneficiary IDs, Medicaid IDs.

> **Claims** — professional and institutional. Diagnosis codes, procedure codes, service dates tied to individuals, financial amounts — every one of those is either clinically sensitive or PHI when linked to a member.

> **Pharmacy claims** — NDC codes, drug names, drug classes. If I can see that a member is on Pembrolizumab, I know they have cancer. That's clinically sensitive even before you link it to an identity.

> **Eligibility** — coverage spans, plan assignments, premium and subsidy amounts. The financial fields here can reveal income level.

> **Prior authorizations** — and this is the one that keeps governance admins up at night. Clinical notes are free text. They contain patient narratives, clinical justifications, denial reasons. This is PHI in its most unstructured, hardest-to-govern form.

> **Providers** — mostly public information, but tax IDs and DEA numbers are sensitive.

> Now, as a governance admin, your first question is: **across all of these tables, which columns actually contain PHI, and how do I prove it?**"

---

## 3. Column-Level Comments — The Documentation Layer (1 min)

*Click into the members table, show the column list with comments*

> "Let's start with something foundational. Every column in every table has a detailed comment that describes what it is and its sensitivity classification. Click on `ssn` — you can see: *'Full Social Security Number. PII — highly sensitive federal identifier. Must be masked for all non-privileged users.'*

> Compare that to `state_code`: *'Two-letter state code. Non-sensitive — state-level geography is not PHI under HIPAA Safe Harbor.'*

> This matters because your analysts and data engineers can see, right in the catalog, what they're looking at and why it matters. But comments are documentation — they don't enforce anything. That's where tags come in."

---

## 4. Tag-Based Governance — The Classification Layer (3 min)

*Click on the members table > Tags tab (or show tags on a column)*

> "This is where it gets powerful. We've applied a structured tag taxonomy to every column across all six tables. Let me walk you through what each tag means and why it matters for your governance workflows."

### sensitivity_level

> "First, `sensitivity_level`. This is a four-tier system: **critical, high, medium, low**.

> - **Critical** — this is your PHI and PII. SSNs, names, dates of birth, addresses, phone numbers, emails, Medicare IDs, member identifiers that link to individuals. These columns require masking for any user who doesn't have explicit PHI access.
> - **High** — clinically sensitive and financially sensitive data. Diagnosis codes, procedure codes, drug names, DRG codes, billed amounts, paid amounts. These reveal health conditions or financial details but aren't direct identifiers on their own.
> - **Medium** — internal business data. Claim types, plan codes, group numbers, administrative dates, workflow states. Useful for operations but not sensitive.
> - **Low** — public information. Provider NPIs, facility names, provider addresses. This is data you'd find on CMS's NPI registry.

> As a governance admin, this gives you a single tag you can query to answer: *show me every critical column in my catalog.* That's your HIPAA audit scope."

*Show the tags on `ssn`: sensitivity_level=critical, hipaa_type=SSN, masking_rule=FULL_MASK*

### hipaa_type

> "Second, `hipaa_type`. This maps directly to the **18 HIPAA Safe Harbor identifiers** — the specific categories that, under 45 CFR 164.514, must be removed or masked for de-identification. We've tagged columns as `NAME`, `SSN`, `DATE`, `EMAIL`, `TELEPHONE`, `GEOGRAPHIC`, `UNIQUE_IDENTIFIER`, `HEALTH_PLAN_BENEFICIARY`, `GOVERNMENT_ID`, `TAX_ID`, and `MEDICAL_RECORD`.

> Why does this matter? When your compliance team asks *'show me every column that qualifies as a HIPAA geographic identifier,'* you run one query against the tag catalog and get a definitive answer. No spreadsheet. No manual inventory."

### masking_rule

> "Third, `masking_rule`. This is the recommended masking treatment for each column: `FULL_MASK`, `PARTIAL_MASK`, `HASH`, `REDACT`, or `NONE`.

> - **FULL_MASK** for SSNs, names, drivers licenses — these get completely replaced.
> - **PARTIAL_MASK** for phone numbers, emails, dates of birth, ZIP codes — show enough for analytics but hide the identifying parts. An email becomes `m***@***.com`. A phone becomes `***-***-0101`. A ZIP shows the first 3 digits.
> - **HASH** for member IDs and subscriber IDs — you need joinability for analytics, but you don't need the actual identifier. A deterministic hash preserves referential integrity without exposing the real ID.
> - **REDACT** for diagnosis codes, drug names, financial amounts — these get nulled out or replaced with a category label for users who shouldn't see clinical or financial detail.
> - **NONE** for internal and public columns.

> The key insight here: **the masking rule tag tells your policy engine what to do, and the sensitivity_level tag tells it when to do it.** Together, they drive your row and column access policies automatically."

### Table-level tags

> "At the table level, we've tagged each table with `business_domain`, `compliance`, and `retention`.

> `business_domain` tells you which part of the payer organization owns this data — Member, Claims, Pharmacy, Eligibility, Provider, Utilization Management.

> `compliance` confirms the regulatory framework — HIPAA for all of these.

> `retention` sets the data retention policy — 7 years for member and provider data per HIPAA, 10 years for claims and pharmacy per CMS requirements.

> These are the tags your data stewards reference when building lifecycle policies."

---

## 5. Data Classification — The Automated Discovery Layer (2 min)

> "Now, everything I've shown you so far was manually applied — we defined the tags and assigned them. That's fine for a curated governance schema, but in reality you've got hundreds of schemas, thousands of tables, and new data landing every day. You can't tag everything by hand.

> This is where **Databricks Data Classification** comes in. When you enable it on this catalog or schema, the platform automatically scans your tables and detects sensitive data — names, emails, SSNs, phone numbers, addresses — using AI-based classifiers. It assigns **system tags** that map to the same types of identifiers we've been discussing.

> The scan is **incremental and smart**. It doesn't re-scan unchanged data. When new tables land or existing tables get new columns, classification picks them up automatically.

> For your governance team, this means: **you set the scope, and the platform keeps classification current.** You focus on policy, not scanning jobs."

*If the workspace has classification enabled, show the classification results UI. Otherwise, describe it.*

> "The classification results show you, per table and per column, what was detected and what tag was applied. You can review, override, or accept. And you can query the results programmatically through system tables — `system.data_classification.results` — to feed into your governance dashboards and audit workflows."

---

## 6. From Tags to Masking Policies — The Enforcement Layer (3 min)

> "Here's the 'aha' moment for governance admins. Tags alone don't protect anything — they're labels. The power comes when you use those labels to **drive masking policies** that enforce access rules automatically.

> Let me show you what that looks like conceptually."

*You can describe this or, if you have permissions, create a live masking function.*

> "In Unity Catalog, I can create a masking function that reads the tags on a column and the group membership of the querying user, and decides what they see.

> Here's a simple example for SSN:

> - A user in the `phi_full_access` group — your care management team, your HEDIS analysts — sees the full SSN: `423-55-6789`.
> - Everyone else sees: `***-**-6789` — a partial mask that preserves the last four for verification workflows.
> - A user in the `de_identified_only` group — your actuarial sandbox, your external research partners — sees: `REDACTED`.

> The critical thing is: **this policy applies to every column tagged with `masking_rule=FULL_MASK` and `hipaa_type=SSN`**. I don't write a separate policy for `members.ssn` and `claims.member_ssn` and `eligibility.member_ssn`. I write one tag-based policy and it covers every SSN column in the catalog, current and future.

> That's the shift from table-by-table governance to **tag-driven governance at scale**. One policy, hundreds of columns, consistent enforcement."

### Walk through the access tiers

> "In practice, for a payer like Humana, you'd set up three or four access tiers:

> 1. **PHI Full Access** — care management, clinical quality (HEDIS/STARS), fraud investigation. These users see everything because their job requires it.
> 2. **PHI Partial** — provider operations, network adequacy, member services. They see partial masks — enough to do their job, not enough to identify.
> 3. **De-Identified** — actuarial, population health analytics, external research partners, sandbox environments. They see hashed IDs and redacted clinical/financial fields. They can still do aggregate analytics.
> 4. **No Access** — users who shouldn't see the table at all. Row-level security or table-level grants handle this.

> The tags you've seen — `sensitivity_level`, `hipaa_type`, `masking_rule` — are the inputs that make these tiers work without manual column-by-column configuration."

---

## 7. Governance Queries — The Audit Layer (2 min)

> "Let me show you some queries a governance admin would actually run day-to-day."

*Run or describe these queries:*

### Where is all my PHI?

```sql
SELECT table_name, column_name, tag_value as hipaa_type
FROM serverless_stable_swv01_catalog.information_schema.column_tags
WHERE schema_name = 'governance'
  AND tag_name = 'hipaa_type'
ORDER BY table_name, column_name
```

> "This gives me every PHI column across every table in one query. That's your HIPAA audit inventory — generated live, always current."

### Which columns need masking?

```sql
SELECT table_name, column_name,
  MAX(CASE WHEN tag_name = 'masking_rule' THEN tag_value END) as masking_rule,
  MAX(CASE WHEN tag_name = 'sensitivity_level' THEN tag_value END) as sensitivity
FROM serverless_stable_swv01_catalog.information_schema.column_tags
WHERE schema_name = 'governance'
  AND tag_name IN ('masking_rule', 'sensitivity_level')
GROUP BY table_name, column_name
HAVING MAX(CASE WHEN tag_name = 'masking_rule' THEN tag_value END) != 'NONE'
ORDER BY sensitivity DESC, table_name
```

> "This is your masking coverage report. Every column that requires some form of masking, ranked by sensitivity. Hand this to your compliance officer and they can see exactly what's protected and how."

### Sensitivity distribution

```sql
SELECT tag_value as sensitivity_level, count(*) as column_count
FROM serverless_stable_swv01_catalog.information_schema.column_tags
WHERE schema_name = 'governance' AND tag_name = 'sensitivity_level'
GROUP BY tag_value
ORDER BY
  CASE tag_value WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END
```

> "A quick summary: how many columns fall into each sensitivity tier. This is the kind of metric you'd put on a governance dashboard and track over time as new data domains come online."

---

## 8. Cost Visibility (30 sec)

> "One quick note on cost. When you enable Data Classification, usage appears in your `system.billing.usage` table with `billing_origin_product = 'DATA_CLASSIFICATION'`. Your FinOps team can see exactly what classification costs, broken down by catalog and user. And because scanning is incremental, you're not paying to re-scan unchanged data every day."

---

## 9. Close — HLS Payer Outcomes (1 min)

> "Let me bring this back to what this means for your governance organization:

> **First — faster HIPAA audits.** Instead of manually inventorying PHI across spreadsheets and tribal knowledge, you have a live, queryable catalog that shows where PHI is, what type it is, and what controls apply. That's audit evidence generated on demand.

> **Second — reduced risk of accidental exposure.** When an analyst spins up a new notebook in a sandbox environment, they get masked data by default. The policy follows the tag, not the table. No one has to remember to apply the mask — it's automatic.

> **Third — scalable governance as you grow.** Today we looked at six tables. When you add SDOH data, care management notes, provider performance, Star Ratings analytics — the same tag taxonomy and the same masking policies extend to those new domains without rewriting anything.

> **Fourth — separation of concerns.** Your data engineers build the tables. Your governance team defines the tags and policies. Your compliance team audits the results. Everyone works in the same platform but with clear ownership boundaries.

> So my question for you is: **which domain would you want to start with for a pilot?** Claims analytics is usually the highest-volume, highest-risk starting point. But if you've got a near-term audit on member data or a new analytics use case in pharmacy, we can start there."

---

## Appendix: Demo Data Reference

| Table | Rows | Key Sensitive Fields |
|-------|------|---------------------|
| members | 20 | SSN, DOB, name, address, phone, email, Medicare/Medicaid IDs |
| claims | 30 | Diagnosis codes (E11.9, I21.0, G30.9, C34.90), procedures, financials ($125–$52K) |
| providers | 10 | Tax IDs, DEA numbers |
| eligibility | 20 | Premium/subsidy amounts |
| pharmacy_claims | 20 | NDC codes, drug names (Metformin, Pembrolizumab), drug classes |
| prior_authorizations | 10 | Clinical notes (free text PHI), denial reasons, diagnosis codes |

**Humana-branded plans in data:** Gold Plus HMO-POS, Choice PPO, ChoiceCare, HMOx, Healthy Horizons Medicaid, Dual Complete D-SNP, Honor MA-PD

**Lines of business:** Commercial, Medicare Advantage, Medicaid, Dual-Eligible

**Geography anchor:** Louisville, KY (Humana HQ) with multi-state spread (IL, GA, FL, TX, OH, TN, NV)
