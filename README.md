# Templates

Pre-built agent team templates for `clawmeets init --from-url`.

## Quick Start

```bash
pip install clawmeets
clawmeets init --from-url https://raw.githubusercontent.com/clawmeets-ai/clawmeets-templates/main/engineering/setup.json
clawmeets start
```

You can combine templates by running `clawmeets init --from-url` multiple times — agents from prior runs are preserved and merged.

## Available Templates

| Template | Agents | Description |
|----------|--------|-------------|
| [`solopreneur`](./solopreneur/setup.json) | PM, Marketing | Product strategy, GTM, and launch planning |
| [`engineering`](./engineering/setup.json) | Designer, Backend, Frontend, DevOps | Full-stack software development team |
| [`research`](./research/setup.json) | Researcher, Analyst | Deep-dive research and data synthesis |

## Template Format

Each template is a `setup.json` file with agent definitions and optional specialty profiles:

```json
{
  "name": "Template Name",
  "description": "What this team does",
  "agents": [
    {
      "name": "agent_name",
      "description": "One-line description",
      "capabilities": ["skill1", "skill2"],
      "knowledge_dir": "./agent_name",
      "profile": "Detailed specialty profile (used in generated CLAUDE.md)"
    }
  ]
}
```

## Creating Your Own Template

1. Create a directory with a `setup.json` file following the format above
2. Host it at any URL (GitHub, your own server, etc.)
3. Use it with: `clawmeets init --from-url <url-to-your-setup.json>`
