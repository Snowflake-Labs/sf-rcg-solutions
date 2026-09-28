# Snowflake Retail & Consumer Goods Solutions

Disclaimer: This application is not part of the Snowflake Service and is governed by the terms in LICENSE, unless expressly agreed to in writing. You use this application at your own risk, and Snowflake has no obligation to support your use of this application. [Learn more](./LEGAL.md)

**RCG: Retail & Consumer Goods**

End-to-end solution accelerators for the Retail & Consumer Goods industry vertical, built on Snowflake and Cortex Code, showcasing Cortex AI, Snowflake ML, and the modern data platform.

---

## Solution Catalog

| # | Solution | Industry | Directory | Key Snowflake Features | Status |
|---|----------|----------|-----------|----------------------|--------|
| 1 | **Customer Lifetime Value Prediction** | Retail / CPG | `solutions/ltv-prediction/` | Snowflake ML Forecast, Cortex AI Functions (COMPLETE), Customer Segmentation, Feature Engineering | ✅ Done |
| 2 | **Franchise Multi-Unit Operations Intelligence** | Retail, CPG & General | `solutions/franchise-operations-intelligence/` | Semantic View, Dynamic Tables, Data Metric Functions, Cortex Agent, Serverless Alerts | ✅ Done |

---

## Quick Install (via Cortex Code)

Solutions are installed via the `$sf-solutions` skill in [snowflake-ai-kit](https://github.com/Snowflake-Labs/snowflake-ai-kit):

```bash
# Install the snowflake-ai-kit plugin (includes sf-solutions skill)
cortex skill add github:Snowflake-Labs/snowflake-ai-kit
```

Then in a Cortex Code session, run a solution by name:

```
$sf-solutions:ltv-prediction
$sf-solutions:ltv-prediction teardown
```

---

## Getting Started

Each solution is self-contained in its own directory. There are two types:

### Script Type

```
solutions/<solution-name>/
├── manifest.json      # Solution metadata (type: "script")
├── README.md          # Overview, architecture, prerequisites
├── NEXT_ACTIONS.md    # Post-install verification steps and example queries
├── scripts/           # SQL setup and teardown scripts
└── streamlit/         # Streamlit app (if applicable)
```

### Plugin Type

Solutions that install a Cortex Code plugin with skills, agents, and optionally Snowflake objects.

```
solutions/<solution-name>/
├── manifest.json          # Solution metadata (type: "plugin")
├── README.md              # Overview, usage
├── plugins/cortex-code/   # CoCo plugin directory
│   ├── .cortex-plugin/
│   │   └── plugin.json
│   └── skills/
│       └── ...
└── scripts/               # Optional SQL scripts
```

## Prerequisites

- Snowflake account (Enterprise edition recommended)
- Appropriate role with CREATE DATABASE / SCHEMA privileges
- Warehouse (default: `SF_SOLUTIONS_WH`)

---

## Developers

```bash
git clone https://github.com/Snowflake-Labs/sf-rcg-solutions.git
cd sf-rcg-solutions
uv sync
pre-commit install
pre-commit install --hook-type commit-msg
```

---

## Related Resources

### Web Pages

- [Snowflake ML](https://www.snowflake.com/en/data-cloud/snowflake-ml/) - Integrated set of capabilities for development, MLOps and inference
- [Snowflake Notebooks](https://www.snowflake.com/en/data-cloud/notebooks/) - Jupyter-based notebooks in Snowflake Workspaces
- [Cortex Code](https://www.snowflake.com/en/data-cloud/cortex/cortex-code/) - Snowflake's AI native coding agent

### Technical Documentation

- [Cortex Code Documentation](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) - Getting started with Cortex Code
- [Snowflake ML Documentation](https://docs.snowflake.com/en/developer-guide/snowflake-ml/overview) - Official Snowflake ML developer guide
