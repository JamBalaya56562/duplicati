// Temporary probe, not committed
using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using Azure.Storage.Blobs.Models;
using Duplicati.Library.Backend.AzureBlob;
using Duplicati.Library.Utility.Options;
using NUnit.Framework;

#nullable enable

namespace Duplicati.UnitTest;

[TestFixture]
public class AzureSlowUploadProbe
{
    private sealed class SlowSink : Stream
    {
        private long m_length;
        public override bool CanRead => false;
        public override bool CanSeek => false;
        public override bool CanWrite => true;
        public override long Length => m_length;
        public override long Position { get => m_length; set => throw new NotSupportedException(); }
        public override void Flush() { }
        public override int Read(byte[] buffer, int offset, int count) => throw new NotSupportedException();
        public override long Seek(long offset, SeekOrigin origin) => throw new NotSupportedException();
        public override void SetLength(long value) => throw new NotSupportedException();
        public override void Write(byte[] buffer, int offset, int count) => WriteAsync(buffer, offset, count).GetAwaiter().GetResult();
        public override async Task WriteAsync(byte[] buffer, int offset, int count, CancellationToken cancellationToken)
        {
            await Task.Delay(TimeSpan.FromSeconds(count / 65536.0), cancellationToken);
            m_length += count;
        }
        public override async ValueTask WriteAsync(ReadOnlyMemory<byte> buffer, CancellationToken cancellationToken = default)
        {
            await Task.Delay(TimeSpan.FromSeconds(buffer.Length / 65536.0), cancellationToken);
            m_length += buffer.Length;
        }
    }

    private sealed class SlowHandler : HttpMessageHandler
    {
        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            // Takes the body at 64 KiB per second, as a slow network would; the content is written to
            // the sink as it is read from the source, like the socket handler does
            var sink = new SlowSink();
            if (request.Content != null)
                await request.Content.CopyToAsync(sink, cancellationToken);
            var length = sink.Length;
            TestContext.Progress.WriteLine($"PROBE: {DateTime.Now:HH:mm:ss} answered {length} bytes {request.RequestUri!.Query.Split('&')[^1]}");
            var response = new HttpResponseMessage(HttpStatusCode.Created) { Content = new ByteArrayContent(Array.Empty<byte>()) };
            response.Headers.ETag = new System.Net.Http.Headers.EntityTagHeaderValue("\"0x1\"");
            response.Content.Headers.LastModified = DateTimeOffset.UtcNow;
            return response;
        }
    }

    [Test]
    public async Task SlowUpload_Async()
    {
        var wrapper = new AzureBlobWrapper("account", null, "sv=2020-08-04&sig=test", "container", "", null,
            new HashSet<AccessTier>(), TimeoutOptionsHelper.Parse(new Dictionary<string, string?>()), 0, new SlowHandler());
        var started = DateTime.UtcNow;
        try
        {
            using var source = new MemoryStream(new byte[8 * 1024 * 1024]);
            await wrapper.AddFileStream("duplicati-b0001.dblock.zip.aes", source, CancellationToken.None);
            TestContext.Progress.WriteLine($"PROBE: upload succeeded after {DateTime.UtcNow - started}");
        }
        catch (Exception ex)
        {
            TestContext.Progress.WriteLine($"PROBE: upload failed after {DateTime.UtcNow - started}: {ex.GetType().Name}: {ex.Message}");
            throw;
        }
    }
}
