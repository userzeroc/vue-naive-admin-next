import type { NextRequest } from "next/server";

import { updateSession } from "@/lib/supabase/proxy";

/**
 * Next.js 16 Proxy entrypoint.
 *
 * Supabase SSR needs this boundary to refresh auth cookies before Server
 * Components render. Route-level redirects can be added here once /login and
 * the protected admin layout exist.
 */
export function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: [
    /**
     * Skip static files and image optimization assets. Auth cookies only need
     * to be refreshed for application routes and route handlers.
     */
    "/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)",
  ],
};
