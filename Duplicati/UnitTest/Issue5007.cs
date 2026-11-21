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

using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Duplicati.Library.Interface;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// Recreating the database of an encrypted backup without the passphrase went
/// through every remote file and reported a failure for each one (#5007).
/// It now stops at once and says that the passphrase is missing
/// </summary>
public class Issue5007 : BasicSetupHelper
{
    [Test]
    [Category("Targeted")]
    public async Task RecreatingAnEncryptedBackupWithoutThePassphraseStopsAtOnceAsync()
    {
        File.WriteAllText(Path.Combine(DATAFOLDER, "a.txt"), "content");

        var opts = TestOptions;
        Assert.That(opts["passphrase"], Is.Not.Empty, "The backup must be encrypted");
        using (var c = new Library.Main.Controller("file://" + TARGETFOLDER, opts, null))
        {
            var result = await c.BackupAsync(new[] { DATAFOLDER });
            Assert.That(result.Errors, Is.Empty);
        }

        File.Delete(DBFILE);

        var withoutPassphrase = TestOptions;
        withoutPassphrase.Remove("passphrase");
        withoutPassphrase["no-encryption"] = "true";

        using (var c = new Library.Main.Controller("file://" + TARGETFOLDER, withoutPassphrase, null))
        {
            var ex = Assert.CatchAsync<UserInformationException>(async () => await c.RepairAsync());
            Assert.That(ex!.HelpID, Is.EqualTo("MissingPassphrase"), ex.ToString());
        }
    }
}
