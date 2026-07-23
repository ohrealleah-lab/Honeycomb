using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class HoneycombOptions
{
    public bool ForceNormalRules { get; set; } = false;
    public List<HoneycombRule> ManualRules { get; set; } = new List<HoneycombRule>();
    public string Difficulty { get; set; } = "Medium";
    public List<string> BannedRules { get; set; } = new List<string>();
}
