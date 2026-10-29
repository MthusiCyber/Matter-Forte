// Deploy with: supabase functions deploy admin-invite-student
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are server-side Edge Function secrets.
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function reply(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response(null, { headers: cors });
  if (request.method !== "POST") return reply(405, { error: "Use POST." });
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const auth = request.headers.get("authorization");
  if (!url || !key) return reply(503, { error: "Invitation service is not configured." });
  if (!auth?.startsWith("Bearer ")) return reply(401, { error: "Sign in first." });

  try {
    // Fetch the current user from Auth; do not trust an unverified JWT or a role
    // supplied by the client. No service key is ever returned to the app.
    const identity = await fetch(`${url}/auth/v1/user`, {
      headers: { apikey: key, Authorization: auth },
    });
    if (!identity.ok) return reply(401, { error: "Session expired. Sign in again." });
    const actor = await identity.json();
    if (actor.app_metadata?.role !== "admin") return reply(403, { error: "Administrator access required." });

    const body = await request.json();
    const name = typeof body.full_name === "string" ? body.full_name.trim() : "";
    const email = typeof body.email === "string" ? body.email.trim() : "";
    if (!name || name.length > 200 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
      return reply(400, { error: "Enter a valid student name and email." });
    }
    const text = (value: unknown) => typeof value === "string" ? value.trim().slice(0, 500) : "";
    const skills = (value: unknown) => Array.isArray(value)
      ? value.filter((item): item is string => typeof item === "string").slice(0, 30).map(item => item.slice(0, 100)) : [];
    const data = {
      full_name: name, requested_role: "student", institute: text(body.institute) || "MCRI",
      programme: text(body.programme), cohort: text(body.cohort) || "MCRI",
      skills: skills(body.skills), essential_skills: skills(body.essential_skills),
    };
    const headers = { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" };
    const redirect = encodeURIComponent("matterforte://auth/callback");
    const invited = await fetch(`${url}/auth/v1/invite?redirect_to=${redirect}`, {
      method: "POST", headers,
      body: JSON.stringify({ email, data }),
    });
    if (!invited.ok) return reply(invited.status === 422 ? 409 : 502,
      { error: "The student could not be invited. Check whether the email is already registered." });
    const result = await invited.json();
    const student = result.user ?? result;
    if (!student.id) return reply(502, { error: "The invitation service returned an invalid response." });
    const updated = await fetch(`${url}/auth/v1/admin/users/${encodeURIComponent(student.id)}`, {
      method: "PUT", headers,
      body: JSON.stringify({ app_metadata: { ...student.app_metadata, role: "student" }, user_metadata: data }),
    });
    if (!updated.ok) return reply(502, { error: "The invitation was sent, but student role setup failed. Contact an administrator." });
    return reply(200, { id: student.id, email, invited: true });
  } catch {
    return reply(500, { error: "The invitation could not be completed. Try again." });
  }
});
