import Testing
import Foundation
@testable import SmartSlushiFeature

// MARK: - Measurement Unit Tests

@Suite("Measurement Unit Tests")
struct MeasurementUnitTests {
    @Test("Convert ounces to milliliters")
    func ozToMl() {
        let oz = MeasurementUnit.oz
        let result = oz.convert(1.0, to: .ml)
        #expect(abs(result - 29.5735) < 0.001)
    }

    @Test("Convert milliliters to ounces")
    func mlToOz() {
        let ml = MeasurementUnit.ml
        let result = ml.convert(29.5735, to: .oz)
        #expect(abs(result - 1.0) < 0.001)
    }

    @Test("Convert cups to milliliters")
    func cupToMl() {
        let cup = MeasurementUnit.cup
        let result = cup.convert(1.0, to: .ml)
        #expect(abs(result - 236.588) < 0.001)
    }

    @Test("Round trip conversion")
    func roundTrip() {
        let original = 5.0
        let inMl = MeasurementUnit.oz.convert(original, to: .ml)
        let backToOz = MeasurementUnit.ml.convert(inMl, to: .oz)
        #expect(abs(backToOz - original) < 0.001)
    }
}

// MARK: - SlushCalculator Tests

@Suite("SlushCalculator Tests")
struct SlushCalculatorTests {
    let calculator = SlushCalculator()

    @Test("Calculate ABV with single ingredient")
    func singleIngredientABV() {
        let ingredients = [(volume: 100.0, abv: 40.0)]
        let result = calculator.calculateFinalABV(ingredients: ingredients)
        #expect(abs(result - 40.0) < 0.01)
    }

    @Test("Calculate ABV with mixed ingredients")
    func mixedIngredientABV() {
        // 50ml vodka (40% ABV) + 50ml water (0% ABV) = 20% ABV
        let ingredients = [
            (volume: 50.0, abv: 40.0),
            (volume: 50.0, abv: 0.0)
        ]
        let result = calculator.calculateFinalABV(ingredients: ingredients)
        #expect(abs(result - 20.0) < 0.01)
    }

    @Test("Calculate ABV with empty ingredients")
    func emptyIngredientABV() {
        let ingredients: [(volume: Double, abv: Double)] = []
        let result = calculator.calculateFinalABV(ingredients: ingredients)
        #expect(result == 0)
    }

    @Test("Calculate Brix with single ingredient")
    func singleIngredientBrix() {
        let ingredients = [(volume: 100.0, brix: 50.0)]
        let result = calculator.calculateFinalBrix(ingredients: ingredients)
        #expect(abs(result - 50.0) < 0.01)
    }

    @Test("Calculate Brix with mixed ingredients")
    func mixedIngredientBrix() {
        // 50ml simple syrup (50 Brix) + 50ml water (0 Brix) = 25 Brix
        let ingredients = [
            (volume: 50.0, brix: 50.0),
            (volume: 50.0, brix: 0.0)
        ]
        let result = calculator.calculateFinalBrix(ingredients: ingredients)
        #expect(abs(result - 25.0) < 0.01)
    }

    @Test("Calculate freezing point Celsius")
    func freezingPointCelsius() {
        // 10% ABV should freeze at -4°C
        let result = calculator.calculateFreezingPointCelsius(abv: 10.0)
        #expect(abs(result - (-4.0)) < 0.01)
    }

    @Test("Calculate freezing point Fahrenheit")
    func freezingPointFahrenheit() {
        // 0% ABV should freeze at ~32°F
        let result = calculator.calculateFreezingPointFahrenheit(abv: 0.0)
        #expect(abs(result - 31.947) < 0.01)
    }

    @Test("Ford Fry Frozen Margarita calculation")
    func fordFryMargarita() {
        // From the implementation plan (Ford Fry batch recipe):
        // 288 oz water + 80 oz simple syrup + 64 oz lime + 69.75 oz triple sec + 101.5 oz tequila
        // Total: 603.25 oz

        // Ingredient values used:
        // Water: 0% ABV, 0 Brix
        // Simple syrup (1:1): 0% ABV, 48 Brix
        // Lime juice: 0% ABV, 8 Brix
        // Triple sec (Stirrings): 30% ABV, 25 Brix
        // Tequila: 40% ABV, 0 Brix

        let abvIngredients = [
            (volume: 288.0, abv: 0.0),    // water
            (volume: 80.0, abv: 0.0),     // simple syrup
            (volume: 64.0, abv: 0.0),     // lime juice
            (volume: 69.75, abv: 30.0),   // triple sec
            (volume: 101.5, abv: 40.0)    // tequila
        ]

        let brixIngredients = [
            (volume: 288.0, brix: 0.0),   // water
            (volume: 80.0, brix: 48.0),   // simple syrup
            (volume: 64.0, brix: 8.0),    // lime juice
            (volume: 69.75, brix: 25.0),  // triple sec
            (volume: 101.5, brix: 0.0)    // tequila
        ]

        let abv = calculator.calculateFinalABV(ingredients: abvIngredients)
        let brix = calculator.calculateFinalBrix(ingredients: brixIngredients)

        // Calculate expected values mathematically:
        // Total volume = 603.25 oz
        // Total alcohol = (69.75 * 0.30) + (101.5 * 0.40) = 20.925 + 40.6 = 61.525 oz
        // ABV = 61.525 / 603.25 * 100 = 10.2%
        // Total sugar = (80 * 0.48) + (64 * 0.08) + (69.75 * 0.25) = 38.4 + 5.12 + 17.4375 = 60.9575 oz
        // Brix = 60.9575 / 603.25 * 100 = 10.1%
        // Note: The plan's expected 6.7% ABV / 13.8 Brix may use different ingredient values

        let expectedABV = 10.2  // Mathematically calculated
        let expectedBrix = 10.1 // Mathematically calculated

        #expect(abs(abv - expectedABV) < 0.2, "ABV calculation should be accurate")
        #expect(abs(brix - expectedBrix) < 0.2, "Brix calculation should be accurate")

        // Also verify this recipe is too alcoholic for proper slush (ABV > 10%)
        let status = SlushabilityStatus.evaluate(abv: abv, brix: brix)
        if case .warning = status {
            // Expected - ABV is borderline high
        } else if status == .willNotFreeze {
            // Also acceptable - might be flagged as too high
        } else {
            Issue.record("Recipe with 10%+ ABV should produce warning or willNotFreeze")
        }
    }

    @Test("Optimal Brix range at low ABV")
    func optimalBrixLowABV() {
        let range = calculator.optimalBrixRange(forABV: 5.0)
        #expect(range.lowerBound >= 12.0)
        #expect(range.upperBound <= 17.0)
    }

    @Test("Optimal Brix range at high ABV")
    func optimalBrixHighABV() {
        let range = calculator.optimalBrixRange(forABV: 10.0)
        // Higher ABV should have slightly lower optimal Brix
        #expect(range.lowerBound >= 12.0)
        #expect(range.upperBound <= 16.0)
    }

    @Test("Water to reduce ABV calculation")
    func waterToReduceABV() {
        // 100ml at 20% ABV, want to reach 10% ABV
        // Need to add 100ml water (double the volume to halve ABV)
        let water = calculator.waterToReduceABV(
            currentVolume: 100.0,
            currentABV: 20.0,
            targetABV: 10.0
        )
        #expect(abs(water - 100.0) < 0.01)
    }

    @Test("Sweetener to increase Brix calculation")
    func sweetenerToIncreaseBrix() {
        // 100ml at 10 Brix, want to reach 15 Brix using 50 Brix syrup
        // Formula: V * (T - B) / (S - T) = 100 * (15 - 10) / (50 - 15) = 100 * 5 / 35 ≈ 14.29ml
        let sweetener = calculator.sweetenerToIncreaseBrix(
            currentVolume: 100.0,
            currentBrix: 10.0,
            targetBrix: 15.0,
            sweetenerBrix: 50.0
        )
        #expect(abs(sweetener - 14.29) < 0.1)
    }

    @Test("Round oz for display")
    func roundOzDisplay() {
        #expect(calculator.roundForDisplay(oz: 1.1) == 1.0)
        #expect(calculator.roundForDisplay(oz: 1.13) == 1.25)
        #expect(calculator.roundForDisplay(oz: 1.4) == 1.5)
        #expect(calculator.roundForDisplay(oz: 1.9) == 2.0)
    }

    @Test("Round ml for display")
    func roundMlDisplay() {
        #expect(calculator.roundForDisplay(ml: 12.0) == 10.0)
        #expect(calculator.roundForDisplay(ml: 13.0) == 15.0)
        #expect(calculator.roundForDisplay(ml: 17.0) == 15.0)
        #expect(calculator.roundForDisplay(ml: 18.0) == 20.0)
    }
}

// MARK: - Slushability Status Tests

@Suite("Slushability Status Tests")
struct SlushabilityStatusTests {
    @Test("Optimal values return optimal status")
    func optimalStatus() {
        let status = SlushabilityStatus.evaluate(abv: 7.0, brix: 14.0)
        #expect(status == .optimal)
    }

    @Test("High ABV returns warning or will not freeze")
    func highABVStatus() {
        // ABV > 12 should not freeze
        let status12 = SlushabilityStatus.evaluate(abv: 13.0, brix: 14.0)
        #expect(status12 == .willNotFreeze)

        // ABV 10-12 should warn
        let status10 = SlushabilityStatus.evaluate(abv: 11.0, brix: 14.0)
        if case .warning = status10 {
            // Expected
        } else {
            Issue.record("Expected warning for 11% ABV")
        }
    }

    @Test("Low Brix returns appropriate status")
    func lowBrixStatus() {
        // Brix < 11 won't freeze
        let status10 = SlushabilityStatus.evaluate(abv: 7.0, brix: 10.0)
        #expect(status10 == .willNotFreeze)

        // Brix 11-13 is not sweet enough
        let status12 = SlushabilityStatus.evaluate(abv: 7.0, brix: 12.0)
        #expect(status12 == .notSweetEnough)
    }

    @Test("High Brix returns appropriate status")
    func highBrixStatus() {
        // Brix > 17 won't freeze properly
        let status18 = SlushabilityStatus.evaluate(abv: 7.0, brix: 18.0)
        #expect(status18 == .willNotFreeze)

        // Brix 15-17 is too sweet but may work
        let status16 = SlushabilityStatus.evaluate(abv: 7.0, brix: 16.0)
        #expect(status16 == .tooSweet)
    }
}

// MARK: - Drink Preferences Tests

@Suite("Drink Preferences Tests")
struct DrinkPreferencesTests {
    @Test("Balanced preferences produce middle-range targets")
    func balancedPreferences() {
        let prefs = DrinkPreferences.balanced
        let targets = prefs.toOptimizationTargets()

        // Should produce roughly 13.5-14.5 Brix and 7-8% ABV
        #expect(targets.brixRange.lowerBound >= 13.0)
        #expect(targets.brixRange.upperBound <= 15.0)
        #expect(targets.abvRange.lowerBound >= 6.0)
        #expect(targets.abvRange.upperBound <= 9.0)
    }

    @Test("Tart preferences produce lower Brix")
    func tartPreferences() {
        let prefs = DrinkPreferences(sweetnessLevel: 0.0, slushThickness: 0.5, alcoholStrength: 0.5)
        let targets = prefs.toOptimizationTargets()

        #expect(targets.brixRange.lowerBound <= 13.0, "Tart preference should have lower Brix target")
    }

    @Test("Sweet preferences produce higher Brix")
    func sweetPreferences() {
        let prefs = DrinkPreferences(sweetnessLevel: 1.0, slushThickness: 0.5, alcoholStrength: 0.5)
        let targets = prefs.toOptimizationTargets()

        #expect(targets.brixRange.lowerBound >= 14.0, "Sweet preference should have higher Brix target")
    }

    @Test("Light alcohol preferences produce lower ABV")
    func lightAlcoholPreferences() {
        let prefs = DrinkPreferences(sweetnessLevel: 0.5, slushThickness: 0.5, alcoholStrength: 0.0)
        let targets = prefs.toOptimizationTargets()

        #expect(targets.abvRange.upperBound <= 6.5, "Light alcohol should target lower ABV")
    }

    @Test("Strong alcohol preferences produce higher ABV")
    func strongAlcoholPreferences() {
        let prefs = DrinkPreferences(sweetnessLevel: 0.5, slushThickness: 0.5, alcoholStrength: 1.0)
        let targets = prefs.toOptimizationTargets()

        #expect(targets.abvRange.lowerBound >= 8.5, "Strong alcohol should target higher ABV")
    }
}

// MARK: - Ingredient Tests

@Suite("Ingredient Tests")
struct IngredientTests {
    @Test("Ingredient isAlcoholic property")
    func isAlcoholic() {
        let vodka = Ingredient(name: "Vodka", category: .spirit, abv: 40, brix: 0)
        let water = Ingredient(name: "Water", category: .mixer, abv: 0, brix: 0)

        #expect(vodka.isAlcoholic == true)
        #expect(water.isAlcoholic == false)
    }

    @Test("Ingredient isSweetener property")
    func isSweetener() {
        let syrup = Ingredient(name: "Simple Syrup", category: .sweetener, abv: 0, brix: 50)
        let vodka = Ingredient(name: "Vodka", category: .spirit, abv: 40, brix: 0)
        let liqueur = Ingredient(name: "Kahlua", category: .liqueur, abv: 20, brix: 49)

        #expect(syrup.isSweetener == true)
        #expect(vodka.isSweetener == false)
        #expect(liqueur.isSweetener == false, "Liqueurs with ABV are not sweeteners")
    }

    @Test("Ingredient isWater property")
    func isWater() {
        let water = Ingredient(name: "Water", category: .mixer, abv: 0, brix: 0)
        let sparklingWater = Ingredient(name: "Sparkling Water", category: .mixer, abv: 0, brix: 0)
        let tonic = Ingredient(name: "Tonic Water", category: .mixer, abv: 0, brix: 8)

        #expect(water.isWater == true)
        #expect(sparklingWater.isWater == true)
        #expect(tonic.isWater == false, "Tonic has Brix so it's not water")
    }
}

// MARK: - Recipe Ingredient Tests

@Suite("Recipe Ingredient Tests")
struct RecipeIngredientTests {
    @Test("Volume conversion to ml")
    func volumeToMl() {
        let ingredient = RecipeIngredient(
            ingredientId: UUID(),
            amount: 1.0,
            unit: .oz
        )
        #expect(abs(ingredient.volumeInMl - 29.5735) < 0.001)
    }

    @Test("Volume conversion to oz")
    func volumeToOz() {
        let ingredient = RecipeIngredient(
            ingredientId: UUID(),
            amount: 29.5735,
            unit: .ml
        )
        #expect(abs(ingredient.volumeInOz - 1.0) < 0.001)
    }
}

// MARK: - Serving Calculator Tests

@Suite("Serving Calculator Tests")
struct ServingCalculatorTests {
    let calculator = SlushCalculator()

    @Test("Calculate total volume for servings - basic case")
    func basicServingCalculation() {
        // 4 people × 2 servings × 8oz = 64oz
        let result = calculator.calculateTotalVolumeForServings(
            numberOfPeople: 4,
            servingsPerPerson: 2,
            servingSizeOz: 8
        )
        #expect(result == 64.0)
    }

    @Test("Calculate total volume for servings - single person")
    func singlePersonServings() {
        // 1 person × 1 serving × 10oz = 10oz
        let result = calculator.calculateTotalVolumeForServings(
            numberOfPeople: 1,
            servingsPerPerson: 1,
            servingSizeOz: 10
        )
        #expect(result == 10.0)
    }

    @Test("Calculate total volume for servings - large party")
    func largePartyServings() {
        // 12 people × 3 servings × 8oz = 288oz
        let result = calculator.calculateTotalVolumeForServings(
            numberOfPeople: 12,
            servingsPerPerson: 3,
            servingSizeOz: 8
        )
        #expect(result == 288.0)
    }

    @Test("Calculate total volume for servings - custom serving size")
    func customServingSizeCalculation() {
        // 6 people × 2 servings × 12oz = 144oz
        let result = calculator.calculateTotalVolumeForServings(
            numberOfPeople: 6,
            servingsPerPerson: 2,
            servingSizeOz: 12
        )
        #expect(result == 144.0)
    }

    @Test("Calculate servings from volume - standard serving")
    func servingsFromVolumeStandard() {
        // 64oz / 8oz = 8 servings
        let result = calculator.calculateServings(fromVolumeOz: 64, servingSizeOz: 8)
        #expect(result == 8)
    }

    @Test("Calculate servings from volume - rounds correctly")
    func servingsFromVolumeRounding() {
        // 70oz / 8oz = 8.75 → rounds to 9 servings
        let result = calculator.calculateServings(fromVolumeOz: 70, servingSizeOz: 8)
        #expect(result == 9)

        // 65oz / 8oz = 8.125 → rounds to 8 servings
        let result2 = calculator.calculateServings(fromVolumeOz: 65, servingSizeOz: 8)
        #expect(result2 == 8)
    }

    @Test("Calculate servings from volume - minimum 1")
    func servingsMinimumOne() {
        // Even very small volumes should return at least 1 serving
        let result = calculator.calculateServings(fromVolumeOz: 2, servingSizeOz: 8)
        #expect(result >= 1)
    }

    @Test("Calculate servings from volume - zero serving size")
    func servingsZeroServingSize() {
        // Zero serving size should return 0 (protect against division by zero)
        let result = calculator.calculateServings(fromVolumeOz: 64, servingSizeOz: 0)
        #expect(result == 0)
    }

    @Test("Calculate servings from volume - different serving sizes")
    func servingsWithDifferentSizes() {
        let volume = 72.0

        // 72oz / 6oz = 12 servings
        #expect(calculator.calculateServings(fromVolumeOz: volume, servingSizeOz: 6) == 12)

        // 72oz / 8oz = 9 servings
        #expect(calculator.calculateServings(fromVolumeOz: volume, servingSizeOz: 8) == 9)

        // 72oz / 10oz = 7.2 → 7 servings
        #expect(calculator.calculateServings(fromVolumeOz: volume, servingSizeOz: 10) == 7)

        // 72oz / 12oz = 6 servings
        #expect(calculator.calculateServings(fromVolumeOz: volume, servingSizeOz: 12) == 6)

        // 72oz / 16oz = 4.5 → 5 servings (rounds up at .5)
        #expect(calculator.calculateServings(fromVolumeOz: volume, servingSizeOz: 16) == 5)
    }

    @Test("Default serving size constant")
    func defaultServingSizeValue() {
        // Verify the default serving size is 8oz as documented
        #expect(SlushCalculator.defaultServingSizeOz == 8.0)
    }
}

// MARK: - User Settings Serving Size Tests

@Suite("User Settings Serving Size Tests")
struct UserSettingsServingSizeTests {
    @Test("Default serving size is 8oz")
    func defaultServingSize() {
        let settings = UserSettings()
        #expect(settings.servingSizeOz == 8.0)
    }

    @Test("Serving size presets are valid")
    func servingSizePresetsValid() {
        let presets = UserSettings.servingSizePresets

        // Should have at least 5 presets
        #expect(presets.count >= 5)

        // All presets should have positive sizes
        for preset in presets {
            #expect(preset.sizeOz > 0)
        }

        // Presets should include common sizes
        let sizes = presets.map { $0.sizeOz }
        #expect(sizes.contains(6))
        #expect(sizes.contains(8))
        #expect(sizes.contains(10))
        #expect(sizes.contains(12))
    }

    @Test("Custom serving size initialization")
    func customServingSize() {
        let settings = UserSettings(servingSizeOz: 12)
        #expect(settings.servingSizeOz == 12.0)
    }
}

// MARK: - Recipe Stats Serving Calculation Tests

@Suite("Recipe Stats Serving Calculation Tests")
struct RecipeStatsServingTests {
    let calculator = SlushCalculator()

    // Create test ingredients
    let vodka = Ingredient(id: UUID(), name: "Vodka", category: .spirit, abv: 40, brix: 0)
    let juice = Ingredient(id: UUID(), name: "Juice", category: .juice, abv: 0, brix: 12)

    func makeLookup() -> (UUID) -> Ingredient? {
        let ingredients = [vodka, juice]
        return { id in ingredients.first { $0.id == id } }
    }

    @Test("Stats calculation uses custom serving size")
    func statsWithCustomServingSize() {
        // Recipe: 8oz vodka + 32oz juice = 40oz total
        let recipeIngredients = [
            RecipeIngredient(ingredientId: vodka.id, amount: 8, unit: .oz),
            RecipeIngredient(ingredientId: juice.id, amount: 32, unit: .oz)
        ]

        // With 8oz serving size: 40oz / 8oz = 5 servings
        let stats8oz = calculator.calculateStats(
            for: recipeIngredients,
            ingredientLookup: makeLookup(),
            servingSizeOz: 8
        )
        #expect(stats8oz.servings == 5)

        // With 10oz serving size: 40oz / 10oz = 4 servings
        let stats10oz = calculator.calculateStats(
            for: recipeIngredients,
            ingredientLookup: makeLookup(),
            servingSizeOz: 10
        )
        #expect(stats10oz.servings == 4)

        // With 16oz serving size: 40oz / 16oz = 2.5 → 3 servings
        let stats16oz = calculator.calculateStats(
            for: recipeIngredients,
            ingredientLookup: makeLookup(),
            servingSizeOz: 16
        )
        #expect(stats16oz.servings == 3)
    }

    @Test("Stats calculation defaults to 8oz serving")
    func statsDefaultServingSize() {
        // Recipe: 24oz total
        let recipeIngredients = [
            RecipeIngredient(ingredientId: vodka.id, amount: 4, unit: .oz),
            RecipeIngredient(ingredientId: juice.id, amount: 20, unit: .oz)
        ]

        // Default (8oz): 24oz / 8oz = 3 servings
        let stats = calculator.calculateStats(
            for: recipeIngredients,
            ingredientLookup: makeLookup()
        )
        #expect(stats.servings == 3)
    }
}

// MARK: - Real World Recipe Tests

@Suite("Real World Recipe Tests")
struct RealWorldRecipeTests {
    let calculator = SlushCalculator()
    let optimizer = RecipeOptimizer()

    // Create test ingredients
    let blancoTequila = Ingredient(id: UUID(), name: "Blanco Tequila", category: .spirit, abv: 40, brix: 0)
    let water = Ingredient(id: UUID(), name: "Water", category: .mixer, abv: 0, brix: 0)
    let pureAgave = Ingredient(id: UUID(), name: "Agave Nectar (pure)", category: .sweetener, abv: 0, brix: 75)
    let limeJuice = Ingredient(id: UUID(), name: "Fresh Lime Juice", category: .citrus, abv: 0, brix: 8)

    func makeLookup() -> (UUID) -> Ingredient? {
        let ingredients = [blancoTequila, water, pureAgave, limeJuice]
        return { id in ingredients.first { $0.id == id } }
    }

    @Test("User margarita recipe calculates correctly")
    func userMargaritaRecipeStats() {
        // Recipe: 1 cup tequila, 2.5 cups water, 0.5 cup pure agave, 1 cup lime juice
        let recipeIngredients = [
            RecipeIngredient(ingredientId: blancoTequila.id, amount: 8, unit: .oz),   // 1 cup
            RecipeIngredient(ingredientId: water.id, amount: 20, unit: .oz),          // 2.5 cups
            RecipeIngredient(ingredientId: pureAgave.id, amount: 4, unit: .oz),       // 0.5 cup
            RecipeIngredient(ingredientId: limeJuice.id, amount: 8, unit: .oz)        // 1 cup
        ]

        let stats = calculator.calculateStats(for: recipeIngredients, ingredientLookup: makeLookup())

        // Total: 40 oz
        #expect(abs(stats.totalVolumeOz - 40.0) < 0.1, "Total volume should be 40 oz")

        // ABV: (8 * 40) / 40 = 8%
        #expect(abs(stats.finalABV - 8.0) < 0.1, "ABV should be 8%")

        // Brix: (8*0 + 20*0 + 4*75 + 8*8) / 40 = (300 + 64) / 40 = 9.1
        #expect(abs(stats.finalBrix - 9.1) < 0.2, "Brix should be around 9.1")

        print("User Recipe Stats: ABV=\(stats.finalABV)%, Brix=\(stats.finalBrix), Volume=\(stats.totalVolumeOz)oz")
    }

    @Test("Auto-balance user recipe prefers existing ingredients")
    func autoBalanceUserRecipe() {
        // Recipe: 1 cup tequila, 2.5 cups water, 0.5 cup pure agave, 1 cup lime juice
        var recipe = Recipe(name: "User Margarita")
        recipe.ingredients = [
            RecipeIngredient(ingredientId: blancoTequila.id, amount: 8, unit: .oz),
            RecipeIngredient(ingredientId: water.id, amount: 20, unit: .oz),
            RecipeIngredient(ingredientId: pureAgave.id, amount: 4, unit: .oz),
            RecipeIngredient(ingredientId: limeJuice.id, amount: 8, unit: .oz)
        ]

        let lookup = makeLookup()

        // Get stats before
        let beforeStats = calculator.calculateStats(for: recipe.ingredients, ingredientLookup: lookup)
        print("BEFORE: ABV=\(beforeStats.finalABV)%, Brix=\(beforeStats.finalBrix), Volume=\(beforeStats.totalVolumeOz)oz")

        // Auto-balance with default targets (13-15 Brix, 5-10 ABV)
        let balanced = optimizer.autoBalance(
            recipe: recipe,
            targetBrixRange: 13...15,
            targetABVRange: 5...10,
            ingredientLookup: lookup,
            waterIngredientId: water.id,
            sweetenerIngredientId: pureAgave.id,  // Fallback, but should find existing agave
            sweetenerBrix: 75
        )

        let afterStats = calculator.calculateStats(for: balanced.ingredients, ingredientLookup: lookup)
        print("AFTER: ABV=\(afterStats.finalABV)%, Brix=\(afterStats.finalBrix), Volume=\(afterStats.totalVolumeOz)oz")

        // Print ingredient changes
        print("\nIngredient changes:")
        for ingredient in balanced.ingredients {
            if let info = lookup(ingredient.ingredientId) {
                print("  \(info.name): \(ingredient.amount) \(ingredient.unit.abbreviation)")
            }
        }

        // Verify Brix is now in target range
        #expect(afterStats.finalBrix >= 13.0, "Brix should be at least 13 after balancing")
        #expect(afterStats.finalBrix <= 15.0, "Brix should be at most 15 after balancing")

        // Verify ABV is acceptable (can be below target, just not above)
        #expect(afterStats.finalABV <= 10.0, "ABV should be at most 10%")

        // Verify it used existing agave (not a new ingredient)
        let agaveIngredient = balanced.ingredients.first { $0.ingredientId == pureAgave.id }
        #expect(agaveIngredient != nil, "Should have increased existing agave")
        #expect((agaveIngredient?.amount ?? 0) > 4.0, "Agave amount should have increased from 4 oz")

        // No new ingredients should be added (should only have 4 ingredients)
        #expect(balanced.ingredients.count == 4, "Should not add new ingredients, only adjust existing ones")
    }
}
