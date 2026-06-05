import { useEffect, useMemo, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import { Card } from "@/components/ui/card";
import { Search, AlertTriangle, Loader2 } from "lucide-react";
import {
  type DebugUser,
  roleBadgeClasses,
  roleLabel,
} from "@/lib/debugAuth";
import { useDebugUser } from "@/hooks/useDebugUser";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";

function initials(name: string | null | undefined, fallback = "?") {
  if (!name) return fallback;
  return name
    .split(/\s+/)
    .filter(Boolean)
    .slice(0, 2)
    .map((s) => s[0]?.toUpperCase())
    .join("") || fallback;
}

export function DebugUserPicker({ redirectTo = "/" }: { redirectTo?: string }) {
  const [users, setUsers] = useState<DebugUser[]>([]);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const { setDebugUser } = useDebugUser();
  const navigate = useNavigate();

  useEffect(() => {
    let cancelled = false;
    (async () => {
      setLoading(true);
      setError(null);
      const { data: memberships, error: mErr } = await supabase
        .from("organization_users")
        .select("user_id, role, organization_id, organizations(name)")
        .order("created_at", { ascending: false })
        .limit(500);
      if (cancelled) return;
      if (mErr) {
        setError(mErr.message);
        setLoading(false);
        return;
      }
      const userIds = Array.from(
        new Set((memberships ?? []).map((m: any) => m.user_id).filter(Boolean)),
      );
      let profileMap = new Map<string, { full_name: string | null }>();
      if (userIds.length) {
        const { data: profiles, error: pErr } = await supabase
          .from("profiles")
          .select("id, full_name")
          .in("id", userIds);
        if (cancelled) return;
        if (pErr) {
          setError(pErr.message);
          setLoading(false);
          return;
        }
        profileMap = new Map(
          (profiles ?? []).map((p: any) => [p.id, { full_name: p.full_name ?? null }]),
        );
      }
      const mapped: DebugUser[] = (memberships ?? []).map((row: any) => ({
        id: row.user_id,
        full_name: profileMap.get(row.user_id)?.full_name ?? null,
        organization_id: row.organization_id,
        organization_name: row.organizations?.name ?? null,
        role: row.role,
      }));
      mapped.sort((a, b) =>
        (a.full_name ?? "").localeCompare(b.full_name ?? ""),
      );
      setUsers(mapped);
      setLoading(false);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    if (!q) return users;
    return users.filter(
      (u) =>
        (u.full_name ?? "").toLowerCase().includes(q) ||
        (u.email ?? "").toLowerCase().includes(q) ||
        (u.organization_name ?? "").toLowerCase().includes(q) ||
        u.role.toLowerCase().includes(q),
    );
  }, [users, query]);

  const handlePick = (u: DebugUser) => {
    setDebugUser(u);
    toast.success(`Impersonating ${u.full_name ?? u.id} (${roleLabel(u.role)})`);
    navigate(redirectTo, { replace: true });
  };

  return (
    <div className="mx-auto w-full max-w-2xl py-6 px-3 sm:px-4 sm:py-8">

      <div className="mb-6 flex items-start gap-3 rounded-lg border border-amber-500/40 bg-amber-500/10 p-4">
        <AlertTriangle className="h-5 w-5 text-amber-600 dark:text-amber-400 mt-0.5" />
        <div className="text-sm">
          <p className="font-semibold text-amber-700 dark:text-amber-300">
            Debug User Picker (Development Only)
          </p>
          <p className="text-muted-foreground">
            Choose a user to impersonate. No password required. Production builds never see this screen.
          </p>
        </div>
      </div>

      <div className="relative mb-4">
        <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          autoFocus
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search by name, email, organization, or role…"
          className="pl-9 h-11"
        />
      </div>

      {loading && (
        <div className="flex items-center justify-center py-12 text-muted-foreground">
          <Loader2 className="h-5 w-5 animate-spin mr-2" />
          Loading users…
        </div>
      )}

      {error && (
        <Card className="p-4 border-destructive/40">
          <p className="text-sm text-destructive">Failed to load users: {error}</p>
        </Card>
      )}

      {!loading && !error && filtered.length === 0 && (
        <Card className="p-6 text-center text-sm text-muted-foreground">
          No users match "{query}".
        </Card>
      )}

      <div className="space-y-2">
        {filtered.map((u) => (
          <button
            key={`${u.id}-${u.organization_id}`}
            onClick={() => handlePick(u)}
            className="w-full text-left rounded-lg border bg-card hover:bg-accent/40 transition-colors p-4 flex items-center gap-4 min-h-[72px]"
          >
            <Avatar className="h-12 w-12">
              <AvatarFallback className="text-sm font-semibold">
                {initials(u.full_name, "U")}
              </AvatarFallback>
            </Avatar>
            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <p className="font-semibold truncate">{u.full_name ?? "(no name)"}</p>
              </div>
              {u.email && (
                <p className="text-xs text-muted-foreground truncate">{u.email}</p>
              )}
              <p className="text-xs text-muted-foreground truncate mt-0.5">
                {u.organization_name ?? "(no org)"}
              </p>
            </div>
            <span
              className={`inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-semibold ${roleBadgeClasses(u.role)}`}
            >
              {roleLabel(u.role)}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}
