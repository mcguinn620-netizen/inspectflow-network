import { useState, useEffect, createContext, useContext } from "react";
import { supabase } from "@/integrations/supabase/client";
import type { User, Session } from "@supabase/supabase-js";
import { AUTH_BYPASS, getMockUser, clearMockUser } from "@/lib/authBypass";

interface AuthContextType {
  user: User | null;
  session: Session | null;
  loading: boolean;
  signUp: (email: string, password: string, fullName: string) => Promise<{ error: Error | null }>;
  signIn: (email: string, password: string) => Promise<{ error: Error | null }>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

function buildMockUser(): User | null {
  const m = getMockUser();
  if (!m) return null;
  return {
    id: m.id,
    email: m.email,
    aud: "authenticated",
    role: "authenticated",
    app_metadata: {},
    user_metadata: { full_name: m.full_name },
    created_at: new Date(0).toISOString(),
  } as unknown as User;
}

function MockAuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(() => buildMockUser());

  useEffect(() => {
    const handler = () => setUser(buildMockUser());
    window.addEventListener("mock-auth-change", handler);
    window.addEventListener("storage", handler);
    return () => {
      window.removeEventListener("mock-auth-change", handler);
      window.removeEventListener("storage", handler);
    };
  }, []);

  const session = user
    ? ({ user, access_token: "mock", refresh_token: "mock", token_type: "bearer", expires_in: 3600 } as unknown as Session)
    : null;

  const value: AuthContextType = {
    user,
    session,
    loading: false,
    signUp: async () => ({ error: null }),
    signIn: async () => ({ error: null }),
    signOut: async () => {
      clearMockUser();
      window.location.href = "/pick-role";
    },
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

function RealAuthProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setUser(session?.user ?? null);
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  const signUp = async (email: string, password: string, fullName: string) => {
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { full_name: fullName } },
    });
    return { error: error as Error | null };
  };

  const signIn = async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    return { error: error as Error | null };
  };

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <AuthContext.Provider value={{ user, session, loading, signUp, signIn, signOut }}>
      {children}
    </AuthContext.Provider>
  );
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  return AUTH_BYPASS ? <MockAuthProvider>{children}</MockAuthProvider> : <RealAuthProvider>{children}</RealAuthProvider>;
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within AuthProvider");
  return context;
}
