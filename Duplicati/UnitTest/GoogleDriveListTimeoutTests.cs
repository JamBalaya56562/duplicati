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

using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Backend.GoogleDrive;
using NUnit.Framework;

#nullable enable

namespace Duplicati.UnitTest;

/// <summary>
/// A Google Drive listing that the server never answers has to end after --list-timeout,
/// instead of leaving the backup at "Verifying backend data" (#2825)
/// </summary>
[TestFixture]
public class GoogleDriveListTimeoutTests
{
    /// <summary>
    /// A host that cannot be resolved, so a request that is not stubbed fails
    /// instead of reaching the real OAuth service
    /// </summary>
    private const string OAuthUrl = "http://oauth.invalid/token";

    /// <summary>
    /// Answers the token, the about call and the folder lookup, and never answers the
    /// listing of the folder. It ignores the cancellation token, so only the backend's own
    /// timeout can end the wait.
    /// </summary>
    private sealed class StallingHandler : HttpMessageHandler
    {
        private readonly TaskCompletionSource<HttpResponseMessage> _never = new(TaskCreationOptions.RunContinuationsAsynchronously);

        /// <summary>Set when the listing of the folder was requested</summary>
        public bool ListingRequested { get; private set; }

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var url = request.RequestUri?.ToString() ?? "";

            if (url.StartsWith(OAuthUrl, StringComparison.Ordinal))
                return Task.FromResult(Json("{\"access_token\":\"test-token\",\"expires\":3600}"));

            if (url.Contains("/drive/v2/about", StringComparison.Ordinal))
                return Task.FromResult(Json("{\"rootFolderId\":\"root\"}"));

            if (url.Contains("/drive/v2/files", StringComparison.Ordinal))
            {
                // The query is form encoded, so a space arrives as "+"
                var query = Uri.UnescapeDataString(request.RequestUri!.Query).Replace('+', ' ');

                // The folder the backend is configured for is looked up by name first
                if (query.Contains("title = 'target'", StringComparison.Ordinal))
                    return Task.FromResult(Json("{\"items\":[{\"id\":\"folder-1\",\"title\":\"target\",\"mimeType\":\"application/vnd.google-apps.folder\"}]}"));

                ListingRequested = true;
                return _never.Task;
            }

            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
        }

        private static HttpResponseMessage Json(string body)
            => new HttpResponseMessage(HttpStatusCode.OK) { Content = new StringContent(body, Encoding.UTF8, "application/json") };
    }

    [Test]
    [Category("Backend")]
    public async Task AListingTheServerNeverAnswersEndsAfterTheListTimeoutAsync()
    {
        var handler = new StallingHandler();
        using var backend = new GoogleDrive("googledrive://target", new Dictionary<string, string?>
        {
            ["authid"] = "test-authid",
            ["oauth-url"] = OAuthUrl,
            ["list-timeout"] = "2s",
        }, new HttpClient(handler) { Timeout = Timeout.InfiniteTimeSpan });

        var listing = Task.Run(async () =>
        {
            await foreach (var _ in backend.ListAsync(CancellationToken.None))
            {
            }
        });

        var finished = await Task.WhenAny(listing, Task.Delay(TimeSpan.FromSeconds(30))).ConfigureAwait(false);

        Assert.That(handler.ListingRequested, Is.True, "The listing of the folder was never requested");
        Assert.That(finished, Is.SameAs(listing), "The listing was still waiting 30 seconds after the 2 second list timeout");
        Assert.ThrowsAsync<TimeoutException>(() => listing);
    }
}
