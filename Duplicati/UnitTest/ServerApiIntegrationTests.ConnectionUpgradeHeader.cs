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
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A reverse proxy such as nginx configured for WebSockets sends <c>Connection: upgrade</c> on
/// every request, with an empty <c>Upgrade</c> header when the client did not ask for one. The
/// old web server answered every such request with 400 (#2949).
/// </summary>
public partial class ServerApiIntegrationTests
{
    [TestCase("")]
    [TestCase("websocket")]
    [Category("Integration")]
    public async Task ARequestWithConnectionUpgradeIsAnsweredNormally_Async(string upgrade)
    {
        await WithAuthenticatedServerAsync(async httpClient =>
        {
            var address = httpClient.BaseAddress!;
            var token = httpClient.DefaultRequestHeaders.Authorization!.Parameter;

            // Sent on a socket, so the request has exactly the headers a proxy sends
            using var client = new TcpClient();
            await client.ConnectAsync(address.Host, address.Port).ConfigureAwait(false);
            await using var stream = client.GetStream();
            var request =
                "GET /api/v1/serverstate HTTP/1.1\r\n" +
                $"Host: {address.Authority}\r\n" +
                $"Authorization: Bearer {token}\r\n" +
                "Connection: upgrade\r\n" +
                $"Upgrade: {upgrade}\r\n" +
                "\r\n";
            await stream.WriteAsync(Encoding.ASCII.GetBytes(request)).ConfigureAwait(false);

            using var reader = new StreamReader(stream, Encoding.ASCII);
            var statusLine = await reader.ReadLineAsync().WaitAsync(TimeSpan.FromSeconds(30)).ConfigureAwait(false);
            Assert.That(statusLine, Does.StartWith("HTTP/1.1 200"), "The request with Connection: upgrade was not answered normally");
        }).ConfigureAwait(false);
    }
}
