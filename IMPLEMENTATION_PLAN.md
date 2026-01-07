# Smart Slushi - iOS App Implementation Plan

## Implementation Progress

### ✅ Sprint 1: Foundation (COMPLETED)
- [x] Task 1.1: Create Ingredient Model (`Models/Ingredient.swift`)
- [x] Task 1.2: Create Recipe Model (`Models/Recipe.swift`)
- [x] Task 1.3: Create User Preferences Model (`Models/UserPreferences.swift`)
- [x] Task 1.4: Create Calculation Engine (`Services/SlushCalculator.swift`)
- [x] Task 2.1: Create Ingredient Data Store (`Data/IngredientDatabase.swift`)

### ✅ Sprint 2: Core UI (COMPLETED)
- [x] Task 3.1: Main Recipe Builder Screen (`Views/RecipeBuilderView.swift`)
- [x] Task 3.2: Ingredient Picker Screen (`Views/IngredientPickerView.swift`)
- [x] Task 4.1: Implement Basic Calculations (integrated with SlushCalculator)
- [x] Wire up live calculation display with QuickStatsBar component
- [x] ContentView updated to use RecipeBuilderView

### ✅ Sprint 2.5: Batch Size & Unit Improvements (COMPLETED)
- [x] Replace pre-set batch size picker with arbitrary text input
- [x] Add unit toggle (oz/cups/ml) for batch size entry
- [x] Update QuickStatsBar to display volume in selected unit
- [x] Batch size conversions work correctly when switching units

### ✅ Sprint 3: Optimization (COMPLETED)
- [x] Task 4.2: Implement Auto-Balance Algorithm (UI integration complete with before/after comparison)
- [x] Task 4.3: Implement Preference-Based Optimization (sliders show target ranges in QuickStatsBar)
- [x] Add visual feedback for optimization (OptimizationResultView shows before/after stats, ingredient changes, target ranges)
- [x] Add haptic feedback (success/warning haptics on auto-balance completion)
- [x] Test with various recipes (all 35 unit tests passing)

### ✅ Sprint 4: Templates & Persistence (COMPLETED)
- [x] Task 2.2: Add Recipe Templates (`Data/RecipeTemplates.swift`)
- [x] Task 5.1: Implement Data Persistence (SwiftData - `Models/SavedRecipe.swift`, `Data/RecipeStore.swift`)
- [x] Task 3.3: Build Recipe Templates Screen (`Views/RecipeTemplatesView.swift`)
- [x] Task 3.4: Build Saved Recipes Screen (`Views/SavedRecipesView.swift`)

### ✅ Sprint 5: Output & Sharing (COMPLETED)
- [x] Task 3.5: Build Results/Output Screen (`Views/RecipeOutputView.swift`)
  - Shopping List View with checkboxes grouped by category
  - Instructions View with step-by-step mixing guide and tips
  - Share Options (copy text, copy shopping list, share, export JSON)
- [x] Task 5.2: Implement Recipe Import/Export (`Services/RecipeSerializer.swift`)
  - JSON export/import for backup and sharing
  - Shareable text format with recipe details and stats
  - Shopping list format export
  - Import from clipboard functionality

### ✅ Sprint 6: Polish (COMPLETED)
- [x] Task 3.6: Build Settings Screen (`Views/SettingsView.swift`)
  - Default batch size preference
  - Default measurement unit (oz/ml/cups)
  - Ninja Slushi model selection (72oz vs 88oz)
  - Reset all data option
  - About/credits section
- [x] Task 6.1: Haptic Feedback
  - Success/warning haptics on auto-balance completion
  - Selection haptic when preference sliders enter optimal range
- [x] Task 6.2: Visual Feedback
  - Color-coded indicators (green/yellow/red) for ABV/Brix status
  - "Balanced" indicator on preference sliders when in optimal range
  - Animated transitions when stats change
  - Progress indicator during auto-balance
- [x] Task 6.3: Helpful Tooltips (`Views/TooltipViews.swift`)
  - Brix explanation tooltip (tap ABV/Brix badges)
  - ABV explanation tooltip
  - Slushability requirements tooltip
  - Configurable via Settings (show/hide tooltips)
- [x] Task 6.4: Onboarding Flow (`Views/OnboardingView.swift`)
  - 4-page tutorial on first launch
  - Explains app purpose and science
  - Shows auto-balance feature
  - "Show Onboarding Again" option in Settings
- [x] UserSettingsManager for persistent settings (`Services/UserSettingsManager.swift`)

---

## Project Overview

Build an iOS app that makes creating Ninja Slushi recipes "brain-dead easy" by handling all Brix and ABV calculations automatically. Users specify what drink they want, how much, and their taste preferences - the app outputs exact ingredient amounts.

---

## IMPORTANT: Reference Data Available

**All research data is pre-downloaded in the `research/` subfolder. DO NOT perform web searches - use these local files instead:**

| File | Purpose | Use For |
|------|---------|---------|
| `research/ingredient-database.json` | Complete ingredient database with ABV & Brix values | Pre-populating the app's ingredient data store. Contains 100+ ingredients across all categories (spirits, liqueurs, sweeteners, citrus, juices, purees, dairy, mixers, wine). |
| `research/recipe-templates.json` | 15 tested recipe templates with scaling info | Pre-populating recipe templates. Includes classic margarita, daiquiri, piña colada, frosé, and more. Each has base ratios and machine-ready adjustments. |
| `research/calculation-formulas.md` | Complete Swift code implementations | Copy/adapt the Swift code for all calculations: ABV, Brix, freezing point, auto-balance algorithm, scaling, preference mapping. |
| `research/slush-science.md` | Scientific principles and quick reference | Understanding the "why" behind the formulas. Target ranges, troubleshooting, machine specs. |
| `research/README.md` | Index of all research files | Quick reference to find what you need. |

### How to Use the Research Data

1. **For the Ingredient Model & Database (Tasks 1.1, 2.1)**:
   - Parse `research/ingredient-database.json` directly
   - The JSON structure matches the planned data model
   - Categories are already defined

2. **For the Recipe Templates (Task 2.2)**:
   - Parse `research/recipe-templates.json`
   - Includes both single-serve ratios and proven batch recipes
   - `machineReady` object has pre-calculated dilution ratios

3. **For the Calculation Engine (Tasks 1.4, 4.1-4.3)**:
   - `research/calculation-formulas.md` has Swift code ready to use
   - Includes: unit conversion, ABV/Brix calculation, freezing point, auto-balance algorithm
   - Copy and adapt as needed

4. **For Understanding the Science**:
   - Read `research/slush-science.md` for context
   - Key insight: Target 13-15 Brix, 0-10% ABV

---

## Research Summary: The Science of Frozen Drinks

### Critical Parameters

#### Brix (Sugar Content)
- **Definition**: Percentage of dissolved sugar by weight (1 Brix = 1g sucrose per 100g solution)
- **Target Range for Slush**: 13-15 Brix
- **Effect**: Too low = over-freezes into ice block; Too high = stays runny/soupy

#### ABV (Alcohol by Volume)
- **Target Range for Slush**: 0-10% ABV
- **Maximum Feasible**: ~10% ABV (beyond this, domestic machines cannot freeze properly)
- **Effect**: Alcohol depresses freezing point; too much prevents slush formation

#### Freezing Point
- **Formula**: Freezing Point (C) = -0.4 x ABV%
- **Ninja Slushi barrel temp**: -6C to -10C
- **Mix freezes**: 2-4C warmer than barrel sensor
- **Practical limit**: If drink freezes below -9C, it won't slush properly

### Key Formulas

```
Final ABV (%) = SUM(ingredient_volume * ingredient_ABV) / total_volume

Final Brix = SUM(ingredient_volume * ingredient_brix) / total_volume

Freezing Point (C) = -0.4 * Final_ABV

Optimal Brix Range (based on ABV) = MAX(12, MIN(20, 15 - 0.25 * ABV)) to MAX(12, MIN(20, 17 - 0.25 * ABV))
```

### Sweetness Perception Note
Cold temperatures suppress sweetness perception - frozen drinks need ~50% more sugar than room-temperature equivalents to taste the same.

---

## Ingredient Database

### Spirits (ABV%, Brix)

| Ingredient | ABV% | Brix |
|------------|------|------|
| Blanco Tequila | 40 | 0 |
| Reposado Tequila | 40 | 0 |
| Mezcal | 40-45 | 0 |
| White Rum | 40 | 0 |
| Vodka | 40 | 0 |
| Gin | 40-47 | 0 |
| Bourbon | 40-50 | 0 |
| Triple Sec (Stirrings) | 30 | 25 |
| Cointreau | 40 | 24 |
| Grand Marnier | 40 | 32 |
| Aperol | 11 | 32 |
| Campari | 24 | 24 |
| Kahlua | 20 | 49 |
| Chambord | 16.5 | 45 |
| St. Germain | 20 | 40 |
| Creme de Cassis | 15 | 45 |

### Sweeteners (ABV%, Brix)

| Ingredient | ABV% | Brix |
|------------|------|------|
| Simple Syrup (1:1 by volume) | 0 | 48 |
| Simple Syrup (2:1 by volume) | 0 | 65 |
| Agave Nectar (pure) | 0 | 75 |
| Agave Syrup (2:1 diluted) | 0 | 50 |
| Honey (pure) | 0 | 82 |
| Honey Syrup (2:1 diluted) | 0 | 55 |
| Liquid Allulose | 0 | 70* |

*Allulose: Note that allulose has different freezing properties than sugar - it's ~70% as sweet but may require adjustment

### Juices (ABV%, Brix)

| Ingredient | ABV% | Brix |
|------------|------|------|
| Fresh Lime Juice | 0 | 8 |
| Fresh Lemon Juice | 0 | 8 |
| Orange Juice | 0 | 12 |
| Grapefruit Juice | 0 | 10 |
| Pineapple Juice | 0 | 14 |
| Cranberry Juice | 0 | 11 |
| Strawberry Puree | 0 | 8 |
| Mango Puree | 0 | 15 |
| Passion Fruit Puree | 0 | 14 |
| Watermelon Juice | 0 | 8 |
| Coconut Cream (Coco Lopez) | 0 | 40 |
| Coconut Water | 0 | 5 |

### Base Liquids (ABV%, Brix)

| Ingredient | ABV% | Brix |
|------------|------|------|
| Water | 0 | 0 |
| Sparkling Water | 0 | 0 |
| Tonic Water | 0 | 8 |
| Ginger Beer | 0 | 10 |
| Cola | 0 | 11 |
| Rose Wine | 12 | 2 |
| Prosecco | 11 | 2 |

---

## Base Recipe Templates

### Classic Margarita (Standard Ratios)
Based on Ford Fry recipe:
- 1.5 oz tequila (40% ABV)
- 1 oz triple sec (30% ABV, 25 Brix)
- 0.75 oz lime juice (8 Brix)
- 0.25 oz simple syrup (48 Brix)

### Frozen Margarita (Machine Recipe - from Ford Fry)
For 603 oz batch:
- 288 oz water
- 80 oz simple syrup
- 64 oz lime juice
- 69.75 oz triple sec
- 101.5 oz tequila

This yields approximately: 6.7% ABV, 13.8 Brix

### Tommy's Margarita
- 2 oz tequila
- 1 oz lime juice
- 0.5 oz agave nectar

### Pina Colada (from spreadsheet)
- 200ml white rum (40% ABV)
- 400ml coconut cream (40 Brix)
- 800ml pineapple juice (13 Brix)
- 500ml water
- 100ml lime juice (8 Brix)

### Frose (from Ford Fry)
- 4.5L rose wine
- 30 oz strawberry puree
- 24 oz lemon juice
- 1L vodka
- 64 oz simple syrup
- 192 oz water

---

## App Architecture

### Phase 1: Core Data Models

#### Task 1.1: Create Ingredient Model
File: `Models/Ingredient.swift`
**Reference**: `research/ingredient-database.json` - use this JSON structure as a guide for the model

```
struct Ingredient: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let category: IngredientCategory
    let abv: Double           // 0-100 percentage
    let brix: Double          // 0-100 percentage
    let defaultUnit: MeasurementUnit
    let isCustom: Bool
    let notes: String?
}

enum IngredientCategory: String, Codable, CaseIterable {
    case spirit
    case liqueur
    case sweetener
    case citrus
    case juice
    case mixer
    case water
    case dairy
    case other
}

enum MeasurementUnit: String, Codable, CaseIterable {
    case oz
    case ml
    case cup
    case tablespoon
    case teaspoon
}
```

#### Task 1.2: Create Recipe Model
File: `Models/Recipe.swift`

```
struct Recipe: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String?
    var baseRecipeId: UUID?  // If based on a template
    var ingredients: [RecipeIngredient]
    var targetBatchSize: Double  // in oz
    var targetUnit: MeasurementUnit
    var createdAt: Date
    var modifiedAt: Date

    // Computed properties for calculated values
    var calculatedABV: Double
    var calculatedBrix: Double
    var calculatedFreezingPoint: Double
    var slushabilityStatus: SlushabilityStatus
}

struct RecipeIngredient: Identifiable, Codable {
    let id: UUID
    let ingredientId: UUID
    var amount: Double
    var unit: MeasurementUnit
    var isLocked: Bool  // User can lock certain ratios
}

enum SlushabilityStatus {
    case optimal           // 13-15 Brix, 0-10% ABV
    case tooSweet          // Brix > 15
    case notSweetEnough    // Brix < 13
    case tooAlcoholic      // ABV > 10%
    case willNotFreeze     // ABV > 12% or Brix issues
    case warning(String)   // Edge cases with explanation
}
```

#### Task 1.3: Create User Preferences Model
File: `Models/UserPreferences.swift`

```
struct DrinkPreferences {
    var sweetnessLevel: Double      // 0.0 (very tart) to 1.0 (very sweet), default 0.5
    var slushThickness: Double      // 0.0 (sippable) to 1.0 (thick), default 0.5
    var alcoholStrength: Double     // 0.0 (light) to 1.0 (strong), default 0.5

    // These map to target ranges:
    // sweetnessLevel -> adjusts target Brix within 12-16 range
    // slushThickness -> adjusts target Brix (lower = thinner)
    // alcoholStrength -> adjusts target ABV within 5-10% range
}
```

#### Task 1.4: Create Calculation Engine
File: `Services/SlushCalculator.swift`
**Reference**: `research/calculation-formulas.md` - contains complete Swift implementations ready to copy/adapt

Core calculation service that:
1. Takes a list of ingredients with amounts
2. Calculates total volume, final ABV, final Brix
3. Calculates freezing point
4. Determines slushability status
5. Can auto-balance a recipe given constraints

Key methods:
```
class SlushCalculator {
    // Calculate current recipe stats
    func calculateStats(for ingredients: [RecipeIngredient]) -> RecipeStats

    // Given a base recipe and target batch size, scale all ingredients
    func scaleRecipe(recipe: Recipe, toBatchSize: Double) -> Recipe

    // Given user preferences, suggest ingredient adjustments
    func optimizeRecipe(
        recipe: Recipe,
        preferences: DrinkPreferences,
        lockedIngredients: Set<UUID>
    ) -> Recipe

    // Auto-balance by adjusting water and sweetener
    func autoBalance(
        recipe: Recipe,
        targetBrix: ClosedRange<Double>,
        targetABV: ClosedRange<Double>
    ) -> Recipe
}

struct RecipeStats {
    let totalVolumeOz: Double
    let totalVolumeMl: Double
    let finalABV: Double
    let finalBrix: Double
    let freezingPointCelsius: Double
    let freezingPointFahrenheit: Double
    let slushabilityStatus: SlushabilityStatus
    let servings: Int  // Based on 8-11oz portions
    let warnings: [String]
}
```

### Phase 2: Ingredient Database

#### Task 2.1: Create Ingredient Data Store
File: `Data/IngredientDatabase.swift`
**Reference**: `research/ingredient-database.json` - LOAD THIS FILE DIRECTLY. Contains 100+ pre-populated ingredients with ABV and Brix values.

Implement a pre-populated database with all common ingredients from the research. Include:
- All spirits with correct ABV values
- All liqueurs with ABV and Brix values
- All syrups with Brix values
- All juices with Brix values
- Common mixers

Use JSON file or Core Data for persistence. Allow user-added custom ingredients.

#### Task 2.2: Create Recipe Template Store
File: `Data/RecipeTemplates.swift`
**Reference**: `research/recipe-templates.json` - LOAD THIS FILE DIRECTLY. Contains 15 pre-tested recipes with base ratios and machine-ready adjustments.

Pre-populate with tested recipes:
- Classic Margarita (frozen)
- Tommy's Margarita (frozen)
- Pina Colada
- Daiquiri
- Frozen Paloma
- Frose
- Frozen Cosmo
- Frozen Mojito
- Frozen Sangria

Each template should include:
- Base proportions (as ratios, not fixed amounts)
- Suggested ingredient substitutions
- Notes on flavor profile

### Phase 3: User Interface

#### Task 3.1: Main Recipe Builder Screen
File: `Views/RecipeBuilderView.swift`

Layout:
1. **Header**: Recipe name, batch size input (arbitrary text entry with unit toggle: oz/cup/ml)
2. **Quick Stats Bar**: Live-updating display showing:
   - Current ABV (with color indicator: green if good, yellow if warning, red if bad)
   - Current Brix (with color indicator)
   - Slushability indicator (checkmark or warning)
3. **Ingredient List**:
   - Each row shows: ingredient name, amount, unit selector, delete button
   - Swipe to delete
   - Tap to edit amount
   - "+" button to add ingredient
4. **Preference Sliders** (collapsible section):
   - Sweetness: Tart <---> Sweet
   - Thickness: Sippable <---> Thick
   - Strength: Light <---> Strong
5. **Action Buttons**:
   - "Auto-Balance" button - adjusts water/sweetener to hit targets
   - "Save Recipe" button
   - "Share Recipe" button

#### Task 3.2: Ingredient Picker Screen
File: `Views/IngredientPickerView.swift`

- Searchable list grouped by category
- Each item shows: name, ABV%, Brix
- Recent ingredients section at top
- "Add Custom Ingredient" option

#### Task 3.3: Recipe Templates Screen
File: `Views/RecipeTemplatesView.swift`

- Grid or list of recipe cards
- Each card shows: drink name, image (if available), brief description
- Tap to start with that template
- Filter by drink type (margarita, daiquiri, tropical, etc.)

#### Task 3.4: Saved Recipes Screen
File: `Views/SavedRecipesView.swift`

- List of user's saved recipes
- Swipe to delete
- Tap to load into builder
- Sort by: date created, name, most used

#### Task 3.5: Results/Output Screen
File: `Views/RecipeOutputView.swift`

After recipe is finalized, show:
1. **Shopping List View**:
   - Ingredients grouped by type
   - Amounts in both oz and ml
   - Checkboxes for shopping
2. **Instructions View**:
   - Step-by-step mixing instructions
   - Tips for the Ninja Slushi machine
   - Expected freeze time
3. **Share Options**:
   - Copy as text
   - Share as image
   - Export to Notes app

#### Task 3.6: Settings Screen
File: `Views/SettingsView.swift`

- Default batch size preference
- Default measurement unit (oz/ml)
- Ninja Slushi model selection (72oz vs 88oz)
- Reset all data option
- About/credits

### Phase 4: Core Algorithm Implementation

#### Task 4.1: Implement Basic Calculations
File: `Services/SlushCalculator.swift`
**Reference**: `research/calculation-formulas.md` - Copy the Swift code from the "Core Calculations" section

```swift
// Convert all amounts to common unit (ml) first
func normalizeToMl(amount: Double, unit: MeasurementUnit) -> Double

// Calculate weighted ABV
func calculateFinalABV(ingredients: [(volume: Double, abv: Double)]) -> Double {
    let totalVolume = ingredients.reduce(0) { $0 + $1.volume }
    let totalAlcohol = ingredients.reduce(0) { $0 + ($1.volume * $1.abv / 100) }
    return (totalAlcohol / totalVolume) * 100
}

// Calculate weighted Brix
func calculateFinalBrix(ingredients: [(volume: Double, brix: Double)]) -> Double {
    let totalVolume = ingredients.reduce(0) { $0 + $1.volume }
    let totalSugar = ingredients.reduce(0) { $0 + ($1.volume * $1.brix / 100) }
    return (totalSugar / totalVolume) * 100
}

// Calculate freezing point
func calculateFreezingPoint(abv: Double) -> Double {
    return -0.4 * abv  // Returns Celsius
}
```

#### Task 4.2: Implement Auto-Balance Algorithm
File: `Services/RecipeOptimizer.swift`
**Reference**: `research/calculation-formulas.md` - See "Auto-Balance Algorithms" and "Complete Auto-Balance Algorithm" sections for full implementation

The auto-balance algorithm should:
1. Identify which ingredients can be adjusted (water, sweetener)
2. Calculate current stats
3. If ABV too high: add water (dilutes both ABV and Brix)
4. If Brix too low after dilution: add sweetener
5. If Brix too high: add water
6. Iterate until within target range or max iterations reached

```swift
func autoBalance(
    recipe: Recipe,
    targetBrix: ClosedRange<Double> = 13...15,
    targetABV: ClosedRange<Double> = 5...10,
    maxIterations: Int = 100
) -> Recipe {
    var workingRecipe = recipe

    for _ in 0..<maxIterations {
        let stats = calculateStats(for: workingRecipe.ingredients)

        // Check if we're within targets
        if targetBrix.contains(stats.finalBrix) && targetABV.contains(stats.finalABV) {
            break
        }

        // ABV too high - add water
        if stats.finalABV > targetABV.upperBound {
            let waterNeeded = calculateWaterToReduceABV(
                currentVolume: stats.totalVolumeOz,
                currentABV: stats.finalABV,
                targetABV: targetABV.upperBound
            )
            workingRecipe = addWater(to: workingRecipe, amount: waterNeeded)
            continue
        }

        // Brix too low - add sweetener
        if stats.finalBrix < targetBrix.lowerBound {
            let sweetenerNeeded = calculateSweetenerToIncreaseBrix(
                currentVolume: stats.totalVolumeOz,
                currentBrix: stats.finalBrix,
                targetBrix: targetBrix.lowerBound
            )
            workingRecipe = addSweetener(to: workingRecipe, amount: sweetenerNeeded)
            continue
        }

        // Brix too high - add water
        if stats.finalBrix > targetBrix.upperBound {
            let waterNeeded = calculateWaterToReduceBrix(
                currentVolume: stats.totalVolumeOz,
                currentBrix: stats.finalBrix,
                targetBrix: targetBrix.upperBound
            )
            workingRecipe = addWater(to: workingRecipe, amount: waterNeeded)
            continue
        }
    }

    return workingRecipe
}
```

#### Task 4.3: Implement Preference-Based Optimization
File: `Services/RecipeOptimizer.swift`
**Reference**: `research/calculation-formulas.md` - See "User Preference Mapping" section for the slider-to-target-range logic

Map user preference sliders to target ranges:

```swift
func mapPreferencesToTargets(preferences: DrinkPreferences) -> OptimizationTargets {
    // Sweetness: 0.0 = tart (Brix 12-13), 1.0 = sweet (Brix 15-16)
    let brixLow = 12.0 + (preferences.sweetnessLevel * 3.0)
    let brixHigh = brixLow + 1.0

    // Thickness affects Brix target too - thicker = slightly higher Brix
    let thicknessAdjustment = (preferences.slushThickness - 0.5) * 1.0

    // Alcohol strength: 0.0 = light (5-6%), 1.0 = strong (9-10%)
    let abvLow = 5.0 + (preferences.alcoholStrength * 4.0)
    let abvHigh = abvLow + 1.0

    return OptimizationTargets(
        brixRange: (brixLow + thicknessAdjustment)...(brixHigh + thicknessAdjustment),
        abvRange: abvLow...abvHigh
    )
}
```

### Phase 5: Data Persistence

#### Task 5.1: Implement Core Data Stack
File: `Data/CoreDataStack.swift`

Store:
- Custom ingredients
- Saved recipes
- User preferences
- Usage history (for "recent ingredients")

#### Task 5.2: Implement Recipe Import/Export
File: `Services/RecipeSerializer.swift`

Support:
- JSON export/import for backup
- Shareable text format
- Copy to clipboard functionality

### Phase 6: Polish & UX

#### Task 6.1: Add Haptic Feedback
- Haptic when sliders hit optimal range
- Success haptic when recipe is balanced
- Warning haptic when recipe goes out of range

#### Task 6.2: Add Visual Feedback
- Color-coded indicators (green/yellow/red)
- Animated transitions when stats change
- Progress indicator during auto-balance

#### Task 6.3: Add Helpful Tooltips
- Explain what Brix means on first use
- Explain what ABV means
- Explain slushability requirements

#### Task 6.4: Add Onboarding Flow
- Brief tutorial on first launch
- Explain the science simply
- Show example of creating first recipe

---

## Implementation Order

### Sprint 1: Foundation (Tasks 1.1-1.4, 2.1)
1. Create all data models
2. Implement calculation engine with unit tests
3. Create ingredient database with hardcoded data
4. Verify calculations match expected outputs from research

### Sprint 2: Core UI (Tasks 3.1-3.2, 4.1)
1. Build recipe builder screen (basic version)
2. Build ingredient picker
3. Wire up live calculation display
4. Test basic flow end-to-end

### Sprint 3: Optimization (Tasks 4.2-4.3)
1. Implement auto-balance algorithm
2. Implement preference sliders
3. Add visual feedback for optimization
4. Test with various recipes

### Sprint 4: Templates & Persistence (Tasks 2.2, 3.3-3.4, 5.1)
1. Add recipe templates
2. Implement Core Data persistence
3. Build saved recipes screen
4. Build templates browser

### Sprint 5: Output & Sharing (Tasks 3.5, 5.2)
1. Build results/output screen
2. Implement share functionality
3. Add shopping list feature
4. Test export/import

### Sprint 6: Polish (Tasks 3.6, 6.1-6.4)
1. Build settings screen
2. Add haptic feedback
3. Improve visual feedback
4. Add onboarding
5. Final testing and bug fixes

---

## Testing Strategy

### Unit Tests
- `SlushCalculatorTests`: Test all calculation methods
- `RecipeOptimizerTests`: Test auto-balance with various inputs
- `IngredientDatabaseTests`: Test data integrity

### Test Cases for Calculations
1. **Ford Fry Frozen Margarita**: Input the exact batch recipe, verify ABV ~6.7%, Brix ~13.8
2. **High ABV Recipe**: Verify warning when ABV > 10%
3. **Low Brix Recipe**: Verify auto-balance adds sweetener
4. **Edge Cases**: Empty recipe, single ingredient, all water, all alcohol

### UI Tests
- Recipe builder flow
- Ingredient selection
- Save/load recipes
- Share functionality

---

## Technical Notes

### Ninja Slushi Specifics
- 72oz model: Use 64oz as working capacity
- 88oz model: Use 80oz as working capacity
- Freeze time: 15-60 minutes depending on volume
- Optimal serve temp: ~21F (-6C)

### Calculation Precision
- Round Brix to 1 decimal place for display
- Round ABV to 1 decimal place for display
- Round ingredient amounts to nearest 0.25 oz or 5ml

### Unit Conversions
- 1 oz = 29.5735 ml
- 1 cup = 8 oz = 236.588 ml
- 1 tbsp = 0.5 oz = 14.787 ml
- 1 tsp = 0.167 oz = 4.929 ml

---

## Sources

- [Slush Calculator](https://slushcalculator.com/)
- [Jeffrey Morgenthaler - How to Use a Slushie Machine](https://jeffreymorgenthaler.com/how-to-use-a-slushie-machine/)
- [PUNCH - Science Your Way to a Better Frozen Drink](https://punchdrink.com/articles/science-your-way-better-frozen-drink-recipe/)
- [Diffords Guide - Degree of Sweetness (Brix)](https://www.diffordsguide.com/encyclopedia/3594/cocktails/degree-of-sweetness-brix)
- [Ninja Slushi Official](https://www.sharkninja.com/ninja-slushi-professional-frozen-drink-maker/)
- Ford Fry Drink Bible (internal document)
- Slushi Batching Spreadsheet (internal document)
