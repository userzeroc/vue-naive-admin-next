import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

import {
  getSupabasePublishableKey,
  getSupabaseUrl,
} from "@/lib/supabase/env";
import type { Database } from "@/lib/supabase/types";

/**
 * Create a per-request Supabase client for Server Components, Route Handlers,
 * and Server Actions.
 *
 * The client reads auth cookies from the incoming request. When the current
 * runtime allows cookie writes, token refreshes are written back as well.
 */
export async function createClient() {
  const cookieStore = await cookies();

  return createServerClient<Database>(
    getSupabaseUrl(),
    getSupabasePublishableKey(),
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, options);
            });
          } catch {
            /**
             * Server Components cannot always mutate cookies. That is okay as
             * long as src/proxy.ts calls updateSession() before rendering.
             */
          }
        },
      },
    },
  );
}

/**
 * Fetch the verified Supabase user for authorization decisions.
 *
 * Prefer getUser() over getSession() when deciding access, because getUser()
 * validates the token with Supabase Auth instead of trusting cookie contents.
 */
export async function getCurrentUser() {
  const supabase = await createClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error) {
    return null;
  }

  return user;
}
