using System.Collections.Generic;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.Shapes;
using Avalonia.Controls.Primitives;
using Avalonia.Input;
using Avalonia.Layout;
using Avalonia.Media;
using SoliBee.Core.Models;
using SoliBee.Core.Services;

namespace SoliBee.Desktop.Views;

public class ThemeEditorWindow : Window
{
    private record ColorSlot(string Label, System.Func<Color> Get, System.Action<Color> Set);

    private List<ColorSlot> _slots = new();
    private ColorSlot? _active;
    private ColorView? _picker;
    private readonly List<(ColorSlot Slot, Border Row, Rectangle Swatch)> _rows = new();
    private Border? _selectedRow;
    private bool _suppress;
    private TextBlock? _statusLabel;

    public ThemeEditorWindow()
    {
        Title = "Theme Editor (Debug)";
        Width = 760;
        Height = 540;
        Background = new SolidColorBrush(Color.Parse("#2A2A2A"));
        Content = Build();
    }

    private Control Build()
    {
        _slots = BuildNormalSlots();

        // ── Left: scrollable list of color rows ───────────────────────
        var listStack = new StackPanel { Spacing = 2, Margin = new Thickness(6) };
        _rows.Clear();

        foreach (var slot in _slots)
        {
            var swatch = new Rectangle
            {
                Width = 20, Height = 20,
                Fill = new SolidColorBrush(slot.Get()),
                VerticalAlignment = VerticalAlignment.Center
            };
            var label = new TextBlock
            {
                Text = slot.Label,
                Foreground = Brushes.White,
                FontSize = 12,
                VerticalAlignment = VerticalAlignment.Center,
                Margin = new Thickness(8, 0, 0, 0)
            };
            var inner = new StackPanel
            {
                Orientation = Orientation.Horizontal,
                Margin = new Thickness(8, 7),
                Children = { swatch, label }
            };
            var row = new Border
            {
                CornerRadius = new CornerRadius(4),
                Child = inner,
                Cursor = new Cursor(StandardCursorType.Hand)
            };

            var capturedSlot = slot;
            var capturedRow  = row;
            var capturedSwatch = swatch;
            row.PointerPressed += (_, _) => SelectSlot(capturedSlot, capturedRow, capturedSwatch);

            _rows.Add((slot, row, swatch));
            listStack.Children.Add(row);
        }

        var listScroll = new ScrollViewer
        {
            Content = listStack,
            VerticalScrollBarVisibility = ScrollBarVisibility.Auto
        };

        // ── Right: color picker ────────────────────────────────────────
        _picker = new ColorView { Margin = new Thickness(8) };
        _picker.PropertyChanged += OnPickerPropertyChanged;

        // ── Layout ────────────────────────────────────────────────────
        var root = new Grid
        {
            RowDefinitions    = new RowDefinitions("Auto,*,Auto"),
            ColumnDefinitions = new ColumnDefinitions("210,*")
        };

        var modeBar = new Border
        {
            Background = new SolidColorBrush(Color.Parse("#1A1A1A")),
            Padding = new Thickness(10, 7),
            Child = new TextBlock
            {
                Text = "Card Theme Colors",
                Foreground = new SolidColorBrush(Color.Parse("#AAAAAA")),
                FontSize = 11
            }
        };
        Grid.SetColumnSpan(modeBar, 2);
        root.Children.Add(modeBar);

        Grid.SetRow(listScroll, 1);
        root.Children.Add(listScroll);

        Grid.SetRow(_picker, 1);
        Grid.SetColumn(_picker, 1);
        root.Children.Add(_picker);

        // ── Save bar ──────────────────────────────────────────────────
        _statusLabel = new TextBlock
        {
            Foreground = new SolidColorBrush(Color.Parse("#88FFFFFF")),
            FontSize = 11,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(10, 0, 0, 0)
        };
        var saveBtn = new Button
        {
            Content = "Save",
            HorizontalAlignment = HorizontalAlignment.Right,
            Margin = new Thickness(0, 0, 10, 0),
            Padding = new Thickness(16, 6),
            Background = new SolidColorBrush(Color.Parse("#26FFFFFF")),
            Foreground = Brushes.White
        };
        saveBtn.Click += (_, _) => SaveColors();
        var saveBar = new Border
        {
            Background = new SolidColorBrush(Color.Parse("#1A1A1A")),
            Padding = new Thickness(0, 6),
            Child = new Grid
            {
                ColumnDefinitions = new ColumnDefinitions("*,Auto"),
                Children = { _statusLabel, saveBtn }
            }
        };
        Grid.SetColumn(saveBtn, 1);
        Grid.SetRow(saveBar, 2);
        Grid.SetColumnSpan(saveBar, 2);
        root.Children.Add(saveBar);

        // Pre-select first slot
        if (_rows.Count > 0)
        {
            var (s, r, sw) = _rows[0];
            SelectSlot(s, r, sw);
        }

        return root;
    }

    private static List<ColorSlot> BuildNormalSlots() => new()
    {
        new("Card Face Background",
            () => CardView._brushFaceBackNormal.Color,
            c  => CardView._brushFaceBackNormal.Color = c),
        new("Card Border",
            () => CardView._brushFaceBorderNormal.Color,
            c  => CardView._brushFaceBorderNormal.Color = c),
        new("Red Suit / Rank Text",
            () => CardView._brushTextRed.Color,
            c  => CardView._brushTextRed.Color = c),
        new("Black Suit / Rank Text",
            () => CardView._brushTextBlackNormal.Color,
            c  => CardView._brushTextBlackNormal.Color = c),
    };

    private void SelectSlot(ColorSlot slot, Border row, Rectangle swatch)
    {
        if (_selectedRow != null)
            _selectedRow.Background = Brushes.Transparent;

        _selectedRow = row;
        row.Background = new SolidColorBrush(Color.Parse("#44FFFFFF"));
        _active = slot;

        if (_picker != null)
        {
            _suppress = true;
            _picker.Color = slot.Get();
            _suppress = false;
        }
    }

    private void SaveColors()
    {
        var options = SettingsService.LoadOptions();
        options.ThemeFaceBackNormal  = CardView._brushFaceBackNormal.Color.ToString();
        options.ThemeFaceBorderNormal = CardView._brushFaceBorderNormal.Color.ToString();
        options.ThemeTextRed         = CardView._brushTextRed.Color.ToString();
        options.ThemeTextBlackNormal = CardView._brushTextBlackNormal.Color.ToString();
        SettingsService.SaveOptions(options);

        if (_statusLabel != null) _statusLabel.Text = "Saved.";
    }

    private void OnPickerPropertyChanged(object? sender, AvaloniaPropertyChangedEventArgs e)
    {
        if (_suppress || _active == null || _picker == null) return;
        if (e.Property.Name != nameof(ColorView.Color)) return;

        var color = _picker.Color;
        _active.Set(color);

        foreach (var (slot, _, swatch) in _rows)
        {
            if (slot == _active)
            {
                swatch.Fill = new SolidColorBrush(color);
                break;
            }
        }
    }
}
