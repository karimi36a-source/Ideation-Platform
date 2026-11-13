import "server-only";
import { z } from "zod";

/** Catalog identifiers only. A valid code never proves identity or permission. */
export const SYSTEM_ROLE_CODES = ["ADMIN", "MASTER", "MENTOR", "STUDENT"] as const;
export type RoleCode = typeof SYSTEM_ROLE_CODES[number];
export const roleCodeSchema = z.enum(SYSTEM_ROLE_CODES);

/** Immutable M2.1 seed identities, checked against PostgreSQL by integration tests. */
export const SYSTEM_ROLE_IDS: Readonly<Record<RoleCode, string>> = Object.freeze({
  ADMIN: "00000000-0000-4000-8000-000000000101",
  MASTER: "00000000-0000-4000-8000-000000000102",
  MENTOR: "00000000-0000-4000-8000-000000000103",
  STUDENT: "00000000-0000-4000-8000-000000000104",
});
