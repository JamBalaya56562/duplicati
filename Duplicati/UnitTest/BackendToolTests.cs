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
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Main;
using NUnit.Framework;
using NUnit.Framework.Legacy;
using Assert = NUnit.Framework.Legacy.ClassicAssert;

namespace Duplicati.UnitTest
{
    [TestFixture]
    public class BackendToolTests : BasicSetupHelper
    {
        [Test]
        [Category("BackendTool")]
        public async Task GetAsync()
        {
            // Files to create in MB.
            int[] fileSizes = { 10, 20, 30 };
            foreach (int size in fileSizes)
            {
                var data = new byte[size * 1024 * 1024];
                var rng = new Random();
                rng.NextBytes(data);
                File.WriteAllBytes(Path.Combine(DATAFOLDER, size + "MB"), data);
            }

            // Run a backup.
            var options = new Dictionary<string, string>(TestOptions);
            var backendURL = "file://" + this.TARGETFOLDER;
            using (var c = new Controller(backendURL, options, null))
            {
                var backupResults = await c.BackupAsync(new[] { DATAFOLDER });
                foreach (var backupResultsWarning in backupResults.Warnings)
                {
                    TestContext.WriteLine("Backend result warning:" + backupResultsWarning);
                }
                Assert.AreEqual(0, backupResults.Errors.Count());
                Assert.AreEqual(0, backupResults.Warnings.Count());
            }

            // Get the backend files using absolute paths
            var absoluteDownloadFolder = Path.Combine(RESTOREFOLDER, "target-files-absolute");
            Directory.CreateDirectory(absoluteDownloadFolder);
            foreach (var targetFile in Directory.GetFiles(TARGETFOLDER))
            {
                // Absolute path
                var downloadFileName = Path.Combine(absoluteDownloadFolder, Path.GetFileName(targetFile));
                var status = CommandLine.BackendTool.Program.Main(new[] { "GET", $"{backendURL}", $"{downloadFileName}" });
                Assert.AreEqual(0, status);
                Assert.IsTrue(File.Exists(downloadFileName));
                TestUtils.AssertFilesAreEqual(targetFile, downloadFileName, false, downloadFileName);
            }

            // Get the backend files using relative paths
            var relativeDownloadFolder = Path.Combine(RESTOREFOLDER, "target-files-relative");
            Directory.CreateDirectory(relativeDownloadFolder);
            var originalCurrentDirectory = Directory.GetCurrentDirectory();
            Directory.SetCurrentDirectory(relativeDownloadFolder);
            try
            {
                foreach (var targetFile in Directory.GetFiles(TARGETFOLDER))
                {
                    // Relative path
                    var downloadFileName = Path.GetFileName(targetFile);
                    var status = CommandLine.BackendTool.Program.Main(new[] { "GET", $"{backendURL}", $"{downloadFileName}" });
                    Assert.AreEqual(0, status);
                    Assert.IsTrue(File.Exists(downloadFileName));
                    TestUtils.AssertFilesAreEqual(targetFile, downloadFileName, false, downloadFileName);
                }
            }
            finally
            {
                Directory.SetCurrentDirectory(originalCurrentDirectory);
            }
        }

        /// <summary>
        /// The tool was to be checked after the move from .NET Framework (#4539). Each command
        /// is run against a local folder, in the order a user would try them.
        /// </summary>
        [Test]
        [Category("BackendTool")]
        public void EveryCommandWorksAgainstALocalFolder()
        {
            var folder = Path.Combine(TARGETFOLDER, "tool");
            var backendURL = "file://" + folder;
            var upload = Path.Combine(DATAFOLDER, "file.bin");
            var content = new byte[64 * 1024];
            new Random(4539).NextBytes(content);
            File.WriteAllBytes(upload, content);

            Assert.AreEqual(0, CommandLine.BackendTool.Program.Main(new[] { "CREATEFOLDER", backendURL }));
            Assert.IsTrue(Directory.Exists(folder));

            Assert.AreEqual(0, CommandLine.BackendTool.Program.Main(new[] { "PUT", backendURL, upload }));
            Assert.IsTrue(File.Exists(Path.Combine(folder, "file.bin")));

            var originalOut = Console.Out;
            using var listing = new StringWriter();
            Console.SetOut(listing);
            try
            {
                Assert.AreEqual(0, CommandLine.BackendTool.Program.Main(new[] { "LIST", backendURL }));
            }
            finally
            {
                Console.SetOut(originalOut);
            }
            StringAssert.Contains("file.bin\tFile", listing.ToString());

            var downloadFolder = Path.Combine(RESTOREFOLDER, "tool");
            Directory.CreateDirectory(downloadFolder);
            var download = Path.Combine(downloadFolder, "file.bin");
            Assert.AreEqual(0, CommandLine.BackendTool.Program.Main(new[] { "GET", backendURL, download }));
            CollectionAssert.AreEqual(content, File.ReadAllBytes(download));

            Assert.AreEqual(0, CommandLine.BackendTool.Program.Main(new[] { "DELETE", backendURL, "file.bin" }));
            CollectionAssert.IsEmpty(Directory.GetFiles(folder));
        }
    }
}
