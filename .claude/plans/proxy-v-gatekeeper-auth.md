In the context of [ElectricSQL](https://electric-sql.com/docs/guides/auth), both **Proxy Auth** and **Gatekeeper Auth** are patterns used to secure "Shapes" (the data streams synced to the client).

The fundamental difference is **where the authorization logic lives** and **how often it runs**.

---

### 1. Proxy Auth Pattern

In this pattern, every single request from the client to Electric goes through your own backend (the proxy).

* **How it works:** Your client calls `https://my-api.com/shape/items`. Your API validates the user's session, appends a `WHERE` clause (e.g., `where org_id = '123'`) to ensure the user only sees their data, and then forwards the request to Electric.
* **Pros:**
* **Simplicity:** Easier to reason about; it’s just a standard middleware/wrapper.
* **Real-time Security:** Access is checked on every request. If you revoke a user's permission in your DB, their next sync request will fail immediately.
* **Dynamic:** Good for complex, highly dynamic permission sets that change frequently.


* **Cons:**
* **Performance:** Every request hits your backend "hot path." This can add latency and increase the load on your API.
* **Scalability:** Your API becomes a potential bottleneck for the high-throughput streaming that Electric is designed for.



### 2. Gatekeeper Auth Pattern

In this pattern, your API acts as a "Gatekeeper" that issues a short-lived, scoped token.

* **How it works:**
1. Client asks your API: "I want to sync the `items` table."
2. Your API checks permissions and returns a **signed JWT** containing the specific shape definition (e.g., `table: items, where: org_id=123`).
3. The client then talks directly to a lightweight **Authorizing Proxy** (often running at the Edge, like Cloudflare Workers) using that token.
4. The Edge Proxy simply verifies the JWT signature and ensures the requested data matches what’s inside the token.


* **Pros:**
* **High Performance:** The heavy lifting (checking DB permissions) happens once. Subsequent sync requests are validated at the edge in milliseconds.
* **Edge-Friendly:** Ideal for global deployments where you want the data to stay close to the user.


* **Cons:**
* **Complexity:** Requires managing JWT signing/verification and handling token expiration/refresh on the client.
* **Staleness:** If permissions change, the user might still have access until the token expires (though tokens are usually very short-lived).



---

### Comparison Table

| Feature | Proxy Auth | Gatekeeper Auth |
| --- | --- | --- |
| **Auth Check Frequency** | Every request | Once (per token issuance) |
| **Logic Location** | Your main API | API (issuance) + Edge/Proxy (validation) |
| **Latency** | Higher (full roundtrip to API) | Lower (validation at the Edge) |
| **Ease of Implementation** | High | Medium |
| **Recommended for** | Small/Med apps, frequent ACL changes | High-scale apps, global users, CDNs |

---

### Which should you implement?

**Choose Proxy Auth if:**

* You are just starting or have a low-to-medium volume of users.
* Your permissions are "noisy" (they change constantly and must be reflected instantly).
* You want the simplest code possible and don't want to deal with JWT management.

**Choose Gatekeeper Auth if:**

* You are building a high-performance production app.
* You are using a CDN or want to run auth at the Edge (e.g., Supabase Edge Functions, Fly.io).
* You want to offload the "hot path" of data streaming from your main application server.

### Are they complementary?

**Generally, no.** They are alternative architectural approaches to the same problem. You pick the one that fits your scale and infrastructure.

However, they use the same underlying principle: **Electric is "just HTTP."** You can start with Proxy Auth because it's easier to build, and as your app grows, migrate to Gatekeeper Auth without changing how Electric itself is configured, as both patterns ultimately just result in authorized HTTP requests reaching the Electric service.
