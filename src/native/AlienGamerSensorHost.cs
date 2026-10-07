using System;
using System.Diagnostics;
using System.IO;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Threading;

// GUI subsystem: no console, terminal tab, or resident PowerShell.
internal static class AlienGamerSensorHost
{
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern IntPtr OpenProcess(uint access, bool inheritHandle, int processId);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);
    [DllImport("kernel32.dll", SetLastError=true)]
    private static extern bool TerminateProcess(IntPtr process, uint exitCode);
    [DllImport("kernel32.dll")]
    private static extern bool CloseHandle(IntPtr handle);
    private static readonly string DataRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AlienGamerMode");
    private static void Log(string message)
    {
        File.AppendAllText(Path.Combine(DataRoot, "hwinfo-task.log"), DateTime.Now.ToString("o") + " NativeHost: " + message + Environment.NewLine);
    }
    [STAThread]
    private static int Main()
    {
        Directory.CreateDirectory(DataRoot);
        using (var mutex = new Mutex(false, "Local\\AlienGamerMode.SensorHost"))
        {
            bool acquired = false;
            try
            {
                try { acquired = mutex.WaitOne(0); } catch (AbandonedMutexException) { acquired = true; }
                if (!acquired) return 0;
                bool elevated = new WindowsPrincipal(WindowsIdentity.GetCurrent()).IsInRole(WindowsBuiltInRole.Administrator);
                Log("Inicio; Elevado=" + elevated);
                if (!elevated) throw new InvalidOperationException("La tarea de sensores debe ejecutarse con privilegios elevados.");
                string executable = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "HWiNFO64", "HWiNFO64.exe");
                if (!File.Exists(executable)) throw new FileNotFoundException("No se encontro HWiNFO64.", executable);
                // Do not take ownership of sensors launched outside this host.
                if (Process.GetProcessesByName("HWiNFO64").Length != 0) { Log("HWiNFO ya estaba activo; no se toma propiedad."); return 0; }
                string stopSignal = Path.Combine(DataRoot, "stop-hwinfo.signal");
                Log("Signal=" + stopSignal);
                if (File.Exists(stopSignal)) File.Delete(stopSignal);
                using (Process sensor = Process.Start(new ProcessStartInfo(executable) {
                    UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(executable), WindowStyle = ProcessWindowStyle.Minimized
                }))
                {
                    if (sensor == null) throw new InvalidOperationException("HWiNFO no devolvio un proceso.");
                    Log("HWiNFO iniciado; PID=" + sensor.Id);
                    Log("Vigilando cierre.");
                    // Poll the kernel directly; no STA message-pumping waits on a GUI process.
                    IntPtr handle = OpenProcess(0x1001, false, sensor.Id);
                    if (handle == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error());
                    try
                    {
                        uint exitCode;
                        while (GetExitCodeProcess(handle, out exitCode) && exitCode == 259)
                        {
                            if (File.Exists(stopSignal))
                            {
                                Log("Solicitud de cierre recibida.");
                                // HWiNFO minimizes on close; explicitly stop only our child.
                                if (!TerminateProcess(handle, 0)) throw new Win32Exception(Marshal.GetLastWin32Error());
                                File.Delete(stopSignal);
                            }
                            Thread.Sleep(150);
                        }
                        Log("HWiNFO termino; Codigo=" + exitCode);
                    }
                    finally { CloseHandle(handle); }
                    return 0;
                }
            }
            catch (Exception error) { Log("ERROR: " + error); return 1; }
            finally { if (acquired) mutex.ReleaseMutex(); }
        }
    }
}
