package com.leah.honeycomb.honeycomb

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.leah.honeycomb.LocalAppContainer
import com.leah.honeycomb.StringKey
import com.leah.honeycomb.Strings

// Auto/Pick/Ban selection for the house rules a match can roll. Backed entirely by the
// existing HoneycombRuleSelectionEngine state machine — this screen is just a UI over it.
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HoneycombRulesScreen(viewModel: HoneycombViewModel, onBack: () -> Unit) {
    val options by viewModel.options.collectAsState()
    val language by LocalAppContainer.current.language.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(Strings.get(StringKey.ToolbarRules, language)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.ArrowBack, contentDescription = Strings.get(StringKey.Back, language))
                    }
                }
            )
        }
    ) { padding ->
        LazyColumn(modifier = Modifier.fillMaxSize().padding(padding)) {
            items(HoneycombRuleRowID.allCases) { id ->
                val label = when (id) {
                    is HoneycombRuleRowID.NormalMode -> Strings.get(StringKey.ForceNormalRulesToggle, language)
                    is HoneycombRuleRowID.Rule -> id.rule.displayName
                }
                val description = when (id) {
                    is HoneycombRuleRowID.NormalMode -> Strings.get(StringKey.NormalModeBanListTooltip, language)
                    is HoneycombRuleRowID.Rule -> id.rule.explanation(emptySet())
                }
                val state = HoneycombRuleSelection.state(
                    id, options.selectedRules, options.forceNormalMode, options.bannedRules
                )

                Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f).padding(end = 8.dp)) {
                            Text(label, style = MaterialTheme.typography.titleSmall)
                            Text(description, style = MaterialTheme.typography.bodySmall)
                        }
                        SingleChoiceSegmentedButtonRow {
                            listOf(
                                HoneycombRuleState.Auto to Strings.get(StringKey.RuleStateAuto, language),
                                HoneycombRuleState.Picked to Strings.get(StringKey.RuleStatePick, language),
                                HoneycombRuleState.Banned to Strings.get(StringKey.RuleStateBan, language)
                            ).forEachIndexed { index, (candidateState, text) ->
                                SegmentedButton(
                                    selected = state == candidateState,
                                    onClick = {
                                        val selectedRules = options.selectedRules.toMutableSet()
                                        val forceNormalMode = mutableListOf(options.forceNormalMode)
                                        val bannedRules = options.bannedRules.toMutableSet()
                                        val blocked = HoneycombRuleSelection.setState(
                                            candidateState, id, selectedRules, forceNormalMode, bannedRules
                                        )
                                        if (!blocked) {
                                            viewModel.updateOptions(
                                                options.copy(
                                                    selectedRules = selectedRules,
                                                    forceNormalMode = forceNormalMode[0],
                                                    bannedRules = bannedRules
                                                )
                                            )
                                        }
                                    },
                                    shape = SegmentedButtonDefaults.itemShape(index = index, count = 3)
                                ) {
                                    Text(text, style = MaterialTheme.typography.labelSmall)
                                }
                            }
                        }
                    }
                }
                HorizontalDivider()
            }
        }
    }
}
