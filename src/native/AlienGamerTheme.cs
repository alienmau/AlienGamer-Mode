using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace AlienGamer.Desktop {
    public static class Theme {
        public static readonly Color Window = Color.FromArgb(24,24,24);
        public static readonly Color Surface = Color.FromArgb(32,32,32);
        public static readonly Color Raised = Color.FromArgb(43,43,43);
        public static readonly Color Sunken = Color.FromArgb(16,16,16);
        public static readonly Color Text = Color.FromArgb(238,238,238);
        public static readonly Color Secondary = Color.FromArgb(184,184,184);
        public static readonly Color Border = Color.FromArgb(76,76,76);
        public static readonly Color Accent = Color.FromArgb(255,153,64);
        public static readonly Color Danger = Color.FromArgb(255,145,145);
        public static readonly Color PreviewCard = Color.FromArgb(26,35,41);
        [DllImport("dwmapi.dll")] static extern int DwmSetWindowAttribute(IntPtr hwnd,int attr,ref int value,int size);
        public static void Apply(Control root) {
            if(SystemInformation.HighContrast) return;
            root.BackColor = root is Form ? Window : Surface;
            root.ForeColor = Text;
            Form form = root as Form;
            if(form != null) {
                form.Font = new Font("Segoe UI",10f);
                form.HandleCreated += delegate { DarkTitle(form); };
                if(form.IsHandleCreated) DarkTitle(form);
            }
            foreach(Control child in root.Controls) Apply(child);
            Button button = root as Button;
            if(button != null) {
                button.FlatStyle = FlatStyle.Flat;
                button.FlatAppearance.BorderColor = Border;
                button.FlatAppearance.MouseOverBackColor = Color.FromArgb(60,60,60);
                button.FlatAppearance.MouseDownBackColor = Color.FromArgb(70,70,70);
                button.BackColor = Raised;
                button.UseVisualStyleBackColor = false;
            }
            if(root is TextBoxBase || root is ListBox || root is NumericUpDown || root is ComboBox) root.BackColor=Raised;
            if(root is Label) root.BackColor=Color.Transparent;
            LinkLabel link=root as LinkLabel;
            if(link != null) { link.LinkColor=Accent; link.ActiveLinkColor=Text; link.VisitedLinkColor=Accent; }
            ComboBox combo=root as ComboBox;
            if(combo != null && combo.DrawMode != DrawMode.OwnerDrawFixed) {
                combo.FlatStyle=FlatStyle.Flat; combo.DrawMode=DrawMode.OwnerDrawFixed;
                combo.ItemHeight=24;
                combo.DrawItem += delegate(object sender,DrawItemEventArgs e) {
                    bool selected=(e.State & DrawItemState.Selected)!=0;
                    using(var brush=new SolidBrush(selected ? Color.FromArgb(75,51,30) : Raised)) e.Graphics.FillRectangle(brush,e.Bounds);
                    string value=e.Index<0 ? combo.Text : combo.GetItemText(combo.Items[e.Index]);
                    TextRenderer.DrawText(e.Graphics,value,e.Font,e.Bounds,combo.Enabled ? Text : Secondary,TextFormatFlags.Left|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
                    e.DrawFocusRectangle();
                };
            }
        }
        static void DarkTitle(Form form) { try { int enabled=1; DwmSetWindowAttribute(form.Handle,20,ref enabled,4); } catch(DllNotFoundException) {} catch(EntryPointNotFoundException) {} }
        public static void Primary(Button button) {
            if(SystemInformation.HighContrast) return;
            button.BackColor=Accent; button.ForeColor=Window;
            button.FlatAppearance.BorderColor=Accent;
            button.FlatAppearance.MouseOverBackColor=Color.FromArgb(255,177,108);
            button.FlatAppearance.MouseDownBackColor=Color.FromArgb(235,130,40);
            button.EnabledChanged += delegate {
                if(SystemInformation.HighContrast) return;
                button.BackColor=button.Enabled ? Accent : Raised;
                button.ForeColor=button.Enabled ? Window : Secondary;
                button.FlatAppearance.BorderColor=button.Enabled ? Accent : Border;
            };
        }
        public static void Menu(ContextMenuStrip menu) {
            if(SystemInformation.HighContrast) return;
            menu.Renderer=new DarkMenuRenderer(); menu.BackColor=Surface; menu.ForeColor=Text;
            menu.Font=new Font("Segoe UI",10f); menu.ShowImageMargin=false;
            StyleItems(menu.Items);
        }
        static void StyleItems(ToolStripItemCollection items) {
            foreach(ToolStripItem item in items) {
                item.ForeColor=Text; item.Padding=new Padding(8,6,8,6);
                var dropdown=item as ToolStripDropDownItem;
                if(dropdown!=null) { dropdown.DropDown.Renderer=new DarkMenuRenderer(); dropdown.DropDown.BackColor=Surface; dropdown.DropDown.ForeColor=Text; StyleItems(dropdown.DropDownItems); }
            }
        }
        public static Color? ChooseColor(IWin32Window owner,Color initial,bool english) {
            using(var dialog=new Form()) {
                dialog.Text=english ? "Firefly color" : "Color de las luciérnagas";
                dialog.Font=new Font("Segoe UI",10f);
                dialog.ClientSize=new Size(390,266); dialog.FormBorderStyle=FormBorderStyle.FixedDialog;
                dialog.StartPosition=FormStartPosition.CenterParent;dialog.MaximizeBox=false;dialog.MinimizeBox=false;
                var preview=new Panel { Left=24,Top=24,Width=342,Height=52 };
                dialog.Controls.Add(preview);
                var values=new NumericUpDown[3];
                int[] channels={initial.R,initial.G,initial.B};
                string[] names=english ? new[]{"Red","Green","Blue"} : new[]{"Rojo","Verde","Azul"};
                for(int i=0;i<3;i++) {
                    var label=new Label { Left=24+i*118,Top=96,Width=104,Height=24,Text=names[i] };
                    values[i]=new NumericUpDown { Left=24+i*118,Top=124,Width=104,Minimum=0,Maximum=255,Value=channels[i] };
                    values[i].ValueChanged += delegate { preview.BackColor=Color.FromArgb((int)values[0].Value,(int)values[1].Value,(int)values[2].Value); };
                    dialog.Controls.Add(label);dialog.Controls.Add(values[i]);
                }
                var hint=new Label { Left=24,Top=165,Width=342,Height=28,Text=english ? "RGB · values from 0 to 255" : "RGB · valores de 0 a 255" };
                dialog.Controls.Add(hint);
                var ok=new RoundedButton { Left=254,Top=214,Width=112,Height=36,Text=english ? "Apply" : "Aplicar",DialogResult=DialogResult.OK };
                var cancel=new RoundedButton { Left=134,Top=214,Width=112,Height=36,Text=english ? "Cancel" : "Cancelar",DialogResult=DialogResult.Cancel };
                dialog.Controls.Add(ok);dialog.Controls.Add(cancel);dialog.AcceptButton=ok;dialog.CancelButton=cancel;
                Apply(dialog);Primary(ok);preview.BackColor=initial;
                return dialog.ShowDialog(owner)==DialogResult.OK ? (Color?)preview.BackColor : null;
            }
        }
        public static DialogResult Message(IWin32Window owner,string text,string title,MessageBoxButtons buttons,MessageBoxIcon icon,bool english) {
            if(SystemInformation.HighContrast) return MessageBox.Show(owner,text,title,buttons,icon);
            using(var dialog=new Form()) {
                dialog.Font=new Font("Segoe UI",10f);
                dialog.Text=title; dialog.StartPosition=owner==null ? FormStartPosition.CenterScreen : FormStartPosition.CenterParent;
                dialog.ClientSize=new Size(540,300); dialog.MinimumSize=new Size(460,260);
                dialog.ShowInTaskbar=false; dialog.MinimizeBox=false; dialog.MaximizeBox=false;
                var body=new TextBox { Multiline=true,ReadOnly=true,BorderStyle=BorderStyle.None,ScrollBars=ScrollBars.Vertical,Dock=DockStyle.Fill,Text=text };
                var content=new Panel { Dock=DockStyle.Fill,Padding=new Padding(24) }; content.Controls.Add(body);
                var footer=new FlowLayoutPanel { Dock=DockStyle.Bottom,Height=64,Padding=new Padding(16,12,16,12),FlowDirection=FlowDirection.RightToLeft };
                dialog.Controls.Add(content); dialog.Controls.Add(footer);
                DialogResult[] results;
                switch(buttons) {
                    case MessageBoxButtons.YesNo: results=new[]{DialogResult.No,DialogResult.Yes}; break;
                    case MessageBoxButtons.YesNoCancel: results=new[]{DialogResult.Cancel,DialogResult.No,DialogResult.Yes}; break;
                    case MessageBoxButtons.OKCancel: results=new[]{DialogResult.Cancel,DialogResult.OK}; break;
                    case MessageBoxButtons.RetryCancel: results=new[]{DialogResult.Cancel,DialogResult.Retry}; break;
                    case MessageBoxButtons.AbortRetryIgnore: results=new[]{DialogResult.Ignore,DialogResult.Retry,DialogResult.Abort}; break;
                    default: results=new[]{DialogResult.OK}; break;
                }
                Button primary=null;
                foreach(var result in results) {
                    string label=result.ToString();
                    if(!english) { if(result==DialogResult.OK) label="Aceptar"; else if(result==DialogResult.Yes) label="Sí"; else if(result==DialogResult.Cancel) label="Cancelar"; else if(result==DialogResult.Retry) label="Reintentar"; else if(result==DialogResult.Abort) label="Abortar"; else if(result==DialogResult.Ignore) label="Omitir"; }
                    var button=new RoundedButton { Text=label,Width=110,Height=36,DialogResult=result };
                    footer.Controls.Add(button); primary=button;
                    if(result==DialogResult.Cancel || result==DialogResult.No || results.Length==1) dialog.CancelButton=button;
                }
                Apply(dialog); Primary(primary); dialog.AcceptButton=primary;
                body.BackColor=Window;
                if(icon==MessageBoxIcon.Error) body.ForeColor=Danger;
                return owner==null ? dialog.ShowDialog() : dialog.ShowDialog(owner);
            }
        }
    }
    public static class Shapes {
        public static GraphicsPath Round(RectangleF rect,float radius) {
            var path=new GraphicsPath();float diameter=Math.Min(radius*2,Math.Min(rect.Width,rect.Height));
            if(diameter<2) { path.AddRectangle(rect);return path; }
            path.AddArc(rect.X,rect.Y,diameter,diameter,180,90);
            path.AddArc(rect.Right-diameter,rect.Y,diameter,diameter,270,90);
            path.AddArc(rect.Right-diameter,rect.Bottom-diameter,diameter,diameter,0,90);
            path.AddArc(rect.X,rect.Bottom-diameter,diameter,diameter,90,90);path.CloseFigure();return path;
        }
    }
    public class RoundedButton : Button {
        protected bool Hovered,Pressed;
        public int Radius { get; set; }
        public bool Chosen { get; set; }
        public bool NavigationStyle { get; set; }
        public RoundedButton() { Radius=10;FlatStyle=FlatStyle.Flat;SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true); }
        protected override void OnMouseEnter(EventArgs e) { Hovered=true;Invalidate();base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { Hovered=false;Pressed=false;Invalidate();base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { Pressed=true;Invalidate();base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { Pressed=false;Invalidate();base.OnMouseUp(e); }
        protected override void OnEnter(EventArgs e) { base.OnEnter(e);Invalidate(); }
        protected override void OnLeave(EventArgs e) { base.OnLeave(e);Invalidate(); }
        protected virtual void DrawContent(Graphics graphics) {
            if(NavigationStyle) {
                using(var labelFont=new Font(Font,Chosen ? FontStyle.Bold : FontStyle.Regular))
                    TextRenderer.DrawText(graphics,Text,labelFont,new Rectangle(18,4,Math.Max(0,Width-36),Math.Max(0,Height-8)),Enabled ? ForeColor : Theme.Secondary,TextFormatFlags.Left|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
                return;
            }
            TextRenderer.DrawText(graphics,Text,Font,Rectangle.Inflate(ClientRectangle,-10,-4),Enabled ? ForeColor : Theme.Secondary,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
        }
        protected override void OnPaint(PaintEventArgs e) {
            if(SystemInformation.HighContrast) { base.OnPaint(e);return; }
            e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;e.Graphics.Clear(Parent==null ? Theme.Window : Parent.BackColor);
            Color fill=Chosen ? Color.FromArgb(48,48,48) : BackColor;
            if(Enabled && Pressed) fill=FlatAppearance.MouseDownBackColor;
            else if(Enabled && Hovered) fill=FlatAppearance.MouseOverBackColor;
            using(var path=Shapes.Round(new RectangleF(.5f,.5f,Math.Max(1,Width-1),Math.Max(1,Height-1)),Radius))
            using(var brush=new SolidBrush(fill))
            using(var pen=new Pen(Focused ? Theme.Accent : (NavigationStyle ? (Chosen ? Theme.Border : fill) : FlatAppearance.BorderColor),Focused ? 2f : 1f)) { e.Graphics.FillPath(brush,path);e.Graphics.DrawPath(pen,path); }
            DrawContent(e.Graphics);
            if(Focused) ControlPaint.DrawFocusRectangle(e.Graphics,Rectangle.Inflate(ClientRectangle,-5,-5),ForeColor,fill);
        }
    }
    public class DisplayCard : RoundedButton {
        public string Detail { get; set; }
        public string Caption { get; set; }
        public string Kind { get; set; }
        public DisplayCard() { Height=88;Radius=10;Kind="display";Detail="";Caption="";TextAlign=ContentAlignment.MiddleLeft; }
        protected override void DrawContent(Graphics graphics) {
            var color=Enabled ? Theme.Text : Theme.Secondary;
            using(var pen=new Pen(color,1.3f)) {
                if(Kind=="mobile") { graphics.DrawRectangle(pen,18,19,10,17);graphics.DrawLine(pen,21,33,25,33); }
                else { graphics.DrawRectangle(pen,14,18,20,13);graphics.DrawLine(pen,24,32,24,36);graphics.DrawLine(pen,19,36,29,36); }
            }
            using(var strong=new Font(Font,FontStyle.Bold)) {
                TextRenderer.DrawText(graphics,Text,strong,new Rectangle(48,14,Math.Max(0,Width-60),24),color,TextFormatFlags.EndEllipsis|TextFormatFlags.VerticalCenter);
            }
            TextRenderer.DrawText(graphics,Detail,Font,new Rectangle(48,39,Math.Max(0,Width-60),21),Theme.Secondary,TextFormatFlags.EndEllipsis);
            TextRenderer.DrawText(graphics,Caption,Font,new Rectangle(48,62,Math.Max(0,Width-60),22),Chosen ? Theme.Accent : Theme.Secondary,TextFormatFlags.EndEllipsis);
        }
    }
    public class RoundedPanel : Panel {
        public int Radius { get; set; }
        public bool ShowBorder { get; set; }
        public RoundedPanel() { Radius=12;ShowBorder=false;DoubleBuffered=true; }
        protected override void OnPaintBackground(PaintEventArgs e) {
            if(SystemInformation.HighContrast) { base.OnPaintBackground(e);return; }
            e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;e.Graphics.Clear(Parent==null ? Theme.Window : Parent.BackColor);
            using(var path=Shapes.Round(new RectangleF(.5f,.5f,Math.Max(1,Width-1),Math.Max(1,Height-1)),Radius))
            using(var brush=new SolidBrush(BackColor)) { e.Graphics.FillPath(brush,path);if(ShowBorder) using(var pen=new Pen(Theme.Border)) e.Graphics.DrawPath(pen,path); }
        }
    }
    public class ChoiceBox : CheckBox {
        public ChoiceBox() { SetStyle(ControlStyles.UserPaint|ControlStyles.AllPaintingInWmPaint|ControlStyles.OptimizedDoubleBuffer,true);Height=36; }
        protected override void OnPaint(PaintEventArgs e) {
            if(SystemInformation.HighContrast) { base.OnPaint(e);return; }
            e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;e.Graphics.Clear(Parent==null ? Theme.Surface : Parent.BackColor);
            int y=(Height-16)/2;
            using(var path=Shapes.Round(new RectangleF(1,y,16,16),3))
            using(var brush=new SolidBrush(Checked ? Theme.Accent : Theme.Raised))
            using(var pen=new Pen(Focused ? Theme.Accent : Theme.Border)) { e.Graphics.FillPath(brush,path);e.Graphics.DrawPath(pen,path); }
            if(Checked) using(var pen=new Pen(Theme.Window,2f)) e.Graphics.DrawLines(pen,new[]{new Point(4,y+8),new Point(8,y+12),new Point(14,y+4)});
            TextRenderer.DrawText(e.Graphics,Text,Font,new Rectangle(27,0,Math.Max(0,Width-28),Height),Enabled ? ForeColor : Theme.Secondary,TextFormatFlags.VerticalCenter|TextFormatFlags.EndEllipsis);
            if(Focused) ControlPaint.DrawFocusRectangle(e.Graphics,new Rectangle(24,3,Math.Max(0,Width-27),Math.Max(0,Height-6)),Theme.Accent,Parent==null ? BackColor : Parent.BackColor);
        }
    }
    public class ResizeGrip : Label {
        protected override void OnPaint(PaintEventArgs e) {
            e.Graphics.Clear(Parent==null ? Theme.PreviewCard : Parent.BackColor);
            using(var brush=new SolidBrush(SystemInformation.HighContrast ? SystemColors.Highlight : Theme.Accent)) e.Graphics.FillRectangle(brush,Math.Max(0,Width-9),Math.Max(0,Height-9),6,6);
        }
    }
    public class PreviewTile : Panel {
        public bool Selected { get; set; }
        public bool Ring { get; set; }
        public bool FixedHeader { get; set; }
        public PreviewTile() { Padding=new Padding(1); DoubleBuffered=true; TabStop=true; SetStyle(ControlStyles.Selectable,true); }
        protected override bool IsInputKey(Keys keyData) { var key=keyData & Keys.KeyCode; return key==Keys.Left || key==Keys.Right || key==Keys.Up || key==Keys.Down || base.IsInputKey(keyData); }
        protected override void OnMouseDown(MouseEventArgs e) { Focus();base.OnMouseDown(e); }
        protected override void OnEnter(EventArgs e) { base.OnEnter(e);Invalidate(); }
        protected override void OnLeave(EventArgs e) { base.OnLeave(e);Invalidate(); }
        protected override void OnPaint(PaintEventArgs e) {
            e.Graphics.SmoothingMode=SmoothingMode.AntiAlias;
            var textColor=SystemInformation.HighContrast ? SystemColors.ControlText : Theme.Text;
            if(FixedHeader) {
                e.Graphics.Clear(Parent==null ? Theme.Sunken : Parent.BackColor);
                using(var strong=new Font("Segoe UI",Math.Max(5,Math.Min(8,Width/19f)),FontStyle.Bold)) TextRenderer.DrawText(e.Graphics,"ALIENGAMER MODE",strong,new Rectangle(4,0,Math.Max(0,Width-8),Height),textColor,TextFormatFlags.VerticalCenter);return;
            }
            e.Graphics.Clear(Parent==null ? Theme.Sunken : Parent.BackColor);
            using(var path=Shapes.Round(new RectangleF(1,1,Math.Max(1,Width-2),Math.Max(1,Height-2)),6))
            using(var brush=new SolidBrush(Selected ? Color.FromArgb(44,37,29) : BackColor))
            using(var pen=new Pen(SystemInformation.HighContrast ? SystemColors.ControlText : (Selected ? Theme.Accent : Theme.Border),Selected ? 2f : 1f)) { e.Graphics.FillPath(brush,path);e.Graphics.DrawPath(pen,path); }
            if(Ring && Width>90 && Height>90) {
                float diameter=Math.Min(Width*.52f,Height*.46f);float x=(Width-diameter)/2;float y=(Height-diameter)/2-10;
                using(var pen=new Pen(Color.FromArgb(86,99,114),5f)) e.Graphics.DrawEllipse(pen,x,y,diameter,diameter);
                using(var pen=new Pen(Theme.Accent,5f)) e.Graphics.DrawArc(pen,x,y,diameter,diameter,-90,-55);
                TextRenderer.DrawText(e.Graphics,Text,Font,new Rectangle(4,(int)(y+diameter+12),Math.Max(0,Width-8),24),textColor,TextFormatFlags.HorizontalCenter|TextFormatFlags.EndEllipsis);
            } else {
                using(var labelFont=new Font(Font.FontFamily,Math.Max(6,Math.Min(Font.Size,Width/12f)),Font.Style))
                    TextRenderer.DrawText(e.Graphics,Text,labelFont,Rectangle.Inflate(ClientRectangle,-3,-1),textColor,TextFormatFlags.HorizontalCenter|TextFormatFlags.VerticalCenter|TextFormatFlags.WordBreak|TextFormatFlags.EndEllipsis);
            }
            if(Focused) ControlPaint.DrawFocusRectangle(e.Graphics,new Rectangle(3,3,Math.Max(0,Width-6),Math.Max(0,Height-6)),Theme.Accent,BackColor);
        }
    }
    class DarkMenuColors : ProfessionalColorTable {
        public override Color ToolStripDropDownBackground { get { return Theme.Surface; } }
        public override Color MenuBorder { get { return Theme.Border; } }
        public override Color MenuItemSelected { get { return Color.FromArgb(75,51,30); } }
        public override Color MenuItemBorder { get { return Theme.Accent; } }
        public override Color MenuItemSelectedGradientBegin { get { return MenuItemSelected; } }
        public override Color MenuItemSelectedGradientEnd { get { return MenuItemSelected; } }
        public override Color MenuItemPressedGradientBegin { get { return MenuItemSelected; } }
        public override Color MenuItemPressedGradientMiddle { get { return MenuItemSelected; } }
        public override Color MenuItemPressedGradientEnd { get { return MenuItemSelected; } }
        public override Color SeparatorDark { get { return Theme.Border; } }
        public override Color SeparatorLight { get { return Theme.Surface; } }
        public override Color CheckBackground { get { return Theme.Raised; } }
        public override Color CheckSelectedBackground { get { return Theme.Accent; } }
    }
    class DarkMenuRenderer : ToolStripProfessionalRenderer {
        public DarkMenuRenderer() : base(new DarkMenuColors()) { RoundedEdges=false; }
        protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) {
            e.TextColor=e.Item.Enabled ? Theme.Text : Theme.Secondary; base.OnRenderItemText(e);
        }
        protected override void OnRenderArrow(ToolStripArrowRenderEventArgs e) { e.ArrowColor=Theme.Secondary; base.OnRenderArrow(e); }
    }
}
