import { expect, test } from "@playwright/test";
import { randomUUID } from "node:crypto";

// Never record credentials or session cookies in traces/screenshots/storage files.
test.use({ trace: "off", screenshot: "off", video: "off" });
test.describe.configure({ retries: 0 });
let email: string;
let password: string;
test.beforeAll(() => {
  const required = ["NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY", "FICI_E2E_EMAIL", "FICI_E2E_PASSWORD"];
  const missing = required.filter((name) => !process.env[name]);
  if (missing.length) throw new Error(`Live Auth E2E requires non-production configuration in .env.test.local: ${missing.join(", ")}. No auth tests are skipped or mocked.`);
  email = process.env.FICI_E2E_EMAIL!;
  password = process.env.FICI_E2E_PASSWORD!;
});

test("AT-AUTH-001: valid login, authenticated redirect, and logout/session end", async ({ page }) => {
  await page.goto("/login?next=https://evil.example");
  await page.getByLabel("Email", { exact: true }).fill(email);
  await page.getByLabel("Password", { exact: true }).fill(password);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page).toHaveURL(/\/account$/);
  await expect(page.getByRole("heading", { name: "FICI Platform", exact: true })).toBeVisible();
  await page.reload();
  await expect(page.getByRole("button", { name: "Sign out", exact: true })).toBeVisible();
  await page.goto("/login");
  await expect(page).toHaveURL(/\/account$/);
  await page.getByRole("button", { name: "Sign out", exact: true }).click();
  await expect(page).toHaveURL(/\/login$/);
  await page.goto("/account");
  await expect(page).toHaveURL(/\/login$/);
});

test("AT-AUTH-002: invalid password gives a safe error and no authenticated access", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("Email", { exact: true }).fill(email);
  await page.getByLabel("Password", { exact: true }).fill(`invalid-${randomUUID()}`);
  await page.getByRole("button", { name: "Sign in", exact: true }).click();
  await expect(page.locator("#login-error")).toHaveText("Unable to sign in. Check your email and password and try again.");
  await expect(page).toHaveURL(/\/login$/);
  await page.goto("/account");
  await expect(page).toHaveURL(/\/login$/);
});

test("AT-AUTH-003: anonymous protected and account-state access is denied", async ({ page }) => {
  await page.goto("/account"); await expect(page).toHaveURL(/\/login$/);
  await page.goto("/account-state"); await expect(page).toHaveURL(/\/login$/);
});


