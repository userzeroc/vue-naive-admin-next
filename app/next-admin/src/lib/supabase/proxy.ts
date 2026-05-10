import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

import {
  getSupabasePublishableKey,
  getSupabaseUrl,
} from "@/lib/supabase/env";
import type { Database } from "@/lib/supabase/types";

/**
 * Refresh Supabase auth cookies before the request reaches the app.
 *
 * Next.js 16 calls this file convention "Proxy" instead of "Middleware".
 * Keeping the logic here lets src/proxy.ts stay tiny while the Supabase cookie
 * handling remains easy to test and reuse.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient<Database>(
    getSupabaseUrl(),
    getSupabasePublishableKey(),
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet, headers) {
          cookiesToSet.forEach(({ name, value }) => {
            request.cookies.set(name, value);
          });

          response = NextResponse.next({ request });

          cookiesToSet.forEach(({ name, value, options }) => {
            response.cookies.set(name, value, options);
          });

          Object.entries(headers).forEach(([key, value]) => {
            response.headers.set(key, value);
          });
        },
      },
    },
  );

  /**
   * getUser() triggers token validation and refresh when needed. Avoid placing
   * unrelated logic between client creation and this call so refreshed cookies
   * are applied before routes render.
   */
  await supabase.auth.getUser();

  return response;
}
