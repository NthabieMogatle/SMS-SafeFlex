"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { createClient } from "@/lib/supabase/client";

type ExperienceLevel = "entry" | "mid" | "senior";

type Initial = {
  target_role: string;
  industry: string;
  experience_level: ExperienceLevel;
} | null;

// Must match the key used by InterviewClient. Kept inline (not extracted)
// to keep this surgical fix minimal — see related-issues note in the PR.
const DRAFT_KEY = "interview:draft:v1";

function clearLocalDraft() {
  try {
    if (typeof window !== "undefined") {
      window.localStorage.removeItem(DRAFT_KEY);
    }
  } catch {
    // ignore quota / privacy-mode errors
  }
}

export default function SetupForm({
  initial,
  forceNew = false,
}: {
  initial: Initial;
  forceNew?: boolean;
}) {
  const router = useRouter();
  const [targetRole, setTargetRole] = useState(initial?.target_role ?? "");
  const [industry, setIndustry] = useState(initial?.industry ?? "");
  // When the form is rendered for a brand-new interview (forceNew), the
  // experience level starts unselected so the user has to actively pick.
  // Otherwise (the "Update profile" flow), we pre-fill with whatever they
  // last selected.
  const [experienceLevel, setExperienceLevel] = useState<ExperienceLevel | "">(
    initial?.experience_level ?? "",
  );
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);

    if (!experienceLevel) {
      setError("Please pick an experience level.");
      return;
    }

    setLoading(true);
    try {
      const supabase = createClient();
      const {
        data: { user },
      } = await supabase.auth.getUser();
      if (!user) {
        setError("Your session expired. Please log in again.");
        setLoading(false);
        return;
      }
      const { error: upsertError } = await supabase.from("profiles").upsert(
        {
          user_id: user.id,
          target_role: targetRole.trim(),
          industry: industry.trim(),
          experience_level: experienceLevel,
        },
        { onConflict: "user_id" },
      );
      if (upsertError) {
        setError("We couldn't save your profile. Please try again.");
        setLoading(false);
        return;
      }
      // When the user explicitly chose "Start new interview", drop any
      // in-flight draft so the next /interview render is guaranteed-fresh
      // even if they didn't change role/industry/level. (For the regular
      // "Update profile" flow we preserve the draft so users can resume.)
      if (forceNew) {
        clearLocalDraft();
      }
      router.push("/interview");
      router.refresh();
    } catch {
      setError(
        "Something went wrong. Please check your connection and try again.",
      );
      setLoading(false);
    }
  }

  const heading = forceNew ? "Start a new interview" : "Tell us about your goal";
  const subheading = forceNew
    ? "Pick the role, industry, and experience level you want to practice for."
    : "We'll tailor your practice interview based on these.";
  const submitLabel = forceNew ? "Generate questions" : "Save profile";

  return (
    <main className="mx-auto flex min-h-screen max-w-xl flex-col justify-center px-6 py-12">
      <h1 className="mb-2 text-2xl font-semibold">{heading}</h1>
      <p className="mb-6 text-sm text-foreground/60">{subheading}</p>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="mb-1 block text-sm font-medium" htmlFor="role">
            Target role
          </label>
          <input
            id="role"
            type="text"
            required
            value={targetRole}
            onChange={(e) => setTargetRole(e.target.value)}
            placeholder="e.g. Product Manager"
            className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
          />
        </div>
        <div>
          <label className="mb-1 block text-sm font-medium" htmlFor="industry">
            Industry
          </label>
          <input
            id="industry"
            type="text"
            required
            value={industry}
            onChange={(e) => setIndustry(e.target.value)}
            placeholder="e.g. Fintech"
            className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
          />
        </div>
        <div>
          <label
            className="mb-1 block text-sm font-medium"
            htmlFor="experience"
          >
            Experience level
          </label>
          <select
            id="experience"
            required
            value={experienceLevel}
            onChange={(e) =>
              setExperienceLevel(e.target.value as ExperienceLevel | "")
            }
            className="w-full rounded-md border border-foreground/20 bg-transparent px-3 py-2"
          >
            <option value="" disabled>
              Select…
            </option>
            <option value="entry">Entry-level</option>
            <option value="mid">Mid-level</option>
            <option value="senior">Senior</option>
          </select>
        </div>
        {error && <p className="text-sm text-red-500">{error}</p>}
        <button
          type="submit"
          disabled={loading}
          className="w-full rounded-md bg-foreground px-4 py-2.5 text-sm font-medium text-background hover:opacity-90 disabled:opacity-50"
        >
          {loading ? "Saving…" : submitLabel}
        </button>
      </form>
    </main>
  );
}
