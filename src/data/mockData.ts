import type { InspectionStatus } from "@/components/StatusBadge";

export interface Inspector {
  id: string;
  name: string;
  avatar: string;
  rating: number;
  completedJobs: number;
  territory: string;
  status: "available" | "busy" | "offline";
}

export interface InspectionJob {
  id: string;
  vin: string;
  vehicle: string;
  customer: string;
  inspector: string;
  status: InspectionStatus;
  priority: "low" | "medium" | "high";
  scheduledDate: string;
  company: string;
  template: string;
}

export const mockInspectors: Inspector[] = [
  { id: "INS-001", name: "Marcus Rivera", avatar: "MR", rating: 4.9, completedJobs: 342, territory: "North Dallas", status: "available" },
  { id: "INS-002", name: "Sarah Chen", avatar: "SC", rating: 4.8, completedJobs: 287, territory: "Downtown Houston", status: "busy" },
  { id: "INS-003", name: "James Walker", avatar: "JW", rating: 4.7, completedJobs: 198, territory: "Austin Central", status: "available" },
  { id: "INS-004", name: "Emily Patel", avatar: "EP", rating: 4.9, completedJobs: 421, territory: "San Antonio", status: "offline" },
  { id: "INS-005", name: "David Kim", avatar: "DK", rating: 4.6, completedJobs: 156, territory: "Fort Worth", status: "available" },
];

export const mockJobs: InspectionJob[] = [
  { id: "JOB-1024", vin: "1HGCM82633A004352", vehicle: "2023 Honda Accord", customer: "Premier Auto Sales", inspector: "Marcus Rivera", status: "request_received", priority: "high", scheduledDate: "2026-03-17", company: "AutoCheck Pro", template: "Pre-Purchase Full" },
  { id: "JOB-1025", vin: "5YJSA1DN5DFP14555", vehicle: "2024 Tesla Model S", customer: "Metro Leasing Corp", inspector: "Sarah Chen", status: "assigned", priority: "medium", scheduledDate: "2026-03-17", company: "AutoCheck Pro", template: "Lease Return" },
  { id: "JOB-1026", vin: "WBAPH5C55BA345678", vehicle: "2022 BMW 328i", customer: "Sunrise Motors", inspector: "James Walker", status: "scheduled", priority: "low", scheduledDate: "2026-03-18", company: "InspectFirst", template: "Dealer Trade" },
  { id: "JOB-1027", vin: "1G1YY22G965109876", vehicle: "2023 Chevrolet Corvette", customer: "Heritage Fleet Mgmt", inspector: "Marcus Rivera", status: "in_progress", priority: "high", scheduledDate: "2026-03-16", company: "AutoCheck Pro", template: "Fleet Audit" },
  { id: "JOB-1028", vin: "2T1BURHE5JC098765", vehicle: "2024 Toyota Camry", customer: "Capital One Auto", inspector: "Emily Patel", status: "awaiting_review", priority: "medium", scheduledDate: "2026-03-15", company: "InspectFirst", template: "Lender Inspection" },
  { id: "JOB-1029", vin: "3FAHP0HA7AR123456", vehicle: "2023 Ford Fusion", customer: "Quick Flip Autos", inspector: "David Kim", status: "completed", priority: "low", scheduledDate: "2026-03-14", company: "AutoCheck Pro", template: "Pre-Purchase Basic" },
  { id: "JOB-1030", vin: "JN1TANT31U0000123", vehicle: "2022 Nissan Altima", customer: "Southwest Rentals", inspector: "Sarah Chen", status: "report_delivered", priority: "medium", scheduledDate: "2026-03-13", company: "InspectFirst", template: "Rental Return" },
  { id: "JOB-1031", vin: "KMHD74LF1LU123456", vehicle: "2024 Hyundai Elantra", customer: "ABC Credit Union", inspector: "James Walker", status: "request_received", priority: "high", scheduledDate: "2026-03-18", company: "AutoCheck Pro", template: "Lender Inspection" },
  { id: "JOB-1032", vin: "4T1BF1FK5GU654321", vehicle: "2023 Toyota Camry", customer: "Elite Motors", inspector: "", status: "request_received", priority: "medium", scheduledDate: "2026-03-19", company: "InspectFirst", template: "Pre-Purchase Full" },
];
