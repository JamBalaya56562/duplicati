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

using System.Globalization;
using System.Linq;
using System.Reflection;
using Duplicati.Library.AutoUpdater;
using Duplicati.Library.Localization;
using Duplicati.Library.Localization.Short;
using NGettext;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// Translated strings write the application name as {AppName}, so a build with another name
/// (an OEM build) shows that name. The executables set the name when they start.
/// </summary>
[NonParallelizable]
public class LocalizationAppNameTests
{
    private string m_previousName = null!;

    [SetUp]
    public void SetUp()
    {
        m_previousName = LocalizationService.AppName;
        LocalizationService.AppName = "Acme Backup";
    }

    [TearDown]
    public void TearDown()
        => LocalizationService.AppName = m_previousName;

    /// <summary>
    /// The services to check: the one without translation and the gettext one
    /// </summary>
    private static ILocalizationService[] Services()
        => new[] { LocalizationService.Invariant, LocalizationService.Get(new CultureInfo("en-US")) };

    [Test]
    public void ThePlaceholderBecomesTheName([Values(0, 1)] int service)
    {
        var ls = Services()[service];

        Assert.That(ls.Localize("Start {AppName}"), Is.EqualTo("Start Acme Backup"));
        Assert.That(ls.Localize("{AppName} found {0} files", 3), Is.EqualTo("Acme Backup found 3 files"));
        Assert.That(ls.Localize("{AppName}: {0} of {1}", 1, 2), Is.EqualTo("Acme Backup: 1 of 2"));
        Assert.That(ls.Localize("{AppName}: {0}, {1}, {2}", "a", "b", "c"), Is.EqualTo("Acme Backup: a, b, c"));
        Assert.That(ls.Localize("{AppName} {0}{1}{2}{3}", "a", "b", "c", "d"), Is.EqualTo("Acme Backup abcd"));
    }

    [Test]
    public void TheShortHelperUsesTheName()
    {
        using (LocalizationService.TemporaryContext(new CultureInfo("en-US")))
            Assert.That(LC.L("Restart {AppName} to use {0}", "it"), Is.EqualTo("Restart Acme Backup to use it"));
    }

    [Test]
    public void BracesInTheNameAreNotFormatItems([Values(0, 1)] int service)
    {
        LocalizationService.AppName = "Acme {0} Backup";
        Assert.That(Services()[service].Localize("{AppName} found {0} files", 3), Is.EqualTo("Acme {0} Backup found 3 files"));
    }

    [Test]
    public void StringsWithoutThePlaceholderAreUnchanged()
    {
        var gettext = Services()[1];
        Assert.That(gettext.Localize("Uses {{braces}}"), Is.EqualTo("Uses {{braces}}"), "a string without arguments is not formatted");
        Assert.That(gettext.Localize("Uses {{braces}} {0}", 1), Is.EqualTo("Uses {braces} 1"));
        Assert.That(LocalizationService.Invariant.Localize("Uses {{braces}} {0}", 1), Is.EqualTo("Uses {braces} 1"));
    }

    /// <summary>
    /// The gettext service formats the translation itself now, instead of letting the catalog do it,
    /// so every translated string with an argument must come out as the catalog would have made it
    /// </summary>
    [Test]
    public void TranslatedStringsFormatAsTheCatalogDid()
    {
        var culture = new CultureInfo("de");
        var ls = LocalizationService.Get(culture);
        var catalog = (Catalog?)ls.GetType().GetField("catalog", BindingFlags.Instance | BindingFlags.NonPublic)?.GetValue(ls);
        Assert.That(catalog, Is.Not.Null);

        var ids = catalog!.Translations.Keys
            .Where(x => x.Contains("{0}") && !x.Contains("{1}") && !x.Contains(LocalizationService.AppNamePlaceholder))
            .ToList();
        if (ids.Count == 0)
            Assert.Ignore("No German translations with an argument were found");

        foreach (var id in ids)
        {
            string expected;
            try
            {
                expected = catalog.GetString(id, "X");
            }
            catch (System.FormatException)
            {
                continue;
            }

            Assert.That(ls.Localize(id, "X"), Is.EqualTo(expected), id);
        }

        Assert.That(ids.Count, Is.GreaterThan(10), "the German catalog should hold strings with an argument");
    }

    [Test]
    public void StartupSetsTheNameOfTheBuild()
    {
        PreloadSettingsLoader.ConfigureApplicationName();
        Assert.That(LocalizationService.AppName, Is.EqualTo(AutoUpdateSettings.AppName));
        Assert.That(LocalizationService.AppName, Is.Not.EqualTo("Acme Backup"));
    }
}
