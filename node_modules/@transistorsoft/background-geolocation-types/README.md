# @transistorsoft/background-geolocation-types

Shared **TypeScript type definitions** and **generated API documentation** for Transistor Software’s Background Geolocation SDKs:

- **React Native**
- **Capacitor**
- **Cordova**

This package centralizes all public TypeScript interfaces, enums, utility types, and TypeDoc‑generated documentation shared across platform SDKs.  
It contains **types only** — no runtime code.

---

## 📦 Installation

Install as a development dependency:

```bash
npm install @transistorsoft/background-geolocation-types --save-dev
```

```bash
yarn add -D @transistorsoft/background-geolocation-types
```

```bash
pnpm add -D @transistorsoft/background-geolocation-types
```

---

## 🎯 Purpose

This package exists to:

1. Provide **strict, shared TypeScript types** across all Background Geolocation SDKs.
2. Serve as the source for **Typedoc documentation**.
3. Ensure consistent API signatures across React Native, Capacitor, and Cordova.

This avoids duplication and keeps all platform SDKs perfectly in sync.

---

## 📘 Using the Types

Typically, consuming SDKs re‑export all public types:

```ts
import BackgroundGeolocation, {
  Config,
  GeoConfig,
  HttpConfig,
  PersistMode,
  Location,
  State
} from '{{pluginName}}';
```

If desired, types can also be imported directly:

```ts
import type { Location, GeofenceEvent, PersistMode } 
  from '@transistorsoft/background-geolocation-types';
```

---

## 📚 Documentation

Generate API docs using:

```bash
pnpm run docs
```

This runs TypeDoc with the custom Transistorsoft plugins:

- **typedoc-plugin-templates**
- **typedoc-plugin-gitlink**
- **typedoc-plugin-mediaplayer**
- **typedoc-plugin-site**

Docs output to:

```
./docs
```

---

## 🛠️ Development

Build the project:

```bash
pnpm run clean && pnpm run build
```

Watch mode:

```bash
pnpm run watch
```

---

## 📁 Structure

```
background-geolocation-types/
  ├── src/
  ├── dist/
  ├── docs/
  ├── tools/
  ├── typedoc.json
  └── tsconfig.json
```

---

## 🤝 Contributing

Contributions are welcome — especially improvements to TypeScript typings and documentation.

Please ensure:

- No runtime logic is added — this package is **types only**.
- Definitions remain platform‑agnostic.
- Changes reflect the APIs of all supported SDKs.

---

## 📄 License

Commercial license. See `LICENSE` for details.


