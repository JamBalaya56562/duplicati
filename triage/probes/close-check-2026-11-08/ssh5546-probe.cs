using Renci.SshNet;

// Connects to an SSH server that listens on IPv4 only, through a name that resolves to IPv6 first
var host = args.Length > 0 ? args[0] : "localhost";
var port = args.Length > 1 ? int.Parse(args[1]) : 22225;
Console.WriteLine($"SSH.NET {typeof(SftpClient).Assembly.GetName().Version}, {host}:{port}");
using var client = new SftpClient(new ConnectionInfo(host, port, "tester", new PasswordAuthenticationMethod("tester", "secret5546")));
client.HostKeyReceived += (_, e) => e.CanTrust = true;
try
{
    client.Connect();
    Console.WriteLine($"connected, working directory {client.WorkingDirectory}");
    client.Disconnect();
}
catch (Exception ex)
{
    Console.WriteLine($"FAILED: {ex.GetType().Name}: {ex.Message}");
}
