# astro-chart-mcp

A [Model Context Protocol](https://modelcontextprotocol.io) (MCP) server that
exposes the hosted **AstroChart API** (<https://astro-chart-api.fly.dev>) as
tools for LLM agents. It speaks the MCP **stdio** transport, so any MCP client
(Claude Desktop, Claude Code, etc.) can launch it and call astrology
computations — natal charts, synastry, transits, progressions, solar returns,
composite charts, and city lookup — as structured tools.

Each tool forwards your request to the API and returns the raw API JSON as
pretty-printed text. Inputs are validated with [zod](https://zod.dev); API
errors (e.g. `invalid_timezone`) are surfaced as tool errors with a readable
message.

## Install & run

### Via npx (no install)

```bash
npx astro-chart-mcp
```

### Local build

```bash
git clone <this repo> && cd mcp
npm install
npm run build
node dist/index.js
```

The server communicates over stdio; run it from an MCP client rather than
interactively.

## Configuration (environment variables)

| Variable | Required | Default | Purpose |
| --- | --- | --- | --- |
| `ASTRO_API_BASE` | no | `https://astro-chart-api.fly.dev` | Base URL of the AstroChart API. |
| `ASTRO_API_KEY` | no | – | API key (`ak_…`). Sent as `Authorization: Bearer <key>`. Optional in the API's open mode; attributes usage to your key. |
| `ASTRO_API_LANG` | no | `zh-TW` (API default) | Default response language forwarded as `lang`: `zh-TW` \| `en` \| `ja` \| `ko`. A per-call `lang` argument overrides it. |

Language affects translated vocabulary values (planet / sign / aspect names,
etc.) and error messages — never the JSON structure.

## MCP client config

Add this to your MCP client config. For **Claude Desktop** that's
`claude_desktop_config.json`; for other clients, use the equivalent
`mcpServers` block.

```json
{
  "mcpServers": {
    "astro-chart": {
      "command": "npx",
      "args": ["-y", "astro-chart-mcp"],
      "env": {
        "ASTRO_API_BASE": "https://astro-chart-api.fly.dev",
        "ASTRO_API_KEY": "ak_your_key_here",
        "ASTRO_API_LANG": "en"
      }
    }
  }
}
```

Using a local build instead of npx:

```json
{
  "mcpServers": {
    "astro-chart": {
      "command": "node",
      "args": ["/absolute/path/to/mcp/dist/index.js"],
      "env": {
        "ASTRO_API_LANG": "en"
      }
    }
  }
}
```

`ASTRO_API_KEY` and `ASTRO_API_LANG` are optional — omit them to run anonymously
with the API's default language (Traditional Chinese).

## Tools

| Tool | API endpoint | Key inputs |
| --- | --- | --- |
| `natal_chart` | `POST /api/v1/charts` | `birth_date`, `birth_time`, `latitude`, `longitude`, `timezone`, optional `house_system` (`P`/`W`), optional `lang` |
| `synastry` | `POST /api/v1/synastry` | `a` + `b` (birth data), optional `orb_limit`, optional `lang` |
| `transits` | `POST /api/v1/transits` | `natal`, optional `at` (`date`/`time`/`timezone`), optional `orb_limit`, optional `lang` |
| `progressions` | `POST /api/v1/progressions` | `natal`, `target_date`, optional `orb_limit`, optional `lang` |
| `solar_return` | `POST /api/v1/solar-return` | `natal`, `year`, optional `latitude`/`longitude`/`timezone`, optional `lang` |
| `composite` | `POST /api/v1/composite` | `a` + `b` (birth data), optional `lang` |
| `search_cities` | `GET /api/v1/cities` | `q`, optional `lang` |

**Birth data** fields (used by `natal_chart` and the `a`/`b`/`natal` objects):
`birth_date` (`YYYY-MM-DD`), `birth_time` (`HH:MM`), `latitude`, `longitude`,
`timezone` (IANA), and optional `house_system` (`P` = Placidus default, `W` =
Whole Sign).

## License

MIT
