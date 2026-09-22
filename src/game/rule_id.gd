class_name RuleId
extends RefCounted
## backend/RuleManager.cs RuleId - the GNPRTB entry ids this codebase reads by
## name. Values live in the pack, NOT here - if you find yourself putting a
## number next to one of these, that is the bug this class exists to prevent.

# --- travel ---
const SpaceTravelBase           := 1
const SpaceTravelHanSolo        := 60
const SpaceTravelDistanceDiv    := 74

# --- ground combat ---
const BatteryResponseDivisor    := 2
const TroopContestGeneralDiv    := 3
const TroopContestRandomWidth   := 4
const TroopContestDefenderMax   := 5
const TroopContestAttackerMin   := 6
const BatteryOfficerDiv         := 8
const ShipBombardOfficerDiv     := 9
const StrikePermissionMin       := 10
const StrikePermissionMax       := 11
const ShieldsToPreventAssault   := 151

# --- injury and healing ---
const FastHealSpecialPowerThresh   := 21
const FastHealDelayTicks        := 22
const NormalHealDelayTicks      := 23
const FastHealReductionPerTick  := 24
const InjuredCombatPointsPerDay := 25
const AbductionInjuryFloor      := 26
const AbductionInjuryBase       := 27
const AbductionInjurySpread     := 28
const SecondaryInjuryBase       := 30
const SecondaryInjurySpread     := 31
const FallbackInjuryBase        := 33
const FallbackInjurySpread      := 34
const AssassinInjuryBase        := 36
const AssassinInjurySpread      := 37
const PostInjuryFollowupChance  := 38

# --- the Force ---
const LowForceStatusThresh      := 40
const DiscoverForceUserThresh   := 41
const ForceQualifiedThresh      := 42
const PilgrimageInjuryCeiling      := 54   # was PilgrimageInjuryCeiling
const PilgrimageTriggerBase        := 101   # was PilgrimageTriggerBase
const PilgrimageTriggerSpread      := 102   # was PilgrimageTriggerSpread
const PilgrimageBonusPercent       := 129   # was PilgrimageBonusPercent
const PilgrimagePartialDivisor     := 130   # was PilgrimagePartialDivisor
const PilgrimKnowsHeritageThresh   := 55   # was PilgrimKnowsHeritageThresh
const OrdinaryMissionForceReward := 58
const EncounterScanBase         := 43
const EncounterScanSpread       := 44
const EncounterOwnSideMinRank   := 66
const EncounterEnemyMinRank     := 67
const EncounterProbabilityOffset := 68
const PilgrimVsDarkLordGainScale      := 49   # was PilgrimVsDarkLordGainScale
const PilgrimVsDarkMasterGainScale    := 50   # was PilgrimVsDarkMasterGainScale
const HeirVsDarkLordGainScale      := 51   # was HeirVsDarkLordGainScale
const HeirVsDarkMasterGainScale    := 52   # was HeirVsDarkMasterGainScale
const PilgrimVsDarkLordGainMin        := 61   # was PilgrimVsDarkLordGainMin
const PilgrimVsDarkMasterGainMin      := 62   # was PilgrimVsDarkMasterGainMin
const HeirVsDarkLordGainMin        := 63   # was HeirVsDarkLordGainMin
const HeirVsDarkMasterGainMin      := 64   # was HeirVsDarkMasterGainMin
const HeritageInjuryBase        := 56
const HeritageInjurySpread      := 57

# --- the Final Battle ---
const FinalBattleWinThreshold   := 106
const FinalBattleLossInjuryBase := 107
const FinalBattleLossInjurySpread := 108

# --- the bounty hunters, and Jabba's palace ---
const BountyHunterBase          := 103
const BountyHunterSpread        := 104
const BountyHunterChance        := 105
const PalaceEspionageDivisor    := 109
const PalaceCombatDivisor       := 110

# --- captivity ---
const EscapeTimerBase           := 45
const EscapeTimerSpread         := 46

# --- the Death Star ---
const SuperweaponSabotageEspionageGain := 122   # was SuperweaponSabotageEspionageGain
const SuperweaponSabotageCombatGain    := 123   # was SuperweaponSabotageCombatGain

# --- day-zero logistics --- (side A / side B = playable-faction order)
const SeedFirstWorldFirst      := 84   # was SeedFirstWorldFirst
const SeedFirstWorldMax        := 85   # was SeedFirstWorldMax
const SeedHiddenHqFirst := 86   # was SeedHiddenHqFirst
const SeedHiddenHqMax   := 87   # was SeedHiddenHqMax
const SeedCapitalFirst  := 88   # was SeedCapitalFirst
const SeedCapitalMax    := 89   # was SeedCapitalMax
const SeedSideAFleetFirst := 90   # was SeedSideAFleetFirst
const SeedSideAFleetMax   := 91   # was SeedSideAFleetMax
const SeedSideBFleetFirst   := 92   # was SeedSideBFleetFirst
const SeedSideBFleetMax     := 93   # was SeedSideBFleetMax
const SeedHqFacilitiesFirst  := 94
const SeedHqFacilitiesMax    := 95
const SeedCapitalFacilitiesFirst := 96   # was SeedCapitalFacilitiesFirst
const SeedCapitalFacilitiesMax   := 97   # was SeedCapitalFacilitiesMax

# --- repair, and squadron replenishment ---
const CapitalFastRepairDelay   := 19
const CapitalNormalRepairDelay := 20
const SquadronRecoverWithYard  := 72
const SquadronRecoverNoYard    := 73

# --- smuggling ---
const SmugglingSupportShift     := 157
const SmugglingSupportThreshold := 158
const SmugglingFollowupDelay    := 160

# --- blockades ---
const BlockadeCapitalShipPenalty := 152
const BlockadeFighterPenalty     := 153
const BlockadeSupportShiftMatching   := 161
const BlockadeDriftDelayMatching     := 162
const BlockadeSupportShiftMismatched := 163
const BlockadeDriftDelayMismatched   := 164

# --- informants ---
const InformantFrequencyBase    := 171
const InformantFrequencySpread  := 172
const InformantEventIndexBase   := 177
const InformantEventIndexSpread := 178

# --- loyalty ---
const LoyaltyShiftSpread        := 47
const LoyaltyShiftBase          := 48

# --- espionage and decoys ---
const HostileFoilScoreBias      := 65
const DecoyStatDebuffPercent    := 69
const DefenderEspionagePenalty  := 70
const EspionageRevealFloor      := 131
const EspionageRevealSpread     := 132
const EspionageRevealCapitalFloor  := 133   # was EspionageRevealCapitalFloor
const EspionageRevealCapitalSpread := 134   # was EspionageRevealCapitalSpread
const EspionageRevealHqFloor    := 135
const EspionageRevealHqSpread   := 136

# --- mission rewards ---
const ResearchPointsBase        := 126
const ResearchPointsSpread      := 127
const SpecialPowerTrainingGainSpread    := 128   # was SpecialPowerTrainingGainSpread

# Per-mission skill growth on success (guide p094-095). Each is 1 in the shipped
# tables. SuperweaponSabotage (122/123) is applied in its own success block; the three
# Research types (113) grow faction research, not a character rating, so are omitted.
const DiplomacySuccessDiplomacyGain       := 111
const EspionageSuccessEspionageGain       := 112
const RecruitmentSuccessLeadershipGain    := 114
const InciteUprisingSuccessLeadershipGain := 115
const SubdueUprisingSuccessLeadershipGain := 116
const RescueSuccessCombatGain             := 117
const AbductionSuccessCombatGain          := 118
const AssassinationSuccessCombatGain      := 119
const SabotageSuccessEspionageGain        := 120
const SabotageSuccessCombatGain           := 121

# HQ relocation: the support magnitude a hidden, movable HQ lends its system. Applied as
# the small loyalty drop on the world the HQ leaves (manual p090). ⚠ INFERRED sign/use:
# the manual gives "small drop" qualitatively; entry 174 is the shipped HQ support
# magnitude (=5). Measurement in the original would confirm the exact departure cost.
const HiddenHqSupportShift := 174   # was HiddenHqSupportShift

# --- diplomacy and uprisings ---
const DiploOccupiedGainBase     := 137
const DiploOccupiedGainSpread   := 138
const DiploNeutralGainBase      := 139
const DiploNeutralGainSpread    := 140
const SubdueMatchingShiftBase   := 141
const SubdueMatchingShiftSpread := 142
const SubdueNeutralShiftBase    := 143
const SubdueNeutralShiftSpread  := 144

# --- research, passive ---
const PassiveResearchRateA      := 146
const PassiveResearchRateB      := 147

# --- planets and garrisons ---
const UprisingGarrisonMultiple  := 150
const OrbitalStrikeSupportShift := 173
const GarrisonUprisingThresh    := 207
const GarrisonTroopOrder        := 208
const ActiveUprisingSupportShift  := 165
const UprisingSupportDriftDelay   := 166
const UprisingClearBase           := 167
const UprisingClearSpread         := 168
const UprisingIncidentBase        := 169
const UprisingIncidentSpread      := 170
const UprisingRollBase            := 175
const UprisingRollSpread          := 176

# --- galaxy generation ---
const MineSlotsHardMax          := 180
const EnergySlotsHardMax        := 182
const CoreEnergySlotsBase       := 189
const CoreEnergySlotsSpread     := 190
const CoreMineSlotsBase         := 191
const CoreMineSlotsSpread       := 192
const RimEnergySlotsBase        := 193
const RimEnergySlotsSpread1     := 194
const RimEnergySlotsSpread2     := 195
const RimMineSlotsBase          := 196
const RimMineSlotsSpread        := 197
const CoreMineChancePerSlot     := 212
const RimMineChancePerSlot      := 213
const CorePopulatedPct          := 198
const RimPopulatedPct           := 199
const NeutralCoreSupportSpread  := 210
const RimSupportSpread          := 211
