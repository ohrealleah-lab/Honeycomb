using System;
using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class FaceArtSnapshot
{
    public string Slot { get; set; } = "";
    public string RelativePath { get; set; } = "";
    public double Scale { get; set; } = 1.0;
    public double OffsetX { get; set; } = 0.0;
    public double OffsetY { get; set; } = 0.0;
    public bool IsEnabled { get; set; } = true;
}

public class SoliBeeTheme
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string Name { get; set; } = "";
    public string CardBackTheme { get; set; } = "Vulpera";
    public double CardBackScale { get; set; } = 1.0;
    public double CardBackOffsetX { get; set; } = 0.0;
    public double CardBackOffsetY { get; set; } = 0.0;
    public bool IsFinalFantasyMode { get; set; } = false;
    public FeltColorTheme FeltColor { get; set; } = FeltColorTheme.FeltGreen;
    public string CustomFeltColorHex { get; set; } = "#592673";
    public string? ThemeFaceBackNormal { get; set; }
    public string? ThemeFaceBackFF { get; set; }
    public string? ThemeFaceBorderNormal { get; set; }
    public string? ThemeFaceBorderFF { get; set; }
    public string? ThemeFaceBorderFFCard { get; set; }
    public string? ThemeTextRed { get; set; }
    public string? ThemeTextRedFF { get; set; }
    public string? ThemeTextBlackNormal { get; set; }
    public string? ThemeTextBlackFF { get; set; }
    public string? ThemeCardShadow { get; set; }
    public List<FaceArtSnapshot> FaceArts { get; set; } = new();
}
