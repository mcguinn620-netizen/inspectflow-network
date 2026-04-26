import { describe, it, expect, afterEach } from "vitest";
import { render, cleanup } from "@testing-library/react";
import { Sheet, SheetContent } from "@/components/ui/sheet";
import {
  AlertDialog,
  AlertDialogContent,
} from "@/components/ui/alert-dialog";
import { Dialog, DialogContent } from "@/components/ui/dialog";

/**
 * Visual-regression guard for Sheet & AlertDialog positioning.
 *
 * Bug being prevented:
 *   On tablet/desktop, sheets/dialogs were ending mid-screen because they
 *   reserved space for the mobile bottom tab bar (--sheet-bottom / --ad-bottom)
 *   without an `md:` reset that zeroes that reservation on larger viewports.
 *
 * Strategy:
 *   jsdom can't actually layout Tailwind classes, so we snapshot the className
 *   string of the rendered content. Any future change that drops the responsive
 *   `md:` override (or the bottom CSS variable) will fail this test loudly.
 */

afterEach(() => cleanup());

const renderedClass = (selector: string): string => {
  const el = document.querySelector(selector);
  if (!el) throw new Error(`Element not found: ${selector}`);
  return el.className;
};

describe("Sheet positioning (tablet/desktop regression)", () => {
  for (const side of ["top", "bottom", "left", "right"] as const) {
    it(`SheetContent[side=${side}] keeps md: bottom reset and uses --sheet-bottom`, () => {
      render(
        <Sheet open>
          <SheetContent side={side} data-testid={`sheet-${side}`}>
            content
          </SheetContent>
        </Sheet>,
      );

      const cls = renderedClass(`[data-testid="sheet-${side}"]`);

      // Mobile reservation for bottom tab bar must be present.
      expect(cls).toContain("[--sheet-bottom:calc(env(safe-area-inset-bottom)+4rem)]");

      // CRITICAL: tablet/desktop must zero out the tab-bar reservation,
      // otherwise the sheet ends mid-screen on md+ viewports.
      expect(cls).toContain("md:[--sheet-bottom:env(safe-area-inset-bottom)]");

      // Top reservation (header) must always be present.
      expect(cls).toContain("[--sheet-top:calc(env(safe-area-inset-top)+3.5rem)]");

      // Side-specific anchoring sanity.
      if (side === "bottom") {
        expect(cls).toContain("bottom-[var(--sheet-bottom)]");
      }
      if (side === "top") {
        expect(cls).toContain("top-[var(--sheet-top)]");
      }
      if (side === "left" || side === "right") {
        expect(cls).toContain("top-[var(--sheet-top)]");
        expect(cls).toContain("bottom-[var(--sheet-bottom)]");
      }
    });
  }

  it("SheetContent[side=bottom] full snapshot", () => {
    render(
      <Sheet open>
        <SheetContent side="bottom" data-testid="sheet-snap">
          content
        </SheetContent>
      </Sheet>,
    );
    expect(renderedClass('[data-testid="sheet-snap"]')).toMatchInlineSnapshot(
      `"fixed z-50 gap-4 bg-background p-6 shadow-lg transition ease-in-out overflow-y-auto overscroll-contain data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:duration-300 data-[state=open]:duration-500 inset-x-0 border-t data-[state=closed]:slide-out-to-bottom data-[state=open]:slide-in-from-bottom [--sheet-top:calc(env(safe-area-inset-top)+3.5rem)] [--sheet-bottom:calc(env(safe-area-inset-bottom)+4rem)] md:[--sheet-bottom:env(safe-area-inset-bottom)] bottom-[var(--sheet-bottom)] max-h-[calc(100dvh-var(--sheet-top)-var(--sheet-bottom))]"`
    );
  });
});

describe("AlertDialog positioning (tablet/desktop regression)", () => {
  it("AlertDialogContent keeps md: bottom reset and sm: centered override", () => {
    render(
      <AlertDialog open>
        <AlertDialogContent data-testid="ad">content</AlertDialogContent>
      </AlertDialog>,
    );
    const cls = renderedClass('[data-testid="ad"]');

    // Mobile bottom reservation present.
    expect(cls).toContain("[--ad-bottom:calc(env(safe-area-inset-bottom)+4rem+0.5rem)]");
    // CRITICAL: md+ removes tab-bar reservation.
    expect(cls).toContain("md:[--ad-bottom:calc(env(safe-area-inset-bottom)+0.5rem)]");
    // sm+ recenters dialog (so it's not stuck stretched).
    expect(cls).toContain("sm:top-[50%]");
    expect(cls).toContain("sm:bottom-auto");
    expect(cls).toContain("sm:translate-y-[-50%]");
  });
});

describe("Dialog positioning (tablet/desktop regression)", () => {
  it("DialogContent keeps bounds out of inline styles and uses responsive classes", () => {
    render(
      <Dialog open>
        <DialogContent data-testid="dialog">content</DialogContent>
      </Dialog>,
    );

    const el = document.querySelector('[data-testid="dialog"]') as HTMLElement | null;
    if (!el) throw new Error("Element not found: DialogContent");

    const cls = el.className;

    expect(el.style.top).toBe("");
    expect(el.style.bottom).toBe("");
    expect(cls).toContain("[--dialog-bottom:calc(env(safe-area-inset-bottom)+4rem+0.5rem)]");
    expect(cls).toContain("md:[--dialog-bottom:calc(env(safe-area-inset-bottom)+0.5rem)]");
    expect(cls).toContain("sm:top-[50%]");
    expect(cls).toContain("sm:bottom-auto");
    expect(cls).toContain("sm:translate-y-[-50%]");
  });
});
