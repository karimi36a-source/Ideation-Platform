import { expect, test } from "@playwright/test";
import { randomUUID } from "node:crypto";

test.use({ trace: "off", screenshot: "off", video: "off" });
test.describe.configure({ retries: 0 });

test("recovery request displays a non-enumerating response", async ({ page }) => {
  await page.goto("/forgot-password");
  // Reserved invalid domain avoids delivering mail to an unrelated real account.
  await page.getByLabel("Email", { exact: true }).fill(`missing-${randomUUID()}@example.invalid`);
  await page.getByRole("button", { name: "Request reset email" }).click();
  await expect(page.getByRole("status")).toContainText("If an eligible account exists");
});

test("missing and invalid recovery tokens cannot update a password", async ({ page }) => {
  await page.goto("/reset-password");
  await expect(page.getByText("This reset link is invalid or expired.", { exact: false })).toBeVisible();
  await expect(page.getByLabel("New password", { exact: true })).toHaveCount(0);
  const response = await page.goto("/reset-password?token_hash=invalid-fixture&type=recovery");
  expect(response?.headers()["referrer-policy"]).toBe("no-referrer");
  await page.getByLabel("New password", { exact: true }).fill("invalid-token-test-password");
  await page.getByLabel("Confirm new password", { exact: true }).fill("invalid-token-test-password");
  await page.getByRole("button", { name: "Update password" }).click();
  await expect(page.locator("#reset-error")).toContainText("invalid or expired");
  await page.goto("/account"); await expect(page).toHaveURL(/\/login$/);
});

test("verification pending and invalid links have safe clean states", async ({ page }) => {
  await page.goto("/verification");
  await expect(page.getByRole("status")).toContainText("Email verification pending");
  await page.goto("/auth/confirm?token_hash=invalid-fixture&type=signup&next=https://evil.test");
  await expect(page).toHaveURL(/\/verification\?status=invalid$/);
  await expect(page.getByRole("status")).toContainText("invalid or expired");
});
