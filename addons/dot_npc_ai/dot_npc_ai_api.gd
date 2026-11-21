extends RefCounted

## GameSpice NPC AI's API level. The rule for bumping it is on [GSAddonApi].
## LEVEL rises by one for anything new a game could call; OLDEST is raised to LEVEL when something callable is removed or changes meaning, since older packs no longer compile.

# 1: before this file existed. 2: map annotations (GSNpcAiNavAnnotations, GSNpcAiNavAnnotator, GSNpcAiNavDebug). 3: GSNpcAiTokenConfig, attack tokens on GSNpcAiSquad, GSNpcAiTactics.best_flank,
# GSNpcAiBrain.hold_off, line_clear and cruise_between_thinks, GSNpcAiScheduler. 4: utility scoring (GSNpcAiCurve, Personality, Utility, UtilityConfig, UtilityGate; GSNpcAiBrain.use_utility, utility_choose).
# 5: GSNpcAiCrowdGrid (per-tick spatial hash), GSNpcAiBrain.separation to override.
const LEVEL := 5
const OLDEST := 1
