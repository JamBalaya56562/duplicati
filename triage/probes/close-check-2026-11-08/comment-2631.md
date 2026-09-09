The cause found above was the old web server, which wrote the uploaded import file to `/tmp/HttpServer`. Since 2.1, the server runs on Kestrel. The UI sends the configuration as base64 in a JSON body to `POST /api/v1/backups/import`, and the server writes it to a regular temporary file (`Backups.cs`), so `/tmp/HttpServer` is no longer used.

I tested the setup from that comment with the official Docker image `duplicati/duplicati:latest` (2.4.1.0). `/tmp/HttpServer` was owned by root with mode 755, and the server ran as uid 1000. I exported a job without encryption and with a passphrase, and imported each file twice: directly, and for editing. All four imports returned within a second. The two direct imports added the job to the list.

I could not reproduce the old hang with 2.0.5.1. My multipart request got "No file uploaded" whether or not the folder was writable, so my request did not match what the old UI sends.

If nobody can still get the import stuck on 2.1 or later, I think this can be closed.
