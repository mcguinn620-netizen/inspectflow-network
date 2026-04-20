import { DashboardLayout } from "@/components/DashboardLayout";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group";
import { useTheme } from "next-themes";
import { Monitor, Moon, Sun } from "lucide-react";
import { useEffect, useState } from "react";

export default function SettingsPage() {
  const { theme, setTheme } = useTheme();
  const [mounted, setMounted] = useState(false);

  useEffect(() => setMounted(true), []);

  return (
    <DashboardLayout>
      <div className="space-y-6 max-w-3xl">
        <div>
          <h1 className="text-2xl font-semibold tracking-tight">Settings</h1>
          <p className="text-sm text-muted-foreground mt-1">Platform configuration and preferences</p>
        </div>

        <Card>
          <CardHeader>
            <CardTitle>Appearance</CardTitle>
            <CardDescription>Choose how the interface looks. Sync with your system or pick a fixed theme.</CardDescription>
          </CardHeader>
          <CardContent>
            {mounted && (
              <RadioGroup
                value={theme ?? "system"}
                onValueChange={setTheme}
                className="grid grid-cols-1 sm:grid-cols-3 gap-3"
              >
                <ThemeOption value="light" icon={<Sun className="h-5 w-5" />} label="Light" />
                <ThemeOption value="dark" icon={<Moon className="h-5 w-5" />} label="Dark" />
                <ThemeOption value="system" icon={<Monitor className="h-5 w-5" />} label="System" />
              </RadioGroup>
            )}
          </CardContent>
        </Card>
      </div>
    </DashboardLayout>
  );
}

function ThemeOption({ value, icon, label }: { value: string; icon: React.ReactNode; label: string }) {
  return (
    <Label
      htmlFor={`theme-${value}`}
      className="flex items-center gap-3 rounded-lg border bg-card p-4 cursor-pointer hover:border-primary transition-colors [&:has([data-state=checked])]:border-primary [&:has([data-state=checked])]:bg-accent"
    >
      <RadioGroupItem id={`theme-${value}`} value={value} />
      <span className="text-muted-foreground">{icon}</span>
      <span className="font-medium">{label}</span>
    </Label>
  );
}
