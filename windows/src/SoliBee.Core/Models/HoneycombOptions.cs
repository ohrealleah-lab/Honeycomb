using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class HoneycombOptions
{
    public bool ForceNormalRules { get; set; } = false;
    public HashSet<HoneycombRule> ManualRules { get; set; } = new HashSet<HoneycombRule>();
    public HoneycombDifficulty Difficulty { get; set; } = HoneycombDifficulty.Medium;
    public HashSet<string> BannedRules { get; set; } = new HashSet<string>();

    // Mac parity options
    public bool IsSoundEnabled { get; set; } = true;
    public bool NoStressMode { get; set; } = false;
    public bool HideHintButton { get; set; } = false;
    public bool ShowPointHighlights { get; set; } = true;
    public int ActiveDeckIndex { get; set; } = 0;
}
