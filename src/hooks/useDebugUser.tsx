import { createContext, useContext, useEffect, useState, useCallback } from "react";
import {
  clearDebugUser as storageClear,
  isDebugMode,
  loadDebugUser,
  saveDebugUser as storageSave,
  type DebugUser,
} from "@/lib/debugAuth";

interface DebugUserContextValue {
  debugUser: DebugUser | null;
  setDebugUser: (u: DebugUser) => void;
  clearDebugUser: () => void;
  enabled: boolean;
}

const DebugUserContext = createContext<DebugUserContextValue>({
  debugUser: null,
  setDebugUser: () => {},
  clearDebugUser: () => {},
  enabled: false,
});

export function DebugUserProvider({ children }: { children: React.ReactNode }) {
  const enabled = isDebugMode();
  const [debugUser, setDebugUserState] = useState<DebugUser | null>(() =>
    enabled ? loadDebugUser() : null,
  );

  useEffect(() => {
    if (!enabled) return;
    const sync = () => setDebugUserState(loadDebugUser());
    window.addEventListener("storage", sync);
    window.addEventListener("debug-user-changed", sync);
    return () => {
      window.removeEventListener("storage", sync);
      window.removeEventListener("debug-user-changed", sync);
    };
  }, [enabled]);

  const setDebugUser = useCallback((u: DebugUser) => {
    storageSave(u);
    setDebugUserState(u);
  }, []);

  const clearDebugUser = useCallback(() => {
    storageClear();
    setDebugUserState(null);
  }, []);

  return (
    <DebugUserContext.Provider value={{ debugUser, setDebugUser, clearDebugUser, enabled }}>
      {children}
    </DebugUserContext.Provider>
  );
}

export function useDebugUser() {
  return useContext(DebugUserContext);
}
