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
#nullable enable

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using Duplicati.Library.AutoUpdater;
using Duplicati.Library.RestAPI;
using Duplicati.Server;
using Duplicati.Server.Database;
using Duplicati.Server.Serialization;
using Duplicati.WebserverCore.Abstractions;
using NUnit.Framework;
using Program = Duplicati.Server.Program;

namespace Duplicati.UnitTest;

/// <summary>
/// A preload.json in the shared folder that was read before 2.3.0.107 is ignored now,
/// so the server warns about it (forum topic 22797)
/// </summary>
[TestFixture]
public class PreloadLegacyLocationTests
{
    private static readonly string LegacyFile = Path.Combine(Path.GetTempPath(), "shared", "Duplicati", "preload.json");
    private static readonly string DataFile = Path.Combine(Path.GetTempPath(), "data", "preload.json");

    [Test]
    public void AnExistingLegacyFileThatIsNotSearchedIsReported()
        => Assert.That(PreloadSettingsLoader.FindIgnoredLegacyFiles([LegacyFile], [DataFile], _ => true), Is.EqualTo(new[] { LegacyFile }));

    [Test]
    public void AMissingLegacyFileIsNotReported()
        => Assert.That(PreloadSettingsLoader.FindIgnoredLegacyFiles([LegacyFile], [DataFile], _ => false), Is.Empty);

    [Test]
    public void ALegacyFileInTheDataFolderIsReadAndNotReported()
        // A Windows service can use the shared folder as its data folder
        => Assert.That(PreloadSettingsLoader.FindIgnoredLegacyFiles([LegacyFile], [DataFile, LegacyFile], _ => true), Is.Empty);

    [Test]
    public void RelativePathsAreNotReported()
        => Assert.That(PreloadSettingsLoader.FindIgnoredLegacyFiles(["preload.json"], [DataFile], _ => true), Is.Empty);

    [Test]
    public void TheLegacyLocationsOfThisPlatformAreNotSearched()
    {
        // Whatever exists on the test machine, a reported file is never one that is read
        var searched = PreloadSettingsLoader.GetPreloadSettingsPaths().Select(x => x.Path).ToArray();
        Assert.That(PreloadSettingsLoader.GetIgnoredLegacyPreloadFiles(), Has.None.AnyOf(searched));
    }

    private sealed class TestApplicationSettings(string dataFolder) : IApplicationSettings
    {
        public Action? StartOrStopUsageReporter { get; set; }
        public string DataFolder => dataFolder;
        public string Origin { get; set; } = "UnitTest";
        public CancellationToken ApplicationExit => CancellationToken.None;
        public void SignalApplicationExit() { }
        public Library.Interface.ISecretProvider? SecretProvider { get; set; }
        public Library.Interface.ISecretProvider? DefaultSecretProvider { get; set; }
        public bool SettingsEncryptionKeyProvidedExternally { get; set; }
    }

    private string dataFolder = string.Empty;
    private Connection connection = null!;

    [SetUp]
    public void Setup()
    {
        dataFolder = Path.Combine(Path.GetTempPath(), Path.GetRandomFileName());
        Directory.CreateDirectory(dataFolder);
        var options = new Dictionary<string, string> { { "disable-default-secret-provider", "true" } };
        connection = Program.GetDatabaseConnection(new TestApplicationSettings(dataFolder), options, true, false);
    }

    [TearDown]
    public void TearDown()
    {
        connection?.Dispose();
        try { Directory.Delete(dataFolder, true); } catch { }
    }

    private Server.Serialization.Interface.INotification[] Warnings()
        => connection.GetNotifications().Where(x => x.Action == Program.NOTIFICATION_PRELOAD_LEGACY_LOCATION).ToArray();

    [Test]
    [Category("Notifications")]
    public void TheWarningNamesTheFileAndWhereToMoveIt()
    {
        Program.EmitPreloadLegacyLocationWarning(connection, dataFolder, [LegacyFile], true);

        var warning = Warnings().Single();
        Assert.That(warning.Type, Is.EqualTo(NotificationType.Warning));
        Assert.That(warning.Message, Does.Contain(LegacyFile));
        Assert.That(warning.Message, Does.Contain(Path.Combine(dataFolder, "preload.json")));
    }

    [Test]
    [Category("Notifications")]
    public void TheWarningIsShownOnce()
    {
        Program.EmitPreloadLegacyLocationWarning(connection, dataFolder, [LegacyFile], true);
        Program.EmitPreloadLegacyLocationWarning(connection, dataFolder, [LegacyFile], true);

        Assert.That(Warnings(), Has.Length.EqualTo(1));
    }

    [Test]
    [Category("Notifications")]
    public void ADismissedWarningIsNotShownAgainUntilTheNextVersion()
    {
        Program.EmitPreloadLegacyLocationWarning(connection, dataFolder, [LegacyFile], true);
        connection.DismissNotification(Warnings().Single().ID);

        Program.EmitPreloadLegacyLocationWarning(connection, dataFolder, [LegacyFile], false);

        Assert.That(Warnings(), Is.Empty);
    }

    [Test]
    [Category("Notifications")]
    public void TheWarningIsRemovedWhenTheFileIsGone()
    {
        Program.EmitPreloadLegacyLocationWarning(connection, dataFolder, [LegacyFile], true);

        Program.EmitPreloadLegacyLocationWarning(connection, dataFolder, [], false);

        Assert.That(Warnings(), Is.Empty);
    }
}
