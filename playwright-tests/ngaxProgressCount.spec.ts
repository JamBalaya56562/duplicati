import { expect, Page, test } from "@playwright/test";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";

const SERVER_URL = process.env.SERVER_URL || "http://localhost:8200";
const LOGIN_URL = `${SERVER_URL}/login.html`;
const NGAX_URL = `${SERVER_URL}/ngax/index.html`;
const WEBSERVICE_PASSWORD = process.env.WEBSERVICE_PASSWORD || "easy1234";

test.use({ locale: "en-US" });

async function login(page: Page) {
  // After a successful login the page continues to the new UI, which refreshes the
  // login token while it loads. Leaving it halfway can leave ngax with a token the
  // server already replaced, so stop at an empty page instead.
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

// Calls the server API through the page's own AppService, which holds the login token
function callApi(page: Page, method: "get" | "post" | "delete", url: string, body?: unknown) {
  return page.evaluate(
    ([method, url, body]) =>
      new Promise((resolve, reject) => {
        const appService = (window as any).angular
          .element(document.body)
          .injector()
          .get("AppService");
        appService[method](url, body).then(
          (response: any) => resolve(response.data),
          (error: any) => reject(new Error(`${method} ${url}: ${error.status}`)),
        );
      }),
    [method, url, body] as const,
  );
}

// The progress of a running backup shows its file counts with the digit grouping of the
// chosen language, so a count of 168338 reads 168,338 (issue #3041)
test("ngax groups the digits of the file counts in the progress text", async ({ page, context }) => {
  await page.setViewportSize({ width: 1280, height: 900 });
  await login(page);
  await page.goto(`${NGAX_URL}#/home`);
  await page.waitForLoadState("networkidle");

  const source = fs.mkdtempSync(path.join(os.tmpdir(), "duplicati-progress-source-"));
  const target = fs.mkdtempSync(path.join(os.tmpdir(), "duplicati-progress-target-"));

  const name = `Progress count backup ${Date.now()}`;
  const defaults: any = await callApi(page, "get", "/backupdefaults");
  defaults.Backup.Name = name;
  defaults.Backup.Sources = [source + path.sep];
  defaults.Backup.TargetURL = "file://" + target;
  defaults.Backup.Settings = [{ Name: "--no-encryption", Value: "true" }];
  const created: any = await callApi(page, "post", "/backups", {
    Backup: defaults.Backup,
    Schedule: null,
  });
  const id = String(created.ID);

  try {
    // The server reports the backup as the active task over the websocket, and the
    // page then asks for its progress
    await page.routeWebSocket(/\/notifications/, (ws) => {
      const server = ws.connectToServer();
      server.onMessage((message) => {
        const data = JSON.parse(String(message));
        data.ActiveTask = { Item1: 999999, Item2: id };
        ws.send(JSON.stringify(data));
      });
    });

    let progress: any = {
      Phase: "Backup_ProcessingFiles",
      StillCounting: true,
      TotalFileCount: 168338,
      TotalFileSize: 50 * 1024 * 1024 * 1024,
      ProcessedFileCount: 0,
      ProcessedFileSize: 0,
      CurrentFileoffset: 0,
      CurrentFilecomplete: false,
      BackendSpeed: -1,
      OverallProgress: 0,
    };
    await page.route("**/api/v1/progressstate", (route) =>
      route.fulfill({ contentType: "application/json", body: JSON.stringify(progress) }),
    );

    const stateText = page.locator("div.state div.task-state-info");

    await page.reload();
    await expect(stateText).toContainText("Counting (168,338 files found", { timeout: 15000 });

    progress = { ...progress, StillCounting: false, ProcessedFileCount: 38338, ProcessedFileSize: 1024 };
    await expect(stateText).toContainText("130,000 files", { timeout: 15000 });

    progress = { ...progress, Phase: "Backup_RemoteSynchronization", TotalFileCount: 12345, ProcessedFileCount: 0 };
    await expect(stateText).toContainText("Synchronizing remote destination: 12,345 files", { timeout: 15000 });

    // The grouping follows the language chosen in the settings
    await context.addCookies([{ name: "ui-locale", value: "de", url: SERVER_URL }]);
    await page.reload();
    await expect(stateText).toContainText("12.345", { timeout: 15000 });
  } finally {
    await page.unrouteAll({ behavior: "ignoreErrors" });
    await callApi(page, "delete", `/backup/${id}?delete-local-db=true&delete-remote-files=false`);
    fs.rmSync(source, { recursive: true, force: true });
    fs.rmSync(target, { recursive: true, force: true });
  }
});
