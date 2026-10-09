namespace EndpointMonitorService.Desktop;

internal static class CsUi
{
    internal static Style Style(string key) => (Style)Application.Current.FindResource(key);

    internal static Brush Brush(string key) => (Brush)Application.Current.FindResource(key);

    internal static FontFamily Font(string key) => (FontFamily)Application.Current.FindResource(key);

    internal static TextBlock Icon(string glyph, double size = 16)
    {
        return new TextBlock
        {
            Text = glyph,
            FontFamily = Font("CsFontIcon"),
            FontSize = size,
            VerticalAlignment = VerticalAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center,
        };
    }

    internal static UIElement Labeled(string glyph, string text)
    {
        var panel = new StackPanel { Orientation = Orientation.Horizontal };
        var icon = Icon(glyph, 14);
        icon.Margin = new Thickness(0, 0, 8, 0);
        panel.Children.Add(icon);
        panel.Children.Add(new TextBlock
        {
            Text = text,
            VerticalAlignment = VerticalAlignment.Center,
        });
        return panel;
    }

    internal static Border Badge(string glyph, string accentBrushKey)
    {
        return new Border
        {
            Width = 36,
            Height = 36,
            CornerRadius = new CornerRadius(10),
            Background = Brush("CsSurfaceContainerLowBrush"),
            BorderBrush = Brush("CsGhostBorderBrush"),
            BorderThickness = new Thickness(1),
            Child = new TextBlock
            {
                Text = glyph,
                FontFamily = Font("CsFontIcon"),
                FontSize = 16,
                Foreground = Brush(accentBrushKey),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
            },
        };
    }
}

internal sealed class SparklineChart : FrameworkElement
{
    private readonly System.Windows.Media.Pen _cpuPen;
    private readonly System.Windows.Media.Pen _ramPen;
    private readonly System.Windows.Media.Pen _guidePen;
    private double[] _cpu = [];
    private double[] _ram = [];

    public SparklineChart()
    {
        MinHeight = 78;
        VerticalAlignment = VerticalAlignment.Stretch;
        SnapsToDevicePixels = true;
        _cpuPen = MakePen(CsUi.Brush("CsPrimaryBrush"));
        _ramPen = MakePen(CsUi.Brush("CsTertiaryBrush"));
        _guidePen = MakePen(CsUi.Brush("CsGhostBorderBrush"), 1);
    }

    public void SetSeries(IReadOnlyList<double> cpu, IReadOnlyList<double> ram)
    {
        _cpu = cpu.ToArray();
        _ram = ram.ToArray();
        InvalidateVisual();
    }

    protected override System.Windows.Size MeasureOverride(System.Windows.Size availableSize)
    {
        var width = double.IsInfinity(availableSize.Width) ? 0 : availableSize.Width;
        var height = !double.IsInfinity(availableSize.Height) && availableSize.Height > MinHeight
            ? availableSize.Height
            : MinHeight;
        return new System.Windows.Size(Math.Max(0, width), height);
    }

    protected override void OnRender(DrawingContext dc)
    {
        var width = ActualWidth;
        var height = ActualHeight;
        if (width <= 2 || height <= 2)
            return;

        var mid = height / 2;
        dc.DrawLine(_guidePen, new System.Windows.Point(0, mid), new System.Windows.Point(width, mid));
        DrawSeries(dc, _ram, _ramPen, width, height);
        DrawSeries(dc, _cpu, _cpuPen, width, height);
    }

    private static void DrawSeries(DrawingContext dc, double[] values, System.Windows.Media.Pen pen, double width, double height)
    {
        if (values.Length < 2)
            return;

        var geometry = new StreamGeometry();
        using (var ctx = geometry.Open())
        {
            for (var i = 0; i < values.Length; i++)
            {
                var x = i * (width - 1) / (values.Length - 1);
                var y = (height - 6) - (Math.Clamp(values[i], 0, 100) / 100.0) * (height - 10);
                var point = new System.Windows.Point(x, y);
                if (i == 0)
                    ctx.BeginFigure(point, false, false);
                else
                    ctx.LineTo(point, true, true);
            }
        }

        geometry.Freeze();
        dc.DrawGeometry(null, pen, geometry);
    }

    private static System.Windows.Media.Pen MakePen(Brush brush, double thickness = 1.75)
    {
        var pen = new System.Windows.Media.Pen(brush, thickness)
        {
            StartLineCap = PenLineCap.Round,
            EndLineCap = PenLineCap.Round,
            LineJoin = PenLineJoin.Round,
        };
        if (brush.IsFrozen)
            pen.Freeze();
        return pen;
    }
}

internal sealed class CountdownRing : Grid
{
    private readonly System.Windows.Shapes.Ellipse _track;
    private readonly System.Windows.Shapes.Path _arc;
    private readonly TextBlock _label;
    private double _fraction = 1;
    private bool _warning;

    public CountdownRing()
    {
        Width = 84;
        Height = 84;
        _track = new System.Windows.Shapes.Ellipse
        {
            StrokeThickness = 5,
            Margin = new Thickness(2.5),
        };
        _arc = new System.Windows.Shapes.Path
        {
            StrokeThickness = 5,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
            Stretch = Stretch.None,
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment = VerticalAlignment.Top,
        };
        _label = new TextBlock
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
        };
        Children.Add(_track);
        Children.Add(_arc);
        Children.Add(_label);
        SizeChanged += (_, _) => Redraw();
    }

    public void SetProgress(double fraction, string centerText, bool warning)
    {
        _fraction = Math.Clamp(fraction, 0, 1);
        _warning = warning;
        _label.Text = centerText;
        _label.FontFamily = CsUi.Font("CsFontMono");
        Redraw();
    }

    private void Redraw()
    {
        var size = Math.Min(ActualWidth, ActualHeight);
        _label.Foreground = _warning ? CsUi.Brush("CsErrorBrush") : CsUi.Brush("CsOnSurfaceBrush");
        _arc.Stroke = _warning ? CsUi.Brush("CsErrorBrush") : CsUi.Brush("CsPrimaryBrush");
        _track.Stroke = CsUi.Brush("CsGhostBorderBrush");
        _arc.Data = size <= 0 ? Geometry.Empty : Arc(size, _fraction);
    }

    private static Geometry Arc(double size, double fraction)
    {
        if (fraction <= 0.001)
            return Geometry.Empty;

        fraction = Math.Clamp(fraction, 0, 0.999);
        const double thickness = 5;
        var radius = (size - thickness) / 2;
        var center = size / 2;
        var sweep = fraction * 360.0;
        var startRad = -Math.PI / 2;
        var endRad = startRad + sweep * Math.PI / 180.0;
        var start = new System.Windows.Point(center + (radius * Math.Cos(startRad)), center + (radius * Math.Sin(startRad)));
        var end = new System.Windows.Point(center + (radius * Math.Cos(endRad)), center + (radius * Math.Sin(endRad)));
        var figure = new PathFigure { StartPoint = start, IsClosed = false };
        figure.Segments.Add(new ArcSegment
        {
            Point = end,
            Size = new System.Windows.Size(radius, radius),
            IsLargeArc = sweep > 180,
            SweepDirection = SweepDirection.Clockwise,
        });
        var geometry = new PathGeometry();
        geometry.Figures.Add(figure);
        geometry.Freeze();
        return geometry;
    }
}
