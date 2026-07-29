import assert from "node:assert/strict";
import test from "node:test";

import worker, {
  refreshModelsDevCatalog,
  validateModelsDevCatalog,
} from "./worker.js";

const CATALOG = JSON.stringify({
  openai: {
    id: "openai",
    name: "OpenAI",
    models: {
      "gpt-test": {
        id: "gpt-test",
        name: "GPT Test",
      },
    },
  },
});

class MemoryR2Object {
  constructor(key, value, options = {}) {
    this.key = key;
    this.value = value;
    this.size = new TextEncoder().encode(value).byteLength;
    this.etag = `r2-${this.size}`;
    this.uploaded = new Date();
    this.httpMetadata = options.httpMetadata || {};
    this.customMetadata = options.customMetadata || {};
  }

  get body() {
    return new Response(this.value).body;
  }

  async text() {
    return this.value;
  }
}

class MemoryR2Bucket {
  constructor() {
    this.objects = new Map();
    this.puts = [];
  }

  async head(key) {
    return this.objects.get(key) || null;
  }

  async get(key) {
    return this.objects.get(key) || null;
  }

  async put(key, value, options = {}) {
    const text = typeof value === "string"
      ? value
      : new TextDecoder().decode(value);
    const object = new MemoryR2Object(key, text, options);
    this.objects.set(key, object);
    this.puts.push(key);
    return object;
  }

  async list({ prefix = "" } = {}) {
    return {
      objects: [...this.objects.values()].filter((object) =>
        object.key.startsWith(prefix)
      ),
      truncated: false,
    };
  }

  async delete(keys) {
    for (const key of Array.isArray(keys) ? keys : [keys]) {
      this.objects.delete(key);
    }
  }
}

function testEnv(bucket) {
  return {
    APP_UPDATE_BUCKET: bucket,
    ADMIN_TOKEN: "test-token",
    MODELS_DEV_MIN_BYTES: "1",
    MODELS_DEV_MAX_BYTES: "100000",
    MODELS_DEV_MIN_PROVIDERS: "1",
    MODELS_DEV_MIN_MODELS: "1",
    MODELS_DEV_REQUIRED_PROVIDERS: "openai",
  };
}

function upstreamResponse(body = CATALOG, { status = 200, etag = '"upstream-v1"' } = {}) {
  return new Response(body, {
    status,
    headers: {
      "content-type": "application/json",
      etag,
    },
  });
}

test("refresh stores a validated snapshot and serves it with conditional GET", async () => {
  const bucket = new MemoryR2Bucket();
  const env = testEnv(bucket);
  const result = await refreshModelsDevCatalog(env, {
    fetchImpl: async () => upstreamResponse(),
  });

  assert.equal(result.changed, true);
  assert.equal(result.providerCount, 1);
  assert.equal(result.modelCount, 1);
  assert.ok(result.sha256);
  assert.ok(bucket.objects.has("metadata/models-dev/current.json"));
  assert.ok(
    bucket.objects.has(
      `metadata/models-dev/snapshots/${result.sha256}.json`,
    ),
  );

  const response = await worker.fetch(
    new Request("https://updates.example/catalog/models-dev/api.json"),
    env,
  );
  assert.equal(response.status, 200);
  assert.equal(await response.text(), CATALOG);
  assert.equal(response.headers.get("etag"), `"${result.sha256}"`);
  assert.equal(response.headers.get("access-control-allow-origin"), "*");

  const notModified = await worker.fetch(
    new Request("https://updates.example/catalog/models-dev/api.json", {
      headers: { "if-none-match": `W/"${result.sha256}"` },
    }),
    env,
  );
  assert.equal(notModified.status, 304);
  assert.equal(await notModified.text(), "");
});

test("refresh reuses the upstream ETag and handles 304 without replacing current", async () => {
  const bucket = new MemoryR2Bucket();
  const env = testEnv(bucket);
  await refreshModelsDevCatalog(env, {
    fetchImpl: async () => upstreamResponse(),
  });
  const currentBefore = bucket.objects.get("metadata/models-dev/current.json");
  let conditionalEtag = "";

  const result = await refreshModelsDevCatalog(env, {
    fetchImpl: async (_url, init) => {
      conditionalEtag = init.headers["if-none-match"];
      return new Response(null, {
        status: 304,
        headers: { etag: '"upstream-v1"' },
      });
    },
  });

  assert.equal(conditionalEtag, '"upstream-v1"');
  assert.equal(result.changed, false);
  assert.equal(
    bucket.objects.get("metadata/models-dev/current.json"),
    currentBefore,
  );
});

test("invalid refresh records the failure and preserves the last good snapshot", async () => {
  const bucket = new MemoryR2Bucket();
  const env = testEnv(bucket);
  await refreshModelsDevCatalog(env, {
    fetchImpl: async () => upstreamResponse(),
  });
  const currentBefore = bucket.objects.get("metadata/models-dev/current.json");

  await assert.rejects(
    refreshModelsDevCatalog(env, {
      fetchImpl: async () => upstreamResponse("{}"),
    }),
    /provider count/,
  );

  assert.equal(
    bucket.objects.get("metadata/models-dev/current.json"),
    currentBefore,
  );
  const status = JSON.parse(
    await bucket.objects.get("metadata/models-dev/status.json").text(),
  );
  assert.equal(status.consecutiveFailures, 1);
  assert.match(status.lastError, /provider count/);
});

test("validation blocks a suspicious model-count drop unless forced", () => {
  const config = {
    minBytes: 1,
    maxBytes: 100000,
    minProviders: 1,
    minModels: 1,
    maxDropRatio: 0.35,
    requiredProviders: ["openai"],
  };
  assert.throws(
    () => validateModelsDevCatalog(CATALOG, {
      config,
      previousStatus: { providerCount: 1, modelCount: 10 },
    }),
    /model count dropped/,
  );

  const result = validateModelsDevCatalog(CATALOG, {
    config,
    previousStatus: { providerCount: 1, modelCount: 10 },
    force: true,
  });
  assert.equal(result.modelCount, 1);
});

test("admin status is authenticated and reports the current mirror", async () => {
  const bucket = new MemoryR2Bucket();
  const env = testEnv(bucket);
  await refreshModelsDevCatalog(env, {
    fetchImpl: async () => upstreamResponse(),
  });

  const unauthorized = await worker.fetch(
    new Request("https://updates.example/admin/models-dev"),
    env,
  );
  assert.equal(unauthorized.status, 401);

  const response = await worker.fetch(
    new Request("https://updates.example/admin/models-dev", {
      headers: { authorization: "Bearer test-token" },
    }),
    env,
  );
  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.equal(payload.current.providerCount, 1);
  assert.equal(payload.current.modelCount, 1);
  assert.equal(
    payload.publicPath,
    "/catalog/models-dev/api.json",
  );
});
