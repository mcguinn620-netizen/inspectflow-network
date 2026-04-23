// Re-export from platform layer to keep existing import sites working.
// New code should import from "@/platform/maps" directly.
export type { MapTarget } from "@/platform/maps";
export { buildMapsUrl, open as openInMaps } from "@/platform/maps";
