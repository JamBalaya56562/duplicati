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
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Main.Operation.Backup;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A backup of a whole drive tried to list "System Volume Information", which a user
/// without the backup privilege may not read, and reported a warning for it (#4045).
/// The folder is now left out before it is listed
/// </summary>
public class SystemVolumeInformationExcludeTests
{
    private const FileAttributes SystemFolder = FileAttributes.Directory | FileAttributes.Hidden | FileAttributes.System;

    private sealed class TestEntry : ISourceProviderEntry
    {
        public bool IsFolder { get; set; } = true;
        public bool IsMetaEntry { get; set; }
        public bool IsRootEntry { get; set; }
        public DateTime CreatedUtc { get; set; }
        public DateTime LastModificationUtc { get; set; }
        public string Path { get; set; } = string.Empty;
        public long Size { get; set; }
        public bool IsSymlink { get; set; }
        public string? SymlinkTarget { get; set; }
        public FileAttributes Attributes { get; set; } = SystemFolder;
        public bool IsSpecialFile { get; set; }
        public bool IsCharacterDevice { get; set; }
        public bool IsAlternateStream { get; set; }
        public string? HardlinkTargetId { get; set; }

        public Task<Stream> OpenRead(CancellationToken cancellationToken)
            => throw new NotImplementedException();

        public Task<Dictionary<string, string?>> GetMinorMetadata(CancellationToken cancellationToken)
            => Task.FromResult(new Dictionary<string, string?>());

        public Task<bool> FileExists(string filename, CancellationToken cancellationToken)
            => throw new NotImplementedException();

        public IAsyncEnumerable<ISourceProviderEntry> Enumerate(CancellationToken cancellationToken)
            => throw new UnauthorizedAccessException(Path);
    }

    private static bool IsIncluded(ISourceProviderEntry entry)
    {
        var method = typeof(FileEnumerationProcess).GetMethod(
            "PreFilterSourceEntry",
            BindingFlags.NonPublic | BindingFlags.Static);

        Assert.That(method, Is.Not.Null, "PreFilterSourceEntry not found via reflection");
        return (bool)method!.Invoke(null, [entry, new HashSet<string>()])!;
    }

    [Test]
    [Category("Targeted")]
    public void TheSystemVolumeInformationFolderOfADriveIsLeftOut()
    {
        if (!OperatingSystem.IsWindows())
            Assert.Ignore("The folder is only left out on Windows");

        Assert.That(IsIncluded(new TestEntry { Path = @"C:\System Volume Information\" }), Is.False);
    }

    [Test]
    [Category("Targeted")]
    public void AFolderWithTheSameNameIsKeptWhenItIsNotTheSystemOne()
    {
        if (!OperatingSystem.IsWindows())
            Assert.Ignore("The folder is only left out on Windows");

        // Not hidden and system, so it was made by a user
        Assert.That(IsIncluded(new TestEntry { Path = @"C:\System Volume Information\", Attributes = FileAttributes.Directory }), Is.True);
        // Not at the root of the drive
        Assert.That(IsIncluded(new TestEntry { Path = @"C:\data\System Volume Information\" }), Is.True);
    }
}
