#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using System.Threading.Tasks;
using CoCoL;
using Duplicati.GUI.TrayIcon;
using Duplicati.Library.AutoUpdater;
using Duplicati.Server;
using Duplicati.Server.Serialization;
using Duplicati.WebserverCore.Services;
using NUnit.Framework;
using ServerProgram = Duplicati.Server.Program;

namespace Duplicati.UnitTest;

// Probe (not to be committed): does a tray connection made after an earlier one was closed,
// as on reconnect, still send pause to the server?
[NonParallelizable]
public class TrayReconnectProbeTests : BasicSetupHelper
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBERECON " + msg);

    [Test]
    public void NamedChannels()
    {
        var a = CoCoL.Channel.Create<int>(name: "ProbeSameName");
        var b = CoCoL.Channel.Create<int>(name: "ProbeSameName");
        W($"same object: {ReferenceEquals(a, b)}");
        a.Retire();
        try { b.WriteNoWait(1); W("write to the second after retiring the first: ok"); }
        catch (Exception ex) { W($"write to the second after retiring the first: {ex.GetType().Name}"); }
    }

    private static async Task<bool> WaitForAsync(Func<bool> condition, TimeSpan timeout)
    {
        var end = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < end)
        {
            if (condition())
                return true;
            await Task.Delay(50);
        }
        return condition();
    }

    private async Task WithServerAsync(Func<string, Task> body)
    {
        var dataFolder = Path.Combine(BASEFOLDER, "server-data-tray-reconnect");
        Directory.CreateDirectory(dataFolder);
        var previousDataFolderEnv = Environment.GetEnvironmentVariable(DataFolderManager.DATAFOLDER_ENV_NAME);
        Environment.SetEnvironmentVariable(DataFolderManager.DATAFOLDER_ENV_NAME, dataFolder);
        var previousPortable = Environment.GetEnvironmentVariable("DUPLICATI__PORTABLE_MODE");
        Environment.SetEnvironmentVariable("DUPLICATI__PORTABLE_MODE", "false");
        var applicationSettings = new ApplicationSettings();
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
                $"--{WebServerLoader.OPTION_WEBSERVICE_PASSWORD}=tray-probe",
                $"--{DataFolderManager.SERVER_DATAFOLDER_OPTION}={dataFolder}",
                "--webservice-api-only=true"
            };
            ServerProgram.ServerStartedEvent.Reset();
            var tcs = new TaskCompletionSource<int>();
            new Thread(() =>
            {
                try { tcs.TrySetResult(ServerProgram.Main(applicationSettings, args)); }
                catch (Exception ex) { tcs.TrySetException(ex); }
            })
            { IsBackground = true }.Start();
            serverTask = tcs.Task;
            Assert.That(ServerProgram.ServerStartedEvent.WaitOne(TimeSpan.FromSeconds(60)), Is.True, "Server did not start");
            ServerProgram.LiveControl.Resume();
            await body($"http://127.0.0.1:{ServerProgram.DuplicatiWebserver.Port}/");
        }
        finally
        {
            ServerProgram.LiveControl?.Resume();
            applicationSettings.SignalApplicationExit();
            if (serverTask != null)
                try { await serverTask.WaitAsync(TimeSpan.FromSeconds(30)); } catch { }
            Environment.SetEnvironmentVariable(DataFolderManager.DATAFOLDER_ENV_NAME, previousDataFolderEnv);
            Environment.SetEnvironmentVariable("DUPLICATI__PORTABLE_MODE", previousPortable);
            ServerProgram.ServerStartedEvent.Reset();
        }
    }

    private static async Task<HttpServerConnection> ConnectAsync(string host)
    {
        var passwords = await PasswordStorageHelper.CreateAsync(host, true, "tray-probe", GUI.TrayIcon.Program.PasswordSource.SuppliedPassword, new Dictionary<string, string?>());
        var connection = new HttpServerConnection(null, GUI.TrayIcon.Program.PasswordSource.SuppliedPassword, false, "", false, new Dictionary<string, string>(), passwords);
        await connection.UpdateStatusAsync().WaitAsync(TimeSpan.FromSeconds(30));
        return connection;
    }

    [Test] public Task PauseFromAFirstConnection() => PauseFromTheTray(false);
    [Test] public Task PauseAfterAReconnect() => PauseFromTheTray(true);

    private Task PauseFromTheTray(bool afterAnEarlierConnection)
        => WithServerAsync(async host =>
        {
            if (afterAnEarlierConnection)
            {
                var first = await ConnectAsync(host);
                first.Close();
                W("first connection closed");
            }

            var connection = await ConnectAsync(host);
            try
            {
                connection.Pause();
                var paused = await WaitForAsync(() => ServerProgram.LiveControl.State == LiveControls.LiveControlState.Paused, TimeSpan.FromSeconds(10));
                W($"after an earlier connection: {afterAnEarlierConnection}; pause reached the server: {paused}");
            }
            finally
            {
                connection.Close();
            }
        });
}
