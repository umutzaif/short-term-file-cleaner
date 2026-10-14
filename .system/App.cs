// Kısa Süreli Dosya Temizleyici - uygulama (Dosya Temizleyici.exe)
// PowerShell motorunu kendi süreci içinde barındırır ve .system\MainApp.ps1'i çalıştırır.
// Ayrı bir powershell.exe başlatılmadığı için hiçbir konsol penceresi açılmaz; görev çubuğunda
// ve Görev Yöneticisi'nde uygulamanın kendi adı ve simgesi görünür.
//
//   Dosya Temizleyici.exe                 -> uygulama (ilk açılışta kurulum sihirbazı)
//   Dosya Temizleyici.exe /startup        -> oturum açılışı modu
//   Dosya Temizleyici.exe /setup:a,b,c    -> seçilen kurulum adımlarını uygula ve aç
//
// Derleme: .system\build\Build.ps1

using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Windows.Forms;

[assembly: AssemblyTitle("Kısa Süreli Dosya Temizleyici")]
[assembly: AssemblyDescription("Kısa Süreli Dosya Temizleyici")]
[assembly: AssemblyProduct("Kısa Süreli Dosya Temizleyici")]
[assembly: AssemblyCompany("Umut Zaif")]
[assembly: AssemblyCopyright("MIT License - github.com/umutzaif/short-term-file-cleaner")]
[assembly: AssemblyVersion("3.3.0.0")]
[assembly: AssemblyFileVersion("3.3.0.0")]

static class Program
{
    const string Title = "Kısa Süreli Dosya Temizleyici";

    [STAThread]
    static int Main(string[] args)
    {
        string root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
        string systemDir = Path.Combine(root, ".system");
        string script = Path.Combine(systemDir, "MainApp.ps1");
        if (!File.Exists(script))
        {
            MessageBox.Show("Uygulama dosyaları bulunamadı:\n" + script +
                "\n\nLütfen programı GitHub'dan yeniden indirin.", Title, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }

        InitialSessionState iss = InitialSessionState.CreateDefault();
        iss.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;

        try
        {
            using (Runspace rs = RunspaceFactory.CreateRunspace(iss))
            {
                rs.ApartmentState = ApartmentState.STA;
                rs.ThreadOptions = PSThreadOptions.UseCurrentThread;
                rs.Open();
                using (PowerShell ps = PowerShell.Create())
                {
                    ps.Runspace = rs;
                    ps.AddCommand(script);
                    foreach (string a in args)
                    {
                        if (a.Equals("/startup", StringComparison.OrdinalIgnoreCase)) ps.AddParameter("Startup");
                        else if (a.StartsWith("/setup:", StringComparison.OrdinalIgnoreCase)) ps.AddParameter("Setup", a.Substring(7));
                    }
                    ps.Invoke();
                    if (ps.Streams.Error.Count > 0)
                    {
                        StringBuilder sb = new StringBuilder();
                        foreach (ErrorRecord e in ps.Streams.Error)
                            sb.AppendLine(DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " - " + e + " @ " + e.InvocationInfo.PositionMessage);
                        TryAppend(Path.Combine(systemDir, "error.log"), sb.ToString());
                    }
                }
            }
            return 0;
        }
        catch (Exception ex)
        {
            TryAppend(Path.Combine(systemDir, "error.log"), DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " - " + ex + Environment.NewLine);
            MessageBox.Show("Uygulama beklenmedik bir hatayla karşılaştı:\n\n" + ex.Message +
                "\n\nAyrıntılar: .system\\error.log", Title, MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }

    static void TryAppend(string path, string text)
    {
        try { File.AppendAllText(path, text, Encoding.UTF8); } catch { }
    }
}
