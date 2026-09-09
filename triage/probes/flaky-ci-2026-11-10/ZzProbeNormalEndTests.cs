#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// Scratch probe: is the source provider disposed while a listing that the backup no longer
/// waits for is still running, and does that listing use the source after it was disposed?
/// </summary>
[NonParallelizable]
public class ZzProbeNormalEndTests : BasicSetupHelper
{
    private static readonly ManualResetEventSlim Release = new(false);
    private static int s_stuck;
    private static volatile bool s_disposed;
    private static int s_usedAfterDispose;
    private static int s_disposeWhileStuck;
    private static readonly List<int> s_depths = new();

    private static int IsolatingDepth()
    {
        var prop = typeof(Library.Logging.Log).GetProperty("CurrentScope", BindingFlags.NonPublic | BindingFlags.Static)!;
        object? scope = prop.GetValue(null);
        var depth = 0;
        while (scope != null)
        {
            var t = scope.GetType();
            if ((bool)t.GetField("IsolatingScope")!.GetValue(scope)!)
                depth++;
            scope = t.GetField("Parent", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(scope)
                ?? t.GetProperty("Parent", BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance)?.GetValue(scope);
        }
        return depth;
    }

    public class Entry : DispatchProxy
    {
        public string EntryPath = "";
        public bool Folder;
        public bool Root;
        public List<ISourceProviderEntry> Children = new();

        public static ISourceProviderEntry Create(string path, bool folder, bool root = false, params ISourceProviderEntry[] children)
        {
            var proxy = Create<ISourceProviderEntry, Entry>();
            var e = (Entry)(object)proxy;
            e.EntryPath = path;
            e.Folder = folder;
            e.Root = root;
            e.Children.AddRange(children);
            return proxy;
        }

        private async IAsyncEnumerable<ISourceProviderEntry> EnumerateAsync([EnumeratorCancellation] CancellationToken token)
        {
            await Task.CompletedTask;
            if (!Root)
            {
                Interlocked.Increment(ref s_stuck);
                // Only the counting pass, which runs in an isolating log scope, is slow
                var d = IsolatingDepth();
                lock (s_depths) s_depths.Add(d);
                if (d >= 2)
                {
                    Interlocked.Increment(ref s_disposeWhileStuck);
                    Thread.Sleep(3000);
                }
                // This is where a disk source reads its disk
                if (s_disposed)
                    Interlocked.Increment(ref s_usedAfterDispose);
            }
            foreach (var c in Children)
                yield return c;
        }

        protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            switch (targetMethod!.Name)
            {
                case "get_Path": return EntryPath;
                case "get_IsFolder": return Folder;
                case "get_IsRootEntry": return Root;
                case "get_Attributes": return Folder ? FileAttributes.Directory : FileAttributes.Normal;
                case "get_Size": return Folder ? 0L : 1L;
                case "get_CreatedUtc":
                case "get_LastModificationUtc": return new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Utc);
                case "Enumerate": return EnumerateAsync((CancellationToken)args![0]!);
                case "OpenRead": return Task.FromResult<Stream>(new MemoryStream(new byte[] { 1 }));
                case "GetMinorMetadata": return Task.FromResult(new Dictionary<string, string?>());
                case "FileExists": return Task.FromResult(false);
            }
            var type = targetMethod.ReturnType;
            return type.IsValueType ? Activator.CreateInstance(type) : null;
        }
    }

    private sealed class Provider : ISourceProviderModule
    {
        private readonly string _mountPoint;
        public Provider() { _mountPoint = string.Empty; }
        public Provider(string url, string mountPoint, Dictionary<string, string?> options) { _mountPoint = mountPoint; }
        public string Key => "test-probe-normalend";
        public string DisplayName => "probe";
        public string Description => "probe";
        public IList<ICommandLineArgument> SupportedCommands => [];
        public string MountedPath => _mountPoint;
        public bool NeedsStoredMetadata => false;
        public Task InitializeAsync(CancellationToken cancellationToken) => Task.CompletedTask;
        public Task TestAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public async IAsyncEnumerable<ISourceProviderEntry> EnumerateAsync([EnumeratorCancellation] CancellationToken cancellationToken)
        {
            await Task.CompletedTask;
            yield return Entry.Create(_mountPoint, true, true,
                Entry.Create(_mountPoint + "sub" + Path.DirectorySeparatorChar, true, false,
                    Entry.Create(_mountPoint + "sub" + Path.DirectorySeparatorChar + "file.txt", false)));
        }

        public Task<ISourceProviderEntry?> GetEntryAsync(string path, bool isFolder, CancellationToken cancellationToken)
            => Task.FromResult<ISourceProviderEntry?>(null);

        public void Dispose()
        {
            s_disposed = true;
        }
    }

    [Test]
    [Repeat(3)]
    public async Task ProbeNormalEndAsync()
    {
        Library.DynamicLoader.SourceProviderLoader.AddSourceProvider(new Provider());
        lock (s_depths) s_depths.Clear(); s_stuck = 0; s_disposed = false; s_usedAfterDispose = 0; s_disposeWhileStuck = 0;
        var options = new Dictionary<string, string>(TestOptions) { ["no-encryption"] = "true" };
        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
        {
            var sw = System.Diagnostics.Stopwatch.StartNew();
            var r = await c.BackupAsync(["@/probe|test-probe-normalend://source"]);
            TestContext.Progress.WriteLine($"PROBE backup ended: {r.ParsedResult}, listings started: {s_stuck}, counting listings slowed: {s_disposeWhileStuck}, depths: {string.Join(",", s_depths)}, disposed: {s_disposed}, backup took {sw.ElapsedMilliseconds} ms");
        }
        await Task.Delay(4000);
        TestContext.Progress.WriteLine($"PROBE listings that went on after the provider was disposed: {s_usedAfterDispose}");
    }
}
