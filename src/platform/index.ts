// Platform abstraction layer.
// Browser implementations now; Capacitor-ready interfaces.
// All field-execution UI should call these instead of touching DOM/window APIs
// directly so we can swap to native implementations later.
export * as platformMaps from "./maps";
export * as platformExport from "./export";
export * as platformShare from "./share";
export * as platformLocation from "./location";
