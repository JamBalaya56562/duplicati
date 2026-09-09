#nullable enable
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Threading.Tasks;
using Duplicati.Library.Modules.Builtin;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// Scratch probe, not part of the PR. Run with SSL_CERT_DIR pointing at PROBE_DIR/trust, so that
/// the process trusts the private CA without changing any system trust store.
/// The leaf names an unreachable CRL and OCSP responder, the state of forum 20747.
/// </summary>
public class RevocationProbeTests
{
    private static string Dir => Environment.GetEnvironmentVariable("PROBE_DIR")!;

    private static X509Certificate2 Load(string name)
        => X509Certificate2.CreateFromPemFile(Path.Combine(Dir, name + ".crt"), Path.Combine(Dir, name + ".key")) is var c
            ? X509CertificateLoader.LoadPkcs12(c.Export(X509ContentType.Pfx), null)
            : throw new InvalidOperationException();

    private static async Task<bool> ServeAsync(TcpListener listener, X509Certificate2 certificate)
    {
        try
        {
            using var tcp = await listener.AcceptTcpClientAsync();
            using var ssl = new SslStream(tcp.GetStream());
            await ssl.AuthenticateAsServerAsync(certificate);
            using var reader = new StreamReader(ssl, Encoding.ASCII);
            using var writer = new StreamWriter(ssl, Encoding.ASCII) { NewLine = "\r\n", AutoFlush = true };
            var delivered = false;
            await writer.WriteLineAsync("220 test ESMTP");
            while (await reader.ReadLineAsync() is { } line)
            {
                var command = line.ToUpperInvariant();
                if (command.StartsWith("EHLO") || command.StartsWith("HELO"))
                    await writer.WriteLineAsync("250 test");
                else if (command.StartsWith("DATA"))
                {
                    await writer.WriteLineAsync("354 go ahead");
                    while (await reader.ReadLineAsync() is { } data && data != ".") { }
                    delivered = true;
                    await writer.WriteLineAsync("250 queued");
                }
                else if (command.StartsWith("QUIT"))
                {
                    await writer.WriteLineAsync("221 bye");
                    break;
                }
                else
                    await writer.WriteLineAsync("250 ok");
            }
            return delivered;
        }
        catch (Exception ex) when (ex is IOException || ex is AuthenticationException || ex is ObjectDisposedException)
        {
            return false;
        }
    }

    private static async Task<bool> SendAsync(string certName, Dictionary<string, string> extra)
    {
        using var certificate = Load(certName);
        var listener = new TcpListener(IPAddress.Loopback, 0);
        listener.Start();
        try
        {
            var port = ((IPEndPoint)listener.LocalEndpoint).Port;
            var server = ServeAsync(listener, certificate);
            var options = new Dictionary<string, string>(extra)
            {
                ["send-mail-to"] = "someone@example.com",
                ["send-mail-from"] = "duplicati@example.com",
                ["send-mail-url"] = $"smtps://127.0.0.1:{port}",
                ["send-mail-level"] = "all"
            };
            var module = new SendMail();
            module.Configure(options);
            var url = "file:///not-used";
            var paths = Array.Empty<string>();
            module.OnStart("Backup", ref url, ref paths);
            module.OnFinish(null, new Exception("Simulated failure"));
            listener.Stop();
            return await server.WaitAsync(TimeSpan.FromSeconds(60));
        }
        finally
        {
            listener.Stop();
        }
    }

    [Test]
    public void ThePreconditionHolds()
    {
        using var leaf = Load("unreachable");
        using var noCheck = new X509Chain();
        noCheck.ChainPolicy.RevocationMode = X509RevocationMode.NoCheck;
        var trusted = noCheck.Build(leaf);
        TestContext.Progress.WriteLine($"PROBE NoCheck valid={trusted} status=[{string.Join(",", noCheck.ChainStatus.Select(s => s.Status))}]");

        using var online = new X509Chain();
        online.ChainPolicy.RevocationMode = X509RevocationMode.Online;
        var valid = online.Build(leaf);
        var flags = online.ChainStatus.Select(s => s.Status).ToArray();
        TestContext.Progress.WriteLine($"PROBE Online valid={valid} status=[{string.Join(",", flags)}]");

        Assert.That(trusted, Is.True, "the CA must be trusted through SSL_CERT_DIR");
        Assert.That(valid, Is.False);
        Assert.That(flags.All(f => (f & ~(X509ChainStatusFlags.RevocationStatusUnknown | X509ChainStatusFlags.OfflineRevocation)) == 0), Is.True);
    }

    [Test]
    public async Task DefaultRefusesWhenRevocationCannotBeChecked()
        => Assert.That(await SendAsync("unreachable", []), Is.False);

    [Test]
    public async Task GeneralOptionDoesNotReachTheMailReport()
        => Assert.That(await SendAsync("unreachable", new() { ["ignore-revocation-failure"] = "true" }), Is.False);

    [Test]
    public async Task MailOptionDeliversWhenRevocationCannotBeChecked()
        => Assert.That(await SendAsync("unreachable", new() { ["send-mail-ignore-revocation-failure"] = "true" }), Is.True);

    [Test]
    public async Task MailOptionStillRefusesAnUntrustedChain()
        => Assert.That(await SendAsync("untrusted", new() { ["send-mail-ignore-revocation-failure"] = "true" }), Is.False);

    [Test]
    public async Task MailOptionStillRefusesAWrongName()
        => Assert.That(await SendAsync("wrongname", new() { ["send-mail-ignore-revocation-failure"] = "true" }), Is.False);
}
