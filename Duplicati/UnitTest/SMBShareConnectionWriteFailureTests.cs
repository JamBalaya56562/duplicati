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
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using Duplicati.Library.Backend.SMB;
using Duplicati.Library.Backend.SMB.Model;
using Duplicati.Library.Interface;
using Duplicati.Library.Utility.Options;
using NUnit.Framework;
using SMBLibrary;
using SMBLibrary.Client;

namespace Duplicati.UnitTest;

/// <summary>
/// A write the server refuses reports no bytes written. The upload compared the byte counts
/// first, so a refused write was reported as "difference between bytes read and bytes written"
/// instead of with the status the server gave, such as a timeout (#6767). No network: the file
/// store is a proxy.
/// </summary>
public class SMBShareConnectionWriteFailureTests : BasicSetupHelper
{
    private const int ChunkSize = 1024;

    /// <summary>
    /// A file store whose writes answer with a fixed status and number of bytes written
    /// </summary>
    public class FileStore : DispatchProxy
    {
        public NTStatus WriteStatus;
        public Func<int, int> BytesWritten = n => n;
        public int Closed;

        protected override object? Invoke(MethodInfo? targetMethod, object?[]? args)
        {
            switch (targetMethod!.Name)
            {
                case nameof(ISMBFileStore.CreateFile):
                    args![0] = new object();
                    args[1] = FileStatus.FILE_CREATED;
                    return NTStatus.STATUS_SUCCESS;

                case nameof(ISMBFileStore.WriteFile):
                    args![0] = WriteStatus == NTStatus.STATUS_SUCCESS ? BytesWritten(((byte[])args[3]!).Length) : 0;
                    return WriteStatus;

                case nameof(ISMBFileStore.CloseFile):
                    Interlocked.Increment(ref Closed);
                    return NTStatus.STATUS_SUCCESS;

                default:
                    throw new NotImplementedException(targetMethod.Name);
            }
        }
    }

    private static (SMBShareConnection Connection, FileStore Store) Create(NTStatus writeStatus)
    {
        var proxy = DispatchProxy.Create<ISMBFileStore, FileStore>();
        var store = (FileStore)(object)proxy;
        store.WriteStatus = writeStatus;

        // The client has not negotiated with a server, so set the transfer sizes it would have been given
        var client = new SMB2Client();
        foreach (var field in new[] { "m_maxReadSize", "m_maxWriteSize" })
        {
            var f = typeof(SMB2Client).GetField(field, BindingFlags.NonPublic | BindingFlags.Instance)
                ?? throw new InvalidOperationException($"Field {field} not found on {nameof(SMB2Client)}");
            f.SetValue(client, Convert.ChangeType(ChunkSize, f.FieldType));
        }

        var timeout = TimeSpan.FromSeconds(30);
        var connection = new SMBShareConnection(client, proxy,
            new SMBConnectionParameters("server", SMBTransportType.DirectTCPTransport, "share", "folder", null, null, null, null, null, false),
            new TimeoutOptionsHelper.Timeouts(timeout, timeout, timeout, TimeSpan.FromMinutes(10)));
        return (connection, store);
    }

    [Test]
    [Category("Utility")]
    public void AWriteTheServerRefusesIsReportedWithItsStatus()
    {
        var (connection, store) = Create(NTStatus.STATUS_IO_TIMEOUT);

        var ex = Assert.ThrowsAsync<UserInformationException>(() => connection.PutAsync("file", new MemoryStream(new byte[ChunkSize * 2]), CancellationToken.None));

        Assert.That(ex!.Message, Does.Contain(nameof(NTStatus.STATUS_IO_TIMEOUT)));
        Assert.That(ex.Message, Does.Not.Contain("difference between bytes"));
        Assert.That(store.Closed, Is.EqualTo(1), "The handle must be released on failure");
    }

    [Test]
    [Category("Utility")]
    public void AShortWriteIsReportedAsADifference()
    {
        var (connection, store) = Create(NTStatus.STATUS_SUCCESS);
        store.BytesWritten = n => n / 2;

        var ex = Assert.ThrowsAsync<UserInformationException>(() => connection.PutAsync("file", new MemoryStream(new byte[ChunkSize * 2]), CancellationToken.None));

        Assert.That(ex!.Message, Does.Contain("difference between bytes"));
        Assert.That(store.Closed, Is.EqualTo(1), "The handle must be released on failure");
    }
}
