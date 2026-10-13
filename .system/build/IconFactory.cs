// Kisa Sureli Dosya Temizleyici - simge ureticisi (yalnizca gelistirme icin, Build.ps1 kullanir)
// app.ico   : uygulama simgesi (gradyan zemin uzerinde kum saati)
// folder.ico: short-term-files klasor simgesi (saat rozetli renkli klasor)

using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

namespace StfcBuild
{
    public static class IconFactory
    {
        static readonly Color Violet = Color.FromArgb(124, 92, 255);
        static readonly Color Sky = Color.FromArgb(56, 189, 248);
        static readonly Color Sand = Color.FromArgb(251, 191, 36);
        static readonly int[] Sizes = { 16, 20, 24, 32, 40, 48, 64, 128, 256 };

        static GraphicsPath Round(RectangleF r, float rad)
        {
            GraphicsPath p = new GraphicsPath();
            float d = Math.Min(rad * 2, Math.Min(r.Width, r.Height));
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        static Graphics Prepare(Bitmap b)
        {
            Graphics g = Graphics.FromImage(b);
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.Clear(Color.Transparent);
            return g;
        }

        static void Hourglass(Graphics g, float cx, float cy, float h, Color glass, Color sand, Color frame)
        {
            float w = h * 0.70f;
            float neck = h * 0.07f;
            float top = cy - h / 2, bottom = cy + h / 2;
            float bar = Math.Max(1.5f, h * 0.11f);

            using (GraphicsPath p = new GraphicsPath())
            {
                p.AddLine(cx - w / 2, top + bar * 0.5f, cx + w / 2, top + bar * 0.5f);
                p.AddBezier(cx + w / 2, top + bar * 0.5f, cx + w / 2, cy - h * 0.12f, cx + neck * 1.2f, cy - h * 0.05f, cx + neck, cy);
                p.AddBezier(cx + neck, cy, cx + neck * 1.2f, cy + h * 0.05f, cx + w / 2, cy + h * 0.12f, cx + w / 2, bottom - bar * 0.5f);
                p.AddLine(cx + w / 2, bottom - bar * 0.5f, cx - w / 2, bottom - bar * 0.5f);
                p.AddBezier(cx - w / 2, bottom - bar * 0.5f, cx - w / 2, cy + h * 0.12f, cx - neck * 1.2f, cy + h * 0.05f, cx - neck, cy);
                p.AddBezier(cx - neck, cy, cx - neck * 1.2f, cy - h * 0.05f, cx - w / 2, cy - h * 0.12f, cx - w / 2, top + bar * 0.5f);
                p.CloseFigure();
                using (SolidBrush b = new SolidBrush(glass)) g.FillPath(b, p);
            }

            // ust kum ve asagi akan kum
            using (SolidBrush b = new SolidBrush(sand))
            {
                g.FillPolygon(b, new PointF[] {
                    new PointF(cx - w * 0.26f, cy - h * 0.20f), new PointF(cx + w * 0.26f, cy - h * 0.20f), new PointF(cx, cy - h * 0.02f) });
                using (GraphicsPath mound = new GraphicsPath())
                {
                    mound.AddBezier(cx - w * 0.40f, bottom - bar * 0.6f, cx - w * 0.22f, cy + h * 0.24f, cx + w * 0.22f, cy + h * 0.24f, cx + w * 0.40f, bottom - bar * 0.6f);
                    mound.CloseFigure();
                    g.FillPath(b, mound);
                }
                if (h >= 20) g.FillRectangle(b, cx - h * 0.012f, cy - h * 0.02f, h * 0.024f, h * 0.30f);
            }

            using (SolidBrush b = new SolidBrush(frame))
            {
                using (GraphicsPath t = Round(new RectangleF(cx - w / 2 - h * 0.06f, top - bar * 0.4f, w + h * 0.12f, bar), bar / 2)) g.FillPath(b, t);
                using (GraphicsPath t = Round(new RectangleF(cx - w / 2 - h * 0.06f, bottom - bar * 0.6f, w + h * 0.12f, bar), bar / 2)) g.FillPath(b, t);
            }
        }

        public static Bitmap App(int s)
        {
            Bitmap bmp = new Bitmap(s, s, PixelFormat.Format32bppArgb);
            using (Graphics g = Prepare(bmp))
            {
                float pad = s * (s <= 24 ? 0.02f : 0.06f);
                RectangleF r = new RectangleF(pad, pad, s - pad * 2, s - pad * 2);
                float rad = r.Width * 0.24f;
                if (s >= 48)
                {
                    using (GraphicsPath sh = Round(new RectangleF(r.X, r.Y + s * 0.025f, r.Width, r.Height), rad))
                    using (SolidBrush b = new SolidBrush(Color.FromArgb(70, 10, 10, 40))) g.FillPath(b, sh);
                }
                using (GraphicsPath p = Round(r, rad))
                {
                    using (LinearGradientBrush b = new LinearGradientBrush(RectangleF.Inflate(r, 1, 1), Violet, Sky, 50f)) g.FillPath(b, p);
                    if (s >= 32)
                    {
                        RectangleF gloss = new RectangleF(r.X, r.Y, r.Width, r.Height * 0.55f);
                        g.SetClip(p);
                        using (LinearGradientBrush b = new LinearGradientBrush(new RectangleF(gloss.X, gloss.Y - 1, gloss.Width, gloss.Height + 4), Color.FromArgb(55, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), 90f))
                            g.FillRectangle(b, gloss);
                        g.ResetClip();
                    }
                }
                Hourglass(g, s / 2f, s / 2f + s * 0.01f, s * 0.58f, Color.FromArgb(235, 255, 255, 255), Sand, Color.White);
            }
            return bmp;
        }

        public static Bitmap Folder(int s)
        {
            Bitmap bmp = new Bitmap(s, s, PixelFormat.Format32bppArgb);
            using (Graphics g = Prepare(bmp))
            {
                float x = s * 0.04f, w = s * 0.92f;
                float rad = s * 0.08f;
                RectangleF back = new RectangleF(x, s * 0.14f, w, s * 0.74f);
                RectangleF tab = new RectangleF(x, s * 0.08f, s * 0.42f, s * 0.16f);
                RectangleF front = new RectangleF(x, s * 0.26f, w, s * 0.62f);

                if (s >= 48)
                {
                    using (GraphicsPath sh = Round(new RectangleF(front.X, front.Y + s * 0.03f, front.Width, front.Height), rad))
                    using (SolidBrush b = new SolidBrush(Color.FromArgb(60, 10, 10, 40))) g.FillPath(b, sh);
                }
                Color backA = Color.FromArgb(88, 60, 210), backB = Color.FromArgb(30, 140, 210);
                using (LinearGradientBrush b = new LinearGradientBrush(new RectangleF(x - 1, s * 0.07f, w + 2, s * 0.83f), backA, backB, 45f))
                {
                    using (GraphicsPath p = Round(tab, rad * 0.8f)) g.FillPath(b, p);
                    using (GraphicsPath p = Round(back, rad)) g.FillPath(b, p);
                }
                using (GraphicsPath p = Round(front, rad))
                {
                    using (LinearGradientBrush b = new LinearGradientBrush(RectangleF.Inflate(front, 1, 1), Color.FromArgb(146, 116, 255), Color.FromArgb(70, 200, 250), 45f))
                        g.FillPath(b, p);
                    if (s >= 32)
                        using (Pen pen = new Pen(Color.FromArgb(90, 255, 255, 255), Math.Max(1f, s * 0.012f)))
                            g.DrawLine(pen, front.X + rad, front.Y + s * 0.012f, front.Right - rad, front.Y + s * 0.012f);
                }

                // saat rozeti
                float cr = s * 0.19f;
                float cx = s * 0.5f, cy = front.Y + front.Height * 0.52f;
                using (SolidBrush b = new SolidBrush(Color.White)) g.FillEllipse(b, cx - cr, cy - cr, cr * 2, cr * 2);
                float pw = Math.Max(1.4f, s * 0.045f);
                using (Pen pen = new Pen(Violet, pw))
                {
                    pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
                    g.DrawLine(pen, cx, cy, cx, cy - cr * 0.62f);
                    g.DrawLine(pen, cx, cy, cx + cr * 0.48f, cy + cr * 0.22f);
                }
                if (s >= 32)
                    using (SolidBrush b = new SolidBrush(Sand)) g.FillEllipse(b, cx - pw * 0.7f, cy - pw * 0.7f, pw * 1.4f, pw * 1.4f);
            }
            return bmp;
        }

        // 256 px PNG, digerleri 32 bit BMP olarak .ico dosyasina yazilir.
        public static void WriteIco(string path, Func<int, Bitmap> render)
        {
            List<byte[]> images = new List<byte[]>();
            foreach (int s in Sizes)
            {
                using (Bitmap b = render(s))
                {
                    if (s >= 256)
                    {
                        using (MemoryStream ms = new MemoryStream()) { b.Save(ms, ImageFormat.Png); images.Add(ms.ToArray()); }
                    }
                    else images.Add(Dib(b));
                }
            }
            using (FileStream fs = new FileStream(path, FileMode.Create))
            using (BinaryWriter w = new BinaryWriter(fs))
            {
                w.Write((short)0); w.Write((short)1); w.Write((short)Sizes.Length);
                int offset = 6 + 16 * Sizes.Length;
                for (int i = 0; i < Sizes.Length; i++)
                {
                    int s = Sizes[i];
                    w.Write((byte)(s >= 256 ? 0 : s)); w.Write((byte)(s >= 256 ? 0 : s));
                    w.Write((byte)0); w.Write((byte)0);
                    w.Write((short)1); w.Write((short)32);
                    w.Write(images[i].Length); w.Write(offset);
                    offset += images[i].Length;
                }
                foreach (byte[] img in images) w.Write(img);
            }
        }

        static byte[] Dib(Bitmap b)
        {
            int s = b.Width;
            int maskStride = ((s + 31) / 32) * 4;
            using (MemoryStream ms = new MemoryStream())
            using (BinaryWriter w = new BinaryWriter(ms))
            {
                w.Write(40); w.Write(s); w.Write(s * 2); w.Write((short)1); w.Write((short)32);
                w.Write(0); w.Write(s * s * 4 + maskStride * s); w.Write(0); w.Write(0); w.Write(0); w.Write(0);
                for (int y = s - 1; y >= 0; y--)
                    for (int x = 0; x < s; x++)
                    {
                        Color c = b.GetPixel(x, y);
                        w.Write(c.B); w.Write(c.G); w.Write(c.R); w.Write(c.A);
                    }
                w.Write(new byte[maskStride * s]);
                return ms.ToArray();
            }
        }

        public static void Preview(string path)
        {
            using (Bitmap sheet = new Bitmap(700, 560))
            using (Graphics g = Graphics.FromImage(sheet))
            {
                g.Clear(Color.FromArgb(32, 96, 160));
                int x = 10;
                foreach (int s in new int[] { 16, 24, 32, 48, 64, 128, 256 })
                {
                    using (Bitmap a = App(s)) g.DrawImage(a, x, 10, s, s);
                    using (Bitmap f = Folder(s)) g.DrawImage(f, x, 280, s, s);
                    x += s + 14;
                }
                sheet.Save(path, ImageFormat.Png);
            }
        }
    }
}
