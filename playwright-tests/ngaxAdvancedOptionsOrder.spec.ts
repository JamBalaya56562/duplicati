import { expect, Page, test } from "@playwright/test";

const SERVER_URL = process.env.SERVER_URL || "http://localhost:8200";
const LOGIN_URL = `${SERVER_URL}/login.html`;
const NGAX_URL = `${SERVER_URL}/ngax/index.html`;
const WEBSERVICE_PASSWORD = process.env.WEBSERVICE_PASSWORD || "easy1234";

async function login(page: Page) {
  // Stop at an empty page after the login instead of loading the new UI
  const rootUrl = `${SERVER_URL}/`;
  await page.route(rootUrl, (route) =>
    route.fulfill({ contentType: "text/html", body: "<html></html>" }),
  );
  await page.goto(LOGIN_URL);
  await page.fill("#login-password", WEBSERVICE_PASSWORD);
  await page.click("#login-button");
  await page.waitForURL(rootUrl);
  await page.unroute(rootUrl);
}

// Not in alphabetical order, so the list sorts them
const OPTIONS = ["delta", "alpha", "echo", "charlie", "bravo"];

async function listedOptions(page: Page) {
  const entries = page.locator("li.advancedentry");
  await expect(entries).toHaveCount(OPTIONS.length);
  const listed: [string, string][] = [];
  for (let i = 0; i < OPTIONS.length; i++) {
    const entry = entries.nth(i);
    listed.push([
      (await entry.locator("label.shortname").textContent())!.trim(),
      await entry.locator('input[type="text"]').inputValue(),
    ]);
  }
  return listed;
}

// The list of advanced options is sorted, and each value was bound by its
// place in the unsorted list, so the labels showed the values of other
// options (#2604)
test("ngax shows each advanced option with its own value", async ({ page }) => {
  await login(page);
  await page.goto(`${NGAX_URL}#/commandline`);
  await page.waitForLoadState("networkidle");

  const editor = page.locator("div.input:not(.textarea)").filter({ has: page.locator("advanced-options-editor") });
  const text = page.locator("textarea#backupOptions");

  await editor.locator("a.advanced-toggle").click();
  await text.fill(OPTIONS.map((name) => `--option-${name}=value-${name}`).join("\n"));
  await page.locator("div.input.textarea a.advanced-toggle").click();

  expect(await listedOptions(page)).toEqual(
    [...OPTIONS].sort().map((name) => [`option-${name}`, `value-${name}`]),
  );

  // A change in the list goes to the option it is shown with
  const charlie = page.locator("li.advancedentry").filter({ hasText: "option-charlie" });
  await charlie.locator('input[type="text"]').fill("changed");
  await editor.locator("a.advanced-toggle").click();

  const lines = (await text.inputValue()).split("\n").map((line) => line.trim()).filter((line) => line);
  expect(lines.sort()).toEqual(
    OPTIONS.map((name) => `--option-${name}=${name === "charlie" ? "changed" : `value-${name}`}`).sort(),
  );
});
