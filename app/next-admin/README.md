# next-admin

Next.js 16 + Supabase migration target for the admin system.

## Getting Started

Install dependencies and run the development server from this directory:

```bash
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) with your browser to see the result.

## Project Structure

Application source code lives under `src/` so framework configuration, environment files, and public assets stay at the project root.

```text
next-admin/
├── docs/                  # Migration notes and architecture analysis
├── public/                # Static assets served from /
├── src/
│   ├── actions/           # Server Actions
│   ├── app/               # Next.js App Router
│   ├── components/        # Reusable UI and layout components
│   ├── hooks/             # Client-side React hooks
│   ├── lib/               # Supabase clients and auth helpers
│   ├── proxy.ts           # Next.js Proxy entrypoint
│   └── types/             # Shared TypeScript types
├── supabase/
│   └── migrations/        # Database migration SQL
├── next.config.ts
├── package.json
└── tsconfig.json
```

## Source Aliases

`@/*` points at `src/*`, so imports such as `@/lib/auth` resolve to `src/lib/auth.ts`.

## Notes

- Keep `public/`, `next.config.ts`, `tsconfig.json`, `package.json`, and `.env.*` at the project root.
- Keep `proxy.ts` inside `src/` because the App Router now lives in `src/app`.
- See `docs/migration_design.md` for the Vue + Nest to Next.js + Supabase migration plan.

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
