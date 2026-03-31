-- ============================================================================
-- HLS Payer Governance Demo — Schema & Tables
-- Target: Humana-style governance admin walkthrough
-- Catalog: serverless_stable_swv01_catalog
-- Schema: governance
-- ============================================================================

-- 1. Create the governance schema
CREATE SCHEMA IF NOT EXISTS serverless_stable_swv01_catalog.governance
COMMENT 'HLS payer governance demo — member, claims, provider, eligibility, pharmacy, and authorization tables with PHI/PII governance tags for data classification and masking policy walkthrough.';

-- 2. Members table — the core member/subscriber record
CREATE OR REPLACE TABLE serverless_stable_swv01_catalog.governance.members (
  member_id           STRING    COMMENT 'Unique member identifier (UUID). PHI — HIPAA individual identifier.',
  subscriber_id       STRING    COMMENT 'Subscriber/policy-holder ID linking dependents. PHI — HIPAA individual identifier.',
  first_name          STRING    COMMENT 'Member legal first name. PII — directly identifies an individual.',
  last_name           STRING    COMMENT 'Member legal last name. PII — directly identifies an individual.',
  middle_initial      STRING    COMMENT 'Single-character middle initial. PII — contributes to identification.',
  date_of_birth       DATE      COMMENT 'Date of birth (YYYY-MM-DD). PHI — HIPAA protected date element.',
  gender              STRING    COMMENT 'Administrative gender (Male/Female/Other/Unknown). Non-sensitive demographic.',
  ssn                 STRING    COMMENT 'Full Social Security Number (XXX-XX-XXXX). PII — highly sensitive federal identifier. Must be masked for all non-privileged users.',
  drivers_license     STRING    COMMENT 'State drivers license number. PII — government-issued identifier.',
  address_line1       STRING    COMMENT 'Street address line 1. PHI — HIPAA geographic subdivision smaller than state.',
  address_line2       STRING    COMMENT 'Street address line 2 (apt, suite, etc.). PHI — HIPAA geographic subdivision.',
  city                STRING    COMMENT 'City of residence. PHI — HIPAA geographic subdivision smaller than state.',
  state_code          STRING    COMMENT 'Two-letter state code. Non-sensitive — state-level geography is not PHI under HIPAA Safe Harbor.',
  zip_code            STRING    COMMENT 'Five-digit ZIP code. PHI — HIPAA geographic subdivision (3-digit ZIP is safe harbor; 5-digit is PHI).',
  county              STRING    COMMENT 'County of residence. PHI — geographic subdivision smaller than state.',
  phone_home          STRING    COMMENT 'Home phone number. PHI — HIPAA telephone number identifier.',
  phone_mobile        STRING    COMMENT 'Mobile phone number. PHI — HIPAA telephone number identifier.',
  email               STRING    COMMENT 'Email address. PHI — HIPAA electronic mail address identifier.',
  preferred_language  STRING    COMMENT 'Preferred communication language. Non-sensitive demographic attribute.',
  race                STRING    COMMENT 'Self-reported race. Sensitive demographic — used in health equity analytics.',
  ethnicity           STRING    COMMENT 'Self-reported ethnicity. Sensitive demographic — used in health equity analytics.',
  marital_status      STRING    COMMENT 'Marital status. Non-sensitive demographic attribute.',
  pcp_npi             STRING    COMMENT 'National Provider Identifier of assigned primary care physician. Non-sensitive provider reference.',
  medicare_beneficiary_id STRING COMMENT 'Medicare Beneficiary Identifier (MBI). PHI — federal health plan beneficiary number.',
  medicaid_id         STRING    COMMENT 'State Medicaid ID. PHI — state health plan beneficiary number.',
  group_number        STRING    COMMENT 'Employer group number for coverage. Non-sensitive plan attribute.',
  plan_code           STRING    COMMENT 'Health plan product code (e.g., HMO, PPO, MA-PD). Non-sensitive plan attribute.',
  effective_date      DATE      COMMENT 'Coverage effective date. Non-sensitive administrative date.',
  termination_date    DATE      COMMENT 'Coverage termination date (NULL if active). Non-sensitive administrative date.',
  is_active           BOOLEAN   COMMENT 'Whether member coverage is currently active. Non-sensitive status flag.',
  created_at          TIMESTAMP COMMENT 'Record creation timestamp. Non-sensitive audit metadata.',
  updated_at          TIMESTAMP COMMENT 'Last record update timestamp. Non-sensitive audit metadata.',
  source_system       STRING    COMMENT 'Originating source system (e.g., EPIC, FACETS, QNXT). Non-sensitive lineage metadata.'
)
COMMENT 'Core member/subscriber table for an HLS payer. Contains demographics, contact information, government identifiers, and plan enrollment data. Multiple columns contain PHI and PII subject to HIPAA Privacy Rule and require classification-driven masking policies.'
TBLPROPERTIES ('quality' = 'gold', 'domain' = 'member', 'phi_contains' = 'true');

-- 3. Claims table — medical/institutional/professional claims
CREATE OR REPLACE TABLE serverless_stable_swv01_catalog.governance.claims (
  claim_id            STRING    COMMENT 'Unique claim identifier. Non-sensitive business key.',
  member_id           STRING    COMMENT 'Foreign key to members table. PHI — links to identifiable individual.',
  subscriber_id       STRING    COMMENT 'Subscriber ID for the claim. PHI — links to identifiable individual.',
  claim_type          STRING    COMMENT 'Claim type: Professional (CMS-1500), Institutional (UB-04), Dental. Non-sensitive classification.',
  claim_status        STRING    COMMENT 'Adjudication status: Paid, Denied, Pending, Adjusted. Non-sensitive workflow state.',
  service_date_from   DATE      COMMENT 'First date of service. PHI — HIPAA date directly related to an individual.',
  service_date_to     DATE      COMMENT 'Last date of service. PHI — HIPAA date directly related to an individual.',
  admission_date      DATE      COMMENT 'Inpatient admission date (institutional claims). PHI — HIPAA date.',
  discharge_date      DATE      COMMENT 'Inpatient discharge date (institutional claims). PHI — HIPAA date.',
  diagnosis_code_primary STRING COMMENT 'Primary ICD-10-CM diagnosis code. Sensitive clinical — reveals health conditions.',
  diagnosis_code_2    STRING    COMMENT 'Secondary ICD-10-CM diagnosis code. Sensitive clinical data.',
  diagnosis_code_3    STRING    COMMENT 'Tertiary ICD-10-CM diagnosis code. Sensitive clinical data.',
  procedure_code      STRING    COMMENT 'CPT/HCPCS procedure code. Sensitive clinical — reveals treatments received.',
  procedure_modifier  STRING    COMMENT 'CPT modifier (e.g., 25, 59, GT for telehealth). Non-sensitive billing attribute.',
  revenue_code        STRING    COMMENT 'Revenue code for institutional claims. Non-sensitive billing classification.',
  place_of_service    STRING    COMMENT 'CMS place-of-service code (11=Office, 21=Inpatient, 23=ER). Non-sensitive.',
  rendering_provider_npi STRING COMMENT 'NPI of rendering/treating provider. Non-sensitive provider reference.',
  billing_provider_npi   STRING COMMENT 'NPI of billing provider/facility. Non-sensitive provider reference.',
  referring_provider_npi STRING COMMENT 'NPI of referring provider. Non-sensitive provider reference.',
  facility_name       STRING    COMMENT 'Name of servicing facility. Non-sensitive provider attribute.',
  billed_amount       DECIMAL(12,2) COMMENT 'Total amount billed by provider. Sensitive financial — reveals cost of care.',
  allowed_amount      DECIMAL(12,2) COMMENT 'Payer-allowed amount after contractual adjustments. Sensitive financial.',
  paid_amount         DECIMAL(12,2) COMMENT 'Amount paid by payer to provider. Sensitive financial.',
  member_liability    DECIMAL(12,2) COMMENT 'Member out-of-pocket responsibility (copay + coinsurance + deductible). Sensitive financial.',
  copay_amount        DECIMAL(12,2) COMMENT 'Copay collected or owed. Sensitive financial.',
  coinsurance_amount  DECIMAL(12,2) COMMENT 'Coinsurance amount. Sensitive financial.',
  deductible_amount   DECIMAL(12,2) COMMENT 'Deductible applied. Sensitive financial.',
  drg_code            STRING    COMMENT 'MS-DRG code for inpatient stays. Sensitive clinical — reveals admission reason.',
  authorization_number STRING   COMMENT 'Prior authorization reference number. Non-sensitive administrative reference.',
  received_date       DATE      COMMENT 'Date claim was received by payer. Non-sensitive administrative date.',
  adjudicated_date    DATE      COMMENT 'Date claim was adjudicated. Non-sensitive administrative date.',
  paid_date           DATE      COMMENT 'Date payment was issued. Non-sensitive administrative date.',
  created_at          TIMESTAMP COMMENT 'Record creation timestamp. Non-sensitive audit metadata.',
  updated_at          TIMESTAMP COMMENT 'Last record update timestamp. Non-sensitive audit metadata.'
)
COMMENT 'Medical claims table (professional and institutional). Contains service dates, diagnoses, procedures, financial amounts, and provider references. Diagnosis and procedure codes are clinically sensitive; financial amounts are financially sensitive; service dates linked to members are PHI.'
TBLPROPERTIES ('quality' = 'gold', 'domain' = 'claims', 'phi_contains' = 'true');

-- 4. Providers table — provider directory/credentialing
CREATE OR REPLACE TABLE serverless_stable_swv01_catalog.governance.providers (
  provider_id         STRING    COMMENT 'Internal provider identifier. Non-sensitive business key.',
  npi                 STRING    COMMENT 'National Provider Identifier (10-digit). Non-sensitive — NPI is public.',
  tax_id              STRING    COMMENT 'Provider Tax Identification Number (EIN or SSN). PII — sensitive financial identifier. Must be masked.',
  first_name          STRING    COMMENT 'Provider first name (individual providers). Non-sensitive — publicly available.',
  last_name           STRING    COMMENT 'Provider last name (individual providers). Non-sensitive — publicly available.',
  organization_name   STRING    COMMENT 'Practice or facility legal name. Non-sensitive — publicly available.',
  specialty_code      STRING    COMMENT 'CMS specialty code (e.g., 08=Family Practice). Non-sensitive classification.',
  specialty_desc      STRING    COMMENT 'Human-readable specialty description. Non-sensitive.',
  provider_type       STRING    COMMENT 'Provider type: Individual, Organization. Non-sensitive classification.',
  network_status      STRING    COMMENT 'In-Network, Out-of-Network, or Tier designation. Non-sensitive plan attribute.',
  credential          STRING    COMMENT 'Professional credential (MD, DO, NP, PA). Non-sensitive.',
  dea_number          STRING    COMMENT 'DEA registration number for prescribers. Sensitive — controlled substance authority.',
  license_number      STRING    COMMENT 'State medical license number. Non-sensitive — publicly available.',
  license_state       STRING    COMMENT 'State of licensure. Non-sensitive.',
  address_line1       STRING    COMMENT 'Practice address line 1. Non-sensitive — publicly listed.',
  city                STRING    COMMENT 'Practice city. Non-sensitive.',
  state_code          STRING    COMMENT 'Practice state. Non-sensitive.',
  zip_code            STRING    COMMENT 'Practice ZIP code. Non-sensitive.',
  phone               STRING    COMMENT 'Practice phone number. Non-sensitive — publicly listed.',
  fax                 STRING    COMMENT 'Practice fax number. Non-sensitive.',
  accepting_patients  BOOLEAN   COMMENT 'Whether provider is accepting new patients. Non-sensitive.',
  effective_date      DATE      COMMENT 'Network participation effective date. Non-sensitive.',
  termination_date    DATE      COMMENT 'Network participation end date. Non-sensitive.',
  created_at          TIMESTAMP COMMENT 'Record creation timestamp. Non-sensitive audit metadata.',
  updated_at          TIMESTAMP COMMENT 'Last record update timestamp. Non-sensitive audit metadata.'
)
COMMENT 'Provider directory and credentialing table. Most provider information is publicly available (NPI, name, address). Tax ID and DEA number are sensitive and require masking. Used for network adequacy reporting and claims adjudication.'
TBLPROPERTIES ('quality' = 'gold', 'domain' = 'provider', 'phi_contains' = 'false');

-- 5. Eligibility/enrollment table — coverage spans
CREATE OR REPLACE TABLE serverless_stable_swv01_catalog.governance.eligibility (
  eligibility_id      STRING    COMMENT 'Unique eligibility record identifier. Non-sensitive business key.',
  member_id           STRING    COMMENT 'Foreign key to members table. PHI — links to identifiable individual.',
  subscriber_id       STRING    COMMENT 'Subscriber ID. PHI — links to identifiable individual.',
  plan_code           STRING    COMMENT 'Health plan product code. Non-sensitive plan attribute.',
  plan_description    STRING    COMMENT 'Plan product description (e.g., Humana Gold Plus HMO). Non-sensitive.',
  line_of_business    STRING    COMMENT 'Line of business: Commercial, Medicare Advantage, Medicaid, Dual-Eligible. Non-sensitive.',
  coverage_type       STRING    COMMENT 'Coverage type: Medical, Dental, Vision, Pharmacy. Non-sensitive classification.',
  benefit_package     STRING    COMMENT 'Benefit package tier (Platinum, Gold, Silver, Bronze). Non-sensitive.',
  effective_date      DATE      COMMENT 'Coverage effective date. Non-sensitive administrative date.',
  termination_date    DATE      COMMENT 'Coverage termination date (NULL if active). Non-sensitive administrative date.',
  termination_reason  STRING    COMMENT 'Reason for coverage termination. Non-sensitive administrative.',
  group_number        STRING    COMMENT 'Employer group number. Non-sensitive.',
  group_name          STRING    COMMENT 'Employer group name. Non-sensitive.',
  cobra_flag          BOOLEAN   COMMENT 'Whether member is on COBRA continuation. Non-sensitive status.',
  exchange_flag       BOOLEAN   COMMENT 'Whether enrolled via ACA marketplace exchange. Non-sensitive status.',
  premium_amount      DECIMAL(10,2) COMMENT 'Monthly premium amount. Sensitive financial — reveals cost information.',
  subsidy_amount      DECIMAL(10,2) COMMENT 'Premium tax credit/subsidy amount. Sensitive financial — reveals income level.',
  created_at          TIMESTAMP COMMENT 'Record creation timestamp. Non-sensitive audit metadata.',
  updated_at          TIMESTAMP COMMENT 'Last record update timestamp. Non-sensitive audit metadata.'
)
COMMENT 'Member eligibility and enrollment spans. Tracks coverage periods, plan assignments, and enrollment details. Member linkage columns are PHI; premium and subsidy amounts are financially sensitive.'
TBLPROPERTIES ('quality' = 'gold', 'domain' = 'eligibility', 'phi_contains' = 'true');

-- 6. Pharmacy claims table
CREATE OR REPLACE TABLE serverless_stable_swv01_catalog.governance.pharmacy_claims (
  rx_claim_id         STRING    COMMENT 'Unique pharmacy claim identifier. Non-sensitive business key.',
  member_id           STRING    COMMENT 'Foreign key to members table. PHI — links to identifiable individual.',
  fill_date           DATE      COMMENT 'Date prescription was filled. PHI — HIPAA date related to individual.',
  ndc_code            STRING    COMMENT 'National Drug Code (11-digit). Sensitive clinical — reveals medications.',
  drug_name           STRING    COMMENT 'Drug brand or generic name. Sensitive clinical — reveals medications and conditions.',
  drug_class          STRING    COMMENT 'Therapeutic drug class. Sensitive clinical — reveals condition categories.',
  quantity_dispensed   DECIMAL(10,2) COMMENT 'Quantity of drug dispensed. Non-sensitive dispensing detail.',
  days_supply         INT       COMMENT 'Days supply dispensed. Non-sensitive dispensing detail.',
  refill_number       INT       COMMENT 'Refill number (0 = original fill). Non-sensitive dispensing detail.',
  prescriber_npi      STRING    COMMENT 'NPI of prescribing provider. Non-sensitive provider reference.',
  pharmacy_npi        STRING    COMMENT 'NPI of dispensing pharmacy. Non-sensitive provider reference.',
  pharmacy_name       STRING    COMMENT 'Dispensing pharmacy name. Non-sensitive.',
  formulary_tier      STRING    COMMENT 'Formulary tier (1=Generic, 2=Preferred Brand, 3=Non-Preferred, 4=Specialty). Non-sensitive.',
  daw_code            STRING    COMMENT 'Dispense As Written code. Non-sensitive.',
  ingredient_cost     DECIMAL(10,2) COMMENT 'Drug ingredient cost. Sensitive financial.',
  dispensing_fee      DECIMAL(10,2) COMMENT 'Pharmacy dispensing fee. Sensitive financial.',
  paid_amount         DECIMAL(10,2) COMMENT 'Amount paid by plan. Sensitive financial.',
  member_copay        DECIMAL(10,2) COMMENT 'Member copay amount. Sensitive financial.',
  prior_auth_required BOOLEAN   COMMENT 'Whether prior authorization was required. Non-sensitive.',
  specialty_drug_flag BOOLEAN   COMMENT 'Whether drug is a specialty medication. Non-sensitive classification.',
  created_at          TIMESTAMP COMMENT 'Record creation timestamp. Non-sensitive audit metadata.',
  updated_at          TIMESTAMP COMMENT 'Last record update timestamp. Non-sensitive audit metadata.'
)
COMMENT 'Pharmacy/prescription drug claims. Contains drug dispensing details, NDC codes, and financial amounts. Drug names and NDC codes are clinically sensitive (reveal conditions); financial amounts are financially sensitive.'
TBLPROPERTIES ('quality' = 'gold', 'domain' = 'pharmacy', 'phi_contains' = 'true');

-- 7. Prior authorizations table
CREATE OR REPLACE TABLE serverless_stable_swv01_catalog.governance.prior_authorizations (
  auth_id             STRING    COMMENT 'Unique authorization identifier. Non-sensitive business key.',
  member_id           STRING    COMMENT 'Foreign key to members table. PHI — links to identifiable individual.',
  auth_type           STRING    COMMENT 'Authorization type: Inpatient, Outpatient, Pharmacy, DME, Behavioral Health. Non-sensitive classification.',
  auth_status         STRING    COMMENT 'Authorization status: Approved, Denied, Pended, Modified, Withdrawn. Non-sensitive workflow state.',
  request_date        DATE      COMMENT 'Date authorization was requested. PHI — date related to individual care.',
  decision_date       DATE      COMMENT 'Date authorization decision was made. Non-sensitive administrative date.',
  effective_date      DATE      COMMENT 'Authorization effective start date. Non-sensitive.',
  expiration_date     DATE      COMMENT 'Authorization expiration date. Non-sensitive.',
  diagnosis_code      STRING    COMMENT 'Primary ICD-10 diagnosis code for the request. Sensitive clinical.',
  procedure_code      STRING    COMMENT 'Requested CPT/HCPCS procedure code. Sensitive clinical.',
  requesting_provider_npi STRING COMMENT 'NPI of requesting provider. Non-sensitive provider reference.',
  servicing_provider_npi  STRING COMMENT 'NPI of approved servicing provider. Non-sensitive provider reference.',
  facility_name       STRING    COMMENT 'Facility where service will be rendered. Non-sensitive.',
  units_requested     INT       COMMENT 'Number of units/visits requested. Non-sensitive.',
  units_approved      INT       COMMENT 'Number of units/visits approved. Non-sensitive.',
  denial_reason       STRING    COMMENT 'Denial reason description. Sensitive clinical — may reveal clinical details.',
  clinical_notes      STRING    COMMENT 'Clinical justification notes. PHI — contains clinical narrative with potential patient details.',
  peer_reviewer       STRING    COMMENT 'Name of peer-to-peer reviewer. Non-sensitive internal staff.',
  urgency             STRING    COMMENT 'Urgency level: Routine, Urgent, Emergent. Non-sensitive classification.',
  created_at          TIMESTAMP COMMENT 'Record creation timestamp. Non-sensitive audit metadata.',
  updated_at          TIMESTAMP COMMENT 'Last record update timestamp. Non-sensitive audit metadata.'
)
COMMENT 'Prior authorization (utilization management) table. Tracks authorization requests, clinical justification, and approval decisions. Clinical notes and diagnosis/procedure codes are sensitive. Critical for demonstrating governance over UM workflows.'
TBLPROPERTIES ('quality' = 'gold', 'domain' = 'utilization_management', 'phi_contains' = 'true');
