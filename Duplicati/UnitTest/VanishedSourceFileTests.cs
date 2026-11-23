// Copyright (C) 2026, The Duplicati Team
// https://duplicati.com, hello@duplicati.com
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A file that is listed and then removed before it is read, as temporary files often are,
/// used to stop the whole backup with a FileNotFoundException (#2642). It is now left out with
/// a warning, and the other files are backed up.
/// </summary>
[NonParallelizable]
public class VanishedSourceFileTests : BasicSetupHelper
{
    private const string GoneName = "gone.txt";
    private const string KeptName = "kept.txt";

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
            foreach (var c in Children)
                yield return c;
        }

        private Task<Stream> OpenRead()
        {
            // The file was there when the folder was listed, and is gone when it is opened
            if (EntryPath.EndsWith(GoneName, StringComparison.Ordinal))
                throw new FileNotFoundException("Could not find file", EntryPath);
            return Task.FromResult<Stream>(new MemoryStream([1, 2, 3]));
        }

        protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            switch (targetMethod!.Name)
            {
                case "get_Path": return EntryPath;
                case "get_IsFolder": return Folder;
                case "get_IsRootEntry": return Root;
                case "get_Attributes": return Folder ? FileAttributes.Directory : FileAttributes.Normal;
                case "get_Size": return Folder ? 0L : 3L;
                case "get_CreatedUtc":
                case "get_LastModificationUtc": return new DateTime(2024, 1, 1, 0, 0, 0, DateTimeKind.Utc);
                case "Enumerate": return EnumerateAsync((CancellationToken)args![0]!);
                case "OpenRead": return OpenRead();
                case "GetMinorMetadata": return Task.FromResult(new Dictionary<string, string?>());
                case "FileExists": return Task.FromResult(false);
            }
            var type = targetMethod.ReturnType;
            return type.IsValueType ? Activator.CreateInstance(type) : null;
        }
    }

    private sealed class VanishingFileProvider : ISourceProviderModule
    {
        private readonly string _mountPoint;

        public VanishingFileProvider() { _mountPoint = string.Empty; }

        public VanishingFileProvider(string url, string mountPoint, Dictionary<string, string?> options) { _mountPoint = mountPoint; }

        public string Key => "test-vanishing-file";
        public string DisplayName => "Test vanishing file provider";
        public string Description => "Test provider with a file that is gone when it is read";
        public IList<ICommandLineArgument> SupportedCommands => [];
        public string MountedPath => _mountPoint;
        public bool NeedsStoredMetadata => false;
        public bool NeedsCaseSensitiveFilters => false;

        public Task InitializeAsync(CancellationToken cancellationToken) => Task.CompletedTask;
        public Task TestAsync(CancellationToken cancellationToken) => Task.CompletedTask;

        public async IAsyncEnumerable<ISourceProviderEntry> EnumerateAsync([EnumeratorCancellation] CancellationToken cancellationToken)
        {
            await Task.CompletedTask;
            yield return Entry.Create(_mountPoint, true, true,
                Entry.Create(_mountPoint + GoneName, false),
                Entry.Create(_mountPoint + KeptName, false));
        }

        public Task<ISourceProviderEntry?> GetEntryAsync(string path, bool isFolder, CancellationToken cancellationToken)
            => Task.FromResult<ISourceProviderEntry?>(null);

        public void Dispose() { }
    }

    [Test]
    [Category("Targeted")]
    public async Task AFileThatIsGoneWhenItIsReadIsLeftOutWithAWarningAsync()
    {
        Library.DynamicLoader.SourceProviderLoader.AddSourceProvider(new VanishingFileProvider());
        var options = new Dictionary<string, string>(TestOptions) { ["no-encryption"] = "true" };

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
        {
            var results = await c.BackupAsync(["@/vanish|test-vanishing-file://source"]);
            Assert.That(results.Errors, Is.Empty, string.Join(Environment.NewLine, results.Errors));
            Assert.That(results.Warnings.Any(x => x.Contains("PathNotFound") && x.Contains(GoneName)), Is.True,
                "Expected a PathNotFound warning for the file that is gone: " + string.Join(Environment.NewLine, results.Warnings));
        }

        using (var c = new Controller("file://" + TARGETFOLDER, options, null))
        {
            var files = (await c.ListAsync("*")).Files.Select(x => x.Path).ToList();
            Assert.That(files.Any(x => x.EndsWith(KeptName, StringComparison.Ordinal)), Is.True, "The other file was not backed up: " + string.Join(", ", files));
            Assert.That(files.Any(x => x.EndsWith(GoneName, StringComparison.Ordinal)), Is.False, "The file that is gone was listed in the backup");
        }
    }
}
