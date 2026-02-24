# Holder Values

The four holder fields identify **who** is affected by a piece of legislation. Each is a JSONB map where keys are actor tags and values are `true`.

Source of truth: Airtable actor taxonomy, replicated in `backend/lib/sertantai_legal/legal/taxa/actor_definitions.ex`.

## Holder Columns

| Column | Populated By | DB Count | Description |
|--------|-------------|----------|-------------|
| `duty_holder` | Governed actors | 2,606 | Entities with legal duties/obligations |
| `rights_holder` | Governed actors | 1,943 | Entities with legal rights/entitlements |
| `responsibility_holder` | Government actors | 2,652 | Government bodies with responsibilities |
| `power_holder` | Government actors | 2,244 | Government bodies with statutory powers |

**Format**: `{"Ind: Person": true, "Org: Employer": true}`

**Governed** actors (individuals, businesses, specialists, supply chain) appear in `duty_holder` and `rights_holder`.
**Government** actors appear in `responsibility_holder` and `power_holder`.

## Prefix Taxonomy

Tags use a hierarchical prefix system:

| Prefix | Category | Example |
|--------|----------|---------|
| `Ind:` | Individual person | `Ind: Person`, `Ind: Employee` |
| `Org:` | Organisation/business | `Org: Employer`, `Org: Company` |
| `SC:` | Supply chain actor | `SC: Supplier`, `SC: Manufacturer` |
| `SC: C:` | Construction supply chain | `SC: C: Contractor`, `SC: C: Designer` |
| `SC: T&L:` | Transport & logistics | `SC: T&L: Driver`, `SC: T&L: Carrier` |
| `Spc:` | Specialist/professional | `Spc: Inspector`, `Spc: Engineer` |
| `Svc:` | Service provider | `Svc: Installer`, `Svc: Maintainer` |
| `Env:` | Environmental actor | `Env: Recycler`, `Env: Polluter` |
| `Gvt:` | Government body | `Gvt: Minister`, `Gvt: Authority` |
| `Gvt: Agency:` | Named agency | `Gvt: Agency: Health and Safety Executive` |
| `Gvt: Authority:` | Typed authority | `Gvt: Authority: Local` |
| `Gvt: Ministry:` | Named ministry | `Gvt: Ministry: Treasury` |
| `Gvt: Devolved Admin:` | Devolved administration | `Gvt: Devolved Admin: Scottish Parliament` |
| `Gvt: Minister:` | Named minister role | `Gvt: Minister: Secretary of State for Defence` |
| `Gvt: Emergency Services:` | Emergency service | `Gvt: Emergency Services: Police` |
| `EU:` | EU institution | `EU: Commission` |
| `HM Forces` | Armed forces | `HM Forces`, `HM Forces: Navy` |
| `Maritime:` | Maritime roles | `Maritime: master`, `Maritime: crew` |
| (none) | Unprefixed governed | `Operator`, `Organisation`, `Public` |

---

## Governed Actors (duty_holder, rights_holder)

### Individual (`Ind:`)

| Tag | Duty | Rights | Description |
|-----|-----:|-------:|-------------|
| `Ind: Person` | 2,066 | 1,442 | Generic person/individual |
| `Ind: Applicant` | 359 | 264 | Person applying for licence/permit |
| `Ind: Holder` | 179 | 103 | Generic holder (of licence, certificate, etc.) |
| `Ind: Employee` | 155 | 46 | Worker in employment relationship |
| `Ind: Manager` | 153 | 19 | Manager of operation/facility |
| `Ind: Authorised Person` | 152 | 172 | Person authorised to act |
| `Ind: Appointed Person` | 75 | 45 | Formally appointed person |
| `Ind: Relevant Person` | 63 | 32 | Person relevant to specific provisions |
| `Ind: User` | 58 | 27 | User of equipment/facility |
| `Ind: Responsible Person` | 57 | 25 | Designated responsible person |
| `Ind: Self-employed Worker` | 54 | 1 | Self-employed individual |
| `Ind: Worker` | 51 | 30 | Worker (broader than employee) |
| `Ind: Licensee` | 47 | 23 | Holder of a licence |
| `Ind: Young Person` | 45 | 11 | Child or young person |
| `Ind: Chair` | 36 | 16 | Chairman/chairperson |
| `Ind: Licence Holder` | 27 | 19 | Specific licence holder |
| `Ind: Supervisor` | 21 | 7 | Person supervising work |
| `Ind: Duty Holder` | 17 | 6 | Named duty holder in legislation |
| `Ind: Competent Person` | 12 | 4 | Person deemed competent |
| `Ind: Diver` | 3 | 0 | Commercial/professional diver |
| `Ind: Suitable Person` | 1 | 3 | Person deemed suitable |
| `Ind: Dutyholder` | 2 | 0 | **Legacy variant** of `Ind: Duty Holder` |

### Organisation (`Org:`)

| Tag | Duty | Rights | Description |
|-----|-----:|-------:|-------------|
| `Org: Company` | 594 | 155 | Company/business/enterprise/body corporate |
| `Org: Owner` | 480 | 398 | Owner of property/installation/mine |
| `Org: Occupier` | 274 | 103 | Occupier of premises |
| `Org: Employer` | 178 | 58 | Employer |
| `Org: Partnership` | 124 | 16 | Partnership/unincorporated body |
| `Org: Lessee` | 59 | 40 | Lessee of property |
| `Org: Landlord` | 36 | 28 | Landlord |
| `Org: Investor` | 1 | 0 | Investor |

### Supply Chain (`SC:`)

| Tag | Duty | Rights | Description |
|-----|-----:|-------:|-------------|
| `SC: Agent` | 119 | 31 | Agent acting on behalf of another |
| `SC: Supplier` | 96 | 52 | Supplier of goods/services |
| `SC: T&L: Carrier` | 79 | 19 | Transporter/carrier of goods |
| `SC: Importer` | 65 | 24 | Importer of goods |
| `SC: Manufacturer` | 64 | 42 | Manufacturer of products |
| `SC: Producer` | 63 | 32 | Producer of goods |
| `SC: C: Contractor` | 48 | 7 | Contractor (construction) |
| `SC: Consumer` | 48 | 24 | Consumer/end user |
| `SC: T&L: Driver` | 37 | 9 | Driver of vehicle |
| `SC: Distributor` | 34 | 16 | Distributor of goods |
| `SC: Dealer` | 31 | 3 | Dealer (scrap metal, etc.) |
| `SC: Customer` | 29 | 14 | Customer |
| `SC: Seller` | 24 | 12 | Seller of goods |
| `SC: T&L: Consignee` | 21 | 4 | Receiver of consigned goods |
| `SC: Generator` | 19 | 1 | Generator (of waste, energy, etc.) |
| `SC: T&L: Consignor` | 17 | 6 | Sender of consigned goods |
| `SC: Client` | 14 | 6 | Client (construction) |
| `SC: Keeper` | 13 | 11 | Keeper of animals/substances |
| `SC: Exporter` | 10 | 7 | Exporter of goods |
| `SC: Retailer` | 9 | 3 | Retailer |
| `SC: C: Principal Contractor` | 7 | 0 | Principal contractor (CDM) |
| `SC: C: Designer` | 7 | 1 | Designer (construction) |
| `SC: C: Principal Designer` | 5 | 1 | Principal designer (CDM) |
| `SC: Domestic Client` | 4 | 1 | Domestic client (CDM) |
| `SC: Marketer` | 0 | 2 | Marketer/advertiser |

### Specialist (`Spc:`)

| Tag | Duty | Rights | Description |
|-----|-----:|-------:|-------------|
| `Spc: Inspector` | 249 | 251 | Inspector/verifier/well examiner |
| `Spc: Surveyor` | 39 | 22 | Surveyor |
| `Spc: Body` | 33 | 19 | Approved/notified/assessment body |
| `Spc: Assessor` | 30 | 21 | Assessor |
| `Spc: OH Advisor` | 22 | 10 | Occupational health advisor/nurse/physician |
| `Spc: Engineer` | 14 | 9 | Engineer |
| `Spc: Trade Union` | 11 | 3 | Trade union |
| `Spc: Advisor` | 10 | 4 | Advisor (generic) |
| `Spc: Employees' Representative` | 5 | 3 | Employees' or safety representative |
| `Spc: Representative` | 1 | 2 | Authorised representative |

### Service Provider (`Svc:`)

| Tag | Duty | Rights | Description |
|-----|-----:|-------:|-------------|
| `Svc: Installer` | 4 | 1 | Installer |
| `Svc: Maintainer` | 3 | 0 | Maintainer |

### Maritime

| Tag | Duty | Rights | Description |
|-----|-----:|-------:|-------------|
| `Maritime: master` | 107 | 37 | Master of a ship/vessel |
| `Maritime: crew` | 4 | 0 | Crew of a ship |

### Unprefixed Governed

| Tag | Duty | Rights | Description |
|-----|-----:|-------:|-------------|
| `Operator` | 367 | 148 | Operator of plant/installation/vehicle |
| `Public` | 418 | 161 | Public/everyone/citizens |
| `Organisation` | 133 | 60 | Third party/organisation |
| `Public: Parents` | 20 | 2 | Parents |
| `: He` | 513 | 447 | Pronoun reference (he/person referred to) |
| `Parents` | 2 | 0 | **Legacy variant** of `Public: Parents` |

---

## Government Actors (responsibility_holder, power_holder)

### Minister / Secretary of State

| Tag | Resp | Power | Description |
|-----|-----:|------:|-------------|
| `Gvt: Minister` | 1,558 | 1,308 | Secretary of State / Minister (generic) |
| `Gvt: Minister: Secretary of State for Defence` | 26 | 39 | Secretary of State for Defence |
| `Gvt: Minister: Secretary of State for Transport` | 11 | 12 | Secretary of State for Transport |
| `Gvt: Minister: Attorney General` | 4 | 7 | Attorney General |

### Authority

| Tag | Resp | Power | Description |
|-----|-----:|------:|-------------|
| `Gvt: Authority` | 739 | 439 | Generic authority/regulator |
| `Gvt: Authority: Local` | 366 | 313 | Local authority/council |
| `Gvt: Authority: Enforcement` | 179 | 138 | Regulatory/enforcement authority |
| `Gvt: Authority: Harbour` | 97 | 82 | Harbour authority/harbour master |
| `Gvt: Authority: Traffic` | 75 | 75 | Traffic authority |
| `Gvt: Authority: Public` | 52 | 38 | Public authority |
| `Gvt: Authority: Licensing` | 43 | 27 | Licensing authority |
| `Gvt: Authority: Planning` | 33 | 24 | Planning authority |
| `Gvt: Authority: Waste` | 22 | 13 | Waste collection/disposal authority |
| `Gvt: Authority: Market` | 20 | 11 | Market surveillance/weights and measures |
| `Gvt: Authority: Energy` | 5 | 2 | Energy regulation authority |

### Agency

| Tag | Resp | Power | Description |
|-----|-----:|------:|-------------|
| `Gvt: Agency:` | 190 | 138 | Generic agency |
| `Gvt: Agency: Health and Safety Executive` | 123 | 91 | HSE |
| `Gvt: Agency: Environment Agency` | 63 | 36 | Environment Agency |
| `Gvt: Agency: Scottish Environment Protection Agency` | 56 | 38 | SEPA |
| `Gvt: Agency: Natural Resources Body for Wales` | 17 | 16 | NRW |
| `Gvt: Agency: Office of Rail and Road` | 13 | 11 | ORR |
| `Gvt: Agency: Office for Nuclear Regulation` | 12 | 7 | ONR |
| `Gvt: Agency: OFCOM` | 10 | 7 | Office of Communications |
| `Gvt: Agency: Health and Safety Executive for Northern Ireland` | 8 | 3 | HSENI |

### Ministry / Department

| Tag | Resp | Power | Description |
|-----|-----:|------:|-------------|
| `Gvt: Ministry:` | 343 | 289 | Generic ministry/department |
| `Gvt: Ministry: Treasury` | 49 | 41 | Treasury |
| `Gvt: Ministry: Department of the Environment` | 20 | 14 | DoE |
| `Gvt: Ministry: Ministry of Defence` | 4 | 4 | MoD |
| `Gvt: Ministry: Department of Enterprise, Trade and Investment` | 3 | 3 | DETI (NI) |
| `Gvt: Ministry: HMRC` | 1 | 8 | HMRC |

### Other Government

| Tag | Resp | Power | Description |
|-----|-----:|------:|-------------|
| `Gvt: Officer` | 643 | 546 | Authorised officer |
| `Gvt: Judiciary` | 627 | 569 | Court/tribunal/justice/sheriff |
| `EU: Commission` | 341 | 187 | European Commission |
| `Crown` | 169 | 129 | Crown |
| `Gvt: Commissioners` | 116 | 95 | Commissioners |
| `Gvt: Emergency Services: Police` | 108 | 101 | Constable/chief of police |
| `Gvt: Devolved Admin:` | 75 | 63 | Generic devolved administration |
| `Gvt: Devolved Admin: National Assembly for Wales` | 44 | 39 | Senedd / Welsh Parliament |
| `Gvt: Official` | 32 | 22 | Official |
| `Gvt: Appropriate Person` | 29 | 19 | Appropriate person |
| `Gvt: Devolved Admin: Scottish Parliament` | 20 | 15 | Scottish Parliament |
| `Gvt: Emergency Services` | 13 | 9 | Emergency services (generic) |
| `Gvt: Devolved Admin: Northern Ireland Assembly` | 9 | 3 | NI Assembly |
| `HM Forces` | 7 | 0 | Armed forces |

---

## Data Quality Notes

### Known Issues (non-blocking)

1. **Broken CSV split** (9 records): `"Gvt: Ministry: Department of Enterprise` and `Trade and Investment"` appear as two separate tags due to comma in the ministry name splitting during CSV parsing. Should be the single tag `Gvt: Ministry: Department of Enterprise, Trade and Investment`.

2. **Duplicate spelling** (2 records): `Ind: Dutyholder` is a legacy variant of `Ind: Duty Holder`. Should be normalized.

3. **Missing prefix** (2 records): `Parents` is a legacy variant of `Public: Parents`. Should be normalized.

### Tags in Code Not Yet in DB

These tags are defined in `actor_definitions.ex` but have not yet appeared in any parsed law:

| Tag | Category |
|-----|----------|
| `Env: Disposer` | Environmental |
| `Env: Polluter` | Environmental |
| `Env: Recycler` | Environmental |
| `Env: Reuser` | Environmental |
| `Env: Treater` | Environmental |
| `Gvt: Agency: Office for Environmental Protection` | Government agency |
| `HM Forces: Navy` | Armed forces |
| `SC: C: Constructor` | Construction supply chain |
| `SC: Storer` | Supply chain |
| `SC: T&L: Handler` | Transport & logistics |
| `Spc: Technician` | Specialist |
| `Svc: Repairer` | Service provider |

## Writers

| Writer | Fields Written | Vocabulary |
|--------|---------------|------------|
| CSV import (`update_uk_lrt_taxa.exs`) | All 4 holder columns | Airtable prefixed taxonomy |
| Taxa parser (`taxa_parser.ex` via `actor_definitions.ex`) | All 4 holder columns | Same Airtable prefixed taxonomy |
| SQL dump (`import_uk_lrt.sql`) | None (all NULL) | N/A |

Both writers produce identical `{"tag": true, ...}` JSONB format. The taxa parser was built to replicate the Airtable vocabulary. There is no vocabulary conflict between the two writers.

## Related Documents

- [LRT Schema](./LRT-SCHEMA.md) - Full schema reference
- [Function Values](./FUNCTION_VALUES.md) - Function field taxonomy
- [Purpose Values](./PURPOSE_VALUES.md) - Purpose and duty_type taxonomy
- [Actor Definitions](../backend/lib/sertantai_legal/legal/taxa/actor_definitions.ex) - Regex patterns for actor detection
