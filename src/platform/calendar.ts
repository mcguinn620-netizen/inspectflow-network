// Calendar platform layer.
// Web: generates and downloads .ics files (RFC 5545) the OS opens directly into
// Apple Calendar / Google Calendar / Outlook.
// Future Capacitor: swap in @capacitor-community/calendar for two-way sync.

export interface CalendarEvent {
  uid: string;            // stable, e.g. job-<id>@inspector.app
  title: string;
  start: Date;
  /** Minutes; defaults to 60 if omitted. */
  durationMinutes?: number;
  location?: string | null;
  description?: string | null;
  url?: string | null;
}

const pad = (n: number) => String(n).padStart(2, "0");

/** YYYYMMDDTHHMMSSZ — UTC, per RFC 5545. */
function toIcsDate(d: Date): string {
  return (
    d.getUTCFullYear().toString() +
    pad(d.getUTCMonth() + 1) +
    pad(d.getUTCDate()) + "T" +
    pad(d.getUTCHours()) +
    pad(d.getUTCMinutes()) +
    pad(d.getUTCSeconds()) + "Z"
  );
}

function escapeText(s: string): string {
  return s
    .replace(/\\/g, "\\\\")
    .replace(/;/g, "\\;")
    .replace(/,/g, "\\,")
    .replace(/\r?\n/g, "\\n");
}

function fold(line: string): string {
  // RFC 5545 §3.1: lines should be ≤75 octets; fold with CRLF + space.
  const max = 73;
  if (line.length <= max) return line;
  const parts: string[] = [];
  let i = 0;
  while (i < line.length) {
    parts.push((i === 0 ? "" : " ") + line.slice(i, i + max));
    i += max;
  }
  return parts.join("\r\n");
}

function buildVEvent(e: CalendarEvent): string {
  const dur = Math.max(5, e.durationMinutes ?? 60);
  const end = new Date(e.start.getTime() + dur * 60_000);
  const lines = [
    "BEGIN:VEVENT",
    `UID:${e.uid}`,
    `DTSTAMP:${toIcsDate(new Date())}`,
    `DTSTART:${toIcsDate(e.start)}`,
    `DTEND:${toIcsDate(end)}`,
    `SUMMARY:${escapeText(e.title)}`,
  ];
  if (e.location) lines.push(`LOCATION:${escapeText(e.location)}`);
  if (e.description) lines.push(`DESCRIPTION:${escapeText(e.description)}`);
  if (e.url) lines.push(`URL:${escapeText(e.url)}`);
  lines.push("END:VEVENT");
  return lines.map(fold).join("\r\n");
}

export function buildIcs(events: CalendarEvent[], calName = "Inspector Schedule"): string {
  const body = events.map(buildVEvent).join("\r\n");
  return [
    "BEGIN:VCALENDAR",
    "VERSION:2.0",
    "PRODID:-//Lovable//Inspector//EN",
    "CALSCALE:GREGORIAN",
    "METHOD:PUBLISH",
    `X-WR-CALNAME:${escapeText(calName)}`,
    body,
    "END:VCALENDAR",
  ].join("\r\n");
}

/** Trigger a download of an .ics file. iOS/Android open it in their calendar app. */
export function downloadIcs(filename: string, events: CalendarEvent[], calName?: string): void {
  if (typeof window === "undefined") return;
  const ics = buildIcs(events, calName);
  const blob = new Blob([ics], { type: "text/calendar;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = filename.endsWith(".ics") ? filename : `${filename}.ics`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/** Convert webcal:// → https:// or vice versa. Apple/Google accept either, but
 *  webcal:// triggers the "Subscribe?" prompt on iOS automatically. */
export function toWebcal(httpsUrl: string): string {
  return httpsUrl.replace(/^https?:\/\//, "webcal://");
}
