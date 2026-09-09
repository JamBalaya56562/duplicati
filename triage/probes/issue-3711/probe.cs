using System.Net;
using System.Net.Sockets;
var l = new TcpListener(IPAddress.Loopback, 0); l.Start();
var port = ((IPEndPoint)l.LocalEndpoint).Port;
var srv = Task.Run(async () => {
  using var c = await l.AcceptTcpClientAsync(); var s = c.GetStream();
  var buf = new byte[8192]; var n = await s.ReadAsync(buf);
  var req = System.Text.Encoding.ASCII.GetString(buf, 0, n);
  Console.WriteLine("Authorization header: " + (req.Split("\r\n").FirstOrDefault(x => x.StartsWith("Authorization:", StringComparison.OrdinalIgnoreCase)) ?? "(none)"));
  await s.WriteAsync(System.Text.Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"));
});
using var h = new HttpClientHandler();
using var client = new HttpClient(h);
var r = await client.SendAsync(new HttpRequestMessage(HttpMethod.Post, new Uri($"http://user:secret@127.0.0.1:{port}/hook")) { Content = new StringContent("x") });
Console.WriteLine("status " + (int)r.StatusCode + ", runtime " + Environment.Version);
await srv;
