I could not reproduce this with the official Docker image `duplicati/duplicati:latest` (2.4.1.0). The container has no locale set (`LANG` and `LC_ALL` empty, `LC_CTYPE="POSIX"`), which is the setup reported here. Since 2.1, the server runs on .NET with Kestrel instead of Mono.

I logged in through the REST API and called `serverstate`, `backups`, `systeminfo`, `serversettings` and `notifications`. I used `Accept-Language` set to `en-GB`, `en-US`, `fr-FR`, `ja-JP` and `de-CH`. Every response was HTTP 200 with a valid JSON body. After I added a backup, `GET /api/v1/backups` returned it with `en-GB` too, and the UI page loaded.

I could not reproduce the old failure either, with the `2.0.5.1_beta_2020-01-18` image and browser-style headers such as `en-GB,en-US;q=0.9,en;q=0.8`. So I cannot say which change fixed it, or whether the Raspberry Pi setup differs in some way.

If nobody sees the empty responses on 2.1 or later, I think this can be closed.
