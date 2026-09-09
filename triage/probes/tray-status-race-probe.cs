using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.GUI.TrayIcon;
using Duplicati.Server.Serialization;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): the tray asks for the status twice at start, once plainly and
// once with a long poll. If the plain answer carries an older state and arrives after the long
// poll's newer one, which one does the tray keep?
public class TrayStatusRaceProbeTests
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBETRAY " + msg);

    private static int FreePort()
    {
        var l = new TcpListener(IPAddress.Loopback, 0);
        l.Start();
        var port = ((IPEndPoint)l.LocalEndpoint).Port;
        l.Stop();
        return port;
    }

    private static string State(string programState, string icon, long eventId)
        => $"{{\"ProgramState\":\"{programState}\",\"SuggestedStatusIcon\":\"{icon}\",\"LastEventID\":{eventId},\"LastDataUpdateID\":0,\"LastNotificationUpdateID\":0}}";

    private static async Task Reply(HttpListenerContext ctx, string json)
    {
        var bytes = Encoding.UTF8.GetBytes(json);
        ctx.Response.ContentType = "application/json";
        ctx.Response.ContentLength64 = bytes.Length;
        await ctx.Response.OutputStream.WriteAsync(bytes);
        ctx.Response.Close();
    }

    [Test]
    public async Task Probe()
    {
        var port = FreePort();
        var prefix = $"http://localhost:{port}/";
        using var listener = new HttpListener();
        listener.Prefixes.Add(prefix);
        listener.Start();

        var longPollAnswered = new TaskCompletionSource();
        var secondLongPollSeen = new TaskCompletionSource();
        var plainAnswered = new TaskCompletionSource();
        var held = new List<HttpListenerContext>();
        using var stop = new CancellationTokenSource();

        var server = Task.Run(async () =>
        {
            while (!stop.IsCancellationRequested)
            {
                HttpListenerContext ctx;
                try { ctx = await listener.GetContextAsync(); }
                catch { return; }
                var path = ctx.Request.Url!.AbsolutePath;
                var query = ctx.Request.Url.Query;
                W($"request {ctx.Request.HttpMethod} {path}{query}");
                _ = Task.Run(async () =>
                {
                    if (path.EndsWith("/auth/login"))
                        await Reply(ctx, "{\"AccessToken\":\"token\"}");
                    else if (path.EndsWith("/serverstate") && query.Contains("longpoll=true") && query.Contains("lastEventId=0"))
                    {
                        // The long poll sees the newer state: paused, event 2
                        await Reply(ctx, State("Paused", "Paused", 2));
                        longPollAnswered.TrySetResult();
                    }
                    else if (path.EndsWith("/serverstate") && query.Contains("longpoll=true"))
                    {
                        // Nothing changes after that; the long poll waits
                        lock (held) held.Add(ctx);
                        secondLongPollSeen.TrySetResult();
                    }
                    else if (path.EndsWith("/serverstate"))
                    {
                        // The plain request was answered with the state before the change,
                        // and that answer arrives after the long poll's
                        await longPollAnswered.Task;
                        await Task.Delay(200);
                        await Reply(ctx, State("Running", "Ready", 1));
                        plainAnswered.TrySetResult();
                    }
                    else if (path.EndsWith("/notifications"))
                        await Reply(ctx, "[]");
                    else
                        await Reply(ctx, "{}");
                });
            }
        });

        var passwords = await PasswordStorageHelper.CreateAsync(prefix, true, "password", Program.PasswordSource.SuppliedPassword, new Dictionary<string, string?>());
        var connection = new HttpServerConnection(null, Program.PasswordSource.SuppliedPassword, false, "", false, new Dictionary<string, string>(), passwords);
        var seen = new List<string>();
        connection.OnStatusUpdated = s => { lock (seen) seen.Add($"{s.ProgramState}/{s.LastEventID}"); return Task.CompletedTask; };
        try
        {
            // As at start: the plain request, next to the long poll the connection started
            var plain = connection.UpdateStatusAsync();
            await Task.WhenAll(plain, secondLongPollSeen.Task).WaitAsync(TimeSpan.FromSeconds(30));
            await Task.Delay(500);

            W($"updates seen, in order: {string.Join(" -> ", seen)}");
            W($"status kept by the tray: {connection.Status.ProgramState}, event {connection.Status.LastEventID}");
            W($"server state is: Paused, event 2");
        }
        finally
        {
            connection.Close();
            stop.Cancel();
            lock (held) foreach (var h in held) { try { h.Response.Abort(); } catch { } }
            listener.Stop();
        }
    }
}
