# Family Values

The `family` field is the primary classification for UK EHS legislation.

## Health & Safety Families (💙)

| Family | Description |
|--------|-------------|
| 💙 FIRE | Fire safety legislation |
| 💙 FIRE: Dangerous and Explosive Substances | Petroleum, explosives |
| 💙 FOOD | Food safety and hygiene |
| 💙 HEALTH: Coronavirus | COVID-19 related |
| 💙 HEALTH: Drug & Medicine Safety | Pharmaceuticals |
| 💙 HEALTH: Patient Safety | NHS, medical devices |
| 💙 HEALTH: Public | Public health, mental health |
| 💙 OH&S: Gas & Electrical Safety | Utilities safety |
| 💙 OH&S: Mines & Quarries | Mining industry |
| 💙 OH&S: Occupational / Personal Safety | Core H&S at work |
| 💙 OH&S: Offshore Safety | Offshore installations |
| 💙 PUBLIC | General public safety |
| 💙 PUBLIC: Building Safety | Building regulations |
| 💙 PUBLIC: Consumer / Product Safety | Consumer protection |
| 💙 PUBLIC: Data | Data protection, online safety |
| 💙 TRANSPORT: Air Safety | Aviation |
| 💙 TRANSPORT: Rail Safety | Railways |
| 💙 TRANSPORT: Road Safety | Road transport |
| 💙 TRANSPORT: Maritime Safety | Shipping |

## Environment Families (💚)

| Family | Description |
|--------|-------------|
| 💚 AGRICULTURE | Agricultural regulations |
| 💚 AGRICULTURE: Pesticides | Pesticide controls |
| 💚 AIR QUALITY | Clean air, emissions |
| 💚 ANIMALS & ANIMAL HEALTH | Animal welfare |
| 💚 ANTARCTICA | Antarctic protection |
| 💚 BUILDINGS | Building environmental standards |
| 💚 CLIMATE CHANGE | Climate, emissions trading |
| 💚 ENERGY | Energy efficiency, renewables |
| 💚 ENVIRONMENTAL PROTECTION | General environmental |
| 💚 FINANCE | Environmental taxes, levies |
| 💚 FISHERIES & FISHING | Fisheries management |
| 💚 GMOs | Genetically modified organisms |
| 💚 HISTORIC ENVIRONMENT | Heritage protection |
| 💚 MARINE & RIVERINE | Marine, coastal, rivers |
| 💚 NOISE | Noise control |
| 💚 NUCLEAR & RADIOLOGICAL | Nuclear safety |
| 💚 OIL & GAS - OFFSHORE - PETROLEUM | Petroleum industry |
| 💚 PLANNING & INFRASTRUCTURE | Planning regulations |
| 💚 PLANT HEALTH | Plant protection |
| 💚 POLLUTION | Pollution control |
| 💚 TOWN & COUNTRY PLANNING | Town planning |
| 💚 TRANSPORT | General transport |
| 💚 TRANSPORT: Aviation | Aviation environmental |
| 💚 TRANSPORT: Harbours & Shipping | Maritime environmental |
| 💚 TRANSPORT: Railways & Rail Transport | Rail environmental |
| 💚 TRANSPORT: Roads & Vehicles | Vehicle emissions |
| 💚 TREES: Forestry & Timber | Forestry |
| 💚 WASTE | Waste management |
| 💚 WATER & WASTEWATER | Water resources |
| 💚 WILDLIFE & COUNTRYSIDE | Nature conservation |

## HR Families (💜)

| Family | Description |
|--------|-------------|
| 💜 HR: Employment | Employment rights |
| 💜 HR: Insurance / Compensation / Wages / Benefits | Pay and benefits |
| 💜 HR: Working Time | Working hours |

## DB Column

- **Column**: `family` (varchar 255)
- **Type**: Single select (string)
- **Secondary**: `family_ii` for sub-classification

## Related Fields

| Field | Type | Purpose |
|-------|------|---------|
| `family_ii` | varchar | Secondary classification |
| `si_code` | JSONB | SI code classification (maps to families) |
| `tags` | array | Searchable tags |

## Source

Family values are defined in:
- `backend/lib/sertantai_legal/scraper/models.ex`
- API endpoint: `GET /api/family-options`
