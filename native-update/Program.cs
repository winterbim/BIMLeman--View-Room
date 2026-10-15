using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

internal static class Program
{
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    private static extern bool SetWindowText(IntPtr hwnd, string text);
    [DllImport("user32.dll")]
    private static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
    [STAThread]
    private static int Main(string[] args)
    {
        if (Array.Exists(args, a => a == "--credits"))
        {
            MessageBox.Show("BIMLéman View Room utilise Veyon Master. Veyon est sous licence GPL. Sources : https://github.com/veyon/veyon", "Crédits et licence");
            return 0;
        }
        var exe = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Veyon", "veyon-master.exe");
        if (!File.Exists(exe))
        {
            MessageBox.Show("Veyon Master introuvable : " + exe, "BIMLéman View Room", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 2;
        }
        try
        {
            using var process = Process.Start(new ProcessStartInfo(exe) { UseShellExecute = true });
            if (process == null) throw new Exception("Démarrage impossible");
            using var icon = new System.Drawing.Icon(Path.Combine(AppContext.BaseDirectory, "brand.ico"));
            for (var i = 0; i < 120 && !process.HasExited; i++)
            {
                process.Refresh();
                var hwnd = process.MainWindowHandle;
                if (hwnd != IntPtr.Zero)
                {
                    SetWindowText(hwnd, "BIMLéman View Room");
                    SendMessage(hwnd, 0x80, IntPtr.Zero, icon.Handle);
                    SendMessage(hwnd, 0x80, (IntPtr)1, icon.Handle);
                }
                Thread.Sleep(500);
            }
            return 0;
        }
        catch (Exception ex)
        {
            MessageBox.Show(ex.Message, "BIMLéman View Room", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }
    }
}