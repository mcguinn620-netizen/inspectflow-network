// Platform abstraction layer.
// Browser implementations now; Capacitor wired for native shells.
// All field-execution UI should call these instead of touching DOM/window APIs
// directly so we can swap to native implementations without touching call sites.
export * as platformMaps from "./maps";
export * as platformExport from "./export";
export * as platformShare from "./share";
export * as platformLocation from "./location";
export * as platformCalendar from "./calendar";
export * as platformStorage from "./storage";
export { isNative, getPlatform } from "./native";

