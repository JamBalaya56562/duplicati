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
using System.IO;
using System.Linq;
using Duplicati.Library.AutoUpdater;
using NUnit.Framework;

namespace Duplicati.UnitTest;

public class PackageHelperExecutableNameTests
{
    /// <summary>
    /// On Windows each executable is named after its project in the Executables folder, so the
    /// name <see cref="PackageHelper.GetExecutableName"/> returns must be the name of one of them
    /// </summary>
    [Test]
    [Platform("Win")]
    public void EveryWindowsNameIsTheNameOfAnExecutableProject()
    {
        var root = new DirectoryInfo(TestContext.CurrentContext.TestDirectory);
        while (root != null && !Directory.Exists(Path.Combine(root.FullName, "Executables")))
            root = root.Parent;
        Assert.That(root, Is.Not.Null, "The Executables folder was not found above the test folder");

        var projects = Directory.GetFiles(Path.Combine(root!.FullName, "Executables"), "*.csproj", SearchOption.AllDirectories)
            .Select(x => Path.GetFileNameWithoutExtension(x) + ".exe")
            .ToHashSet(StringComparer.Ordinal);

        foreach (var executable in Enum.GetValues<PackageHelper.NamedExecutable>())
            Assert.That(projects, Does.Contain(PackageHelper.GetExecutableName(executable)), executable.ToString());
    }
}
