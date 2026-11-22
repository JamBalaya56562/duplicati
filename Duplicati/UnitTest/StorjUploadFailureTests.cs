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
using System.IO;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Backend.Storj;
using Duplicati.Library.Utility.Options;
using NUnit.Framework;
using uplink.NET.Interfaces;
using uplink.NET.Models;

#nullable enable

namespace Duplicati.UnitTest;

/// <summary>
/// uplink.NET reports an upload that failed, for example because the project ran out of storage,
/// by setting <c>Failed</c> on the operation, not by failing its task. The upload has to end with
/// the error uplink.NET gives instead of passing as a success, so the user sees why the backup
/// failed (#5102). The uploads are uplink.NET's own operation objects, made without their
/// constructor so that the native library is not loaded.
/// </summary>
[TestFixture]
public class StorjUploadFailureTests
{
    private const BindingFlags Instance = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic;
    private const string Error = "uplink: project storage limit exceeded";

    private static Storj CreateBackend(UploadOperation upload)
    {
        var bucket = (Bucket)RuntimeHelpers.GetUninitializedObject(typeof(Bucket));
        var bucketService = CreateService<IBucketService>(m => m.Name == nameof(IBucketService.EnsureBucketAsync)
            ? Task.FromResult(bucket)
            : throw new NotSupportedException(m.Name));
        var objectService = CreateService<IObjectService>(m => m.Name == nameof(IObjectService.UploadObjectAsync)
            ? Task.FromResult(upload)
            : throw new NotSupportedException(m.Name));
        var timeout = TimeSpan.FromSeconds(30);
        return new Storj(bucketService, objectService, new TimeoutOptionsHelper.Timeouts(timeout, timeout, timeout, TimeSpan.FromMinutes(10)));
    }

    private static T CreateService<T>(Func<MethodInfo, object?> handler) where T : class
    {
        var service = DispatchProxy.Create<T, StorjDownloadFailureTests.ServiceProxy>();
        ((StorjDownloadFailureTests.ServiceProxy)(object)service).Handler = handler;
        return service;
    }

    /// <summary>
    /// Creates an upload that is running and then fails with <see cref="Error"/>, or completes
    /// </summary>
    /// <param name="fails">If true, the upload fails; otherwise it completes</param>
    private static UploadOperation CreateUpload(bool fails)
    {
        var type = typeof(UploadOperation);
        var op = (UploadOperation)RuntimeHelpers.GetUninitializedObject(type);
        type.GetField("_byteStreamToUpload", Instance)!.SetValue(op, new MemoryStream(new byte[100]));
        op.Running = true;
        type.GetField("_uploadTask", Instance)!.SetValue(op, Task.Run(async () =>
        {
            await Task.Delay(50);
            type.GetProperty(nameof(UploadOperation.BytesSent))!.SetValue(op, fails ? 40L : 100L);
            op.Running = false;
            if (fails)
            {
                type.GetField("_errorMessage", Instance)!.SetValue(op, Error);
                op.Failed = true;
            }
            else
                type.GetProperty(nameof(UploadOperation.Completed))!.SetValue(op, true);
        }));

        return op;
    }

    [Test]
    public void AnUploadThatFailsIsAnErrorWithTheReason()
    {
        using var backend = CreateBackend(CreateUpload(true));
        using var source = new MemoryStream(new byte[100]);

        var ex = Assert.CatchAsync(() => backend.PutAsync("file", source, CancellationToken.None));

        Assert.That(ex?.Message, Does.Contain(Error));
    }

    [Test]
    public void AnUploadThatFailedBeforeItStartedIsAnErrorWithTheReason()
    {
        // uplink.NET marks the upload as failed, and starts nothing, when it could not be opened
        var upload = (UploadOperation)RuntimeHelpers.GetUninitializedObject(typeof(UploadOperation));
        typeof(UploadOperation).GetField("_byteStreamToUpload", Instance)!.SetValue(upload, new MemoryStream(new byte[100]));
        typeof(UploadOperation).GetField("_uploadTask", Instance)!.SetValue(upload, Task.CompletedTask);
        typeof(UploadOperation).GetField("_errorMessage", Instance)!.SetValue(upload, Error);
        upload.Failed = true;
        using var backend = CreateBackend(upload);
        using var source = new MemoryStream(new byte[100]);

        var ex = Assert.CatchAsync(() => backend.PutAsync("file", source, CancellationToken.None));

        Assert.That(ex?.Message, Does.Contain(Error));
    }

    [Test]
    public void AnUploadThatCompletesIsASuccess()
    {
        using var backend = CreateBackend(CreateUpload(false));
        using var source = new MemoryStream(new byte[100]);

        Assert.DoesNotThrowAsync(() => backend.PutAsync("file", source, CancellationToken.None));
    }
}
