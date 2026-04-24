// Share platform layer.
// Web: navigator.share + clipboard fallback.
// Native (Capacitor): @capacitor/share — opens system share sheet.

import { isNative, loadNativePlugin } from "./native";

export interface ShareOptions {
  title?: string;
  text?: string;
  url?: string;
  files?: File[];
}

export async function share(opts: ShareOptions): Promise<boolean> {
  if (isNative()) {
    const mod = await loadNativePlugin<any>("@capacitor/share");
    if (mod?.Share?.share) {
      try {
        await mod.Share.share({
          title: opts.title,
          text: opts.text,
          url: opts.url,
          dialogTitle: opts.title ?? "Share",
        });
        return true;
      } catch {
        /* fall through */
      }
    }
  }
  try {
    if (typeof navigator !== "undefined" && (navigator as any).share) {
      await (navigator as any).share(opts);
      return true;
    }
    if (opts.url && navigator.clipboard) {
      await navigator.clipboard.writeText(opts.url);
      return true;
    }
    return false;
  } catch {
    return false;
  }
}

export function canShareFiles(files: File[]) {
  return typeof navigator !== "undefined" && (navigator as any).canShare?.({ files });
}
