Add-Type -TypeDefinition @"
using System;
using System.IO;

public static class TaskPomodoroAudioSynth
{
    const int SampleRate = 44100;

    static void WriteWav(string path, double[] samples)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path));
        using (var fs = new FileStream(path, FileMode.Create, FileAccess.Write))
        using (var bw = new BinaryWriter(fs))
        {
            int dataLength = samples.Length * 2;
            bw.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
            bw.Write(36 + dataLength);
            bw.Write(System.Text.Encoding.ASCII.GetBytes("WAVE"));
            bw.Write(System.Text.Encoding.ASCII.GetBytes("fmt "));
            bw.Write(16);
            bw.Write((short)1);
            bw.Write((short)1);
            bw.Write(SampleRate);
            bw.Write(SampleRate * 2);
            bw.Write((short)2);
            bw.Write((short)16);
            bw.Write(System.Text.Encoding.ASCII.GetBytes("data"));
            bw.Write(dataLength);

            for (int i = 0; i < samples.Length; i++)
            {
                double v = Math.Max(-1.0, Math.Min(1.0, samples[i]));
                bw.Write((short)Math.Round(v * short.MaxValue));
            }
        }
    }

    static double Envelope(double x, double attack, double release)
    {
        if (x < 0.0 || x > 1.0) return 0.0;
        if (x < attack) return x / attack;
        if (x > 1.0 - release) return (1.0 - x) / release;
        return 1.0;
    }

    static void AddTone(double[] s, double start, double duration, double freq, double amp)
    {
        int a = Math.Max(0, (int)(start * SampleRate));
        int b = Math.Min(s.Length, (int)((start + duration) * SampleRate));
        for (int i = a; i < b; i++)
        {
            double local = (double)(i - a) / SampleRate;
            double x = local / duration;
            double env = Envelope(x, 0.08, 0.18);
            s[i] += Math.Sin(2.0 * Math.PI * freq * local) * amp * env;
        }
    }

    static void AddBell(double[] s, double start, double duration, double freq, double amp)
    {
        int a = Math.Max(0, (int)(start * SampleRate));
        int b = Math.Min(s.Length, (int)((start + duration) * SampleRate));
        for (int i = a; i < b; i++)
        {
            double t = (double)(i - a) / SampleRate;
            double env = Math.Exp(-4.0 * t / duration);
            double attack = Math.Min(1.0, t / 0.025);
            double v =
                Math.Sin(2.0 * Math.PI * freq * t) * 0.78 +
                Math.Sin(2.0 * Math.PI * freq * 2.01 * t) * 0.18 +
                Math.Sin(2.0 * Math.PI * freq * 3.02 * t) * 0.07;
            s[i] += v * amp * env * attack;
        }
    }

    static void AddPad(double[] s, double duration, double[] freqs, double amp, double tremoloCycles)
    {
        for (int i = 0; i < s.Length; i++)
        {
            double t = (double)i / SampleRate;
            double x = t / duration;
            double edge = Envelope(x, 0.03, 0.03);
            double trem = 0.74 + 0.26 * Math.Sin(2.0 * Math.PI * tremoloCycles * x - Math.PI / 2.0);
            double v = 0.0;
            for (int j = 0; j < freqs.Length; j++)
            {
                double f = freqs[j];
                v += Math.Sin(2.0 * Math.PI * f * t) * 0.72;
                v += Math.Sin(2.0 * Math.PI * f * 2.0 * t) * 0.14;
            }
            v /= freqs.Length;
            s[i] += v * amp * edge * trem;
        }
    }

    static void SoftLimit(double[] s, double gain)
    {
        for (int i = 0; i < s.Length; i++)
        {
            s[i] = Math.Tanh(s[i] * gain) * 0.88;
        }
    }

    static double[] NewBuffer(double seconds)
    {
        return new double[(int)(seconds * SampleRate)];
    }

    public static void GenerateAll(string outDir)
    {
        Directory.CreateDirectory(outDir);

        var focusStart = NewBuffer(1.35);
        AddBell(focusStart, 0.00, 0.85, 659.25, 0.34);
        AddBell(focusStart, 0.18, 0.85, 783.99, 0.30);
        AddBell(focusStart, 0.36, 0.90, 987.77, 0.26);
        AddTone(focusStart, 0.00, 1.15, 130.81, 0.06);
        SoftLimit(focusStart, 1.2);
        WriteWav(Path.Combine(outDir, "focus-start.wav"), focusStart);

        var breakStart = NewBuffer(1.55);
        AddBell(breakStart, 0.00, 1.05, 880.00, 0.24);
        AddBell(breakStart, 0.24, 1.05, 659.25, 0.24);
        AddBell(breakStart, 0.48, 1.00, 523.25, 0.22);
        AddTone(breakStart, 0.00, 1.35, 196.00, 0.05);
        SoftLimit(breakStart, 1.15);
        WriteWav(Path.Combine(outDir, "break-start.wav"), breakStart);

        var focusLoop = NewBuffer(24.0);
        AddPad(focusLoop, 24.0, new double[] { 110.00, 146.83, 220.00, 293.66 }, 0.070, 2.0);
        for (int k = 0; k < 4; k++)
        {
            double st = 1.5 + k * 6.0;
            AddBell(focusLoop, st, 2.2, 440.00, 0.055);
            AddBell(focusLoop, st + 1.2, 1.8, 554.37, 0.040);
        }
        SoftLimit(focusLoop, 1.6);
        WriteWav(Path.Combine(outDir, "focus-loop.wav"), focusLoop);

        var breakLoop = NewBuffer(20.0);
        AddPad(breakLoop, 20.0, new double[] { 130.81, 164.81, 196.00, 261.63 }, 0.075, 1.0);
        for (int k = 0; k < 5; k++)
        {
            double st = 0.9 + k * 4.0;
            AddBell(breakLoop, st, 1.9, 523.25, 0.050);
            AddBell(breakLoop, st + 0.8, 1.7, 659.25, 0.035);
        }
        SoftLimit(breakLoop, 1.45);
        WriteWav(Path.Combine(outDir, "break-loop.wav"), breakLoop);
    }
}
"@

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$outDir = Join-Path $root "assets\audio"
[TaskPomodoroAudioSynth]::GenerateAll($outDir)
Get-ChildItem -LiteralPath $outDir -Filter *.wav | Select-Object Name, Length, FullName
