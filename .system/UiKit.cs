// Kisa Sureli Dosya Temizleyici - modern WinForms kontrol kiti
// MainApp.ps1 tarafindan derlenir (ilk calistirmada %LOCALAPPDATA% altina onbelleklenir).
// Not: Windows PowerShell 5.1'in derleyicisi C# 5 destekler; yeni dil ozellikleri kullanmayin.

using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace StfcUi
{
    public static class Theme
    {
        public static Color Bg = Color.FromArgb(12, 14, 21);
        public static Color Side = Color.FromArgb(17, 20, 30);
        public static Color Card = Color.FromArgb(22, 26, 38);
        public static Color CardHi = Color.FromArgb(30, 35, 50);
        public static Color Border = Color.FromArgb(36, 42, 59);
        public static Color Text = Color.FromArgb(236, 239, 247);
        public static Color Muted = Color.FromArgb(137, 146, 168);
        public static Color Accent = Color.FromArgb(124, 92, 255);
        public static Color Accent2 = Color.FromArgb(56, 189, 248);
        public static Color Success = Color.FromArgb(34, 197, 94);
        public static Color Warning = Color.FromArgb(245, 158, 11);
        public static Color Danger = Color.FromArgb(244, 63, 94);
        public static string IconFamily = "Segoe MDL2 Assets";
        public static string FontFamily = "Segoe UI";
        public static float Scale = 1f;

        public static int S(float v) { return (int)Math.Round(v * Scale); }
    }

    public static class Native
    {
        [DllImport("dwmapi.dll")] private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int value, int size);
        [DllImport("kernel32.dll")] private static extern IntPtr GetConsoleWindow();
        [DllImport("kernel32.dll")] private static extern uint GetConsoleProcessList(uint[] list, uint count);
        [DllImport("user32.dll")] private static extern bool ShowWindow(IntPtr hWnd, int cmd);
        [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] private static extern bool IsIconic(IntPtr hWnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr FindWindow(string cls, string title);
        [DllImport("user32.dll")] private static extern bool SetProcessDPIAware();
        [DllImport("uxtheme.dll", CharSet = CharSet.Unicode)] private static extern int SetWindowTheme(IntPtr hwnd, string app, string idList);

        // Konsol yalnizca bu surece aitse gizlenir (acik bir terminalden calistirildiginda terminale dokunulmaz).
        public static void HideOwnConsole()
        {
            IntPtr h = GetConsoleWindow();
            if (h == IntPtr.Zero) return;
            uint[] list = new uint[4];
            if (GetConsoleProcessList(list, 4) <= 1) ShowWindow(h, 0);
        }

        public static void EnableDpiAwareness()
        {
            try { SetProcessDPIAware(); } catch { }
        }

        public static void StyleWindow(IntPtr hwnd, Color caption)
        {
            int on = 1;
            if (DwmSetWindowAttribute(hwnd, 20, ref on, 4) != 0) DwmSetWindowAttribute(hwnd, 19, ref on, 4);
            int round = 2;
            DwmSetWindowAttribute(hwnd, 33, ref round, 4);
            int color = caption.R | (caption.G << 8) | (caption.B << 16);
            DwmSetWindowAttribute(hwnd, 35, ref color, 4);
        }

        public static bool ActivateWindow(string title)
        {
            IntPtr h = FindWindow(null, title);
            if (h == IntPtr.Zero) return false;
            if (IsIconic(h)) ShowWindow(h, 9);
            return SetForegroundWindow(h);
        }

        // Kaydirma cubuklari gibi yerel parcalari koyu temaya alir.
        public static void DarkTheme(Control c)
        {
            if (c.IsHandleCreated) SetWindowTheme(c.Handle, "DarkMode_Explorer", null);
            else c.HandleCreated += delegate(object s, EventArgs e) { SetWindowTheme(((Control)s).Handle, "DarkMode_Explorer", null); };
            foreach (Control child in c.Controls) DarkTheme(child);
        }
    }

    public static class Gfx
    {
        public static GraphicsPath Round(RectangleF r, float radius)
        {
            GraphicsPath p = new GraphicsPath();
            float d = Math.Min(radius * 2, Math.Min(r.Width, r.Height));
            if (d <= 0) { p.AddRectangle(r); return p; }
            p.AddArc(r.X, r.Y, d, d, 180, 90);
            p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
            p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure();
            return p;
        }

        public static Color Mix(Color a, Color b, float t)
        {
            return Color.FromArgb(
                (int)(a.R + (b.R - a.R) * t),
                (int)(a.G + (b.G - a.G) * t),
                (int)(a.B + (b.B - a.B) * t));
        }

        public static void Hq(Graphics g)
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
        }

        public static Color OuterColor(Control c)
        {
            return c.Parent != null ? c.Parent.BackColor : Theme.Bg;
        }

        public static void Glyph(Graphics g, string glyph, float size, Color color, Rectangle r)
        {
            if (string.IsNullOrEmpty(glyph)) return;
            using (Font f = new Font(Theme.IconFamily, size))
                TextRenderer.DrawText(g, glyph, f, r, color,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }

        public static Icon GlyphIcon(string glyph, Color c1, Color c2)
        {
            Bitmap bmp = new Bitmap(64, 64);
            using (Graphics g = Graphics.FromImage(bmp))
            {
                Hq(g);
                g.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
                using (GraphicsPath p = Round(new RectangleF(2, 2, 60, 60), 16))
                using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, 0, 64, 64), c1, c2, 45f))
                    g.FillPath(b, p);
                using (Font f = new Font(Theme.IconFamily, 30, GraphicsUnit.Pixel))
                using (StringFormat sf = new StringFormat())
                {
                    sf.Alignment = StringAlignment.Center;
                    sf.LineAlignment = StringAlignment.Center;
                    g.DrawString(glyph, f, Brushes.White, new RectangleF(0, 3, 64, 64), sf);
                }
            }
            return Icon.FromHandle(bmp.GetHicon());
        }
    }

    // Yuvarlak koseli kart. Fill2 verilirse gradyan dolgu kullanir.
    public class Card : Panel
    {
        private int radius = 16;
        private Color fill = Theme.Card;
        private Color fill2 = Color.Empty;
        private Color border = Theme.Border;

        public int Radius { get { return radius; } set { radius = value; Invalidate(); } }
        public Color Fill { get { return fill; } set { fill = value; BackColor = value; Invalidate(); } }
        public Color Fill2 { get { return fill2; } set { fill2 = value; Invalidate(); } }
        public Color BorderColor { get { return border; } set { border = value; Invalidate(); } }

        public Card()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            BackColor = fill;
            Padding = new Padding(Theme.S(20));
        }

        protected override void OnPaintBackground(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(Gfx.OuterColor(this));
            if (Width < 2 || Height < 2) return;
            Gfx.Hq(g);
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (GraphicsPath p = Gfx.Round(r, Theme.S(radius)))
            {
                if (fill2.IsEmpty)
                {
                    using (SolidBrush b = new SolidBrush(fill)) g.FillPath(b, p);
                }
                else
                {
                    using (LinearGradientBrush b = new LinearGradientBrush(ClientRectangle, fill, fill2, 25f)) g.FillPath(b, p);
                }
                if (border.A > 0) using (Pen pen = new Pen(border)) g.DrawPath(pen, p);
            }
        }
    }

    public enum ButtonKind { Solid, Soft, Ghost, Outline }

    public class ModernButton : Control
    {
        private ButtonKind kind = ButtonKind.Solid;
        private Color accent = Theme.Accent;
        private string glyph = "";
        private bool hover, down, selected;

        public ButtonKind Kind { get { return kind; } set { kind = value; Invalidate(); } }
        public Color Accent { get { return accent; } set { accent = value; Invalidate(); } }
        public string Glyph { get { return glyph; } set { glyph = value ?? ""; Invalidate(); } }
        public bool Selected { get { return selected; } set { selected = value; Invalidate(); } }

        public ModernButton()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            SetStyle(ControlStyles.Selectable, false);
            Cursor = Cursors.Hand;
            Font = new Font("Segoe UI Semibold", 9.75f);
            Size = new Size(140, 40);
        }

        protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; Invalidate(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { down = true; Invalidate(); } base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
        protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Color outer = Gfx.OuterColor(this);
            g.Clear(outer);
            Gfx.Hq(g);

            Color bg, fg, bd = Color.Empty;
            ButtonKind k = selected ? ButtonKind.Solid : kind;
            switch (k)
            {
                case ButtonKind.Solid:
                    bg = hover ? Gfx.Mix(accent, Color.White, 0.12f) : accent;
                    fg = Color.White;
                    break;
                case ButtonKind.Soft:
                    bg = Gfx.Mix(outer, accent, hover ? 0.30f : 0.18f);
                    fg = Gfx.Mix(accent, Color.White, 0.45f);
                    break;
                case ButtonKind.Outline:
                    bg = hover ? Gfx.Mix(outer, accent, 0.14f) : outer;
                    bd = Gfx.Mix(outer, accent, 0.75f);
                    fg = Gfx.Mix(accent, Color.White, 0.35f);
                    break;
                default:
                    bg = hover ? Gfx.Mix(outer, Color.White, 0.07f) : Gfx.Mix(outer, Color.White, 0.03f);
                    bd = Gfx.Mix(outer, Color.White, 0.10f);
                    fg = Theme.Text;
                    break;
            }
            if (down) bg = Gfx.Mix(bg, Color.Black, 0.15f);
            if (!Enabled) { bg = Gfx.Mix(bg, outer, 0.55f); fg = Gfx.Mix(fg, outer, 0.55f); if (!bd.IsEmpty) bd = Gfx.Mix(bd, outer, 0.55f); }

            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (GraphicsPath p = Gfx.Round(r, Theme.S(10)))
            {
                using (SolidBrush b = new SolidBrush(bg)) g.FillPath(b, p);
                if (!bd.IsEmpty) using (Pen pen = new Pen(bd)) g.DrawPath(pen, p);
            }

            TextFormatFlags flags = TextFormatFlags.NoPadding | TextFormatFlags.SingleLine;
            Size ts = string.IsNullOrEmpty(Text) ? Size.Empty : TextRenderer.MeasureText(g, Text, Font, Size.Empty, flags);
            int gw = glyph.Length > 0 ? Theme.S(18) : 0;
            int gap = (gw > 0 && ts.Width > 0) ? Theme.S(8) : 0;
            int total = gw + gap + ts.Width;
            int x = Math.Max(Theme.S(10), (Width - total) / 2);
            if (gw > 0) Gfx.Glyph(g, glyph, Font.SizeInPoints * 1.05f, fg, new Rectangle(x, 0, gw, Height));
            if (ts.Width > 0)
                TextRenderer.DrawText(g, Text, Font, new Rectangle(x + gw + gap, 0, Width - x - gw - gap, Height), fg,
                    flags | TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);
        }
    }

    // Kenar cubugu gezinme ogesi
    public class NavItem : Control
    {
        private string glyph = "";
        private bool active, hover;
        private int badge;

        public string Glyph { get { return glyph; } set { glyph = value ?? ""; Invalidate(); } }
        public bool Active { get { return active; } set { active = value; Invalidate(); } }
        public int Badge { get { return badge; } set { badge = value; Invalidate(); } }

        public NavItem()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            Cursor = Cursors.Hand;
            Font = new Font(Theme.FontFamily, 10f);
            Height = 44;
        }

        protected override void OnMouseEnter(EventArgs e) { hover = true; Invalidate(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hover = false; Invalidate(); base.OnMouseLeave(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Color outer = Gfx.OuterColor(this);
            g.Clear(outer);
            Gfx.Hq(g);
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);

            if (active)
            {
                using (GraphicsPath p = Gfx.Round(r, Theme.S(10)))
                using (LinearGradientBrush b = new LinearGradientBrush(ClientRectangle,
                    Gfx.Mix(outer, Theme.Accent, 0.30f), Gfx.Mix(outer, Theme.Accent, 0.08f), 0f))
                    g.FillPath(b, p);
                using (GraphicsPath bar = Gfx.Round(new RectangleF(0, Height * 0.28f, Theme.S(3), Height * 0.44f), Theme.S(2)))
                using (SolidBrush b = new SolidBrush(Theme.Accent))
                    g.FillPath(b, bar);
            }
            else if (hover)
            {
                using (GraphicsPath p = Gfx.Round(r, Theme.S(10)))
                using (SolidBrush b = new SolidBrush(Gfx.Mix(outer, Color.White, 0.05f)))
                    g.FillPath(b, p);
            }

            Color fg = active ? Theme.Text : (hover ? Gfx.Mix(Theme.Muted, Theme.Text, 0.5f) : Theme.Muted);
            Color gc = active ? Gfx.Mix(Theme.Accent, Color.White, 0.40f) : fg;
            Gfx.Glyph(g, glyph, 12f, gc, new Rectangle(Theme.S(14), 0, Theme.S(24), Height));

            int right = Width - Theme.S(10);
            if (badge > 0)
            {
                string s = badge > 99 ? "99+" : badge.ToString();
                using (Font bf = new Font("Segoe UI Semibold", 8f))
                {
                    Size bs = TextRenderer.MeasureText(g, s, bf, Size.Empty, TextFormatFlags.NoPadding);
                    int bw = Math.Max(Theme.S(22), bs.Width + Theme.S(12));
                    int bh = Theme.S(20);
                    Rectangle br = new Rectangle(right - bw, (Height - bh) / 2, bw, bh);
                    using (GraphicsPath p = Gfx.Round(br, bh / 2f))
                    using (SolidBrush b = new SolidBrush(Theme.Warning))
                        g.FillPath(b, p);
                    TextRenderer.DrawText(g, s, bf, br, Color.FromArgb(30, 20, 0),
                        TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
                    right = br.Left - Theme.S(6);
                }
            }

            using (Font f = active ? new Font("Segoe UI Semibold", Font.SizeInPoints) : (Font)Font.Clone())
                TextRenderer.DrawText(g, Text, f, new Rectangle(Theme.S(48), 0, right - Theme.S(48), Height), fg,
                    TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
        }
    }

    // Istatistik karosu: ikon balonu, baslik, buyuk deger ve alt metin
    public class StatTile : Control
    {
        private string title = "", value = "0", sub = "", glyph = "";
        private Color accent = Theme.Accent;

        public string Title { get { return title; } set { title = value ?? ""; Invalidate(); } }
        public string Value { get { return value; } set { this.value = value ?? ""; Invalidate(); } }
        public string Sub { get { return sub; } set { sub = value ?? ""; Invalidate(); } }
        public string Glyph { get { return glyph; } set { glyph = value ?? ""; Invalidate(); } }
        public Color Accent { get { return accent; } set { accent = value; Invalidate(); } }

        public StatTile()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.Clear(Gfx.OuterColor(this));
            if (Width < 2 || Height < 2) return;
            Gfx.Hq(g);
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (GraphicsPath p = Gfx.Round(r, Theme.S(16)))
            {
                using (LinearGradientBrush b = new LinearGradientBrush(ClientRectangle,
                    Gfx.Mix(Theme.Card, accent, 0.13f), Theme.Card, 35f))
                    g.FillPath(b, p);
                using (Pen pen = new Pen(Gfx.Mix(Theme.Border, accent, 0.18f))) g.DrawPath(pen, p);
            }

            int pad = Theme.S(18);
            int bub = Theme.S(38);
            Rectangle br = new Rectangle(pad, pad, bub, bub);
            using (GraphicsPath p = Gfx.Round(br, Theme.S(11)))
            using (SolidBrush b = new SolidBrush(Gfx.Mix(Theme.Card, accent, 0.26f)))
                g.FillPath(b, p);
            Gfx.Glyph(g, glyph, 13f, Gfx.Mix(accent, Color.White, 0.30f), br);

            using (Font tf = new Font(Theme.FontFamily, 9.5f))
                TextRenderer.DrawText(g, title, tf, new Rectangle(br.Right + Theme.S(12), pad, Width - br.Right - pad - Theme.S(12), bub), Theme.Muted,
                    TextFormatFlags.VerticalCenter | TextFormatFlags.Left | TextFormatFlags.EndEllipsis);

            int vy = br.Bottom + Theme.S(10);
            using (Font vf = new Font("Segoe UI Semibold", 21f))
            {
                Size vs = TextRenderer.MeasureText(g, value, vf, Size.Empty, TextFormatFlags.NoPadding);
                TextRenderer.DrawText(g, value, vf, new Point(pad - Theme.S(2), vy), Theme.Text, TextFormatFlags.NoPadding);
                using (Font sf = new Font(Theme.FontFamily, 8.75f))
                    TextRenderer.DrawText(g, sub, sf, new Rectangle(pad, vy + vs.Height + Theme.S(2), Width - pad * 2, Theme.S(20)), Theme.Muted,
                        TextFormatFlags.Left | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
            }
        }
    }

    // Parcali yasam dongusu cubugu + gosterge (legend)
    public class LifecycleBar : Control
    {
        private int[] values = new int[0];
        private Color[] colors = new Color[0];
        private string[] labels = new string[0];

        public LifecycleBar()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        public void SetData(int[] v, Color[] c, string[] l)
        {
            values = v ?? new int[0];
            colors = c ?? new Color[0];
            labels = l ?? new string[0];
            Invalidate();
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Color outer = Gfx.OuterColor(this);
            g.Clear(outer);
            Gfx.Hq(g);

            float h = Theme.S(14);
            RectangleF track = new RectangleF(0, Theme.S(2), Width - 1, h);
            using (GraphicsPath p = Gfx.Round(track, h / 2))
            using (SolidBrush b = new SolidBrush(Gfx.Mix(outer, Color.White, 0.06f)))
                g.FillPath(b, p);

            int total = 0, nonZero = 0;
            for (int i = 0; i < values.Length; i++) { total += values[i]; if (values[i] > 0) nonZero++; }
            if (total > 0)
            {
                float gap = Theme.S(4);
                float minW = h;
                float avail = track.Width - gap * (nonZero - 1);
                float x = track.X;
                int drawn = 0;
                for (int i = 0; i < values.Length; i++)
                {
                    if (values[i] <= 0) continue;
                    drawn++;
                    float w = drawn == nonZero ? track.Right - x : Math.Max(minW, avail * values[i] / total);
                    using (GraphicsPath p = Gfx.Round(new RectangleF(x, track.Y, w, h), h / 2))
                    using (SolidBrush b = new SolidBrush(colors[i]))
                        g.FillPath(b, p);
                    x += w + gap;
                }
            }

            int lx = 0;
            int ly = (int)track.Bottom + Theme.S(16);
            int dot = Theme.S(10);
            using (Font lf = new Font(Theme.FontFamily, 9.25f))
            using (Font vf = new Font("Segoe UI Semibold", 9.25f))
            {
                for (int i = 0; i < labels.Length && i < colors.Length; i++)
                {
                    int rowH = Theme.S(20);
                    using (SolidBrush b = new SolidBrush(colors[i]))
                        g.FillEllipse(b, lx, ly + (rowH - dot) / 2, dot, dot);
                    lx += dot + Theme.S(8);
                    Size ls = TextRenderer.MeasureText(g, labels[i], lf, Size.Empty, TextFormatFlags.NoPadding);
                    TextRenderer.DrawText(g, labels[i], lf, new Rectangle(lx, ly, ls.Width + 2, rowH), Theme.Muted,
                        TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
                    lx += ls.Width + Theme.S(6);
                    string v = i < values.Length ? values[i].ToString() : "0";
                    Size vs = TextRenderer.MeasureText(g, v, vf, Size.Empty, TextFormatFlags.NoPadding);
                    TextRenderer.DrawText(g, v, vf, new Rectangle(lx, ly, vs.Width + 2, rowH), Theme.Text,
                        TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
                    lx += vs.Width + Theme.S(28);
                }
            }
        }
    }

    public class Toggle : Control
    {
        private bool on;
        public event EventHandler CheckedChanged;

        public bool Checked
        {
            get { return on; }
            set
            {
                if (on == value) return;
                on = value;
                Invalidate();
                if (CheckedChanged != null) CheckedChanged(this, EventArgs.Empty);
            }
        }

        public Toggle()
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint |
                     ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
            Cursor = Cursors.Hand;
            Size = new Size(46, 24);
        }

        protected override void OnClick(EventArgs e) { Checked = !Checked; base.OnClick(e); }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            Color outer = Gfx.OuterColor(this);
            g.Clear(outer);
            Gfx.Hq(g);
            RectangleF r = new RectangleF(0.5f, 0.5f, Width - 1.5f, Height - 1.5f);
            using (GraphicsPath p = Gfx.Round(r, r.Height / 2))
            using (SolidBrush b = new SolidBrush(on ? Theme.Accent : Gfx.Mix(outer, Color.White, 0.16f)))
                g.FillPath(b, p);
            float d = Height - Theme.S(6);
            float x = on ? Width - d - Theme.S(3) : Theme.S(3);
            using (SolidBrush b = new SolidBrush(Color.White))
                g.FillEllipse(b, x, Theme.S(3), d, d);
        }
    }

    // Koyu temali tablo. "chk" adli sutun yuvarlak onay kutusu, "ext" adli sutun uzanti rozeti olarak cizilir.
    // Satira tiklamak onay kutusunu degistirir; "chk" basligina tiklamak tumunu secer/birakir.
    public class DarkGrid : DataGridView
    {
        private int hoverRow = -1;
        private static readonly Color[] BadgePalette = new Color[] {
            Color.FromArgb(124, 92, 255), Color.FromArgb(56, 189, 248), Color.FromArgb(34, 197, 94),
            Color.FromArgb(245, 158, 11), Color.FromArgb(244, 63, 94), Color.FromArgb(236, 72, 153),
            Color.FromArgb(20, 184, 166), Color.FromArgb(168, 85, 247)
        };

        public DarkGrid()
        {
            DoubleBuffered = true;
            BackgroundColor = Theme.Card;
            BorderStyle = BorderStyle.None;
            GridColor = Theme.Border;
            CellBorderStyle = DataGridViewCellBorderStyle.None;
            ColumnHeadersBorderStyle = DataGridViewHeaderBorderStyle.None;
            EnableHeadersVisualStyles = false;
            ColumnHeadersHeightSizeMode = DataGridViewColumnHeadersHeightSizeMode.DisableResizing;
            ColumnHeadersHeight = Theme.S(40);
            RowHeadersVisible = false;
            AllowUserToAddRows = false;
            AllowUserToDeleteRows = false;
            AllowUserToResizeRows = false;
            AllowUserToOrderColumns = false;
            ReadOnly = true;
            SelectionMode = DataGridViewSelectionMode.FullRowSelect;
            MultiSelect = true;
            RowTemplate.Height = Theme.S(44);
            StandardTab = true;

            DataGridViewCellStyle h = ColumnHeadersDefaultCellStyle;
            h.BackColor = Theme.Card; h.ForeColor = Theme.Muted;
            h.SelectionBackColor = Theme.Card; h.SelectionForeColor = Theme.Muted;
            h.Font = new Font("Segoe UI Semibold", 8.75f);
            h.Padding = new Padding(Theme.S(8), 0, Theme.S(8), 0);

            DataGridViewCellStyle d = DefaultCellStyle;
            d.BackColor = Theme.Card; d.ForeColor = Theme.Text;
            d.SelectionBackColor = Gfx.Mix(Theme.Card, Theme.Accent, 0.20f); d.SelectionForeColor = Theme.Text;
            d.Font = new Font(Theme.FontFamily, 9.75f);
            d.Padding = new Padding(Theme.S(8), 0, Theme.S(8), 0);
            d.WrapMode = DataGridViewTriState.False;

            foreach (Control c in Controls) Native.DarkTheme(c);
        }

        public DataGridViewColumn AddText(string name, string header, int width, bool fill)
        {
            DataGridViewTextBoxColumn c = new DataGridViewTextBoxColumn();
            c.Name = name; c.HeaderText = header; c.SortMode = DataGridViewColumnSortMode.NotSortable;
            if (fill) { c.AutoSizeMode = DataGridViewAutoSizeColumnMode.Fill; c.MinimumWidth = Theme.S(140); }
            else c.Width = Theme.S(width);
            Columns.Add(c);
            return c;
        }

        public DataGridViewColumn AddCheck()
        {
            DataGridViewCheckBoxColumn c = new DataGridViewCheckBoxColumn();
            c.Name = "chk"; c.HeaderText = ""; c.Width = Theme.S(48);
            c.SortMode = DataGridViewColumnSortMode.NotSortable;
            Columns.Add(c);
            return c;
        }

        public bool IsChecked(int row)
        {
            object v = Rows[row].Cells["chk"].Value;
            return v is bool && (bool)v;
        }

        public bool AllChecked()
        {
            if (!Columns.Contains("chk") || Rows.Count == 0) return false;
            for (int i = 0; i < Rows.Count; i++) if (!IsChecked(i)) return false;
            return true;
        }

        public void SetAll(bool value)
        {
            if (!Columns.Contains("chk")) return;
            for (int i = 0; i < Rows.Count; i++) Rows[i].Cells["chk"].Value = value;
        }

        protected override void OnCellMouseClick(DataGridViewCellMouseEventArgs e)
        {
            base.OnCellMouseClick(e);
            if (e.Button != MouseButtons.Left || !Columns.Contains("chk")) return;
            if (e.RowIndex >= 0) Rows[e.RowIndex].Cells["chk"].Value = !IsChecked(e.RowIndex);
            else if (e.ColumnIndex >= 0 && Columns[e.ColumnIndex].Name == "chk") SetAll(!AllChecked());
        }

        protected override void OnCellValueChanged(DataGridViewCellEventArgs e)
        {
            base.OnCellValueChanged(e);
            if (Columns.Contains("chk")) InvalidateCell(Columns["chk"].Index, -1);
        }

        protected override void OnCellMouseEnter(DataGridViewCellEventArgs e)
        {
            base.OnCellMouseEnter(e);
            if (e.RowIndex != hoverRow)
            {
                int old = hoverRow; hoverRow = e.RowIndex;
                if (old >= 0 && old < Rows.Count) InvalidateRow(old);
                if (hoverRow >= 0) InvalidateRow(hoverRow);
            }
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            base.OnMouseLeave(e);
            int old = hoverRow; hoverRow = -1;
            if (old >= 0 && old < Rows.Count) InvalidateRow(old);
        }

        private void DrawCheck(Graphics g, Rectangle cell, bool on)
        {
            int s = Theme.S(18);
            Rectangle r = new Rectangle(cell.X + (cell.Width - s) / 2, cell.Y + (cell.Height - s) / 2, s, s);
            using (GraphicsPath p = Gfx.Round(r, Theme.S(5)))
            {
                if (on)
                {
                    using (SolidBrush b = new SolidBrush(Theme.Accent)) g.FillPath(b, p);
                    Gfx.Glyph(g, "", 8.5f, Color.White, r);
                }
                else
                {
                    using (Pen pen = new Pen(Gfx.Mix(Theme.Card, Color.White, 0.28f), 1.4f)) g.DrawPath(pen, p);
                }
            }
        }

        protected override void OnCellPainting(DataGridViewCellPaintingEventArgs e)
        {
            base.OnCellPainting(e);
            if (e.Handled || e.ColumnIndex < 0) return;
            Graphics g = e.Graphics;
            string col = Columns[e.ColumnIndex].Name;
            Gfx.Hq(g);

            if (e.RowIndex < 0)
            {
                using (SolidBrush b = new SolidBrush(Theme.Card)) g.FillRectangle(b, e.CellBounds);
                using (Pen pen = new Pen(Theme.Border))
                    g.DrawLine(pen, e.CellBounds.Left, e.CellBounds.Bottom - 1, e.CellBounds.Right, e.CellBounds.Bottom - 1);
                if (col == "chk") DrawCheck(g, e.CellBounds, AllChecked());
                else e.Paint(e.CellBounds, DataGridViewPaintParts.ContentForeground);
                e.Handled = true;
                return;
            }

            bool selected = (e.State & DataGridViewElementStates.Selected) != 0;
            Color bg = selected ? Gfx.Mix(Theme.Card, Theme.Accent, 0.20f)
                     : (e.RowIndex == hoverRow ? Gfx.Mix(Theme.Card, Color.White, 0.04f) : Theme.Card);
            using (SolidBrush b = new SolidBrush(bg)) g.FillRectangle(b, e.CellBounds);
            using (Pen pen = new Pen(Gfx.Mix(Theme.Card, Theme.Border, 0.7f)))
                g.DrawLine(pen, e.CellBounds.Left, e.CellBounds.Bottom - 1, e.CellBounds.Right, e.CellBounds.Bottom - 1);

            if (col == "chk")
            {
                DrawCheck(g, e.CellBounds, e.Value is bool && (bool)e.Value);
            }
            else if (col == "ext")
            {
                string ext = Convert.ToString(e.Value);
                if (ext.StartsWith(".")) ext = ext.Substring(1);
                ext = ext.Length == 0 ? "—" : ext.ToUpperInvariant();
                if (ext.Length > 4) ext = ext.Substring(0, 4);
                int hash = 0;
                foreach (char ch in ext) hash = (hash * 31 + ch) & 0x7fffffff;
                Color c = BadgePalette[hash % BadgePalette.Length];
                using (Font f = new Font("Segoe UI Semibold", 7.5f))
                {
                    int bw = Theme.S(44), bh = Theme.S(22);
                    Rectangle r = new Rectangle(e.CellBounds.X + Theme.S(4), e.CellBounds.Y + (e.CellBounds.Height - bh) / 2, bw, bh);
                    using (GraphicsPath p = Gfx.Round(r, Theme.S(6)))
                    using (SolidBrush b = new SolidBrush(Gfx.Mix(bg, c, 0.22f)))
                        g.FillPath(b, p);
                    TextRenderer.DrawText(g, ext, f, r, Gfx.Mix(c, Color.White, 0.35f),
                        TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
                }
            }
            else
            {
                e.Paint(e.CellBounds, DataGridViewPaintParts.ContentForeground);
            }
            e.Handled = true;
        }
    }

    // Silme onayi + animasyonlu ilerleme + sonuc ozeti.
    // Akis: Prepare() -> ShowDialog() -> kullanici "Sil" der -> Confirmed olayi -> her dosya icin Advance() -> Finish()
    public class DeleteDialog : Form
    {
        private enum Phase { Confirm, Working, Done }
        private Phase phase = Phase.Confirm;
        private string[] names = new string[0];
        private string sizeText = "";
        private bool recycle;
        private int total, done, failCount;
        private string current = "";
        private readonly System.Collections.Generic.List<string> recent = new System.Collections.Generic.List<string>();
        private readonly System.Collections.Generic.List<bool> recentOk = new System.Collections.Generic.List<bool>();
        private float shown, spin;
        private DateTime doneAt;
        private string doneTitle = "", doneSub = "", doneNote = "";
        private string[] failures = new string[0];
        private readonly Timer timer = new Timer();
        private readonly ModernButton btnCancel = new ModernButton();
        private readonly ModernButton btnConfirm = new ModernButton();
        private readonly ModernButton btnOk = new ModernButton();

        public event EventHandler Confirmed;

        public DeleteDialog()
        {
            FormBorderStyle = FormBorderStyle.None;
            StartPosition = FormStartPosition.CenterParent;
            ShowInTaskbar = false;
            KeyPreview = true;
            BackColor = Theme.Card;
            Font = new Font(Theme.FontFamily, 9.75f);
            ClientSize = new Size(Theme.S(480), Theme.S(440));
            SetStyle(ControlStyles.OptimizedDoubleBuffer | ControlStyles.AllPaintingInWmPaint | ControlStyles.UserPaint, true);

            int bw = Theme.S(150), bh = Theme.S(44), by = ClientSize.Height - Theme.S(30) - bh;
            btnCancel.Text = "Vazgeç"; btnCancel.Kind = ButtonKind.Ghost;
            btnCancel.SetBounds(ClientSize.Width / 2 - bw - Theme.S(6), by, bw, bh);
            btnCancel.Click += delegate { DialogResult = DialogResult.Cancel; Close(); };
            btnConfirm.Text = "Sil"; btnConfirm.Glyph = ""; btnConfirm.Accent = Theme.Danger;
            btnConfirm.SetBounds(ClientSize.Width / 2 + Theme.S(6), by, bw, bh);
            btnConfirm.Click += delegate { StartWork(); };
            btnOk.Text = "Tamam"; btnOk.Glyph = ""; btnOk.Accent = Theme.Accent; btnOk.Visible = false;
            btnOk.SetBounds((ClientSize.Width - Theme.S(200)) / 2, by, Theme.S(200), bh);
            btnOk.Click += delegate { DialogResult = DialogResult.OK; Close(); };
            Controls.Add(btnCancel); Controls.Add(btnConfirm); Controls.Add(btnOk);

            timer.Interval = 15;
            timer.Tick += delegate { Animate(); };
        }

        protected override CreateParams CreateParams
        {
            get { CreateParams cp = base.CreateParams; cp.ClassStyle |= 0x20000; return cp; }
        }

        protected override void OnHandleCreated(EventArgs e)
        {
            base.OnHandleCreated(e);
            Native.StyleWindow(Handle, Theme.Card);
        }

        public void Prepare(string[] fileNames, string size, bool toRecycle)
        {
            names = fileNames ?? new string[0];
            total = names.Length;
            sizeText = size ?? "";
            recycle = toRecycle;
            Invalidate();
        }

        public void Advance(string name, bool ok)
        {
            done++;
            if (!ok) failCount++;
            current = name;
            recent.Insert(0, name); recentOk.Insert(0, ok);
            if (recent.Count > 4) { recent.RemoveAt(4); recentOk.RemoveAt(4); }
        }

        public void Finish(string title, string sub, string note, string[] failed)
        {
            doneTitle = title ?? ""; doneSub = sub ?? ""; doneNote = note ?? "";
            failures = failed ?? new string[0];
            phase = Phase.Done;
            doneAt = DateTime.Now;
            btnOk.Accent = failures.Length > 0 ? Theme.Warning : Theme.Success;
            btnOk.Visible = true;
            btnOk.Focus();
            timer.Start();
        }

        private void StartWork()
        {
            phase = Phase.Working;
            btnCancel.Visible = false;
            btnConfirm.Visible = false;
            timer.Start();
            Refresh();
            if (Confirmed != null) Confirmed(this, EventArgs.Empty);
        }

        private void Animate()
        {
            float target = total == 0 ? 1f : (float)done / total;
            shown += (target - shown) * 0.16f;
            if (Math.Abs(target - shown) < 0.002f) shown = target;
            spin = (spin + 7f) % 360f;
            if (phase == Phase.Done && (DateTime.Now - doneAt).TotalMilliseconds > 1600) timer.Stop();
            Invalidate();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (phase == Phase.Working) e.Cancel = true;
            else timer.Stop();
            base.OnFormClosing(e);
        }

        protected override void OnKeyDown(KeyEventArgs e)
        {
            if (e.KeyCode == Keys.Escape && phase == Phase.Confirm) { DialogResult = DialogResult.Cancel; Close(); }
            if (e.KeyCode == Keys.Enter && phase == Phase.Done) { DialogResult = DialogResult.OK; Close(); }
            base.OnKeyDown(e);
        }

        private void Center(Graphics g, string text, Font f, Color c, int y, int h)
        {
            TextRenderer.DrawText(g, text, f, new Rectangle(Theme.S(28), y, ClientSize.Width - Theme.S(56), h), c,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            int W = ClientSize.Width, H = ClientSize.Height;
            g.Clear(Theme.Card);
            Gfx.Hq(g);

            Color tint = phase == Phase.Confirm ? Theme.Danger
                       : phase == Phase.Working ? Theme.Accent
                       : (failures.Length > 0 ? Theme.Warning : Theme.Success);
            Rectangle glow = new Rectangle(0, 0, W, Theme.S(190));
            using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(0, -1, W, glow.Height + 2), Gfx.Mix(Theme.Card, tint, 0.16f), Theme.Card, 90f))
                g.FillRectangle(b, glow);
            using (Pen pen = new Pen(Theme.Border)) g.DrawRectangle(pen, 0, 0, W - 1, H - 1);

            using (Font title = new Font("Segoe UI Semibold", 14.5f))
            using (Font body = new Font(Theme.FontFamily, 9.75f))
            using (Font small = new Font(Theme.FontFamily, 9f))
            {
                if (phase == Phase.Confirm) PaintConfirm(g, W, title, body, small);
                else PaintProgress(g, W, title, body, small);
            }
        }

        private void PaintConfirm(Graphics g, int W, Font title, Font body, Font small)
        {
            int cx = W / 2, cy = Theme.S(72), r = Theme.S(34);
            using (SolidBrush b = new SolidBrush(Gfx.Mix(Theme.Card, Theme.Danger, 0.22f))) g.FillEllipse(b, cx - r, cy - r, r * 2, r * 2);
            Gfx.Glyph(g, "", 19f, Gfx.Mix(Theme.Danger, Color.White, 0.25f), new Rectangle(cx - r, cy - r, r * 2, r * 2));

            Center(g, total + " dosya silinsin mi?", title, Theme.Text, Theme.S(118), Theme.S(34));
            string where = recycle ? "Geri Dönüşüm Kutusu'na taşınacak" : "kalıcı olarak silinecek";
            Center(g, "Toplam " + sizeText + " · " + where, body, Theme.Muted, Theme.S(152), Theme.S(24));

            Rectangle box = new Rectangle(Theme.S(32), Theme.S(192), W - Theme.S(64), Theme.S(152));
            using (GraphicsPath p = Gfx.Round(box, Theme.S(12)))
            using (SolidBrush b = new SolidBrush(Gfx.Mix(Theme.Card, Theme.Bg, 0.55f)))
                g.FillPath(b, p);
            int rowH = Theme.S(26), y = box.Y + Theme.S(10);
            int show = Math.Min(names.Length, names.Length > 5 ? 4 : 5);
            for (int i = 0; i < show; i++)
            {
                using (SolidBrush b = new SolidBrush(Gfx.Mix(Theme.Danger, Theme.Card, 0.25f)))
                    g.FillEllipse(b, box.X + Theme.S(16), y + rowH / 2 - Theme.S(3), Theme.S(6), Theme.S(6));
                TextRenderer.DrawText(g, names[i], body, new Rectangle(box.X + Theme.S(32), y, box.Width - Theme.S(48), rowH), Theme.Text,
                    TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
                y += rowH;
            }
            if (names.Length > show)
                TextRenderer.DrawText(g, "+" + (names.Length - show) + " dosya daha", small, new Rectangle(box.X + Theme.S(32), y, box.Width - Theme.S(48), rowH), Theme.Muted,
                    TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        }

        private void PaintProgress(Graphics g, int W, Font title, Font body, Font small)
        {
            int cx = W / 2, cy = Theme.S(118);
            float R = Theme.S(62), th = Theme.S(10);
            RectangleF ring = new RectangleF(cx - R, cy - R, R * 2, R * 2);
            double ms = phase == Phase.Done ? (DateTime.Now - doneAt).TotalMilliseconds : 0;
            Color doneColor = failures.Length > 0 ? Theme.Warning : Theme.Success;

            using (Pen track = new Pen(Gfx.Mix(Theme.Card, Color.White, 0.07f), th)) g.DrawEllipse(track, ring);

            if (phase == Phase.Working)
            {
                using (Pen shimmer = new Pen(Gfx.Mix(Theme.Card, Color.White, 0.14f), th))
                {
                    shimmer.StartCap = LineCap.Round; shimmer.EndCap = LineCap.Round;
                    g.DrawArc(shimmer, ring, spin, 38f);
                }
            }

            float sweep = shown * 360f;
            if (sweep > 0.5f)
            {
                Brush brush;
                if (phase == Phase.Done)
                {
                    float t = (float)Math.Min(1, ms / 350);
                    brush = new SolidBrush(Gfx.Mix(Theme.Accent, doneColor, t));
                }
                else brush = new LinearGradientBrush(RectangleF.Inflate(ring, th, th), Theme.Accent, Theme.Accent2, 45f);
                using (brush)
                using (Pen pen = new Pen(brush, th))
                {
                    pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round;
                    g.DrawArc(pen, ring, -90f, Math.Min(359.9f, sweep));
                }
                if (phase == Phase.Working)
                {
                    double a = (-90 + sweep) * Math.PI / 180;
                    float dx = cx + (float)(R * Math.Cos(a)), dy = cy + (float)(R * Math.Sin(a));
                    using (SolidBrush b = new SolidBrush(Color.White)) g.FillEllipse(b, dx - th * 0.32f, dy - th * 0.32f, th * 0.64f, th * 0.64f);
                }
            }

            if (phase == Phase.Working)
            {
                using (Font big = new Font("Segoe UI Semibold", 20f))
                    TextRenderer.DrawText(g, done + " / " + total, big, new Rectangle(cx - (int)R, cy - Theme.S(22), (int)R * 2, Theme.S(34)), Theme.Text,
                        TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
                TextRenderer.DrawText(g, "dosya", small, new Rectangle(cx - (int)R, cy + Theme.S(12), (int)R * 2, Theme.S(20)), Theme.Muted,
                    TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);

                Center(g, "Dosyalar siliniyor…", title, Theme.Text, Theme.S(200), Theme.S(32));
                Center(g, current, body, Theme.Muted, Theme.S(232), Theme.S(22));
                int y = Theme.S(268);
                for (int i = 0; i < recent.Count; i++)
                {
                    Color fg = Gfx.Mix(Theme.Text, Theme.Card, i * 0.24f);
                    Color gc = Gfx.Mix(recentOk[i] ? Theme.Success : Theme.Danger, Theme.Card, i * 0.24f);
                    int left = Theme.S(70);
                    Gfx.Glyph(g, recentOk[i] ? "" : "", 9f, gc, new Rectangle(left, y, Theme.S(20), Theme.S(24)));
                    TextRenderer.DrawText(g, recent[i], body, new Rectangle(left + Theme.S(28), y, W - left * 2 - Theme.S(28), Theme.S(24)), fg,
                        TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
                    y += Theme.S(25);
                }
                return;
            }

            // Tamamlandi: genisleyen halka + cizilen onay isareti
            float pulse = (float)Math.Min(1, ms / 700);
            if (pulse < 1)
            {
                float pr = R + th / 2 + pulse * Theme.S(28);
                using (Pen pen = new Pen(Color.FromArgb((int)(140 * (1 - pulse)), doneColor), Theme.S(3)))
                    g.DrawEllipse(pen, cx - pr, cy - pr, pr * 2, pr * 2);
            }
            float inner = R - th;
            using (SolidBrush b = new SolidBrush(Gfx.Mix(Theme.Card, doneColor, 0.16f * (float)Math.Min(1, ms / 300))))
                g.FillEllipse(b, cx - inner, cy - inner, inner * 2, inner * 2);

            float progress = (float)Math.Max(0, Math.Min(1, (ms - 150) / 450));
            using (Pen pen = new Pen(doneColor, Theme.S(7)))
            {
                pen.StartCap = LineCap.Round; pen.EndCap = LineCap.Round; pen.LineJoin = LineJoin.Round;
                float k = R * 0.55f;
                if (failures.Length == 0)
                {
                    PointF p0 = new PointF(cx - 0.45f * k, cy + 0.02f * k);
                    PointF p1 = new PointF(cx - 0.12f * k, cy + 0.36f * k);
                    PointF p2 = new PointF(cx + 0.52f * k, cy - 0.34f * k);
                    float l1 = Dist(p0, p1), l2 = Dist(p1, p2), d = progress * (l1 + l2);
                    if (d > 0) g.DrawLine(pen, p0, Lerp(p0, p1, Math.Min(1, d / l1)));
                    if (d > l1) g.DrawLine(pen, p1, Lerp(p1, p2, (d - l1) / l2));
                }
                else if (progress > 0)
                {
                    g.DrawLine(pen, cx, cy - 0.5f * k, cx, cy - 0.5f * k + progress * 0.62f * k);
                    if (progress >= 1) using (SolidBrush b = new SolidBrush(doneColor)) g.FillEllipse(b, cx - Theme.S(4.5f), cy + 0.38f * k, Theme.S(9), Theme.S(9));
                }
            }

            Center(g, doneTitle, title, Theme.Text, Theme.S(200), Theme.S(32));
            Center(g, doneSub, body, Gfx.Mix(doneColor, Color.White, 0.35f), Theme.S(232), Theme.S(22));
            int ny = Theme.S(268);
            Gfx.Glyph(g, "", 10f, Theme.Muted, new Rectangle(Theme.S(40), ny, Theme.S(22), Theme.S(40)));
            TextRenderer.DrawText(g, doneNote, small, new Rectangle(Theme.S(68), ny, W - Theme.S(108), Theme.S(40)), Theme.Muted,
                TextFormatFlags.VerticalCenter | TextFormatFlags.WordBreak | TextFormatFlags.NoPadding);
            int fy = ny + Theme.S(42);
            for (int i = 0; i < failures.Length && i < 2; i++)
            {
                TextRenderer.DrawText(g, "• " + failures[i], small, new Rectangle(Theme.S(48), fy, W - Theme.S(96), Theme.S(20)), Theme.Warning,
                    TextFormatFlags.VerticalCenter | TextFormatFlags.EndEllipsis | TextFormatFlags.NoPadding);
                fy += Theme.S(20);
            }
        }

        private static float Dist(PointF a, PointF b) { return (float)Math.Sqrt((a.X - b.X) * (a.X - b.X) + (a.Y - b.Y) * (a.Y - b.Y)); }
        private static PointF Lerp(PointF a, PointF b, float t) { return new PointF(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t); }
    }
}
