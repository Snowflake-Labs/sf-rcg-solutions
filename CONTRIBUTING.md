# Contributing to sf-rcg-solutions

Thank you for contributing to Snowflake Retail & Consumer Goods Solutions!

## Repository Structure

```
sf-rcg-solutions/
├── solutions/
│   └── <solution-name>/      # Solution assets (SQL, Streamlit, prompts)
│       ├── manifest.json
│       ├── README.md
│       ├── NEXT_ACTIONS.md
│       ├── scripts/setup.sql
│       ├── scripts/teardown.sql
│       └── streamlit/        # Optional dashboard
└── README.md
```

## Adding a New Solution

Create files in `solutions/<solution-name>/`:

Required files:
- `manifest.json` — solution metadata (name, industry, database, schemas, features)
- `README.md` — architecture overview, quick start, example usage
- `NEXT_ACTIONS.md` — post-install guidance
- `scripts/setup.sql` — full installation script (idempotent, uses CREATE OR REPLACE)
- `scripts/teardown.sql` — cleanup script (drops all created objects)

Optional:
- `scripts/deploy_streamlit.sql` — Streamlit deployment (separate from setup)
- `streamlit/` — Streamlit dashboard files

## Naming Conventions

- Solution directory: `kebab-case` (e.g., `ltv-prediction`)
- Database: `SF_SOLUTIONS` (shared across all solutions)
- Schemas: `UPPER_SNAKE_CASE` (e.g., `LTV_RAW`, `LTV_ANALYTICS`, `LTV_ML`)
- Streamlit apps: `UPPER_SNAKE_CASE` (e.g., `LTV_PREDICTION_DASHBOARD`)

## Testing

Before submitting a PR:
1. Run `setup.sql` end-to-end on a clean account
2. Verify all objects are created (check INFORMATION_SCHEMA)
3. Open the Streamlit dashboard URL and confirm it loads without errors
4. Run `teardown.sql` and verify everything is removed
5. Run linters: `uv run ruff check .`, `uv run ruff format --check .`, `uv run sqruff lint .`
