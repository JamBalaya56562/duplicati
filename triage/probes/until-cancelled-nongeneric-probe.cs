using System;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Utility;
using NUnit.Framework;

namespace Duplicati.UnitTest
{
    // Throwaway probe for the non-generic UntilCancelledAsync
    public class UntilCancelledProbe
    {
        private static async Task<int> CountUnobservedAsync(Func<Task, CancellationToken, Task> wait)
        {
            var unobserved = 0;
            EventHandler<UnobservedTaskExceptionEventArgs> handler = (_, e) => { if (e.Exception.InnerException?.Message == "probe") Interlocked.Increment(ref unobserved); };
            TaskScheduler.UnobservedTaskException += handler;
            try
            {
                await RunOnceAsync(wait);
                for (var i = 0; i < 5; i++)
                {
                    GC.Collect();
                    GC.WaitForPendingFinalizers();
                    await Task.Delay(50);
                }
                return unobserved;
            }
            finally
            {
                TaskScheduler.UnobservedTaskException -= handler;
            }
        }

        private static async Task RunOnceAsync(Func<Task, CancellationToken, Task> wait)
        {
            using var release = new ManualResetEventSlim(false);
            using var cts = new CancellationTokenSource();
            var call = Task.Run(() => { release.Wait(); throw new InvalidOperationException("probe"); });
            var waiting = wait(call, cts.Token);
            cts.CancelAfter(100);
            var sw = System.Diagnostics.Stopwatch.StartNew();
            Assert.CatchAsync<OperationCanceledException>(async () => await waiting);
            Assert.That(sw.Elapsed, Is.LessThan(TimeSpan.FromSeconds(5)));
            release.Set();
            // Wait for the call to fail without observing it
            while (!call.IsCompleted)
                await Task.Delay(10);
        }

        [Test]
        public async Task WaitAsyncLeavesTheFailureUnobserved()
            => Assert.That(await CountUnobservedAsync((t, c) => t.WaitAsync(c)), Is.EqualTo(0), "unobserved");

        [Test]
        public async Task UntilCancelledAsyncObservesTheFailure()
            => Assert.That(await CountUnobservedAsync((t, c) => t.UntilCancelledAsync(c)), Is.EqualTo(0), "unobserved");

        [Test]
        public async Task UntilCancelledAsyncPassesThroughWithoutCancel()
        {
            await Task.Run(() => Thread.Sleep(50)).UntilCancelledAsync(CancellationToken.None);
            Assert.ThrowsAsync<InvalidOperationException>(async () => await Task.Run(() => throw new InvalidOperationException("x")).UntilCancelledAsync(CancellationToken.None));
        }
    }
}
