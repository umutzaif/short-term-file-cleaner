// Kisa Sureli Dosya Temizleyici - sessiz baslatici
// PowerShell'i hic konsol penceresi olusturmadan baslatir. Install-CleanupTask tarafindan
// .system\Launcher.exe olarak derlenir; Gorev Zamanlayici ve Baslat menusu kisayolu bunu kullanir.
//   Launcher.exe            -> MainApp.ps1 (panel)
//   Launcher.exe /startup   -> MainApp.ps1 -Startup (oturum acilisi taramasi)

using System;
using System.Diagnostics;
using System.IO;

static class Launcher
{
    [STAThread]
    static void Main(string[] args)
    {
        string systemDir = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
        string app = Path.Combine(Path.GetDirectoryName(systemDir), "MainApp.ps1");
        bool startup = args.Length > 0 && args[0].Equals("/startup", StringComparison.OrdinalIgnoreCase);

        ProcessStartInfo psi = new ProcessStartInfo();
        psi.FileName = Path.Combine(Environment.SystemDirectory, @"WindowsPowerShell\v1.0\powershell.exe");
        psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"" + app + "\"" + (startup ? " -Startup" : "");
        psi.WorkingDirectory = systemDir;
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.WindowStyle = ProcessWindowStyle.Hidden;
        Process.Start(psi);
    }
}
