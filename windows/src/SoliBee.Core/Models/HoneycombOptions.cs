using System.Collections.Generic;

namespace SoliBee.Core.Models;

public class HoneycombOptions
{
    public bool ForceNormalRules { get; set; } = false;
    public HashSet<HoneycombRule> ManualRules { get; set; } = new HashSet<HoneycombRule>();
    public HoneycombDifficulty Difficulty { get; set; } = HoneycombDifficulty.Medium;
    public HashSet<string> BannedRules { get; set; } = new HashSet<string>();

    // Mac parity options. IsSoundEnabled/NoStressMode/ActiveDeckIndex/HoneyMode are
    // deliberately NOT here — Mac keeps those per-game because it has no separate
    // global-options object, but Windows already covers the same ground via
    // GameOptions.IsSoundEnabled (checked by SoundService.PlaySound for every
    // Honeycomb sound call), GameOptions.IsNoStressMode, GameOptions.HoneyMode (the
    // "+N"/"-N" point-popup toggle, checked directly in HoneycombViewModel), and
    // GameOptions.HoneycombActiveDeckIndex (wired to the Manage Decks UI) —
    // duplicating them here would just create a second, unread source of truth for
    // the same setting.
    public bool HideHintButton { get; set; } = false;
}
