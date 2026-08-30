using System;
using System.IO;
using System.Threading.Tasks;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Media;
using Avalonia.Media.Imaging;
using Avalonia.Platform.Storage;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;

namespace SoliBee.Desktop.Views;

public partial class FaceCardArtSectionView : UserControl
{
    // Same PointerPressed + async void + ShowDialog gotcha as PreferencesView's
    // AdjustCardBack_Click: OnTileClickAsync awaits a file picker and a modal editor
    // dialog, and without this guard a rapid double-click (or a click landing before the
    // dialog visually captures input) could re-enter it, stacking a second file
    // picker/editor on top of the first or racing two FaceCardArtService.Add/Update calls.
    private bool _isEditorOpen;

    private static readonly FaceCardSlot[] SpadesSlots =
        { FaceCardSlot.BlackAce, FaceCardSlot.BlackJack, FaceCardSlot.BlackQueen, FaceCardSlot.BlackKing };
    private static readonly FaceCardSlot[] HeartsSlots =
        { FaceCardSlot.RedAce, FaceCardSlot.RedJack, FaceCardSlot.RedQueen, FaceCardSlot.RedKing };
    private static readonly FaceCardSlot[] DiamondsSlots =
        { FaceCardSlot.DiamondsAce, FaceCardSlot.DiamondsJack, FaceCardSlot.DiamondsQueen, FaceCardSlot.DiamondsKing };
    private static readonly FaceCardSlot[] ClubsSlots =
        { FaceCardSlot.ClubsAce, FaceCardSlot.ClubsJack, FaceCardSlot.ClubsQueen, FaceCardSlot.ClubsKing };

    public FaceCardArtSectionView()
    {
        InitializeComponent();
        this.Loaded += (_, _) => BuildGrid();

        // Rebuild whenever face art changes from anywhere — not just edits made within
        // this section's own tiles, but also e.g. PreferencesView applying a theme
        // (ThemeService.ApplyTheme replaces the underlying art via FaceCardArtService),
        // which previously left these tiles showing stale thumbnails until reopened.
        WeakReferenceMessenger.Default.Register<FaceCardArtChangedMessage>(this, (r, m) => BuildGrid());
        this.Unloaded += (_, _) => WeakReferenceMessenger.Default.Unregister<FaceCardArtChangedMessage>(this);
    }

    private void BuildGrid()
    {
        SpadesRow.Children.Clear();
        HeartsRow.Children.Clear();
        DiamondsRow.Children.Clear();
        ClubsRow.Children.Clear();
        
        foreach (var slot in SpadesSlots) SpadesRow.Children.Add(BuildTile(slot));
        foreach (var slot in HeartsSlots) HeartsRow.Children.Add(BuildTile(slot));
        foreach (var slot in DiamondsSlots) DiamondsRow.Children.Add(BuildTile(slot));
        foreach (var slot in ClubsSlots) ClubsRow.Children.Add(BuildTile(slot));
    }

    private Control BuildTile(FaceCardSlot slot)
    {
        var art = FaceCardArtService.GetArt(slot);
        bool hasArt = art != null;
        bool isRed = slot.GetIsRed();
        string rankLabel = slot.GetRankLabel();
        string suitChar = slot.GetSuitSymbol();
        var color = isRed ? Color.Parse("#CC1A1A") : Color.Parse("#1A1A1A");
        var brush = new SolidColorBrush(color);

        // Mini card border (78×111 — ~1.3x the original 60×85). A larger scale filled
        // more of the panel's width but pushed the 4-row grid taller than the visible
        // area, forcing a vertical scrollbar — this size keeps all 16 slots on screen
        // at once, which matters more than filling the width. Every inner element below
        // is scaled by the same factor to keep proportions identical, per the
        // ClipToBounds note above about not distorting this ratio.
        var cardBorder = new Border
        {
            Width = 78, Height = 111,
            Background = new SolidColorBrush(Colors.White),
            BorderBrush = new SolidColorBrush(Color.Parse("#D9000000")),
            BorderThickness = new Thickness(0.75),
            CornerRadius = new CornerRadius(6),
            ClipToBounds = true,
            Cursor = new Cursor(StandardCursorType.Hand)
        };

        var innerGrid = new Grid();
        cardBorder.Child = innerGrid;

        // Top-left rank + suit
        var topLeft = new StackPanel
        {
            Orientation = Avalonia.Layout.Orientation.Horizontal,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Top,
            Margin = new Thickness(4, 3, 0, 0),
            Spacing = 1
        };
        topLeft.Children.Add(new TextBlock
        {
            Text = rankLabel, FontSize = 12, FontWeight = FontWeight.Bold,
            Foreground = brush, FontFamily = new FontFamily("Segoe UI")
        });
        topLeft.Children.Add(new TextBlock
        {
            Text = suitChar, FontSize = 9, Foreground = brush,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center
        });
        innerGrid.Children.Add(topLeft);

        // Center content area (45×73 — CardView's 74x119 face-art clip window scaled
        // down by this tile's own ~0.61x factor vs a real 128x181 card). GetCachedFaceArtBitmap
        // below returns the same bitmap the real card bakes, which is now sized to that
        // 74:119 aspect — sizing this box to match keeps art proportional instead of
        // letterboxing inside a mismatched, much wider 47x70 box.
        var centerGrid = new Grid
        {
            Width = 45, Height = 73,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center,
            ClipToBounds = true
        };

        bool showArt = art != null;
        if (showArt && art != null)
        {
            var img = new Image { Stretch = Stretch.Uniform, Width = 45, Height = 73 };
            // Created in code, not XAML — set explicitly since this control never goes
            // through the .axaml-only interpolation-mode pass (see the matching comment
            // in CardView.PopulateSuitCanvas). The source bitmap here is baked at 280x240
            // (FaceArtCacheW/H), roughly a 10x downscale to this tile size, so this
            // matters even more than most.
            RenderOptions.SetBitmapInterpolationMode(img, BitmapInterpolationMode.HighQuality);
            try
            {
                img.Source = CardView.GetCachedFaceArtBitmap(FaceCardArtService.GetFullPath(art), art.Scale, art.OffsetX, art.OffsetY);
                centerGrid.Children.Add(img);
            }
            catch { showArt = false; }
        }
        if (!showArt)
        {
            bool isAce = slot.GetRank() == 1;
            centerGrid.Children.Add(new TextBlock
            {
                Text = isAce ? suitChar : rankLabel,
                FontSize = isAce ? 26 : 23,
                FontWeight = isAce ? FontWeight.Normal : FontWeight.Bold,
                Foreground = brush,
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center,
                FontFamily = new FontFamily("Segoe UI")
            });
        }
        innerGrid.Children.Add(centerGrid);

        // Bottom-right rank + suit (rotated 180°)
        var bottomRight = new StackPanel
        {
            Orientation = Avalonia.Layout.Orientation.Horizontal,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Bottom,
            Margin = new Thickness(0, 0, 4, 3),
            Spacing = 1,
            RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative)
        };
        bottomRight.RenderTransform = new RotateTransform(180);
        bottomRight.Children.Add(new TextBlock
        {
            Text = rankLabel, FontSize = 12, FontWeight = FontWeight.Bold,
            Foreground = brush, FontFamily = new FontFamily("Segoe UI")
        });
        bottomRight.Children.Add(new TextBlock
        {
            Text = suitChar, FontSize = 9, Foreground = brush,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center
        });
        innerGrid.Children.Add(bottomRight);

        // Click to open picker or editor. Capture(null) before awaiting — same
        // PointerPressed + async void + ShowDialog gotcha as PreferencesView's
        // AdjustCardBack_Click (see windows/CLAUDE.md); without it the implicit
        // pointer capture lingers on cardBorder while the file picker/editor is up,
        // which can block or misroute pointer input elsewhere until it resolves.
        cardBorder.PointerPressed += async (_, e) =>
        {
            e.Pointer.Capture(null);
            await OnTileClickAsync(slot);
        };

        // Container: the card, with a delete badge overlaid on its lower-left corner
        // when art is loaded — art is always considered active once loaded (no separate
        // on/off state), so the only per-tile action needed here is removing it.
        var container = new Grid();
        container.Children.Add(cardBorder);

        if (hasArt)
        {
            var deleteBtn = new Button
            {
                Content = "✕",
                Width = 22, Height = 22,
                FontSize = 11,
                Padding = new Thickness(0),
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Right,
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Bottom,
                HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                VerticalContentAlignment = Avalonia.Layout.VerticalAlignment.Center,
                Margin = new Thickness(4),
                Background = new SolidColorBrush(Color.Parse("#CC3333")),
                Foreground = new SolidColorBrush(Colors.White)
            };
            deleteBtn.Click += (_, _) => OnDeleteClick(slot);
            container.Children.Add(deleteBtn);
        }

        return container;
    }

    private async Task OnTileClickAsync(FaceCardSlot slot)
    {
        if (_isEditorOpen) return;
        _isEditorOpen = true;
        try
        {
            await OnTileClickCoreAsync(slot);
        }
        finally
        {
            _isEditorOpen = false;
        }
    }

    private async Task OnTileClickCoreAsync(FaceCardSlot slot)
    {
        var existingArt = FaceCardArtService.GetArt(slot);

        if (existingArt == null)
        {
            var topLevel = TopLevel.GetTopLevel(this);
            if (topLevel == null) return;

            var gifType = new FilePickerFileType("Animated GIF") { Patterns = new[] { "*.gif" } };
            var files = await topLevel.StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
            {
                Title = $"Select Art for {slot.GetDisplayName()}",
                AllowMultiple = false,
                FileTypeFilter = new[] { FilePickerFileTypes.ImageAll, gifType }
            });

            if (files == null || files.Count == 0) return;

            var file = files[0];
            bool isGif = file.Name.EndsWith(".gif", StringComparison.OrdinalIgnoreCase);
            string uniqueFileName = Guid.NewGuid().ToString() + (isGif ? ".gif" : ".png");
            string artDir = FaceCardArtService.ArtDirectory;
            Directory.CreateDirectory(artDir);
            string destPath = Path.Combine(artDir, uniqueFileName);

            try
            {
                using (var src = await file.OpenReadAsync())
                using (var dst = File.Create(destPath))
                    await src.CopyToAsync(dst);

                var newArt = new CustomFaceArt
                {
                    Slot = slot,
                    RelativePath = uniqueFileName,
                    Scale = 1.0, OffsetX = 0.0, OffsetY = 0.0,
                    IsEnabled = true
                };

                var owner = (Window?)TopLevel.GetTopLevel(this);
                var editor = new FaceCardArtEditorWindow(newArt, slot);

                if (owner != null)
                    await editor.ShowDialog(owner);
                else
                    editor.Show();

                if (editor.Saved)
                {
                    FaceCardArtService.Add(editor.Art);
                    CardView.InvalidateFaceArtCache();
                    Refresh();
                }
                else
                {
                    try { File.Delete(destPath); } catch { }
                }
            }
            catch (Exception ex)
            {
                System.Diagnostics.Debug.WriteLine($"Face art upload error: {ex}");
                try { if (File.Exists(destPath)) File.Delete(destPath); } catch { }
            }
        }
        else
        {
            var owner = (Window?)TopLevel.GetTopLevel(this);
            var editor = new FaceCardArtEditorWindow(existingArt, slot);

            if (owner != null)
                await editor.ShowDialog(owner);
            else
                editor.Show();

            if (editor.Saved)
            {
                FaceCardArtService.Update(editor.Art);
                CardView.InvalidateFaceArtCache();
                Refresh();
            }
        }
    }

    private FaceCardSlot? _pendingDeleteSlot;

    private void OnDeleteClick(FaceCardSlot slot)
    {
        _pendingDeleteSlot = slot;
        ConfirmDeleteOverlay.IsVisible = true;
    }

    private void CancelDelete_Click(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        _pendingDeleteSlot = null;
        ConfirmDeleteOverlay.IsVisible = false;
    }

    private void ConfirmDelete_Click(object? sender, Avalonia.Interactivity.RoutedEventArgs e)
    {
        ConfirmDeleteOverlay.IsVisible = false;
        if (_pendingDeleteSlot is { } slot)
        {
            _pendingDeleteSlot = null;
            var relativePath = FaceCardArtService.GetArt(slot)?.RelativePath;
            FaceCardArtService.Remove(slot);
            if (relativePath != null)
                ThemeService.ClearFaceArtReferences(relativePath);
            CardView.InvalidateFaceArtCache();
            Refresh();
        }
    }

    private void Refresh()
    {
        BuildGrid();
        SendArtChangedMessage();
        CardView.PreloadFaceArt();
    }

    private static void SendArtChangedMessage() =>
        WeakReferenceMessenger.Default.Send(new FaceCardArtChangedMessage());
}
