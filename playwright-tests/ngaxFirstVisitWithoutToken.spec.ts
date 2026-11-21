import { expect, test } from "@playwright/test";

const NGAX_URL = process.env.NGAX_URL || "http://localhost:8200/ngax/index.html";

// A browser that has never logged in has no token, and the real server
// rejects its refresh. That must lead to the login page, not to the
// "Connection lost" dialog that keeps trying again (#5591)
test("ngax sends a first visit without a token to the login page", async ({ browser }) => {
  const context = await browser.newContext();
  const page = await context.newPage();

  const refreshStatuses: number[] = [];
  page.on("response", (response) => {
    if (response.url().includes("/api/v1/auth/refresh"))
      refreshStatuses.push(response.status());
  });

  await page.goto(NGAX_URL, { waitUntil: "domcontentloaded" });
  await page.waitForURL(/\/login\.html(\?.*)?$/, { timeout: 15000 });

  // The refresh was rejected, and was not tried again and again
  expect(refreshStatuses.length).toBeGreaterThanOrEqual(1);
  expect(refreshStatuses.length).toBeLessThanOrEqual(3);

  await context.close();
});
