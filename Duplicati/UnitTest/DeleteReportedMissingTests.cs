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

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using Duplicati.Library.Logging;
using Duplicati.Library.Main;
using NUnit.Framework;

namespace Duplicati.UnitTest
{
    /// <summary>
    /// A server can answer a delete with "not found" although the file is gone, for example when
    /// the file was deleted on an earlier try. The delete then lists the folder: if the file is not
    /// there the delete counts as done and gives no warning, and only a file that is still there
    /// gives one (#2663).
    /// </summary>
    public class DeleteReportedMissingTests : BasicSetupHelper
    {
        /// <summary>
        /// When set, a delete removes the file and then reports it as missing; when not set, a
        /// delete leaves the file and reports it as missing
        /// </summary>
        private static bool s_deleteBeforeReporting;

        /// <summary>
        /// A file backend whose deletes report the file as missing
        /// </summary>
        private sealed class MissingOnDeleteBackend : DeterministicErrorBackend, IBackend
        {
            public MissingOnDeleteBackend()
            {
            }

            public MissingOnDeleteBackend(string url, Dictionary<string, string> options)
                : base(url, options)
            {
            }

            string IBackend.ProtocolKey => "missingondelete";

            async Task IBackend.DeleteAsync(string remotename, CancellationToken cancelToken)
            {
                if (s_deleteBeforeReporting)
                    await DeleteAsync(remotename, cancelToken).ConfigureAwait(false);
                throw new FileMissingException($"File not found: {remotename}");
            }
        }

        /// <summary>
        /// Runs two backups with one version kept, so the second one deletes the first dlist, and
        /// returns what the second one logged
        /// </summary>
        private async Task<(IBackupResults Result, Exception Error, LogEntry[] Messages)> BackUpTwiceAsync(Dictionary<string, string> options)
        {
            Directory.CreateDirectory(DATAFOLDER);
            var file = Path.Combine(DATAFOLDER, "a.txt");
            File.WriteAllText(file, "first version");

            using (var c = new Controller("file://" + TARGETFOLDER, options, null))
                TestUtils.AssertResults(await c.BackupAsync(new[] { DATAFOLDER }));

            File.WriteAllText(file, "second version, which is longer");

            var messages = new ConcurrentQueue<LogEntry>();
            IBackupResults result = null;
            Exception error = null;
            using (Log.StartIsolatingScope(true))
            using (Log.StartScope(messages.Enqueue))
            using (var c2 = new Controller("missingondelete://" + TARGETFOLDER, options, null))
            {
                try
                {
                    result = await c2.BackupAsync(new[] { DATAFOLDER });
                }
                catch (Exception ex)
                {
                    error = ex;
                }
            }

            return (result, error, messages.ToArray());
        }

        private static bool IsNotDeletedWarning(LogEntry x)
            => x.Id == "DeleteRemoteFileFailed" && x.Level == LogMessageType.Warning;

        [Test]
        [Category("Targeted")]
        public async Task AFileThatIsGoneAfterAMissingAnswerGivesNoWarningAsync()
        {
            Library.DynamicLoader.BackendLoader.AddBackend(new MissingOnDeleteBackend());
            s_deleteBeforeReporting = true;
            var options = new Dictionary<string, string>(TestOptions) { ["keep-versions"] = "1" };

            var (result, error, messages) = await BackUpTwiceAsync(options);

            Assert.That(error, Is.Null, error?.ToString());
            Assert.That(messages.Any(x => x.Id == "DeleteRemoteFileSuccess"), Is.True, "The delete should be confirmed by the listing");
            Assert.That(messages.Where(IsNotDeletedWarning), Is.Empty, "A file that is gone should give no warning");
            TestUtils.AssertResults(result);
            Assert.That(Directory.GetFiles(TARGETFOLDER, "*.dlist.*").Length, Is.EqualTo(1), "The first dlist should be deleted");
        }

        [Test]
        [Category("Targeted")]
        public async Task AFileThatIsStillThereAfterAMissingAnswerGivesAWarningAsync()
        {
            Library.DynamicLoader.BackendLoader.AddBackend(new MissingOnDeleteBackend());
            s_deleteBeforeReporting = false;
            var options = new Dictionary<string, string>(TestOptions) { ["keep-versions"] = "1", ["number-of-retries"] = "0" };

            var (_, error, messages) = await BackUpTwiceAsync(options);

            Assert.That(error, Is.InstanceOf<FileMissingException>(), "The delete that left the file should fail the backup");
            Assert.That(messages.Where(IsNotDeletedWarning), Is.Not.Empty, "The delete that left the file should be reported");
            Assert.That(Directory.GetFiles(TARGETFOLDER, "*.dlist.*").Length, Is.EqualTo(2), "Neither dlist should be deleted");
        }
    }
}
