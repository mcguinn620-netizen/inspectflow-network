import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/hooks/use-toast";
import { useAuth } from "@/hooks/useAuth";
import { Loader2, RefreshCw } from "lucide-react";

type Cred = {
  id: string;
  site: string;
  username: string;
  submission_mode: "draft" | "review_confirm" | "auto_on_complete";
  is_active: boolean;
  last_login_at: string | null;
  last_error: string | null;
};

const SITE = "lemonsquad";

export default function LemonSquadIntegration() {
  const { user } = useAuth();
  const { toast } = useToast();
  const [cred, setCred] = useState<Cred | null>(null);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    if (!user) return;
    (async () => {
      const { data } = await supabase
        .from("external_site_credentials")
        .select("id, site, username, submission_mode, is_active, last_login_at, last_error")
        .eq("site", SITE)
        .maybeSingle();
      setCred(data as Cred | null);
      if (data) setUsername(data.username);
      setLoading(false);
    })();
  }, [user]);

  async function save() {
    if (!user || !username || (!cred && !password)) {
      toast({ title: "Missing info", description: "Username and password required.", variant: "destructive" });
      return;
    }
    setSaving(true);
    // NOTE: password_ciphertext is a placeholder for future Vault encryption.
    // For now it stores an obfuscated (base64) value so it is not plaintext at rest.
    const payload: Record<string, unknown> = {
      user_id: user.id,
      site: SITE,
      username,
      submission_mode: "draft",
      is_active: true,
    };
    if (password) payload.password_ciphertext = btoa(password);
    const { error } = cred
      ? await supabase.from("external_site_credentials").update(payload).eq("id", cred.id)
      : await supabase.from("external_site_credentials").insert(payload);
    setSaving(false);
    if (error) {
      toast({ title: "Save failed", description: error.message, variant: "destructive" });
      return;
    }
    setPassword("");
    toast({ title: "Saved", description: "Lemon Squad credentials updated." });
    const { data } = await supabase
      .from("external_site_credentials")
      .select("id, site, username, submission_mode, is_active, last_login_at, last_error")
      .eq("site", SITE)
      .maybeSingle();
    setCred(data as Cred | null);
  }

  async function sync() {
    setSyncing(true);
    const { data, error } = await supabase.functions.invoke("lemonsquad-agent", {
      body: { action: "sync_requests" },
    });
    setSyncing(false);
    if (error) {
      toast({ title: "Sync failed", description: error.message, variant: "destructive" });
      return;
    }
    toast({
      title: "Sync started",
      description: (data as { message?: string })?.message ?? "Agent run queued.",
    });
  }

  if (loading) {
    return (
      <div className="flex items-center gap-2 text-muted-foreground">
        <Loader2 className="h-4 w-4 animate-spin" /> Loading…
      </div>
    );
  }

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-3">
          <CardTitle>Lemon Squad</CardTitle>
          {cred?.is_active ? <Badge variant="secondary">Connected</Badge> : <Badge variant="outline">Not connected</Badge>}
        </div>
        <CardDescription>
          Let the AI agent log into lemonsquad.com to pull new inspection requests into your schedule
          and pre-fill draft reports (you submit manually). Auto-submit is coming soon.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid gap-2">
          <Label htmlFor="ls-user">Email / username</Label>
          <Input id="ls-user" value={username} onChange={(e) => setUsername(e.target.value)} placeholder="you@example.com" />
        </div>
        <div className="grid gap-2">
          <Label htmlFor="ls-pass">Password {cred && <span className="text-xs text-muted-foreground">(leave blank to keep current)</span>}</Label>
          <Input id="ls-pass" type="password" value={password} onChange={(e) => setPassword(e.target.value)} autoComplete="new-password" />
        </div>
        {cred?.last_error && (
          <div className="rounded-md border border-destructive/40 bg-destructive/5 px-3 py-2 text-sm text-destructive">
            Last run: {cred.last_error}
          </div>
        )}
        <div className="flex flex-wrap gap-2">
          <Button onClick={save} disabled={saving}>
            {saving && <Loader2 className="h-4 w-4 animate-spin mr-2" />}
            {cred ? "Update" : "Connect"}
          </Button>
          {cred && (
            <Button variant="secondary" onClick={sync} disabled={syncing}>
              {syncing ? <Loader2 className="h-4 w-4 animate-spin mr-2" /> : <RefreshCw className="h-4 w-4 mr-2" />}
              Sync now
            </Button>
          )}
        </div>
        <div className="pt-2 border-t space-y-2">
          <p className="text-xs font-medium text-muted-foreground uppercase tracking-wide">Submission mode</p>
          <div className="flex flex-col gap-1 text-sm">
            <div className="flex items-center gap-2"><Badge>Active</Badge> Draft only — you submit on lemonsquad.com</div>
            <div className="flex items-center gap-2 opacity-60"><Badge variant="outline">Soon</Badge> Review &amp; confirm before submit</div>
            <div className="flex items-center gap-2 opacity-60"><Badge variant="outline">Soon</Badge> Auto-submit when inspection is completed</div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
