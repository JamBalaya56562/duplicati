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

using System.Net;
using System.Net.Http;
using System.Threading.Tasks;
using NUnit.Framework;

namespace Duplicati.UnitTest;

/// <summary>
/// A browser sends every cookie set for the host, including those of other applications on the
/// same host name. The old web server answered a request with more than a few kilobytes of
/// headers with 400 (#4627).
/// </summary>
public partial class ServerApiIntegrationTests
{
    [TestCase(4_600)]
    [TestCase(16_000)]
    [TestCase(30_000)]
    [Category("Integration")]
    public async Task ARequestWithALargeCookieHeaderIsAnswered_Async(int cookieLength)
    {
        await WithAuthenticatedServerAsync(async httpClient =>
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, "/api/v1/serverstate");
            request.Headers.TryAddWithoutValidation("Cookie", "other-application=" + new string('x', cookieLength));

            using var response = await httpClient.SendAsync(request).ConfigureAwait(false);
            Assert.That(response.StatusCode, Is.EqualTo(HttpStatusCode.OK), $"A {cookieLength} byte cookie header was refused");
        }).ConfigureAwait(false);
    }
}
