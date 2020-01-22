using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CustomActivityApp
{
    public class CustomLogger
    {
        public void StdOut (string message)
        {
            string timeStamp = DateTime.Now.ToString("dd/MM/yyyy HH:mm:ss");
            string logLine = timeStamp + "|" + message;

            Console.WriteLine(logLine);
        }
    }
}   
 