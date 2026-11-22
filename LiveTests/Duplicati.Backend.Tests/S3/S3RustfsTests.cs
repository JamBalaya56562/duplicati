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

namespace Duplicati.Backend.Tests.S3;

/// <summary>
/// S3 tests against a RustFS server started in a container, so they need no S3 account
/// </summary>
[TestClass]
public sealed class S3RustfsTests : BaseTest
{
    private const string RustfsImage = "rustfs/rustfs:1.0.6";
    private const string AccessKey = "duplicatitest";
    private const string SecretKey = "duplicatitestsecret";
    private const int S3Port = 9000;

    /// <summary>
    /// Perform tests using AWS Client
    /// </summary>
    [TestMethod]
    public Task TestRustfsWithAwsClient()
        => TestRustfsWithClient("aws");

    /// <summary>
    /// Perform tests using Minio Client
    /// </summary>
    [TestMethod]
    public Task TestRustfsWithMinioClient()
        => TestRustfsWithClient("minio");

    /// <summary>
    /// Starts RustFS and runs the backend tester against it with the selected client
    /// </summary>
    /// <param name="client">client to be used, either aws or minio</param>
    private static async Task TestRustfsWithClient(string client)
    {
        var outputConsumer = new OutputConsumer();
        var container = new ContainerBuilder()
            .WithImage(RustfsImage)
            .WithEnvironment("RUSTFS_ACCESS_KEY", AccessKey)
            .WithEnvironment("RUSTFS_SECRET_KEY", SecretKey)
            .WithPortBinding(S3Port, true)
            .WithOutputConsumer(outputConsumer)
            .WithWaitStrategy(Wait.ForUnixContainer().UntilHttpRequestIsSucceeded(r => r.ForPort(S3Port).ForPath("/health")))
            .Build();

        Console.WriteLine("Starting container");
        await container.StartAsync();

        try
        {
            var serverName = $"{container.Hostname}:{container.GetMappedPublicPort(S3Port)}";
            // RustFS refuses to create a bucket in any region but its own, which is us-east-1
            var exitCode = CommandLine.BackendTester.Program.Main(
                new[]
                {
                    $"s3://duplicati-{client}/?s3-server-name={Uri.EscapeDataString(serverName)}&use-ssl=false&s3-location-constraint=us-east-1&s3-client={client}&auth-username={AccessKey}&auth-password={SecretKey}"
                }.Concat(Parameters.GlobalTestParameters).ToArray());

            if (exitCode != 0)
            {
                Console.WriteLine(await outputConsumer.GetStreamsOutput());
                Assert.Fail("BackendTester is returning non-zero exit code, check logs for details");
            }
        }
        finally
        {
            await container.StopAsync();
        }
    }
}
