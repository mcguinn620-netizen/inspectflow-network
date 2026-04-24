// 2025 US Federal income tax brackets + standard deduction
// Source: IRS Rev. Proc. 2024-40 (tax year 2025)

export type FilingStatus = "single" | "married_joint" | "married_separate" | "head_of_household";

export interface Bracket {
  /** Income at which this rate begins (taxable income, after deductions) */
  threshold: number;
  /** Marginal rate as decimal (0.22 = 22%) */
  rate: number;
}

export const FEDERAL_BRACKETS_2025: Record<FilingStatus, Bracket[]> = {
  single: [
    { threshold: 0, rate: 0.10 },
    { threshold: 11925, rate: 0.12 },
    { threshold: 48475, rate: 0.22 },
    { threshold: 103350, rate: 0.24 },
    { threshold: 197300, rate: 0.32 },
    { threshold: 250525, rate: 0.35 },
    { threshold: 626350, rate: 0.37 },
  ],
  married_joint: [
    { threshold: 0, rate: 0.10 },
    { threshold: 23850, rate: 0.12 },
    { threshold: 96950, rate: 0.22 },
    { threshold: 206700, rate: 0.24 },
    { threshold: 394600, rate: 0.32 },
    { threshold: 501050, rate: 0.35 },
    { threshold: 751600, rate: 0.37 },
  ],
  married_separate: [
    { threshold: 0, rate: 0.10 },
    { threshold: 11925, rate: 0.12 },
    { threshold: 48475, rate: 0.22 },
    { threshold: 103350, rate: 0.24 },
    { threshold: 197300, rate: 0.32 },
    { threshold: 250525, rate: 0.35 },
    { threshold: 375800, rate: 0.37 },
  ],
  head_of_household: [
    { threshold: 0, rate: 0.10 },
    { threshold: 17000, rate: 0.12 },
    { threshold: 64850, rate: 0.22 },
    { threshold: 103350, rate: 0.24 },
    { threshold: 197300, rate: 0.32 },
    { threshold: 250500, rate: 0.35 },
    { threshold: 626350, rate: 0.37 },
  ],
};

export const STANDARD_DEDUCTION_2025: Record<FilingStatus, number> = {
  single: 15000,
  married_joint: 30000,
  married_separate: 15000,
  head_of_household: 22500,
};

// Self-employment tax: 15.3% on 92.35% of net SE earnings (SS 12.4% + Medicare 2.9%)
// SS portion capped at the SS wage base. Medicare uncapped.
export const SE_TAX_2025 = {
  ssRate: 0.124,
  medicareRate: 0.029,
  netEarningsMultiplier: 0.9235,
  ssWageBase: 176100, // 2025
  // Half of SE tax is deductible from AGI (above-the-line)
  deductibleHalf: 0.5,
};

/** Apply progressive brackets to an income amount, return total tax owed. */
export function calcBracketTax(income: number, brackets: Bracket[]): number {
  if (income <= 0) return 0;
  let tax = 0;
  for (let i = 0; i < brackets.length; i++) {
    const b = brackets[i];
    const next = brackets[i + 1];
    const ceiling = next ? next.threshold : Infinity;
    if (income > b.threshold) {
      const slice = Math.min(income, ceiling) - b.threshold;
      tax += slice * b.rate;
    } else break;
  }
  return tax;
}

/** Compute SE tax using 2025 formula. Input = net SE earnings (gross - business deductions). */
export function calcSelfEmploymentTax(netSeEarnings: number): {
  taxable: number;
  ssTax: number;
  medicareTax: number;
  total: number;
  deductibleHalf: number;
} {
  if (netSeEarnings <= 0) {
    return { taxable: 0, ssTax: 0, medicareTax: 0, total: 0, deductibleHalf: 0 };
  }
  const taxable = netSeEarnings * SE_TAX_2025.netEarningsMultiplier;
  const ssTax = Math.min(taxable, SE_TAX_2025.ssWageBase) * SE_TAX_2025.ssRate;
  const medicareTax = taxable * SE_TAX_2025.medicareRate;
  const total = ssTax + medicareTax;
  return { taxable, ssTax, medicareTax, total, deductibleHalf: total * 0.5 };
}

/** US estimated tax quarterly due dates (federal). */
export const QUARTERLY_DUE_DATES = [
  { q: 1, label: "Q1", dueMonth: 3, dueDay: 15 }, // Apr 15 (filing for Jan 1 - Mar 31)
  { q: 2, label: "Q2", dueMonth: 5, dueDay: 15 }, // Jun 15 (Apr 1 - May 31)
  { q: 3, label: "Q3", dueMonth: 8, dueDay: 15 }, // Sep 15 (Jun 1 - Aug 31)
  { q: 4, label: "Q4", dueMonth: 0, dueDay: 15 }, // Jan 15 next year (Sep 1 - Dec 31)
] as const;

/** Returns the quarter (1-4) a given date falls into for IRS estimated-tax purposes. */
export function quarterOf(date: Date): 1 | 2 | 3 | 4 {
  const m = date.getMonth(); // 0-indexed
  if (m <= 2) return 1; // Jan-Mar
  if (m <= 4) return 2; // Apr-May
  if (m <= 7) return 3; // Jun-Aug
  return 4; // Sep-Dec
}

/** Date range for a given IRS quarter in a year. */
export function quarterRange(year: number, q: 1 | 2 | 3 | 4): { start: Date; end: Date; due: Date } {
  switch (q) {
    case 1:
      return { start: new Date(year, 0, 1), end: new Date(year, 2, 31, 23, 59, 59), due: new Date(year, 3, 15) };
    case 2:
      return { start: new Date(year, 3, 1), end: new Date(year, 4, 31, 23, 59, 59), due: new Date(year, 5, 15) };
    case 3:
      return { start: new Date(year, 5, 1), end: new Date(year, 7, 31, 23, 59, 59), due: new Date(year, 8, 15) };
    case 4:
      return { start: new Date(year, 8, 1), end: new Date(year, 11, 31, 23, 59, 59), due: new Date(year + 1, 0, 15) };
  }
}
