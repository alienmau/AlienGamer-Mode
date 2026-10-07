using System;
using System.Diagnostics;
using System.IO;
using System.Text;

namespace AlienGamer.Runtime {
    public static class ProcessHost {
        // A hidden window is not the same as preventing console allocation.
        // CREATE_NO_WINDOW also avoids creating a Windows Terminal tab.
        public static Process Start(string executable, string arguments, string errorPath) {
            var info=new ProcessStartInfo(executable,arguments) {
                // Keep graphical dialogs visible; suppress only console allocation.
                UseShellExecute=false, CreateNoWindow=true, WindowStyle=ProcessWindowStyle.Normal,
                RedirectStandardError=!String.IsNullOrEmpty(errorPath)
            };
            var process=new Process { StartInfo=info };
            if(info.RedirectStandardError) process.ErrorDataReceived += delegate(object sender,DataReceivedEventArgs e) {
                if(e.Data==null) return;
                try { File.AppendAllText(errorPath,e.Data+Environment.NewLine,Encoding.UTF8); } catch { }
            };
            process.Start();
            if(info.RedirectStandardError) process.BeginErrorReadLine();
            return process;
        }
        public static string Quote(string value) {
            var result=new StringBuilder("\"");int slashes=0;
            foreach(char c in value) {
                if(c=='\\') { slashes++;continue; }
                result.Append('\\',c=='"' ? slashes*2+1 : slashes);result.Append(c);slashes=0;
            }
            result.Append('\\',slashes*2);return result.Append('"').ToString();
        }
        [STAThread]
        public static int Main(string[] args) {
            try {
                if(args.Length<2) return 2;
                var arguments=new StringBuilder();
                for(int i=1;i<args.Length;i++) { if(i>1) arguments.Append(' ');arguments.Append(Quote(args[i])); }
                using(var child=Start(args[0],arguments.ToString(),null)) { }
                return 0;
            } catch(Exception error) {
                try {
                    string directory=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"AlienGamerMode");
                    Directory.CreateDirectory(directory);File.AppendAllText(Path.Combine(directory,"launcher.error.log"),error.ToString()+Environment.NewLine);
                } catch { }
                return 1;
            }
        }
    }
}
