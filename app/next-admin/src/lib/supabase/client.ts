"use client";

import { createBrowserClient } from "@supabase/ssr";

import {
  getSupabasePublishableKey,
  getSupabaseUrl,
} from "@/lib/supabase/env";
import type { Database } from "@/lib/supabase/types";

/**
 * Create a Supabase client for Client Components.
 *
 * This client uses the browser-safe publishable key and relies on Supabase RLS
 * for authorization. Do not import server-only helpers from this file.
 */
export function createClient() {
  return createBrowserClient<Database>(
    getSupabaseUrl(),
    getSupabasePublishableKey(),
  );
}
