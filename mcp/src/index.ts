#!/usr/bin/env node
/**
 * astro-chart-mcp
 *
 * A Model Context Protocol (stdio) server that exposes the hosted AstroChart
 * astrology API (https://astro-chart-api.fly.dev) as tools for LLM agents.
 *
 * Configuration (environment variables):
 *   ASTRO_API_BASE  Base URL of the API (default https://astro-chart-api.fly.dev)
 *   ASTRO_API_KEY   Optional API key -> sent as "Authorization: Bearer <key>"
 *   ASTRO_API_LANG  Optional default response language forwarded as "lang"
 *                   (zh-TW | en | ja | ko). Per-tool "lang" overrides it.
 */

import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

const API_BASE = (process.env.ASTRO_API_BASE || "https://astro-chart-api.fly.dev").replace(/\/+$/, "");
const API_KEY = process.env.ASTRO_API_KEY;
const DEFAULT_LANG = process.env.ASTRO_API_LANG;

// ---------------------------------------------------------------------------
// Shared fetch helper
// ---------------------------------------------------------------------------

class AstroApiError extends Error {
  code?: string;
  constructor(message: string, code?: string) {
    super(message);
    this.name = "AstroApiError";
    this.code = code;
  }
}

/**
 * Perform a request against the AstroChart API.
 * Forwards auth (Bearer) + the effective lang, parses JSON, and turns an
 * {"error":{code,message}} envelope (or a non-2xx status) into a readable throw.
 */
async function apiRequest(
  method: "GET" | "POST",
  path: string,
  options: { body?: Record<string, unknown>; query?: Record<string, string | undefined> } = {}
): Promise<unknown> {
  const url = new URL(API_BASE + path);
  if (options.query) {
    for (const [k, v] of Object.entries(options.query)) {
      if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, v);
    }
  }

  const headers: Record<string, string> = { Accept: "application/json" };
  if (API_KEY) headers["Authorization"] = `Bearer ${API_KEY}`;

  let bodyStr: string | undefined;
  if (method === "POST") {
    headers["Content-Type"] = "application/json";
    bodyStr = JSON.stringify(options.body ?? {});
  }

  let resp: Response;
  try {
    resp = await fetch(url.toString(), { method, headers, body: bodyStr });
  } catch (e) {
    throw new AstroApiError(`Network error calling ${method} ${url.pathname}: ${(e as Error).message}`);
  }

  const text = await resp.text();
  let json: unknown;
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    throw new AstroApiError(
      `Non-JSON response from ${method} ${url.pathname} (HTTP ${resp.status}): ${text.slice(0, 300)}`
    );
  }

  const errEnvelope =
    json && typeof json === "object" && "error" in json
      ? (json as { error?: { code?: string; message?: string } }).error
      : undefined;

  if (errEnvelope) {
    const code = errEnvelope.code;
    const msg = errEnvelope.message || "unknown error";
    throw new AstroApiError(`API error${code ? ` [${code}]` : ""}: ${msg}`, code);
  }

  if (!resp.ok) {
    throw new AstroApiError(`HTTP ${resp.status} from ${method} ${url.pathname}: ${text.slice(0, 300)}`);
  }

  return json;
}

/** The effective lang for a call: explicit arg wins, else the configured default. */
function effectiveLang(lang?: string): string | undefined {
  return lang ?? DEFAULT_LANG;
}

/** Wrap a tool handler so any error becomes an MCP isError text result. */
function toolResult(json: unknown) {
  return { content: [{ type: "text" as const, text: JSON.stringify(json, null, 2) }] };
}
function toolError(err: unknown) {
  const message = err instanceof Error ? err.message : String(err);
  return { isError: true as const, content: [{ type: "text" as const, text: message }] };
}

// ---------------------------------------------------------------------------
// Shared zod shapes
// ---------------------------------------------------------------------------

const langSchema = z
  .enum(["zh-TW", "en", "ja", "ko"])
  .describe("Response language for vocabulary values + error messages. Defaults to zh-TW (or ASTRO_API_LANG).");

// Birth data as a reusable raw shape (so it can be nested via z.object).
const birthDataShape = {
  birth_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "birth_date must be YYYY-MM-DD").describe("Birth date, YYYY-MM-DD (e.g. 1990-01-01)."),
  birth_time: z.string().regex(/^\d{1,2}:\d{2}$/, "birth_time must be HH:MM").describe("Birth time, 24h HH:MM (e.g. 12:00)."),
  latitude: z.number().min(-90).max(90).describe("Latitude in decimal degrees (e.g. 25.033)."),
  longitude: z.number().min(-180).max(180).describe("Longitude in decimal degrees (e.g. 121.5654)."),
  timezone: z.string().min(1).describe("IANA timezone identifier (e.g. Asia/Taipei)."),
  house_system: z
    .enum(["P", "W"])
    .optional()
    .describe('Optional house system: "P" = Placidus (default), "W" = Whole Sign.'),
};

const birthData = z.object(birthDataShape);

/** Strip undefined keys so we never send explicit nulls the API doesn't expect. */
function clean<T extends Record<string, unknown>>(obj: T): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(obj)) if (v !== undefined) out[k] = v;
  return out;
}

// ---------------------------------------------------------------------------
// Server + tools
// ---------------------------------------------------------------------------

const server = new McpServer({ name: "astro-chart-mcp", version: "0.1.0" });

server.tool(
  "natal_chart",
  "Compute a full natal (birth) chart: ascendant, planets/points (with retrograde flags), house cusps, aspects, aspect patterns, and element statistics. POST /api/v1/charts.",
  { ...birthDataShape, lang: langSchema.optional() },
  async (args) => {
    try {
      const { lang, ...birth } = args;
      const data = await apiRequest("POST", "/api/v1/charts", {
        body: clean({ ...birth, lang: effectiveLang(lang) }),
      });
      return toolResult(data);
    } catch (e) {
      return toolError(e);
    }
  }
);

server.tool(
  "synastry",
  "Relationship comparison of two natal charts: both charts, cross-chart aspects, and each person's planets falling in the other's houses. POST /api/v1/synastry.",
  {
    a: birthData.describe("Person A birth data."),
    b: birthData.describe("Person B birth data."),
    orb_limit: z.number().positive().optional().describe("Optional cross-chart aspect orb limit in degrees; omit for natal defaults."),
    lang: langSchema.optional(),
  },
  async (args) => {
    try {
      const data = await apiRequest("POST", "/api/v1/synastry", {
        body: clean({ a: args.a, b: args.b, orb_limit: args.orb_limit, lang: effectiveLang(args.lang) }),
      });
      return toolResult(data);
    } catch (e) {
      return toolError(e);
    }
  }
);

server.tool(
  "transits",
  "Current or dated transits against a natal chart: transiting planet positions, the natal houses they fall in, and transit-to-natal aspects (default orb 3°). Omit `at` for the server's current UTC. POST /api/v1/transits.",
  {
    natal: birthData.describe("Natal birth data."),
    at: z
      .object({
        date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "date must be YYYY-MM-DD").describe("Transit date, YYYY-MM-DD."),
        time: z.string().regex(/^\d{1,2}:\d{2}$/, "time must be HH:MM").describe("Transit time, HH:MM."),
        timezone: z.string().min(1).describe("IANA timezone for the transit moment."),
      })
      .optional()
      .describe("Optional transit moment; if given, all three sub-fields are required. Omit for current UTC."),
    orb_limit: z.number().positive().optional().describe("Optional transit aspect orb limit in degrees (default 3.0)."),
    lang: langSchema.optional(),
  },
  async (args) => {
    try {
      const data = await apiRequest("POST", "/api/v1/transits", {
        body: clean({ natal: args.natal, at: args.at, orb_limit: args.orb_limit, lang: effectiveLang(args.lang) }),
      });
      return toolResult(data);
    } catch (e) {
      return toolError(e);
    }
  }
);

server.tool(
  "progressions",
  'Secondary progressions ("a day for a year"): progressed planet positions in natal houses and progressed-to-natal aspects (default orb 1°). POST /api/v1/progressions.',
  {
    natal: birthData.describe("Natal birth data."),
    target_date: z
      .string()
      .regex(/^\d{4}-\d{2}-\d{2}$/, "target_date must be YYYY-MM-DD")
      .describe("Progression target date, YYYY-MM-DD."),
    orb_limit: z.number().positive().optional().describe("Optional progression aspect orb limit in degrees (default 1.0)."),
    lang: langSchema.optional(),
  },
  async (args) => {
    try {
      const data = await apiRequest("POST", "/api/v1/progressions", {
        body: clean({ natal: args.natal, target_date: args.target_date, orb_limit: args.orb_limit, lang: effectiveLang(args.lang) }),
      });
      return toolResult(data);
    } catch (e) {
      return toolError(e);
    }
  }
);

server.tool(
  "solar_return",
  "Solar return chart for a given year: the moment the transiting Sun returns to its natal longitude, and the chart cast for it. Optionally relocate via latitude/longitude/timezone. POST /api/v1/solar-return.",
  {
    natal: birthData.describe("Natal birth data."),
    year: z.number().int().describe("Solar return year (integer, 1885–2099)."),
    latitude: z.number().min(-90).max(90).optional().describe("Optional relocation latitude (defaults to natal)."),
    longitude: z.number().min(-180).max(180).optional().describe("Optional relocation longitude (defaults to natal)."),
    timezone: z.string().min(1).optional().describe("Optional relocation IANA timezone (display only)."),
    lang: langSchema.optional(),
  },
  async (args) => {
    try {
      const data = await apiRequest("POST", "/api/v1/solar-return", {
        body: clean({
          natal: args.natal,
          year: args.year,
          latitude: args.latitude,
          longitude: args.longitude,
          timezone: args.timezone,
          lang: effectiveLang(args.lang),
        }),
      });
      return toolResult(data);
    } catch (e) {
      return toolError(e);
    }
  }
);

server.tool(
  "composite",
  "Composite chart of two people (midpoint method): both natal charts plus the derived composite chart. POST /api/v1/composite.",
  {
    a: birthData.describe("Person A birth data."),
    b: birthData.describe("Person B birth data."),
    lang: langSchema.optional(),
  },
  async (args) => {
    try {
      const data = await apiRequest("POST", "/api/v1/composite", {
        body: clean({ a: args.a, b: args.b, lang: effectiveLang(args.lang) }),
      });
      return toolResult(data);
    } catch (e) {
      return toolError(e);
    }
  }
);

server.tool(
  "search_cities",
  "Search ~160 cities (22 Taiwan counties + major world cities) for coordinates and timezone. Case-insensitive; supports Chinese names and English/pinyin aliases; prefix matches rank first; max 10 results. GET /api/v1/cities.",
  {
    q: z.string().min(1).describe("Search keyword (e.g. tokyo, tai, 東京)."),
    lang: langSchema.optional(),
  },
  async (args) => {
    try {
      const data = await apiRequest("GET", "/api/v1/cities", {
        query: { q: args.q, lang: effectiveLang(args.lang) },
      });
      return toolResult(data);
    } catch (e) {
      return toolError(e);
    }
  }
);

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  // stderr is safe; stdout is reserved for the JSON-RPC stream.
  console.error(`astro-chart-mcp running (stdio) -> ${API_BASE}`);
}

main().catch((err) => {
  console.error("Fatal:", err);
  process.exit(1);
});
