// Tax calculation engine — combines federal brackets, state tables, and SE tax
// Used by InspectorTax to compute YTD, quarterly, and projected annual tax.

import {
  calcBracketTax,
  calcSelfEmploymentTax,
  FEDERAL_BRACKETS_2025,
  STANDARD_DEDUCTION_2025,
  type FilingStatus,
} from "@/data/federalTaxTables";
import { calcStateTax } from "@/data/stateTaxTables";

export interface PeriodIncome {
  /** Gross income (job fees + mileage fees billed) */
  gross: number;
  /** Business deductions (mileage × IRS rate, plus other) */
  deductions: number;
}

export interface TaxBreakdown {
  gross: number;
  deductions: number;
  netSelfEmployment: number;
  /** Half of SE tax — deductible from AGI */
  seDeduction: number;
  standardDeduction: number;
  taxableFederal: number;
  taxableState: number;
  seTax: number;
  federalTax: number;
  stateTax: number;
  totalTax: number;
  net: number;
  effectiveRate: number;
}

export interface QuarterlyEstimate {
  q: 1 | 2 | 3 | 4;
  label: string;
  periodStart: Date;
  periodEnd: Date;
  dueDate: Date;
  income: number;
  deductions: number;
  estimatedTax: number;
  /** Whether this quarter's due date has passed */
  isPast: boolean;
  /** Whether this is the next upcoming quarter */
  isNext: boolean;
}

/**
 * Compute taxes for a period. Uses annualized projection so brackets apply correctly.
 * For a partial-year period (week, month, quarter), we project the period to a full year,
 * compute annual tax, then prorate back. This gives a realistic effective rate.
 */
export function calculateTax(
  income: PeriodIncome,
  filingStatus: FilingStatus,
  stateCode: string | null,
  /** Fraction of year this period represents (e.g. 0.25 for a quarter). 1 = YTD/full year */
  yearFraction: number = 1,
): TaxBreakdown {
  const { gross, deductions } = income;
  const netSE = Math.max(0, gross - deductions);

  // Annualize for bracket lookup
  const annualizedNetSE = yearFraction > 0 ? netSE / yearFraction : netSE;

  // SE tax (on annualized basis)
  const seCalc = calcSelfEmploymentTax(annualizedNetSE);
  const annualSeTax = seCalc.total;
  const annualSeDeduction = seCalc.deductibleHalf;

  // Federal taxable income = net SE - half SE tax - standard deduction
  const stdDed = STANDARD_DEDUCTION_2025[filingStatus];
  const annualTaxableFederal = Math.max(0, annualizedNetSE - annualSeDeduction - stdDed);
  const annualFederalTax = calcBracketTax(annualTaxableFederal, FEDERAL_BRACKETS_2025[filingStatus]);

  // State taxable (most states piggyback on federal AGI; we use net SE - half SE tax)
  const annualTaxableState = Math.max(0, annualizedNetSE - annualSeDeduction);
  const stateCalc = calcStateTax(stateCode, annualTaxableState, filingStatus);
  const annualStateTax = stateCalc.tax;

  // Prorate back to the period
  const seTax = annualSeTax * yearFraction;
  const federalTax = annualFederalTax * yearFraction;
  const stateTax = annualStateTax * yearFraction;
  const seDeduction = annualSeDeduction * yearFraction;
  const taxableFederal = annualTaxableFederal * yearFraction;
  const taxableState = annualTaxableState * yearFraction;
  const standardDeduction = stdDed * yearFraction;

  const totalTax = seTax + federalTax + stateTax;
  const net = gross - totalTax;
  const effectiveRate = gross > 0 ? totalTax / gross : 0;

  return {
    gross,
    deductions,
    netSelfEmployment: netSE,
    seDeduction,
    standardDeduction,
    taxableFederal,
    taxableState,
    seTax,
    federalTax,
    stateTax,
    totalTax,
    net,
    effectiveRate,
  };
}

import { quarterRange, quarterOf, QUARTERLY_DUE_DATES } from "@/data/federalTaxTables";

/**
 * Build quarterly estimates for the current year given per-quarter income/deductions.
 * Each quarter's tax is computed standalone (annualized × 0.25) so the user sees
 * what to set aside for that quarter alone.
 */
export function buildQuarterlyEstimates(
  year: number,
  perQuarter: Record<1 | 2 | 3 | 4, PeriodIncome>,
  filingStatus: FilingStatus,
  stateCode: string | null,
  now: Date = new Date(),
): QuarterlyEstimate[] {
  const currentQ = year === now.getFullYear() ? quarterOf(now) : 4;
  return ([1, 2, 3, 4] as const).map((q) => {
    const range = quarterRange(year, q);
    const income = perQuarter[q] ?? { gross: 0, deductions: 0 };
    const breakdown = calculateTax(income, filingStatus, stateCode, 0.25);
    const isPast = now > range.due;
    const isNext = !isPast && q >= currentQ && ([1, 2, 3, 4] as const)
      .filter((qq) => quarterRange(year, qq).due >= now).sort((a, b) =>
        quarterRange(year, a).due.getTime() - quarterRange(year, b).due.getTime())[0] === q;
    return {
      q,
      label: QUARTERLY_DUE_DATES[q - 1].label,
      periodStart: range.start,
      periodEnd: range.end,
      dueDate: range.due,
      income: income.gross,
      deductions: income.deductions,
      estimatedTax: breakdown.totalTax,
      isPast,
      isNext,
    };
  });
}
