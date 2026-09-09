namespace Duplicati.Library.Main.Operation.Backup
{
    // Probe (not to be committed): marks where a stat of big.bin starts and ends
    internal static class StallTrace
    {
        private static readonly object Lock = new object();
        public static void Mark(string what, string path)
        {
            if (path == null || !path.Contains("big.bin"))
                return;
            lock (Lock)
                System.IO.File.AppendAllText("/tmp/stall-trace.log", System.DateTime.Now.ToString("HH:mm:ss.fff") + " " + what + " " + path + "\n");
        }
    }
}
