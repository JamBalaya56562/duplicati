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
using System.Net;
using System.Net.Http;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library;
using Duplicati.Library.Backend;
using NUnit.Framework;
using NUnit.Framework.Legacy;
using Assert = NUnit.Framework.Legacy.ClassicAssert;

namespace Duplicati.UnitTest;

/// <summary>
/// https://github.com/duplicati/duplicati/issues/2263
/// Listing a OneDrive folder of a backup over 400 GB timed out, because the whole listing had to
/// finish within one timeout. The Microsoft Graph backends now apply --list-timeout to each page of
/// the listing, so a listing of many pages can take longer than the timeout in total.
/// </summary>
[Category("Targeted")]
public class MicrosoftGraphListTimeoutTests
{
    private const string SiteId = "contoso-my.sharepoint.com,1111,2222";
    private const string ChildrenUrl = $"https://graph.microsoft.com/v1.0/sites/{SiteId}/drive/root:/Backup:/children";

    /// <summary>The number of pages in the listing</summary>
    private const int Pages = 3;

    /// <summary>How long each page takes to answer: below the timeout, but the pages together are over it</summary>
    private static readonly TimeSpan PageDelay = TimeSpan.FromSeconds(1.5);

    /// <summary>The --list-timeout the backend gets</summary>
    private const string ListTimeout = "3s";

    /// <summary>
    /// Answers the Graph requests for a personal site without a network or a token, and lists the
    /// backup folder in <see cref="Pages"/> slow pages linked with @odata.nextLink
    /// </summary>
    private sealed class SlowPagesGraph() : OAuthHttpMessageHandler(new OAuthHelperHttpClient("test-authid", "sharepoint", "http://127.0.0.1:1/", new HttpClient()))
    {
        public List<string> Unanswered { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var url = request.RequestUri!.AbsoluteUri;
            if (url.StartsWith("https://graph.microsoft.com/v1.0/sites/contoso-my.sharepoint.com:", StringComparison.Ordinal))
                return Json(HttpStatusCode.OK, $$"""{"id":"{{SiteId}}"}""");
            if (url == $"https://graph.microsoft.com/v1.0/sites/{SiteId}/drive")
                return Json(HttpStatusCode.OK, """{"id":"drive","webUrl":"https://contoso-my.sharepoint.com/personal/someone_contoso_com/Documents"}""");

            if (url.StartsWith(ChildrenUrl, StringComparison.Ordinal))
            {
                var query = request.RequestUri.Query;
                var page = query.StartsWith("?page=", StringComparison.Ordinal) ? int.Parse(query["?page=".Length..]) : 1;

                // A page that takes a while, as on a large folder
                await Task.Delay(PageDelay, cancellationToken).ConfigureAwait(false);

                var next = page < Pages ? $",\"@odata.nextLink\":\"{ChildrenUrl}?page={page + 1}\"" : "";
                return Json(HttpStatusCode.OK, $$$"""{"value":[{"id":"{{{page}}}","name":"file-{{{page}}}.zip","size":1,"file":{}}]{{{next}}}}""");
            }

            Unanswered.Add(url);
            return Json(HttpStatusCode.NotFound, """{"error":{"code":"itemNotFound","message":"stub"}}""");
        }
    }

    private static HttpResponseMessage Json(HttpStatusCode code, string body)
        => new HttpResponseMessage(code) { Content = new StringContent(body, Encoding.UTF8, "application/json") };

    [Test]
    public async Task ListingOfManyPagesMayTakeLongerThanTheListTimeoutAsync()
    {
        var graph = new SlowPagesGraph();
        using var backend = new SharePointV2(
            "sharepoint://contoso-my.sharepoint.com/personal/someone_contoso_com//Documents/Backup",
            new Dictionary<string, string?> { ["authid"] = "test-authid", ["list-timeout"] = ListTimeout },
            graph);

        var names = new List<string>();
        await foreach (var entry in backend.ListAsync(CancellationToken.None))
            names.Add(entry.Name);

        CollectionAssert.IsEmpty(graph.Unanswered);
        CollectionAssert.AreEqual(new[] { "file-1.zip", "file-2.zip", "file-3.zip" }, names);
    }
}
