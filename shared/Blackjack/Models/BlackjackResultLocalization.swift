import Foundation

// Display-only translation for a just-finished Blackjack round's result banner.
// BlackjackState.resultOutcome/lastNetResult/playerHands stay language-agnostic data;
// this recomputes the headline/subline text at the point of rendering, so a language
// switch while the banner is still on screen (before the next round starts) updates it
// immediately instead of leaving it frozen in whichever language was active when the
// round completed. Shared so Mac's BlackjackView.swift and iOS's BlackjackTouchView.swift
// can't drift out of sync.
public func localizedBlackjackResult(_ state: BlackjackState, language: AppLanguage) -> (headline: String, subline: String) {
    guard state.resultOutcome != .none else { return ("", "") }

    let headline: String
    switch state.resultOutcome {
    case .none:      headline = ""
    case .blackjack: headline = L(.resultHeadlineBlackjack, language: language)
    case .win:       headline = L(.youWin, language: language)
    case .push:      headline = L(.resultHeadlinePush, language: language)
    case .bust:      headline = L(.resultHeadlineBust, language: language)
    case .loss:      headline = L(.notTodayPartner, language: language)
    }

    // A split round's headline only reflects the aggregate outcome (e.g. "You Win!" if
    // any hand won), which loses the fact that another hand may have lost or pushed —
    // show the per-hand breakdown instead of the generic net amount so a split result
    // is never misreported as a clean win/loss.
    let subline: String
    if state.playerHands.count > 1 {
        subline = state.playerHands.enumerated().map { i, hand -> String in
            switch hand.result {
            case .blackjack: return L(.resultHeadlineBlackjack, language: language) + " 🃏"
            case .win:       return L(.resultHandWinFmt, language: language, i + 1)
            case .loss:      return L(.resultHandLossFmt, language: language, i + 1)
            case .push:      return L(.resultHandPushFmt, language: language, i + 1)
            case .bust:      return L(.resultHandBustFmt, language: language, i + 1)
            case .none:      return ""
            }
        }.joined(separator: "  ·  ")
    } else if state.resultOutcome == .push {
        subline = L(.resultSubPush, language: language)
    } else {
        let net = state.lastNetResult
        subline = net > 0 ? L(.resultSubNetPositiveFmt, language: language, net)
                 : net < 0 ? L(.resultSubNetNegativeFmt, language: language, net)
                 : L(.resultSubEven, language: language)
    }

    return (headline, subline)
}
