import { cache } from "react";

import { createClient } from "@/lib/supabase/server";

/**
 * Cached per-request current user lookup.
 *
 * React cache() prevents duplicate Supabase Auth calls when multiple Server
 * Components in the same request need the user.
 */
export const getCurrentUser = cache(async () => {
  const supabase = await createClient();
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();

  if (error) {
    return null;
  }

  return user;
});

/**
 * Current user's profile row.
 *
 * This mirrors the old /user/detail foundation. After migrations are added,
 * profiles should be protected by RLS so users can only read allowed rows.
 */
export const getCurrentProfile = cache(async () => {
  const user = await getCurrentUser();

  if (!user) {
    return null;
  }

  const supabase = await createClient();
  const { data, error } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();

  if (error) {
    return null;
  }

  return data;
});

/**
 * Current user's permissions.
 *
 * The RPC will be implemented in Supabase migrations. Keeping the call behind
 * this helper gives pages/layouts one stable API while the SQL evolves.
 */
export const getCurrentPermissions = cache(async () => {
  const supabase = await createClient();
  const { data, error } = await supabase.rpc("get_current_user_permissions");

  if (error) {
    return [];
  }

  return data;
});
