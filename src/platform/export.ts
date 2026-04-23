// Export/file-write platform layer.
// Web: Blob + anchor download. Falls back to share sheet on iOS PWA where
// programmatic download is restricted.
// Future Capacitor: write to Filesystem and trigger Share plugin.

import { share } from "./share";

export function toCsv(rows: Array<Record<string, any>>, columns?: string[]): string {
  if (rows.length === 0) return "";
  const cols = columns ?? Array.from(new Set(rows.flatMap((r) => Object.keys(r))));
  const escape = (v: any) => {
    if (v === null || v === undefined) return "";
    const s = String(v);
    return /[",\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
  };
  return [cols.join(","), ...rows.map((r) => cols.map((c) => escape(r[c])).join(","))].join("\n");
}

function isIosLike() {
  if (typeof navigator === "undefined") return false;
  return /iPhone|iPad|iPod/.test(navigator.userAgent);
}

export async function downloadFile(filename: string, content: string, mimeType = "text/csv;charset=utf-8;") {
  const blob = new Blob([content], { type: mimeType });

  // Prefer share sheet on iOS PWA (anchor downloads are unreliable there).
  if (isIosLike() && (navigator as any).canShare?.({ files: [new File([blob], filename, { type: mimeType })] })) {
    const ok = await share({
      title: filename,
      files: [new File([blob], filename, { type: mimeType })],
    });
    if (ok) return;
  }

  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1500);
}

export const downloadCsv = (filename: string, csv: string) =>
  downloadFile(filename, csv, "text/csv;charset=utf-8;");
