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

using DotNet.Testcontainers.Images;

namespace Duplicati.Backend.Tests.SMB;

/// <summary>
/// SMB Tests
/// </summary>
[TestClass]
public sealed class SMBTests : BaseSftpgoTest
{

    /// <summary>
    /// Test Smb with TestContainers creating a Samba Server with TestContainers.
    ///
    /// This test has no requirement of environment variables.
    /// </summary>
    [TestMethod]
    public Task TestSmb()
        => RunSmbTest("", "");

    /// <summary>
    /// Test Smb against a Samba Server that only accepts SMB 3.1.1 and requires signing and
    /// encryption, which the backend can only reach with the enable-smb311 option (#6819).
    ///
    /// This test has no requirement of environment variables.
    /// </summary>
    [TestMethod]
    public Task TestSmb311Required()
        => RunSmbTest(@"server min protocol = SMB3_11
server signing = mandatory
smb encrypt = required", "&enable-smb311=true");

    /// <summary>
    /// Test listing a folder with 20000 files over a link slow enough that a single page of the
    /// listing takes longer than the 5 seconds SMBLibrary waits for a response by default.
    /// The listing used to fail with "Not enough credits" (forum topic 22594).
    ///
    /// This test has no requirement of environment variables.
    /// </summary>
    [TestMethod]
    public Task TestSmbListLargeFolderOnSlowLink()
        => RunSmbTest("", "",
            @"DEBIAN_FRONTEND=noninteractive apt-get install -y iproute2
mkdir /shares/testshare1/big
(cd /shares/testshare1/big && seq -f 'duplicati-b%032g.dblock.zip.aes' 1 20000 | xargs touch)
chown -R smbuser1:smbuser1 /shares/testshare1/big
tc qdisc add dev eth0 root tbf rate 1mbit burst 32kbit latency 60s",
            async url =>
            {
                using var backend = new Library.Backend.SMBBackend(url.Replace("/new/", "/big/"), new Dictionary<string, string?>());
                var count = 0;
                await foreach (var entry in backend.ListAsync(CancellationToken.None))
                    if (!entry.IsFolder)
                        count++;

                Assert.AreEqual(20000, count);
            });

    /// <summary>
    /// Starts a Samba Server with TestContainers and runs the BackendTester against it.
    /// </summary>
    /// <param name="extraGlobalConfig">Lines added to the [global] section of smb.conf</param>
    /// <param name="extraUrlOptions">Options appended to the query string of the backend url</param>
    /// <param name="extraSetup">Commands run as root in the container before Samba starts; the container is privileged when set</param>
    /// <param name="check">Runs against the backend url instead of the BackendTester when set</param>
    private async Task RunSmbTest(string extraGlobalConfig, string extraUrlOptions, string extraSetup = "", Func<string, Task>? check = null)
    {
        var outputConsumer = new OutputConsumer();
        var randomPassword = GeneratePassword();
        var testFilePath = Path.Combine(Path.GetTempPath(), "samba-test");
        Directory.CreateDirectory(testFilePath);
        // Create smb.conf
        var smbConfig = $@"[global]
workgroup = WORKGROUP
server string = Samba Server
log file = /var/log/samba/log.%m
max log size = 50
security = user
passdb backend = tdbsam
{extraGlobalConfig}

[testshare1]
path = /shares/testshare1
valid users = smbuser1
writable = yes
browseable = yes";

        await File.WriteAllTextAsync(Path.Combine(testFilePath, "smb.conf"), smbConfig);

        // Create entrypoint script
        var entrypoint = $@"#!/bin/bash
useradd -M -s /sbin/nologin smbuser1
mkdir -p /shares/testshare1
chown smbuser1:smbuser1 /shares/testshare1
chmod 700 /shares/testshare1
(echo {randomPassword}; echo {randomPassword}) | smbpasswd -a smbuser1 -s
smbpasswd -e smbuser1
{extraSetup}
smbd --foreground --no-process-group --debug-stdout";

        await File.WriteAllTextAsync(Path.Combine(testFilePath, "entrypoint.sh"), entrypoint);

        var container = new ContainerBuilder()
            .WithImage("ubuntu:22.04")
            .WithImagePullPolicy(PullPolicy.Missing)
            .WithCommand("/bin/bash", "-c", "apt-get update && " +
                "DEBIAN_FRONTEND=noninteractive apt-get install -y samba && " +
                "bash /etc/samba/entrypoint.sh")
            .WithResourceMapping(testFilePath, "/etc/samba", UnixFileModes.UserRead |
                UnixFileModes.UserWrite | UnixFileModes.GroupRead | UnixFileModes.OtherRead)
            .WithPortBinding(139, 139)
            .WithPortBinding(445, 445)
            .WithPrivileged(extraSetup != "")
            .WithOutputConsumer(outputConsumer)
            // Wait until something accepts connections on the port the test uses.
            // UntilPortIsAvailable(139) greps /proc/net/tcp for ':0*8B', which also
            // matches the ephemeral ports 0x8B00-0x8BFF that apt-get may use while it
            // installs Samba, so it could report the port ready before smbd was even
            // installed. Connecting to the port cannot be fooled that way.
            .WithWaitStrategy(Wait.ForUnixContainer()
                .UntilCommandIsCompleted("/bin/bash", "-c", "</dev/tcp/127.0.0.1/445"))
            .Build();

        Console.WriteLine("Starting container with wait strategy for port 445");
        await container.StartAsync();
        Console.WriteLine("Samba has started and its ready to accept connections");

        // Both tests bind host port 445, so the container must stop even when a test fails.
        try
        {
            var url = $"smb://localhost/testshare1/new/?transport=directtcp&auth-domain&auth-username=smbuser1&auth-password={randomPassword}{extraUrlOptions}";
            if (check != null)
            {
                await check(url);
                return;
            }

            var exitCode = CommandLine.BackendTester.Program.Main(
                new[]
                {
                    url,
                }.Concat(Parameters.GlobalTestParameters).ToArray());

            Console.WriteLine(await outputConsumer.GetStreamsOutput());
            if (exitCode != 0)
            {
                Assert.Fail("BackendTester is returning non-zero exit code, check logs for details");
            }
        }
        finally
        {
            await container.StopAsync();
        }
    }

    /// <summary>
    ///  Simple helper to generate a random password for the test.
    ///
    /// Only alphanumeric characters are used.
    /// </summary>
    /// <param name="length">Lenght of the password defaulting to 32</param>
    private string GeneratePassword(int length = 32)
    {
        const string chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var random = new Random();
        return new string(Enumerable.Repeat(chars, length)
            .Select(s => s[random.Next(s.Length)]).ToArray());
    }
}