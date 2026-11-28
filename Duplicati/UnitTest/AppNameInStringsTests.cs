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
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using Duplicati.Library.Localization;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// The strings of the command line client and of the backup engine name the application
/// through <see cref="LocalizationService.AppName"/>, so a build with another name shows that name
/// </summary>
[NonParallelizable]
public class AppNameInStringsTests
{
    private const string Name = "Acme Backup";
    private string m_previousName = null!;

    [SetUp]
    public void SetUp()
    {
        m_previousName = LocalizationService.AppName;
        LocalizationService.AppName = Name;
    }

    [TearDown]
    public void TearDown()
        => LocalizationService.AppName = m_previousName;

    /// <summary>
    /// Reads every string of the Strings classes in the assembly, calling the ones that take arguments with "x"
    /// </summary>
    private static List<(string Member, string Value)> ReadStrings(Assembly assembly, string ns)
        => ReadStrings(assembly, t => t.Namespace == ns);

    /// <summary>
    /// Reads every string of the classes the filter picks, calling the ones that take arguments with "x"
    /// </summary>
    private static List<(string Member, string Value)> ReadStrings(Assembly assembly, Func<Type, bool> filter)
    {
        var result = new List<(string, string)>();
        foreach (var type in assembly.GetTypes().Where(filter))
        {
            foreach (var m in type.GetMethods(BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic))
            {
                if (m.ReturnType != typeof(string) || m.IsGenericMethod)
                    continue;
                var ps = m.GetParameters();
                if (ps.Any(p => p.ParameterType != typeof(string) && p.ParameterType != typeof(object)))
                    continue;

                var value = (string?)m.Invoke(null, ps.Select(_ => (object)"x").ToArray());
                if (value != null)
                    result.Add(($"{type.Name}.{m.Name}", value));
            }
        }
        return result;
    }

    [TestCase(typeof(Library.Main.Controller), "Duplicati.Library.Main.Strings")]
    [TestCase(typeof(CommandLine.Help), "Duplicati.CommandLine.Strings")]
    public void TheStringsShowTheNameOfTheBuild(Type inAssembly, string ns)
    {
        using var _ = LocalizationService.TemporaryContext(new CultureInfo("en-US"));
        var strings = ReadStrings(inAssembly.Assembly, ns);
        Assert.That(strings, Is.Not.Empty);

        foreach (var (member, value) in strings)
            Assert.That(value, Does.Not.Contain(LocalizationService.AppNamePlaceholder), member);

        Assert.That(strings.Count(x => x.Value.Contains(Name)), Is.GreaterThan(0), "no string names the application");
    }

    /// <summary>
    /// The backends keep their strings in a Strings namespace, or in a class named Strings
    /// </summary>
    private static bool IsStringsType(Type t)
        => (t.Namespace?.EndsWith(".Strings", StringComparison.Ordinal) ?? false)
            || t.Name == "Strings"
            || t.DeclaringType?.Name == "Strings";

    [TestCase("Duplicati.Library.Backend.AzureBlob", 1)]
    [TestCase("Duplicati.Library.Backend.FTP", 1)]
    [TestCase("Duplicati.Library.Backend.Internxt", 1)]
    [TestCase("Duplicati.Library.Backend.Rclone", 1)]
    [TestCase("Duplicati.Library.Backend.S3", 3)]
    [TestCase("Duplicati.Library.Backend.Storj", 1)]
    [TestCase("Duplicati.Library.Backend.TahoeLAFS", 1)]
    [TestCase("Duplicati.Library.Backend.Duplicati", 1)]
    public void TheBackendStringsShowTheNameOfTheBuild(string assemblyName, int expected)
    {
        using var _ = LocalizationService.TemporaryContext(new CultureInfo("en-US"));
        var strings = ReadStrings(Assembly.Load(assemblyName), IsStringsType);
        Assert.That(strings, Is.Not.Empty);

        foreach (var (member, value) in strings)
            Assert.That(value, Does.Not.Contain(LocalizationService.AppNamePlaceholder), member);

        Assert.That(strings.Count(x => x.Value.Contains(Name)), Is.EqualTo(expected), "strings that name the application");
    }

    [Test]
    public void TheDuplicatiStorageKeepsItsName()
    {
        // "Duplicati Storage" is the name of a service, not of the application, so it stays
        using var _ = LocalizationService.TemporaryContext(new CultureInfo("en-US"));
        var strings = ReadStrings(Assembly.Load("Duplicati.Library.Backend.Duplicati"), IsStringsType);
        Assert.That(strings.Single(x => x.Member == "DuplicatiBackend.get_DisplayName").Value, Is.EqualTo("Duplicati Storage Backend"));
        Assert.That(strings.Single(x => x.Member == "DuplicatiBackend.ErrorUnsupportedBackend").Value, Does.Contain($"this version of {Name} cannot use. Update {Name} to use"));
    }

    [Test]
    public void TheMainStringsNameTheApplicationThroughThePlaceholder()
    {
        using var _ = LocalizationService.TemporaryContext(new CultureInfo("en-US"));
        var strings = ReadStrings(typeof(Library.Main.Controller).Assembly, "Duplicati.Library.Main.Strings");
        Assert.That(strings.Count(x => x.Value.Contains(Name)), Is.GreaterThanOrEqualTo(30));
        // An interpolated string writes the placeholder with doubled braces
        Assert.That(strings.Single(x => x.Member == "Options.get_DisableReplaceMissingMetadataLong").Value, Does.Contain($"command, {Name} will recover"));
    }

    [Test]
    public void TheHelpShowsTheNameOfTheBuild()
    {
        foreach (var topic in new[] { "changelog", "system-info", "logging", "filters", "errorlevel" })
        {
            using var writer = new StringWriter();
            CommandLine.Help.PrintUsage(writer, topic, new Dictionary<string, string>());
            var output = writer.ToString();

            Assert.That(output, Does.Not.Contain("%APP_NAME%"), topic);
            Assert.That(output, Does.Contain(Name), topic);
        }
    }
}
