#nullable enable

using System;
using System.Threading;
using System.Threading.Tasks;
using Avalonia;
using Duplicati.GUI.TrayIcon;
using NUnit.Framework;

namespace Duplicati.UnitTest;

// Probe (not to be committed): do the named channels in ProcessBasedActionDelay make a
// second instance in the same process misbehave, and can Avalonia be set up twice?
[NonParallelizable]
public class ActionDelayProbeTests
{
    private static void W(string msg) => TestContext.Progress.WriteLine("PROBEDELAY " + msg);

    private static async Task<string> RunOneAsync(ProcessBasedActionDelay d, string label)
    {
        var ran = new TaskCompletionSource();
        try
        {
            await d.ExecuteActionAsync(() => ran.TrySetResult());
        }
        catch (Exception ex)
        {
            return $"{label}: ExecuteActionAsync threw {ex.GetType().Name}";
        }
        var done = await Task.WhenAny(ran.Task, Task.Delay(3000)) == ran.Task;
        return $"{label}: action ran: {done}";
    }

    [Test]
    public async Task SecondAfterFirstDisposed()
    {
        var first = new ProcessBasedActionDelay();
        first.SignalStart();
        W(await RunOneAsync(first, "first"));
        first.Dispose();

        var second = new ProcessBasedActionDelay();
        second.SignalStart();
        W(await RunOneAsync(second, "second, after the first was disposed"));
        try { second.Dispose(); } catch (Exception ex) { W($"second dispose threw {ex.GetType().Name}"); }
    }

    [Test]
    public async Task TwoAliveTogether()
    {
        // The first is started, the second is not: an action given to the second should wait
        var first = new ProcessBasedActionDelay();
        var second = new ProcessBasedActionDelay();
        first.SignalStart();
        W(await RunOneAsync(second, "second not started, while the first is started"));
        first.Dispose();
        try { second.Dispose(); } catch (Exception ex) { W($"second dispose threw {ex.GetType().Name}"); }
    }

    [Test]
    public void AvaloniaStartedStoppedThenAgain()
    {
        // As AvaloniaRunner.Run does, then as a re-spawned AvaloniaRunner would
        for (var i = 1; i <= 2; i++)
        {
            try
            {
                var lifetime = new Avalonia.Controls.ApplicationLifetimes.ClassicDesktopStyleApplicationLifetime()
                {
                    Args = Array.Empty<string>(),
                    ShutdownMode = Avalonia.Controls.ShutdownMode.OnExplicitShutdown
                };
                lifetime.Startup += (_, _) => Avalonia.Threading.Dispatcher.UIThread.Post(() => lifetime.Shutdown());
                AppBuilder.Configure<Application>().UsePlatformDetect().SetupWithLifetime(lifetime);
                W($"run {i}: set up");
                var code = lifetime.Start(Array.Empty<string>());
                W($"run {i}: started and stopped, exit code {code}");
            }
            catch (Exception ex)
            {
                W($"run {i}: {ex.GetType().Name}: {ex.Message}");
            }
        }
    }

    [Test]
    public void AvaloniaSetupTwice()
    {
        for (var i = 1; i <= 2; i++)
        {
            try
            {
                AppBuilder.Configure<Application>().UsePlatformDetect().SetupWithoutStarting();
                W($"setup {i}: ok");
            }
            catch (Exception ex)
            {
                W($"setup {i}: {ex.GetType().Name}: {ex.Message}");
            }
        }
    }
}
