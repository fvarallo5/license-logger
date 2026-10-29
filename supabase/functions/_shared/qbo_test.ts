import { assert, assertFalse } from "jsr:@std/assert@1";
import { verifyIntuitSignature } from "./qbo.ts";
import { safeEqual } from "./http.ts";

Deno.test("Intuit webhook signature: accepts the right HMAC, rejects tampering", async () => {
  const token = "test-verifier-token";
  const body =
    '[{"specversion":"1.0","id":"evt-1","type":"qbo.invoice.updated.v1","intuitentityid":"145","intuitaccountid":"1"}]';
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(token),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = btoa(
    String.fromCharCode(...new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body)))),
  );
  assert(await verifyIntuitSignature(body, sig, token));
  assertFalse(await verifyIntuitSignature(body + " ", sig, token));
  assertFalse(await verifyIntuitSignature(body, null, token));
  assertFalse(await verifyIntuitSignature(body, sig, "wrong-token"));
});

Deno.test("safeEqual", () => {
  assert(safeEqual("abc", "abc"));
  assertFalse(safeEqual("abc", "abd"));
  assertFalse(safeEqual("abc", "abcd"));
});
