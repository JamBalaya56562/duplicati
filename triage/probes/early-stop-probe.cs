#nullable enable

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Net.Sockets;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.AutoUpdater;
using Duplicati.Library.Common.IO;
using Duplicati.Server;
using Duplicati.WebserverCore.Dto;
using Duplicati.WebserverCore.Dto.V2;
using Duplicati.WebserverCore.Services;
using NUnit.Framework;
using ServerProgram = Duplicati.Server.Program;

namespace Duplicati.UnitTest;

// Probe (not to be committed): is a stop sent through the server API right after a backup
// was started, as the web UI's Stop button does, carried out?
[NonParallelizable]
public class EarlyStopProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEEARLY " + msg);

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter() }
    };

    [Test]
    public async Task StopRightAfterStart([Values("abort")] string action)
    {
        var rng = new Random(1);
        var data = new byte[256 * 1024];
        for (var i = 0; i < 200; i++)
        {
            rng.NextBytes(data);
            File.WriteAllBytes(Path.Combine(DATAFOLDER, $"file{i}"), data);
        }

        await WithAuthenticatedServerAsync(async http =>
        {
            foreach (var delay in new[] { int.Parse(Environment.GetEnvironmentVariable("PROBE_DELAY") ?? "100") })
            {
                var target = Path.Combine(BASEFOLDER, $"target-{action}-{delay}-{Guid.NewGuid():N}");
                var backupId = await CreateBackupAsync(http, target);

                var sw = Stopwatch.StartNew();
                var run = await http.PostAsync($"/api/v1/backup/{backupId}/run", null);
                run.EnsureSuccessStatusCode();
                var task = (await run.Content.ReadFromJsonAsync<TaskStartedDto>(JsonOptions))!;
                var started = sw.ElapsedMilliseconds;

                if (delay > 0)
                    await Task.Delay(delay);
                var state0 = await GetTaskStateAsync(http, task.ID);
                var stopAt = sw.ElapsedMilliseconds;
                var stop = await http.PostAsync($"/api/v1/task/{task.ID}/{action}", null);

                var state = await WaitForTaskAsync(http, task.ID);
                var total = sw.ElapsedMilliseconds;

                var (interrupted, examined) = ("?", "?");
                try { (interrupted, examined) = await ReadLastResultAsync(http, backupId); } catch (Exception ex) { interrupted = ex.Message; }
                W($"{action} after {delay} ms: run returned at {started} ms, {action} sent at {stopAt} ms (task state then {state0.Status}), response {(int)stop.StatusCode}; task {state.Status} at {total} ms; result Interrupted={interrupted}, ExaminedFiles={examined}, error {state.ErrorMessage}; target files {Directory.GetFiles(target).Length}; exception {state.Exception?.Replace("\r", "").Replace("\n", " | ")}");
            }
        });
    }

    private static async Task<(string, string)> ReadLastResultAsync(HttpClient http, string backupId)
    {
        var rows = await http.GetFromJsonAsync<List<Dictionary<string, JsonElement>>>($"/api/v1/backup/{backupId}/log?pagesize=20", JsonOptions);
        foreach (var row in rows!)
        {
            if (row.TryGetValue("Type", out var type) && type.GetString() == "Result" && row.TryGetValue("Message", out var msg))
            {
                using var doc = JsonDocument.Parse(msg.GetString()!);
                var root = doc.RootElement;
                var interrupted = root.TryGetProperty("Interrupted", out var i) ? i.ToString() : "?";
                var examined = root.TryGetProperty("ExaminedFiles", out var e) ? e.ToString() : "?";
                return (interrupted, examined);
            }
        }
        return ("no result row", "-");
    }

    private static async Task<GetTaskStateDto> WaitForTaskAsync(HttpClient http, long taskId)
    {
        var sw = Stopwatch.StartNew();
        while (true)
        {
            var state = await GetTaskStateAsync(http, taskId);
            if (state.Status is "Completed" or "Failed")
                return state;
            if (sw.Elapsed > TimeSpan.FromSeconds(60))
                return state;
            await Task.Delay(100);
        }
    }

    private static async Task<GetTaskStateDto> GetTaskStateAsync(HttpClient http, long taskId)
        => (await http.GetFromJsonAsync<GetTaskStateDto>($"/api/v1/task/{taskId}", JsonOptions))!;

    private async Task<string> CreateBackupAsync(HttpClient http, string target)
    {
        Directory.CreateDirectory(target);
        var settings = new[]
        {
            new BackupAndScheduleInputDto.SettingInputDto { Name = "passphrase", Value = "probe" },
            new BackupAndScheduleInputDto.SettingInputDto { Name = "dblock-size", Value = "1mb" },
            new BackupAndScheduleInputDto.SettingInputDto { Name = "blocksize", Value = "4kb" },
            new BackupAndScheduleInputDto.SettingInputDto { Name = "snapshot-policy", Value = "Off" }
        };
        var request = new BackupAndScheduleInputDto
        {
            Backup = new BackupAndScheduleInputDto.BackupInputDto
            {
                Name = $"probe {Guid.NewGuid():N}",
                Description = "probe",
                TargetURL = new Uri(Util.AppendDirSeparator(Path.GetFullPath(target))).AbsoluteUri,
                Sources = new[] { this.DATAFOLDER },
                Settings = settings,
                Filters = Array.Empty<BackupAndScheduleInputDto.FilterInputDto>(),
                Metadata = new Dictionary<string, string>()
            }
        };
        var response = await http.PostAsJsonAsync("/api/v1/backups", request, JsonOptions);
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<CreateBackupDto>(JsonOptions))!.ID!;
    }

    private async Task WithAuthenticatedServerAsync(Func<HttpClient, Task> body)
    {
        var password = "probe-password";
        var dataFolder = Path.Combine(BASEFOLDER, $"server-data-{Guid.NewGuid():N}");
        Directory.CreateDirectory(dataFolder);
        var previous = Environment.GetEnvironmentVariable(DataFolderManager.DATAFOLDER_ENV_NAME);
        Environment.SetEnvironmentVariable(DataFolderManager.DATAFOLDER_ENV_NAME, dataFolder);
        var settings = new ApplicationSettings();
        Task<int>? serverTask = null;
        try
        {
            var probe = new TcpListener(IPAddress.Loopback, 0);
            probe.Start();
            var port = ((IPEndPoint)probe.LocalEndpoint).Port;
            probe.Stop();
            var args = new[]
            {
                $"--{WebServerLoader.OPTION_PORT}={port}",
                $"--{WebServerLoader.OPTION_INTERFACE}=127.0.0.1",
                $"--{WebServerLoader.OPTION_WEBSERVICE_PASSWORD}={password}",
                $"--{DataFolderManager.SERVER_DATAFOLDER_OPTION}={dataFolder}",
                "--webservice-api-only=true"
            };
            ServerProgram.ServerStartedEvent.Reset();
            var tcs = new TaskCompletionSource<int>();
            var thread = new Thread(() =>
            {
                try { tcs.TrySetResult(ServerProgram.Main(settings, args)); }
                catch (Exception ex) { tcs.TrySetException(ex); }
            })
            { IsBackground = true };
            if (OperatingSystem.IsWindows())
                thread.SetApartmentState(ApartmentState.STA);
            thread.Start();
            serverTask = tcs.Task;
            Assert.That(ServerProgram.ServerStartedEvent.WaitOne(TimeSpan.FromSeconds(60)), Is.True);

            using var http = new HttpClient { BaseAddress = new Uri($"http://127.0.0.1:{ServerProgram.DuplicatiWebserver.Port}") };
            var login = await http.PostAsJsonAsync("/api/v1/auth/login", new { password, rememberMe = true }, JsonOptions);
            login.EnsureSuccessStatusCode();
            var token = (await login.Content.ReadFromJsonAsync<AccessTokenOutputDto>(JsonOptions))!;
            http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.AccessToken);

            await body(http);
        }
        finally
        {
            settings.SignalApplicationExit();
            if (serverTask != null)
                try { await serverTask.WaitAsync(TimeSpan.FromSeconds(30)); } catch { }
            Environment.SetEnvironmentVariable(DataFolderManager.DATAFOLDER_ENV_NAME, previous);
            ServerProgram.ServerStartedEvent.Reset();
        }
    }
}
