using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest
{
    // Temporary probe for #6863: where a restore to another folder puts things, and what times it gives the target
    [TestFixture]
    public class ZzProbe6863RestorePathTests : BasicSetupHelper
    {
        private static readonly DateTime FolderTime = new DateTime(2001, 2, 3, 4, 5, 6, DateTimeKind.Utc);

        [Test]
        [TestCase(false)]
        [TestCase(true)]
        public async Task Probe(bool folderSource)
        {
            var folder = Path.Combine(this.DATAFOLDER, "path");
            var file = Path.Combine(folder, "file.txt");
            Directory.CreateDirectory(folder);
            File.WriteAllText(file, "chosen");
            File.WriteAllText(Path.Combine(folder, "other.txt"), "other");
            Directory.SetLastWriteTimeUtc(folder, FolderTime);

            var options = new Dictionary<string, string>(this.TestOptions);
            using (var c = new Controller("file://" + this.TARGETFOLDER, options, null))
                TestUtils.AssertResults(await c.BackupAsync(new[] { folderSource ? Library.Common.IO.Util.AppendDirSeparator(folder) : file }));

            Directory.CreateDirectory(this.RESTOREFOLDER);
            var before = Directory.GetLastWriteTimeUtc(this.RESTOREFOLDER);
            var restore = new Dictionary<string, string>(options) { ["restore-path"] = this.RESTOREFOLDER };
            using (var c = new Controller("file://" + this.TARGETFOLDER, restore, null))
                TestUtils.AssertResults(await c.RestoreAsync(new[] { "*" }));

            var files = Directory.GetFileSystemEntries(this.RESTOREFOLDER, "*", SearchOption.AllDirectories).Select(x => Path.GetRelativePath(this.RESTOREFOLDER, x));
            TestContext.Progress.WriteLine($"PROBE folderSource={folderSource} entries=[{string.Join(", ", files)}] targetTime={Directory.GetLastWriteTimeUtc(this.RESTOREFOLDER):o} before={before:o} recorded={FolderTime:o}");
        }
    }
}
