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

        // Mini card border (60×85)
        var cardBorder = new Border
        {
            Width = 60, Height = 85,
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
            Margin = new Thickness(3, 2, 0, 0),
            Spacing = 1
        };
        topLeft.Children.Add(new TextBlock
        {
            Text = rankLabel, FontSize = 9, FontWeight = FontWeight.Bold,
            Foreground = brush, FontFamily = new FontFamily("Segoe UI")
        });
        topLeft.Children.Add(new TextBlock
        {
            Text = suitChar, FontSize = 7, Foreground = brush,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center
        });
        innerGrid.Children.Add(topLeft);

        // Center content area (36×54)
        var centerGrid = new Grid
        {
            Width = 36, Height = 54,
            HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Center,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center,
            ClipToBounds = true
        };

        bool showArt = art != null;
        if (showArt && art != null)
        {
            var img = new Image { Stretch = Stretch.Uniform, Width = 29, Height = 25 };
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
                FontSize = isAce ? 20 : 18,
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
            Margin = new Thickness(0, 0, 3, 2),
            Spacing = 1,
            RenderTransformOrigin = new RelativePoint(0.5, 0.5, RelativeUnit.Relative)
        };
        bottomRight.RenderTransform = new RotateTransform(180);
        bottomRight.Children.Add(new TextBlock
        {
            Text = rankLabel, FontSize = 9, FontWeight = FontWeight.Bold,
            Foreground = brush, FontFamily = new FontFamily("Segoe UI")
        });
        bottomRight.Children.Add(new TextBlock
        {
            Text = suitChar, FontSize = 7, Foreground = brush,
            VerticalAlignment = Avalonia.Layout.VerticalAlignment.Center
        });
        innerGrid.Children.Add(bottomRight);

        // Click to open picker or editor
        cardBorder.PointerPressed += async (_, _) => await OnTileClickAsync(slot);

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
                Width = 20, Height = 20,
                FontSize = 10,
                Padding = new Thickness(0),
                HorizontalAlignment = Avalonia.Layout.HorizontalAlignment.Left,
                VerticalAlignment = Avalonia.Layout.VerticalAlignment.Bottom,
                HorizontalContentAlignment = Avalonia.Layout.HorizontalAlignment.Center,
                VerticalContentAlignment = Avalonia.Layout.VerticalAlignment.Center,
                Margin = new Thickness(3),
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
            FaceCardArtService.Remove(slot);
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
