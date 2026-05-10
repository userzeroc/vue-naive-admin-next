import { createClient } from "@supabase/supabase-js";

import {
  getSupabaseServiceRoleKey,
  getSupabaseUrl,
} from "@/lib/supabase/env";
import type { Database } from "@/lib/supabase/types";

/**
 * Create a Supabase admin client for trusted server-side code only.
 *
 * This client bypasses RLS with the service role key, so never import it in
 * Client Components. Use it for admin-only Route Handlers, Server Actions,
 * background scripts, or data migration utilities.
 */
export function createAdminClient() {
  return createClient<Database>(getSupabaseUrl(), getSupabaseServiceRoleKey(), {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
