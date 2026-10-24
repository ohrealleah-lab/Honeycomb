using System;
using System.Collections.Generic;
using System.Linq;
using CommunityToolkit.Mvvm.Messaging;
using SoliBee.Core.Models;
using SoliBee.Core.Services;
using SoliBee.Core.ViewModels;
using Xunit;

namespace SoliBee.Tests.ViewModels;

// Odds and ends of player-visible behaviour that the per-game suites don't reach: what a
// Blackjack natural pays at the deal, switching themes from the coordinator, and the Klondike
// felt-colour change.
public class WindowsLeftoversTests : DataSandbox
{
    // ---- Blackjack naturals, settled at the deal ----

    // The deal is random, so this deals until each kind of natural has turned up (a few hundred
    // deals at most) and checks the money for every one that does — never one specific hand.
    [Fact]
    public void BlackjackNaturals_AreSettledAtTheDeal_WithTheRightMoney()
    {
        Options.IsNoStressMode = false;
        Delete("blackjack_stats.json");
        var vm = new BlackjackViewModel();
        bool sawDealerNatural = false, sawPlayerNatural = false, sawBothNaturals = false;

        for (int i = 0; i < 4000 && !(sawDealerNatural && sawPlayerNatural && sawBothNaturals); i++)
        {
            vm.State.Credits = 10_000;
            vm.State.CurrentBet = 10;
            int before = vm.State.Credits;
            vm.Deal();

            if (vm.State.Phase != BlackjackPhase.Result) continue;   // not a natural: the hand plays on
            var player = vm.State.PlayerHands[0];
            var dealer = vm.State.DealerHand;
            int delta = vm.State.Credits - before;

            Assert.All(dealer.Cards, c => Assert.True(c.IsFaceUp));   // the hole card is turned over
            if (dealer.IsBlackjack && player.IsBlackjack)
            {
                Assert.Equal(BlackjackHandResult.Push, player.Result);
                Assert.Equal(0, delta);                               // the bet comes back
                sawBothNaturals = true;
            }
            else if (dealer.IsBlackjack)
            {
                Assert.Equal(BlackjackHandResult.Lost, player.Result);
                Assert.Equal(-10, delta);
                sawDealerNatural = true;
            }
            else
            {
                Assert.True(player.IsBlackjack);
                Assert.Equal(BlackjackHandResult.Blackjack, player.Result);
                Assert.Equal(30, delta);                              // 3:1 — the bet plus three times it back out
                sawPlayerNatural = true;
            }
        }

        Assert.True(sawPlayerNatural, "no player natural in 4000 deals");
        Assert.True(sawDealerNatural, "no dealer natural in 4000 deals");
        Assert.True(sawBothNaturals, "no double natural in 4000 deals");
        Assert.True(vm.Stats.Blackjacks >= 1);
    }

    [Fact]
    public void BlackjackNaturals_InFreePlay_NeverMoveCredits()
    {
        Options.IsNoStressMode = true;
        var vm = new BlackjackViewModel();
        int natural = 0;
        for (int i = 0; i < 2000 && natural < 5; i++)
        {
            vm.State.Credits = 100;
            vm.Deal();
            Assert.Equal(100, vm.State.Credits);                      // free play: no stake, no payout
            if (vm.State.Phase == BlackjackPhase.Result) natural++;
        }
        Assert.True(natural > 0);
    }

    // ---- Switching themes from the coordinator ----

    private static SoliBeeTheme Theme(string name, FeltColorTheme felt, string cardBack) =>
        new() { Name = name, FeltColor = felt, CardBackTheme = cardBack };

    [Fact]
    public void ApplyTheme_SwitchesTheLookAndTellsEveryGame()
    {
        var c = new AppCoordinator();
        var crimson = Theme("Crimson look", FeltColorTheme.Crimson, "Forest");
        ThemeService.AddTheme(crimson);

        var heard = new List<GameOptions>();
        var recipient = new object();
        WeakReferenceMessenger.Default.Register<object, OptionsChangedMessage>(recipient, (_, m) => heard.Add(m.Options));
        try
        {
            c.ApplyTheme(crimson);
        }
        finally { WeakReferenceMessenger.Default.UnregisterAll(recipient); }

        var o = SettingsService.LoadOptions();
        Assert.Equal(FeltColorTheme.Crimson, o.FeltColor);
        Assert.Equal("Forest", o.CardBackTheme);
        Assert.Equal(crimson.Id, o.ActiveThemeId);
        Assert.NotEmpty(heard);
    }

    [Fact]
    public void ApplyTheme_UsesTheSavedCopy_NotAStaleOneTheCallerHolds()
    {
        var c = new AppCoordinator();
        var saved = Theme("Saved look", FeltColorTheme.Crimson, "Forest");
        ThemeService.AddTheme(saved);
        var stale = Theme("Saved look", FeltColorTheme.FeltGreen, "Vulpera");
        stale.Id = saved.Id;

        c.ApplyTheme(stale);

        var o = SettingsService.LoadOptions();
        Assert.Equal(FeltColorTheme.Crimson, o.FeltColor);   // what's on disk wins
        Assert.Equal("Forest", o.CardBackTheme);
    }

    [Fact]
    public void ApplyTheme_SavesTheOutgoingThemesLiveTweaks_BeforeSwitching()
    {
        var c = new AppCoordinator();
        var a = Theme("Theme A", FeltColorTheme.Crimson, "Forest");
        var b = Theme("Theme B", FeltColorTheme.FeltGreen, "Vulpera");
        ThemeService.AddTheme(a);
        ThemeService.AddTheme(b);
        c.ApplyTheme(a);

        var live = SettingsService.LoadOptions();
        live.CardBackScale = 2.25;                          // a tweak made while theme A was on screen
        SettingsService.SaveOptions(live);

        c.ApplyTheme(b);

        var savedA = ThemeService.LoadThemes().Single(t => t.Id == a.Id);
        Assert.Equal(2.25, savedA.CardBackScale);           // not lost by switching away
        Assert.Equal(b.Id, SettingsService.LoadOptions().ActiveThemeId);
    }

    // ---- Klondike felt colour ----

    [Fact]
    public void UpdateFeltColor_ChangesAndSavesTheColour_AndTellsTheOtherGames()
    {
        var vm = new GameViewModel();
        var before = vm.Options.CustomFeltColorRevision;
        var heard = 0;
        var recipient = new object();
        WeakReferenceMessenger.Default.Register<object, OptionsChangedMessage>(recipient, (_, _) => heard++);
        try { vm.UpdateFeltColor(FeltColorTheme.Crimson); }
        finally { WeakReferenceMessenger.Default.UnregisterAll(recipient); }

        Assert.Equal(FeltColorTheme.Crimson, vm.Options.FeltColor);
        Assert.Equal(before + 1, vm.Options.CustomFeltColorRevision);
        Assert.True(heard >= 1);
        DataSandbox.ForgetCachedSettings();
        Assert.Equal(FeltColorTheme.Crimson, SettingsService.LoadOptions().FeltColor);
    }
}
