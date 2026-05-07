import Link from "next/link";
import { createClient } from "@/lib/supabase/server";
import LogoutButton from "./LogoutButton";

export default async function Nav() {
  const supabase = createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return (
    <header className="sticky top-0 z-10 border-b border-foreground/10 bg-background/80 backdrop-blur">
      <div className="mx-auto flex max-w-2xl items-center justify-between px-6 py-3">
        <Link
          href={user ? "/interview" : "/"}
          className="text-sm font-semibold tracking-tight"
        >
          Career OS
        </Link>
        {user ? (
          <LogoutButton />
        ) : (
          <Link
            href="/login"
            className="rounded-md border border-foreground/20 px-3 py-1.5 text-xs font-medium hover:bg-foreground/5"
          >
            Log in
          </Link>
        )}
      </div>
    </header>
  );
}
