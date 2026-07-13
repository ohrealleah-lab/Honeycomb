using System;
using System.Collections.Generic;
using SoliBee.Core.Models;

namespace SoliBee.Core.ViewModels;

// Shared by FreecellViewModel and SpiderViewModel's HasAnyLegalMoves: the player can
// legally drag any suffix of a column's maximal movable run (not just the whole run), so
// a deadlock check must try every suffix length before concluding no move exists there.
public static class MoveSequenceHelper
{
    // Tries every suffix of `seq`, longest first, against `canMove`; returns true on the
    // first length that succeeds. `skip` optionally excludes a specific length (e.g. a
    // pointless whole-column relocation onto another empty column) before checking it.
    public static bool AnySuffixMoves(List<Card> seq, Func<List<Card>, bool> canMove, Func<int, bool>? skip = null)
    {
        for (int len = seq.Count; len >= 1; len--)
        {
            if (skip != null && skip(len)) continue;
            var subSeq = seq.GetRange(seq.Count - len, len);
            if (canMove(subSeq)) return true;
        }
        return false;
    }
}
