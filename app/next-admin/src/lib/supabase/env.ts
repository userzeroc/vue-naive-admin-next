/**
 * Supabase environment helpers.
 *
 * Keep all environment variable access in one place so client creation fails
 * with a clear message instead of a vague "Invalid URL" or auth error later.
 */

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_PUBLISHABLE_KEY =
  process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY ??
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

/**
 * Public Supabase project URL.
 *
 * This value is safe to expose to the browser because it only identifies the
 * Supabase project. Access is still controlled by Auth and RLS policies.
 */
export function getSupabaseUrl() {
  if (!SUPABASE_URL) {
    throw new Error("Missing NEXT_PUBLIC_SUPABASE_URL");
  }

  return SUPABASE_URL;
}

/**
 * Public browser/server key used with RLS-protected requests.
 *
 * Supabase's newer dashboard labels this as a publishable key. Older projects
 * may still call the same browser-safe key an anon key, so we support both env
 * names while standardizing on NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY.
 */
export function getSupabasePublishableKey() {
  if (!SUPABASE_PUBLISHABLE_KEY) {
    throw new Error(
      "Missing NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY or NEXT_PUBLIC_SUPABASE_ANON_KEY",
    );
  }

  return SUPABASE_PUBLISHABLE_KEY;
}

/**
 * Service role key for trusted server-only operations.
 *
 * Never expose this value to Client Components or browser bundles. Use it only
 * in Route Handlers, Server Actions, scripts, or Supabase Edge Functions.
 */
export function getSupabaseServiceRoleKey() {
  const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!serviceRoleKey) {
    throw new Error("Missing SUPABASE_SERVICE_ROLE_KEY");
  }

  return serviceRoleKey;
}
