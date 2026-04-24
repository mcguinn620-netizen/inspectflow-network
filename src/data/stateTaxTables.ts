// 2025 US state income tax data — simplified (single-filer brackets / flat rates)
// Sources: state revenue departments, Tax Foundation 2025 summary.
// For multi-status states we approximate with single brackets; flat-rate states use one entry.
// This is an estimator, not a tax-prep tool.

import type { Bracket, FilingStatus } from "./federalTaxTables";

export interface StateTaxConfig {
  code: string;
  name: string;
  /** "none" = no state income tax, "flat" = single rate, "progressive" = brackets */
  type: "none" | "flat" | "progressive";
  /** For flat or progressive */
  brackets?: Bracket[];
  /** Approx state standard deduction for single (used as rough offset) */
  standardDeduction?: number;
  /** Some states (e.g. CA) tax SE income similarly; flag affects future logic */
  notes?: string;
}

// Brackets are SINGLE filer 2025 (or most-recent published). Married-joint roughly doubles.
// We apply a filing-status multiplier in the calc layer.
export const STATE_TAX_2025: Record<string, StateTaxConfig> = {
  AL: { code: "AL", name: "Alabama", type: "progressive", brackets: [
    { threshold: 0, rate: 0.02 }, { threshold: 500, rate: 0.04 }, { threshold: 3000, rate: 0.05 },
  ], standardDeduction: 3000 },
  AK: { code: "AK", name: "Alaska", type: "none" },
  AZ: { code: "AZ", name: "Arizona", type: "flat", brackets: [{ threshold: 0, rate: 0.025 }], standardDeduction: 14600 },
  AR: { code: "AR", name: "Arkansas", type: "progressive", brackets: [
    { threshold: 0, rate: 0.02 }, { threshold: 4400, rate: 0.04 }, { threshold: 8800, rate: 0.039 },
  ], standardDeduction: 2340 },
  CA: { code: "CA", name: "California", type: "progressive", brackets: [
    { threshold: 0, rate: 0.01 }, { threshold: 10756, rate: 0.02 }, { threshold: 25499, rate: 0.04 },
    { threshold: 40245, rate: 0.06 }, { threshold: 55866, rate: 0.08 }, { threshold: 70606, rate: 0.093 },
    { threshold: 360659, rate: 0.103 }, { threshold: 432787, rate: 0.113 }, { threshold: 721314, rate: 0.123 },
  ], standardDeduction: 5540 },
  CO: { code: "CO", name: "Colorado", type: "flat", brackets: [{ threshold: 0, rate: 0.044 }], standardDeduction: 15000 },
  CT: { code: "CT", name: "Connecticut", type: "progressive", brackets: [
    { threshold: 0, rate: 0.02 }, { threshold: 10000, rate: 0.045 }, { threshold: 50000, rate: 0.055 },
    { threshold: 100000, rate: 0.06 }, { threshold: 200000, rate: 0.065 }, { threshold: 250000, rate: 0.069 },
    { threshold: 500000, rate: 0.0699 },
  ] },
  DE: { code: "DE", name: "Delaware", type: "progressive", brackets: [
    { threshold: 2000, rate: 0.022 }, { threshold: 5000, rate: 0.039 }, { threshold: 10000, rate: 0.048 },
    { threshold: 20000, rate: 0.052 }, { threshold: 25000, rate: 0.0555 }, { threshold: 60000, rate: 0.066 },
  ], standardDeduction: 3250 },
  DC: { code: "DC", name: "District of Columbia", type: "progressive", brackets: [
    { threshold: 0, rate: 0.04 }, { threshold: 10000, rate: 0.06 }, { threshold: 40000, rate: 0.065 },
    { threshold: 60000, rate: 0.085 }, { threshold: 250000, rate: 0.0925 }, { threshold: 500000, rate: 0.0975 },
    { threshold: 1000000, rate: 0.1075 },
  ], standardDeduction: 15000 },
  FL: { code: "FL", name: "Florida", type: "none" },
  GA: { code: "GA", name: "Georgia", type: "flat", brackets: [{ threshold: 0, rate: 0.0539 }], standardDeduction: 12000 },
  HI: { code: "HI", name: "Hawaii", type: "progressive", brackets: [
    { threshold: 0, rate: 0.014 }, { threshold: 2400, rate: 0.032 }, { threshold: 4800, rate: 0.055 },
    { threshold: 9600, rate: 0.064 }, { threshold: 14400, rate: 0.068 }, { threshold: 19200, rate: 0.072 },
    { threshold: 24000, rate: 0.076 }, { threshold: 36000, rate: 0.079 }, { threshold: 48000, rate: 0.0825 },
    { threshold: 150000, rate: 0.09 }, { threshold: 175000, rate: 0.10 }, { threshold: 200000, rate: 0.11 },
  ], standardDeduction: 4400 },
  ID: { code: "ID", name: "Idaho", type: "flat", brackets: [{ threshold: 0, rate: 0.053 }], standardDeduction: 14600 },
  IL: { code: "IL", name: "Illinois", type: "flat", brackets: [{ threshold: 0, rate: 0.0495 }] },
  IN: { code: "IN", name: "Indiana", type: "flat", brackets: [{ threshold: 0, rate: 0.03 }] },
  IA: { code: "IA", name: "Iowa", type: "flat", brackets: [{ threshold: 0, rate: 0.038 }] },
  KS: { code: "KS", name: "Kansas", type: "progressive", brackets: [
    { threshold: 0, rate: 0.052 }, { threshold: 23000, rate: 0.0558 },
  ], standardDeduction: 3500 },
  KY: { code: "KY", name: "Kentucky", type: "flat", brackets: [{ threshold: 0, rate: 0.04 }] },
  LA: { code: "LA", name: "Louisiana", type: "flat", brackets: [{ threshold: 0, rate: 0.03 }], standardDeduction: 12500 },
  ME: { code: "ME", name: "Maine", type: "progressive", brackets: [
    { threshold: 0, rate: 0.058 }, { threshold: 26800, rate: 0.0675 }, { threshold: 63450, rate: 0.0715 },
  ], standardDeduction: 14600 },
  MD: { code: "MD", name: "Maryland", type: "progressive", brackets: [
    { threshold: 0, rate: 0.02 }, { threshold: 1000, rate: 0.03 }, { threshold: 2000, rate: 0.04 },
    { threshold: 3000, rate: 0.0475 }, { threshold: 100000, rate: 0.05 }, { threshold: 125000, rate: 0.0525 },
    { threshold: 150000, rate: 0.055 }, { threshold: 250000, rate: 0.0575 },
  ], standardDeduction: 2700 },
  MA: { code: "MA", name: "Massachusetts", type: "progressive", brackets: [
    { threshold: 0, rate: 0.05 }, { threshold: 1083150, rate: 0.09 },
  ] },
  MI: { code: "MI", name: "Michigan", type: "flat", brackets: [{ threshold: 0, rate: 0.0425 }] },
  MN: { code: "MN", name: "Minnesota", type: "progressive", brackets: [
    { threshold: 0, rate: 0.0535 }, { threshold: 32570, rate: 0.068 }, { threshold: 106990, rate: 0.0785 },
    { threshold: 198630, rate: 0.0985 },
  ], standardDeduction: 14950 },
  MS: { code: "MS", name: "Mississippi", type: "flat", brackets: [{ threshold: 10000, rate: 0.044 }], standardDeduction: 2300 },
  MO: { code: "MO", name: "Missouri", type: "progressive", brackets: [
    { threshold: 1273, rate: 0.02 }, { threshold: 2546, rate: 0.025 }, { threshold: 3819, rate: 0.03 },
    { threshold: 5092, rate: 0.035 }, { threshold: 6365, rate: 0.04 }, { threshold: 7638, rate: 0.045 },
    { threshold: 8911, rate: 0.047 },
  ], standardDeduction: 14600 },
  MT: { code: "MT", name: "Montana", type: "progressive", brackets: [
    { threshold: 0, rate: 0.047 }, { threshold: 21100, rate: 0.059 },
  ], standardDeduction: 14600 },
  NE: { code: "NE", name: "Nebraska", type: "progressive", brackets: [
    { threshold: 0, rate: 0.0246 }, { threshold: 3700, rate: 0.0351 }, { threshold: 22170, rate: 0.0501 },
    { threshold: 35730, rate: 0.052 },
  ], standardDeduction: 8350 },
  NV: { code: "NV", name: "Nevada", type: "none" },
  NH: { code: "NH", name: "New Hampshire", type: "none", notes: "No tax on wages/SE income" },
  NJ: { code: "NJ", name: "New Jersey", type: "progressive", brackets: [
    { threshold: 0, rate: 0.014 }, { threshold: 20000, rate: 0.0175 }, { threshold: 35000, rate: 0.035 },
    { threshold: 40000, rate: 0.05525 }, { threshold: 75000, rate: 0.0637 }, { threshold: 500000, rate: 0.0897 },
    { threshold: 1000000, rate: 0.1075 },
  ] },
  NM: { code: "NM", name: "New Mexico", type: "progressive", brackets: [
    { threshold: 0, rate: 0.017 }, { threshold: 5500, rate: 0.032 }, { threshold: 16500, rate: 0.047 },
    { threshold: 33500, rate: 0.049 }, { threshold: 210000, rate: 0.059 },
  ], standardDeduction: 14600 },
  NY: { code: "NY", name: "New York", type: "progressive", brackets: [
    { threshold: 0, rate: 0.04 }, { threshold: 8500, rate: 0.045 }, { threshold: 11700, rate: 0.0525 },
    { threshold: 13900, rate: 0.055 }, { threshold: 80650, rate: 0.06 }, { threshold: 215400, rate: 0.0685 },
    { threshold: 1077550, rate: 0.0965 }, { threshold: 5000000, rate: 0.103 }, { threshold: 25000000, rate: 0.109 },
  ], standardDeduction: 8000 },
  NC: { code: "NC", name: "North Carolina", type: "flat", brackets: [{ threshold: 0, rate: 0.0425 }], standardDeduction: 12750 },
  ND: { code: "ND", name: "North Dakota", type: "progressive", brackets: [
    { threshold: 0, rate: 0 }, { threshold: 47150, rate: 0.0195 }, { threshold: 238200, rate: 0.025 },
  ] },
  OH: { code: "OH", name: "Ohio", type: "progressive", brackets: [
    { threshold: 26050, rate: 0.0275 }, { threshold: 100000, rate: 0.035 },
  ] },
  OK: { code: "OK", name: "Oklahoma", type: "progressive", brackets: [
    { threshold: 0, rate: 0.0025 }, { threshold: 1000, rate: 0.0075 }, { threshold: 2500, rate: 0.0175 },
    { threshold: 3750, rate: 0.0275 }, { threshold: 4900, rate: 0.0375 }, { threshold: 7200, rate: 0.0475 },
  ], standardDeduction: 6350 },
  OR: { code: "OR", name: "Oregon", type: "progressive", brackets: [
    { threshold: 0, rate: 0.0475 }, { threshold: 4300, rate: 0.0675 }, { threshold: 10750, rate: 0.0875 },
    { threshold: 125000, rate: 0.099 },
  ], standardDeduction: 2745 },
  PA: { code: "PA", name: "Pennsylvania", type: "flat", brackets: [{ threshold: 0, rate: 0.0307 }] },
  RI: { code: "RI", name: "Rhode Island", type: "progressive", brackets: [
    { threshold: 0, rate: 0.0375 }, { threshold: 79900, rate: 0.0475 }, { threshold: 181650, rate: 0.0599 },
  ], standardDeduction: 10550 },
  SC: { code: "SC", name: "South Carolina", type: "progressive", brackets: [
    { threshold: 3460, rate: 0.03 }, { threshold: 17330, rate: 0.062 },
  ], standardDeduction: 14600 },
  SD: { code: "SD", name: "South Dakota", type: "none" },
  TN: { code: "TN", name: "Tennessee", type: "none" },
  TX: { code: "TX", name: "Texas", type: "none" },
  UT: { code: "UT", name: "Utah", type: "flat", brackets: [{ threshold: 0, rate: 0.0455 }] },
  VT: { code: "VT", name: "Vermont", type: "progressive", brackets: [
    { threshold: 0, rate: 0.0335 }, { threshold: 47900, rate: 0.066 }, { threshold: 116000, rate: 0.076 },
    { threshold: 242000, rate: 0.0875 },
  ], standardDeduction: 7400 },
  VA: { code: "VA", name: "Virginia", type: "progressive", brackets: [
    { threshold: 0, rate: 0.02 }, { threshold: 3000, rate: 0.03 }, { threshold: 5000, rate: 0.05 },
    { threshold: 17000, rate: 0.0575 },
  ], standardDeduction: 8500 },
  WA: { code: "WA", name: "Washington", type: "none" },
  WV: { code: "WV", name: "West Virginia", type: "progressive", brackets: [
    { threshold: 0, rate: 0.0222 }, { threshold: 10000, rate: 0.0296 }, { threshold: 25000, rate: 0.0333 },
    { threshold: 40000, rate: 0.0444 }, { threshold: 60000, rate: 0.0482 },
  ] },
  WI: { code: "WI", name: "Wisconsin", type: "progressive", brackets: [
    { threshold: 0, rate: 0.035 }, { threshold: 14680, rate: 0.044 }, { threshold: 29370, rate: 0.053 },
    { threshold: 323290, rate: 0.0765 },
  ], standardDeduction: 13230 },
  WY: { code: "WY", name: "Wyoming", type: "none" },
};

export const STATE_LIST = Object.values(STATE_TAX_2025).sort((a, b) => a.name.localeCompare(b.name));

/** Adjust single-filer thresholds for filing status (rough multiplier). */
function adjustBracketsForStatus(brackets: Bracket[], status: FilingStatus): Bracket[] {
  const mult = status === "married_joint" ? 2 : status === "head_of_household" ? 1.4 : 1;
  if (mult === 1) return brackets;
  return brackets.map((b) => ({ threshold: b.threshold * mult, rate: b.rate }));
}

import { calcBracketTax } from "./federalTaxTables";

/** Estimate state income tax owed on a given taxable income for a state + filing status. */
export function calcStateTax(stateCode: string | null, taxableIncome: number, status: FilingStatus): {
  tax: number;
  effectiveRate: number;
  hasIncomeTax: boolean;
} {
  if (!stateCode) return { tax: 0, effectiveRate: 0, hasIncomeTax: false };
  const cfg = STATE_TAX_2025[stateCode];
  if (!cfg || cfg.type === "none" || !cfg.brackets) {
    return { tax: 0, effectiveRate: 0, hasIncomeTax: false };
  }
  // Apply state-specific standard deduction (rough)
  const deduction = (cfg.standardDeduction ?? 0) * (status === "married_joint" ? 2 : 1);
  const adjustedIncome = Math.max(0, taxableIncome - deduction);
  const brackets = adjustBracketsForStatus(cfg.brackets, status);
  const tax = calcBracketTax(adjustedIncome, brackets);
  return {
    tax,
    effectiveRate: taxableIncome > 0 ? tax / taxableIncome : 0,
    hasIncomeTax: true,
  };
}
