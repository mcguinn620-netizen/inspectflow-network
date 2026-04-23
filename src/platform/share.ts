// Share platform layer.
// Web: navigator.share where supported, else copy-to-clipboard fallback.
// Future Capacitor: @capacitor/share plugin.

export interface ShareOptions {
  title?: string;
  text?: string;
  url?: string;
  files?: File[];
}

export async function share(opts: ShareOptions): Promise<boolean> {
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
