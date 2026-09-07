package com.leah.honeycomb.honeycomb

enum class HoneycombRuleState {
    Auto, Picked, Banned
}

sealed class HoneycombRuleRowID {
    data class Rule(val rule: HoneycombRule) : HoneycombRuleRowID()
    object NormalMode : HoneycombRuleRowID()

    val isPickable: Boolean get() = true

    val banName: String
        get() = when (this) {
            is NormalMode -> "Normal Mode"
            is Rule -> rule.name // Use enum name for serialization consistency
        }

    companion object {
        val allCases: List<HoneycombRuleRowID> by lazy {
            listOf(NormalMode) + HoneycombRule.values().map { Rule(it) }
        }
    }
}

object HoneycombRuleSelection {
    fun state(
        id: HoneycombRuleRowID,
        selectedRules: Set<HoneycombRule>,
        forceNormalMode: Boolean,
        bannedRules: Set<String>
    ): HoneycombRuleState {
        if (bannedRules.contains(id.banName)) return HoneycombRuleState.Banned
        return when (id) {
            is HoneycombRuleRowID.NormalMode -> if (forceNormalMode) HoneycombRuleState.Picked else HoneycombRuleState.Auto
            is HoneycombRuleRowID.Rule -> if (selectedRules.contains(id.rule)) HoneycombRuleState.Picked else HoneycombRuleState.Auto
        }
    }

    // Returns true if the ban was blocked by the "can't ban everything" guard.
    fun setState(
        newState: HoneycombRuleState,
        id: HoneycombRuleRowID,
        selectedRules: MutableSet<HoneycombRule>,
        forceNormalMode: MutableList<Boolean>, // Using list size 1 to mutate reference
        bannedRules: MutableSet<String>
    ): Boolean {
        when (newState) {
            HoneycombRuleState.Auto -> {
                bannedRules.remove(id.banName)
                if (id is HoneycombRuleRowID.NormalMode) forceNormalMode[0] = false
                if (id is HoneycombRuleRowID.Rule) selectedRules.remove(id.rule)
                return false
            }
            HoneycombRuleState.Picked -> {
                if (!id.isPickable) return false
                bannedRules.remove(id.banName)
                when (id) {
                    is HoneycombRuleRowID.NormalMode -> {
                        forceNormalMode[0] = true
                        selectedRules.clear()
                    }
                    is HoneycombRuleRowID.Rule -> {
                        val r = id.rule
                        if (r == HoneycombRule.Ascension) selectedRules.remove(HoneycombRule.Descension)
                        if (r == HoneycombRule.Descension) selectedRules.remove(HoneycombRule.Ascension)
                        if (r == HoneycombRule.Order) selectedRules.remove(HoneycombRule.Chaos)
                        if (r == HoneycombRule.Chaos) selectedRules.remove(HoneycombRule.Order)
                        if (r == HoneycombRule.AllOpen) selectedRules.remove(HoneycombRule.ThreeOpen)
                        if (r == HoneycombRule.ThreeOpen) selectedRules.remove(HoneycombRule.AllOpen)
                        if (r == HoneycombRule.AllOpen || r == HoneycombRule.ThreeOpen) selectedRules.remove(HoneycombRule.BombShelter)
                        if (r == HoneycombRule.BombShelter) {
                            selectedRules.remove(HoneycombRule.AllOpen)
                            selectedRules.remove(HoneycombRule.ThreeOpen)
                        }

                        if (selectedRules.size < 4) {
                            selectedRules.add(r)
                            forceNormalMode[0] = false
                        }
                    }
                }
                return false
            }
            HoneycombRuleState.Banned -> {
                if (bannedRules.size >= HoneycombRuleRowID.allCases.size - 1 && !bannedRules.contains(id.banName)) {
                    return true
                }
                if (id is HoneycombRuleRowID.NormalMode) forceNormalMode[0] = false
                if (id is HoneycombRuleRowID.Rule) selectedRules.remove(id.rule)
                bannedRules.add(id.banName)
                return false
            }
        }
    }
}
