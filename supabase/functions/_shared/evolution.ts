// Port of only createInitialPlan() from evolution_engine.dart: it's
// all that's needed at capture time. The determineSecondType() logic
// will be ported into an evolve-wildkin function once we build that.
//
// IMPORTANT: these ranges must stay identical to the ones in
// lib/models/evolution_plan.dart (EvolutionRanges), otherwise the
// "soon / average / late" hint shown by the client stops matching
// the thresholds generated here.

export interface EvolutionPlanJson {
  total_stages: number;
  current_stage: number;
  next_evolution_level: number;
  second_evolution_level: number | null;
}

const FIRST_JUMP_OF_THREE_STAGE = { min: 15, max: 30 };
const SECOND_JUMP_OF_THREE_STAGE = { min: 30, max: 50 };
const ONLY_JUMP_OF_TWO_STAGE = { min: 30, max: 50 };

function randomInRange(range: { min: number; max: number }): number {
  return range.min + Math.floor(Math.random() * (range.max - range.min + 1));
}

export function createInitialEvolutionPlan(): EvolutionPlanJson {
  const totalStages = Math.random() < 0.5 ? 2 : 3;

  if (totalStages === 2) {
    return {
      total_stages: 2,
      current_stage: 1,
      next_evolution_level: randomInRange(ONLY_JUMP_OF_TWO_STAGE),
      second_evolution_level: null,
    };
  }

  const firstLevel = randomInRange(FIRST_JUMP_OF_THREE_STAGE);
  const secondLevel = randomInRange(SECOND_JUMP_OF_THREE_STAGE);
  const adjustedSecond = Math.max(secondLevel, firstLevel + 5);

  return {
    total_stages: 3,
    current_stage: 1,
    next_evolution_level: firstLevel,
    second_evolution_level: adjustedSecond,
  };
}
