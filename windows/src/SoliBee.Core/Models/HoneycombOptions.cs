using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class HoneycombOptions
{
    public bool ForceNormalRules { get; set; } = false;
    public List<HoneycombRule> ManualRules { get; set; } = new List<HoneycombRule>();
    public string Difficulty { get; set; } = "Medium";
    public List<string> BannedRules { get; set; } = new List<string>();

    // Mac parity options
    public bool IsSoundEnabled { get; set; } = true;
    public bool NoStressMode { get; set; } = false;
    public bool HideHintButton { get; set; } = false;
    public bool ShowPointHighlights { get; set; } = true;
    public int ActiveDeckIndex { get; set; } = 0;
}
