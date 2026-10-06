# Slush Calculation Formulas

This document provides all the mathematical formulas needed to implement the slush calculator.

## Unit Conversions

```
1 oz = 29.5735 ml
1 ml = 0.033814 oz
1 cup = 8 oz = 236.588 ml
1 tablespoon = 0.5 oz = 14.787 ml
1 teaspoon = 0.167 oz = 4.929 ml
1 liter = 33.814 oz
1 750ml bottle = 25.36 oz
```

### Swift Implementation
```swift
enum MeasurementUnit: String, Codable, CaseIterable {
    case oz, ml, cup, tablespoon, teaspoon, liter

    var toMl: Double {
        switch self {
        case .oz: return 29.5735
        case .ml: return 1.0
        case .cup: return 236.588
        case .tablespoon: return 14.787
        case .teaspoon: return 4.929
        case .liter: return 1000.0
        }
    }

    func convert(_ amount: Double, to unit: MeasurementUnit) -> Double {
        let ml = amount * self.toMl
        return ml / unit.toMl
    }
}
```

## Core Calculations

### Final ABV Calculation

The final ABV is a volume-weighted average:

```
Final ABV (%) = Σ(Vi × ABVi) / Σ(Vi)

Where:
- Vi = volume of ingredient i
- ABVi = ABV percentage of ingredient i (0-100)
```

#### Swift Implementation
```swift
func calculateFinalABV(ingredients: [(volume: Double, abv: Double)]) -> Double {
    let totalVolume = ingredients.reduce(0.0) { $0 + $1.volume }
    guard totalVolume > 0 else { return 0 }

    let totalAlcohol = ingredients.reduce(0.0) { $0 + ($1.volume * $1.abv / 100.0) }
    return (totalAlcohol / totalVolume) * 100.0
}
```

### Final Brix Calculation

The final Brix is also a volume-weighted average:

```
Final Brix (%) = Σ(Vi × Brixi) / Σ(Vi)

Where:
- Vi = volume of ingredient i
- Brixi = Brix percentage of ingredient i (0-100)
```

#### Swift Implementation
```swift
func calculateFinalBrix(ingredients: [(volume: Double, brix: Double)]) -> Double {
    let totalVolume = ingredients.reduce(0.0) { $0 + $1.volume }
    guard totalVolume > 0 else { return 0 }

    let totalSugar = ingredients.reduce(0.0) { $0 + ($1.volume * $1.brix / 100.0) }
    return (totalSugar / totalVolume) * 100.0
}
```

### Freezing Point Calculation

Simple linear approximation (accurate for 0-25% ABV), kept consistent across °C and °F:

```
Freezing Point (°C) = -0.4 × ABV%
Freezing Point (°F) = 32 - (0.72 × ABV%)
                    = (°C × 9/5) + 32
```

> Do not use the obsolete polynomial `(0.0075275 × ABV + 0.054922) × ABV + 31.947` —
> it increases freezing point with ABV and contradicts measured ethanol-water data.

#### Swift Implementation
```swift
func calculateFreezingPointCelsius(abv: Double) -> Double {
    return -0.4 * abv
}

func calculateFreezingPointFahrenheit(abv: Double) -> Double {
    let celsius = calculateFreezingPointCelsius(abv: abv)
    return celsius * 9.0 / 5.0 + 32.0
}
```

### Optimal Brix Range Based on ABV

Higher ABV drinks need slightly lower Brix to achieve proper texture:

```
Optimal Brix (low)  = MAX(12, MIN(20, 15 - 0.25 × ABV))
Optimal Brix (high) = MAX(12, MIN(20, 17 - 0.25 × ABV))
```

#### Swift Implementation
```swift
func optimalBrixRange(forABV abv: Double) -> ClosedRange<Double> {
    let low = max(12.0, min(20.0, 15.0 - 0.25 * abv))
    let high = max(12.0, min(20.0, 17.0 - 0.25 * abv))
    return low...high
}
```

## Auto-Balance Algorithms

### Calculate Water Needed to Reduce ABV

To reduce ABV from current to target by adding water (0% ABV, 0 Brix):

```
Water Needed = Current Volume × ((Current ABV / Target ABV) - 1)
```

#### Swift Implementation
```swift
func waterToReduceABV(
    currentVolume: Double,
    currentABV: Double,
    targetABV: Double
) -> Double {
    guard targetABV > 0 && currentABV > targetABV else { return 0 }
    return currentVolume * ((currentABV / targetABV) - 1)
}
```

### Calculate Sweetener Needed to Increase Brix

To increase Brix by adding simple syrup (assume 50 Brix for 1:1 syrup):

```
Let S = sweetener Brix (e.g., 50 for simple syrup)
Let V = current volume
Let B = current Brix
Let T = target Brix

Sweetener Needed = V × (T - B) / (S - T)
```

#### Swift Implementation
```swift
func sweetenerToIncreaseBrix(
    currentVolume: Double,
    currentBrix: Double,
    targetBrix: Double,
    sweetenerBrix: Double = 50.0  // 1:1 simple syrup
) -> Double {
    guard sweetenerBrix > targetBrix && targetBrix > currentBrix else { return 0 }
    return currentVolume * (targetBrix - currentBrix) / (sweetenerBrix - targetBrix)
}
```

### Calculate Water Needed to Reduce Brix

```
Water Needed = Current Volume × ((Current Brix / Target Brix) - 1)
```

#### Swift Implementation
```swift
func waterToReduceBrix(
    currentVolume: Double,
    currentBrix: Double,
    targetBrix: Double
) -> Double {
    guard targetBrix > 0 && currentBrix > targetBrix else { return 0 }
    return currentVolume * ((currentBrix / targetBrix) - 1)
}
```

## Complete Auto-Balance Algorithm

```swift
struct RecipeStats {
    let totalVolume: Double
    let finalABV: Double
    let finalBrix: Double
    let freezingPointC: Double
    let freezingPointF: Double
}

func autoBalance(
    ingredients: inout [(id: UUID, volume: Double, abv: Double, brix: Double, isWater: Bool, isSweetener: Bool)],
    targetBrixRange: ClosedRange<Double> = 13...15,
    targetABVRange: ClosedRange<Double> = 5...10,
    maxIterations: Int = 50,
    sweetenerBrix: Double = 50.0
) -> RecipeStats {

    for _ in 0..<maxIterations {
        let stats = calculateStats(ingredients: ingredients)

        // Check if within acceptable ranges
        let abvOK = targetABVRange.contains(stats.finalABV) || stats.finalABV < targetABVRange.lowerBound
        let brixOK = targetBrixRange.contains(stats.finalBrix)

        if abvOK && brixOK {
            return stats
        }

        // Priority 1: ABV too high - must add water
        if stats.finalABV > targetABVRange.upperBound {
            let waterNeeded = waterToReduceABV(
                currentVolume: stats.totalVolume,
                currentABV: stats.finalABV,
                targetABV: targetABVRange.upperBound
            )
            addWater(to: &ingredients, amount: min(waterNeeded, stats.totalVolume * 0.1))
            continue
        }

        // Priority 2: Brix too low - add sweetener
        if stats.finalBrix < targetBrixRange.lowerBound {
            let sweetenerNeeded = sweetenerToIncreaseBrix(
                currentVolume: stats.totalVolume,
                currentBrix: stats.finalBrix,
                targetBrix: targetBrixRange.lowerBound,
                sweetenerBrix: sweetenerBrix
            )
            addSweetener(to: &ingredients, amount: min(sweetenerNeeded, stats.totalVolume * 0.1), brix: sweetenerBrix)
            continue
        }

        // Priority 3: Brix too high - add water
        if stats.finalBrix > targetBrixRange.upperBound {
            let waterNeeded = waterToReduceBrix(
                currentVolume: stats.totalVolume,
                currentBrix: stats.finalBrix,
                targetBrix: targetBrixRange.upperBound
            )
            addWater(to: &ingredients, amount: min(waterNeeded, stats.totalVolume * 0.1))
            continue
        }
    }

    return calculateStats(ingredients: ingredients)
}

func calculateStats(ingredients: [(id: UUID, volume: Double, abv: Double, brix: Double, isWater: Bool, isSweetener: Bool)]) -> RecipeStats {
    let pairs = ingredients.map { (volume: $0.volume, abv: $0.abv, brix: $0.brix) }
    let totalVolume = pairs.reduce(0) { $0 + $1.volume }
    let finalABV = calculateFinalABV(ingredients: pairs.map { ($0.volume, $0.abv) })
    let finalBrix = calculateFinalBrix(ingredients: pairs.map { ($0.volume, $0.brix) })

    return RecipeStats(
        totalVolume: totalVolume,
        finalABV: finalABV,
        finalBrix: finalBrix,
        freezingPointC: calculateFreezingPointCelsius(abv: finalABV),
        freezingPointF: calculateFreezingPointFahrenheit(abv: finalABV)
    )
}
```

## Scaling Recipes

To scale a recipe to a target batch size:

```
Scale Factor = Target Volume / Current Total Volume
New Amount = Original Amount × Scale Factor
```

#### Swift Implementation
```swift
func scaleRecipe(
    ingredients: [(volume: Double, abv: Double, brix: Double)],
    toTotalVolume targetVolume: Double
) -> [(volume: Double, abv: Double, brix: Double)] {
    let currentTotal = ingredients.reduce(0) { $0 + $1.volume }
    guard currentTotal > 0 else { return ingredients }

    let scaleFactor = targetVolume / currentTotal

    return ingredients.map { ingredient in
        (volume: ingredient.volume * scaleFactor,
         abv: ingredient.abv,
         brix: ingredient.brix)
    }
}
```

## User Preference Mapping

Map preference sliders (0.0-1.0) to target ranges, then **clamp Brix into the ABV-aware science window** from `optimalBrixRange(forABV:)`:

```swift
struct DrinkPreferences {
    var sweetnessLevel: Double   // 0.0 = tart, 1.0 = sweet
    var slushThickness: Double   // 0.0 = thin/sippable, 1.0 = thick
    var alcoholStrength: Double  // 0.0 = light, 1.0 = strong
}

func toOptimizationTargets(_ prefs: DrinkPreferences) -> (brixRange: ClosedRange<Double>, abvRange: ClosedRange<Double>) {
    // Alcohol: 0.0 -> ABV 5-6%, 1.0 -> ABV 9-10%
    let abvBase = 5.0 + (prefs.alcoholStrength * 4.0)
    let abvLow = abvBase
    let abvHigh = abvBase + 1.0
    let abvMid = (abvLow + abvHigh) / 2.0

    // Science-backed Brix window for the target ABV (see Optimal Brix Range Based on ABV)
    let scienceBrix = optimalBrixRange(forABV: abvMid)
    let windowWidth = scienceBrix.upperBound - scienceBrix.lowerBound

    // Sweetness / thickness nudge *within* the science window, then clamp
    let sweetnessShift = (prefs.sweetnessLevel - 0.5) * windowWidth
    let thicknessAdjust = (prefs.slushThickness - 0.5) * (windowWidth * 0.5)

    var brixLow = scienceBrix.lowerBound + sweetnessShift + thicknessAdjust
    var brixHigh = brixLow + max(1.0, windowWidth * 0.5)
    brixLow = min(max(brixLow, scienceBrix.lowerBound), scienceBrix.upperBound - 0.5)
    brixHigh = min(max(brixHigh, brixLow + 0.5), scienceBrix.upperBound)

    return (
        brixRange: brixLow...brixHigh,
        abvRange: abvLow...abvHigh
    )
}
```

> **Note:** An older preference map (`12 + sweetness×3 ± thickness`) is obsolete. Always clamp preference Brix into `optimalBrixRange` so taste sliders cannot request unworkable sugar levels for the chosen ABV.

## Slushability Status

```swift
enum SlushabilityStatus {
    case optimal
    case tooSweet
    case notSweetEnough
    case tooAlcoholic
    case willNotFreeze
    case warning(String)

    static func evaluate(
        abv: Double,
        brix: Double,
        optimalBrixRange: ClosedRange<Double> = 13...15
    ) -> Self {
        if abv > 12 {
            return .willNotFreeze
        }

        if abv > 10 {
            return .tooAlcoholic
        }

        let hardLow = max(11.0, optimalBrixRange.lowerBound - 2.0)
        let hardHigh = min(18.0, optimalBrixRange.upperBound + 2.0)

        if brix < hardLow { return .willNotFreeze }
        if brix < optimalBrixRange.lowerBound { return .notSweetEnough }
        if brix > hardHigh { return .willNotFreeze }
        if brix > optimalBrixRange.upperBound { return .tooSweet }

        return .optimal
    }
}
```

## Rounding Rules

For display purposes:
- ABV: Round to 1 decimal place (e.g., 9.7%)
- Brix: Round to 1 decimal place (e.g., 13.5)
- Volumes in oz: Round to nearest 0.25 oz
- Volumes in ml: Round to nearest 5 ml
- Temperature: Round to 1 decimal place

```swift
func roundForDisplay(oz: Double) -> Double {
    return (oz * 4).rounded() / 4  // Nearest 0.25
}

func roundForDisplay(ml: Double) -> Double {
    return (ml / 5).rounded() * 5  // Nearest 5
}

func roundPercent(_ value: Double) -> Double {
    return (value * 10).rounded() / 10  // 1 decimal
}
```
