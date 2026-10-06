# The Science of Frozen Drinks

## Overview

Creating a perfect slush requires balancing two key factors:
1. **Brix** (sugar content) - controls texture and freezing behavior
2. **ABV** (alcohol content) - depresses freezing point

## Brix Explained

**Definition**: Brix (symbol: °Bx) measures the sugar content of a solution. One degree Brix equals 1 gram of sucrose per 100 grams of solution.

### Target Range for Slush Machines
- **Optimal**: 13-15 Brix
- **Acceptable**: 11-18 Brix
- **Below 13 Brix**: Solution will over-freeze, becoming icy/chunky
- **Above 15 Brix**: Solution stays too runny, won't hold slush texture

### How Sugar Affects Freezing
Sugar molecules physically hinder ice crystal formation by:
1. Interfering with hydrogen bonding between water molecules
2. Lowering the freezing point (freezing point depression)
3. Creating a "softer" ice crystal structure when frozen

### Cold Temperature and Sweetness Perception
Important: Cold suppresses sweetness perception on the tongue. Frozen drinks need approximately **50% more sugar** than room-temperature drinks to taste equally sweet.

**Practical Application**: When converting a standard cocktail to frozen format, increase sugar content by ~50%.

## ABV (Alcohol by Volume) Explained

**Definition**: The percentage of alcohol (ethanol) in a solution by volume.

### Target Range for Home Slush Machines
- **Optimal**: 5-10% ABV
- **Maximum feasible**: ~10% ABV
- **Above 10% ABV**: Most home machines cannot achieve proper freeze

### Why Alcohol Prevents Freezing
Ethanol has a much lower freezing point (-114°C) than water (0°C). When mixed:
- Alcohol molecules disrupt water's crystal lattice formation
- Higher ABV = lower freezing point = harder to slush

### Freezing Point by ABV

| ABV % | Freezing Point (°C) | Freezing Point (°F) |
|-------|--------------------|--------------------|
| 0% | 0 | 32 |
| 5% | -2 | 28.4 |
| 10% | -4 | 24.8 |
| 15% | -6 | 21.2 |
| 20% | -8 | 17.6 |
| 25% | -10 | 14 |
| 30% | -12 | 10.4 |
| 40% | -23 | -9.4 |

### Freezing Point Formula
```
Freezing Point (°C) ≈ -0.4 × ABV%
Freezing Point (°F) ≈ 32 − (0.72 × ABV%)   // equivalent: °C × 9/5 + 32
```

These stay consistent with each other for the 0–25% ABV range used in slush recipes.
The linear model matches measured ethanol-water data well through ~25% ABV; above that,
real freezing points drop faster (e.g. 40% ABV is colder than the linear estimate).

> Note: An older polynomial form that appeared in early drafts (`(0.0075275 × ABV + 0.054922) × ABV + 31.947`)
> incorrectly *raises* freezing point with ABV and must not be used.

## Ninja Slushi Machine Specifications

### Temperature Range
- **Barrel temperature**: -6°C to -10°C (21°F to 14°F)
- **Mix freezes**: 2-4°C warmer than barrel sensor reading
- **Optimal serve temperature**: -2.2°C (28°F)

### Practical Implications
- If your drink's freezing point is below -9°C, it won't slush properly
- At 10% ABV, freezing point is -4°C, which is achievable
- At 15% ABV, freezing point is -6°C, borderline for most machines

### Machine Capacities
- **72oz model**: Working capacity ~64oz
- **88oz model**: Working capacity ~80oz

### Freeze Times
- 15-60 minutes depending on:
  - Starting temperature of ingredients
  - Total volume
  - ABV and Brix levels
  - Ambient temperature

## Optimal Brix Based on ABV

Research from commercial slush operations shows that optimal Brix should be adjusted based on ABV:

```
Optimal Brix (low) = MAX(12, MIN(20, 15 - 0.25 × ABV))
Optimal Brix (high) = MAX(12, MIN(20, 17 - 0.25 × ABV))
```

| ABV % | Optimal Brix Range |
|-------|-------------------|
| 0% | 15-17 |
| 2% | 14.5-16.5 |
| 4% | 14-16 |
| 6% | 13.5-15.5 |
| 8% | 13-15 |
| 10% | 12.5-14.5 |

## The Balancing Act

### Problem: High ABV
- Symptom: Won't freeze, stays liquid
- Solution: Add water or non-alcoholic mixer to dilute

### Problem: Low Brix
- Symptom: Over-freezes, becomes icy block
- Solution: Add sweetener (simple syrup, agave, etc.)

### Problem: High Brix
- Symptom: Stays runny, won't hold texture
- Solution: Add water to dilute

### Problem: ABV within range but still won't slush
- Likely cause: Brix is off
- Solution: Measure/calculate Brix and adjust

## Measurement Tools

### Refractometer
- Measures Brix directly
- Cost: $15-30
- Limitation: Does not work accurately when alcohol is present (alcohol also refracts light)

### Calculation Method (Preferred for Cocktails)
Since refractometers don't work well with alcohol, calculate Brix from known ingredient values:
```
Final Brix = SUM(ingredient_volume × ingredient_brix) / total_volume
```

## Dilution Requirements

Frozen drinks require more dilution than shaken/stirred drinks:
- Standard cocktail dilution: 15-25%
- Frozen drink dilution: 20-30%

### Pre-dilution Recommendation
Add 20% water to your cocktail mix before adding to slush machine:
```
Water to add = Total cocktail volume × 0.2
```

## Key Takeaways

1. **Target 13-15 Brix** for optimal slush texture
2. **Keep ABV at or below 10%** for home machines
3. **Calculate, don't guess** - use known ingredient values
4. **Add water** to reduce both ABV and Brix
5. **Add sweetener** to increase Brix without affecting ABV significantly
6. **Pre-chill ingredients** to reduce freeze time
7. **Sours work best** (Margaritas, Daiquiris) - they're naturally balanced for freezing

## Sources

- Jeffrey Morgenthaler, "How to Use a Slushie Machine"
- White Lyan / PUNCH, "Science Your Way to a Better Frozen Drink"
- Campari Academy, "The Frozen Drink Guide"
- Engineering Toolbox, "Ethanol-Water Freezing Points"
- Commercial slush machine operation manuals
