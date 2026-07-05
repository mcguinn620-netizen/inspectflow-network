import { useNavigate } from "react-router-dom";
import { MOCK_USERS, setMockUser } from "@/lib/authBypass";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function PickRole() {
  const navigate = useNavigate();

  const pick = (role: (typeof MOCK_USERS)[number]) => {
    setMockUser(role.role);
    navigate(role.landing, { replace: true });
  };

  return (
    <div className="min-h-screen bg-background px-6 py-12">
      <div className="max-w-6xl mx-auto">
        <div className="mb-8 text-center space-y-2">
          <Badge variant="secondary">Dev mode — login bypassed</Badge>
          <h1 className="text-3xl font-bold">Pick a role to enter as</h1>
          <p className="text-muted-foreground">
            Real authentication is disabled. Each option signs you in as a test user with that role.
          </p>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          {MOCK_USERS.map((u) => (
            <Card key={u.role} className="flex flex-col">
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg">{u.full_name}</CardTitle>
                  <Badge variant="outline" className="font-mono text-xs">
                    {u.role}
                  </Badge>
                </div>
                <CardDescription>{u.description}</CardDescription>
              </CardHeader>
              <CardContent className="mt-auto space-y-3">
                <div className="text-xs text-muted-foreground space-y-0.5">
                  <div>Email: <span className="font-mono">{u.email}</span></div>
                  <div>Org: {u.org_name}</div>
                  <div>Lands on: <span className="font-mono">{u.landing}</span></div>
                </div>
                <Button className="w-full" onClick={() => pick(u)}>
                  Enter as {u.full_name.split(" ")[0]}
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}
