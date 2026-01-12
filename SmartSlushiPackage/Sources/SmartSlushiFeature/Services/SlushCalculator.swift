import Foundation

// MARK: - Slush Calculator

/// Core calculation engine for slush recipes
/// Handles ABV, Brix, freezing point, and auto-balance calculations
public final class SlushCalculator: Sendable {
    /// Default serving size in ounces (used when no user preference is set)
    public static let defaultServingSizeOz: Double = 8

    /// Simple syrup Brix value (1:1 by weight)
    public static let simpleSyrupBrix: Double = 50

    public init() {}

    // MARK: - Serving Calculations

    /// Calculate total volume needed for a given number of servings
    /// - Parameters:
    ///   - numberOfPeople: How many people will be served
    ///   - servingsPerPerson: How many servings each person will have
    ///   - servingSizeOz: Size of each serving in ounces
    /// - Returns: Total volume needed in ounces
    public func calculateTotalVolumeForServings(
        numberOfPeople: Int,
        servingsPerPerson: Int,
        servingSizeOz: Double
    ) -> Double {
        Double(numberOfPeople) * Double(servingsPerPerson) * servingSizeOz
    }

    /// Calculate number of servings from a total volume
    /// - Parameters:
    ///   - totalVolumeOz: Total volume in ounces
    ///   - servingSizeOz: Size of each serving in ounces
    /// - Returns: Number of servings (rounded up to nearest whole number)
    public func calculateServings(
        fromVolumeOz totalVolumeOz: Double,
        servingSizeOz: Double
    ) -> Int {
        guard servingSizeOz > 0 else { return 0 }
        return max(1, Int((totalVolumeOz / servingSizeOz).rounded()))
    }

    // MARK: - Core Calculations

    /// Calculate final ABV from a list of ingredient volumes and their ABV values
    /// - Parameter ingredients: Array of tuples containing volume and ABV percentage
    /// - Returns: Final ABV as a percentage (0-100)
    public func calculateFinalABV(ingredients: [(volume: Double, abv: Double)]) -> Double {
        let totalVolume = ingredients.reduce(0.0) { $0 + $1.volume }
        guard totalVolume > 0 else { return 0 }

        let totalAlcohol = ingredients.reduce(0.0) { $0 + ($1.volume * $1.abv / 100.0) }
        return (totalAlcohol / totalVolume) * 100.0
    }

    /// Calculate final Brix from a list of ingredient volumes and their Brix values
    /// - Parameter ingredients: Array of tuples containing volume and Brix percentage
    /// - Returns: Final Brix as a percentage (0-100)
    public func calculateFinalBrix(ingredients: [(volume: Double, brix: Double)]) -> Double {
        let totalVolume = ingredients.reduce(0.0) { $0 + $1.volume }
        guard totalVolume > 0 else { return 0 }

        let totalSugar = ingredients.reduce(0.0) { $0 + ($1.volume * $1.brix / 100.0) }
        return (totalSugar / totalVolume) * 100.0
    }

    /// Calculate freezing point in Celsius based on ABV
    /// - Parameter abv: Alcohol by volume percentage
    /// - Returns: Freezing point in Celsius
    public func calculateFreezingPointCelsius(abv: Double) -> Double {
        return -0.4 * abv
    }

    /// Calculate freezing point in Fahrenheit using polynomial approximation
    /// More accurate than simple linear conversion for 0-25% ABV range
    /// - Parameter abv: Alcohol by volume percentage
    /// - Returns: Freezing point in Fahrenheit
    public func calculateFreezingPointFahrenheit(abv: Double) -> Double {
        return (0.0075275 * abv + 0.054922) * abv + 31.947
    }

    /// Calculate optimal Brix range based on ABV
    /// Higher ABV drinks need slightly lower Brix for proper texture
    /// - Parameter abv: Current ABV percentage
    /// - Returns: Optimal Brix range
    public func optimalBrixRange(forABV abv: Double) -> ClosedRange<Double> {
        let low = max(12.0, min(20.0, 15.0 - 0.25 * abv))
        let high = max(12.0, min(20.0, 17.0 - 0.25 * abv))
        return low...high
    }

    // MARK: - Recipe Stats Calculation

    /// Calculate complete stats for a recipe given its ingredients (using default machine)
    /// - Parameters:
    ///   - recipeIngredients: Recipe ingredients to analyze
    ///   - ingredientLookup: Function to look up ingredient details by ID
    ///   - servingSizeOz: Size of each serving in ounces (defaults to 8oz)
    /// - Returns: Complete recipe statistics
    public func calculateStats(
        for recipeIngredients: [RecipeIngredient],
        ingredientLookup: (UUID) -> Ingredient?,
        servingSizeOz: Double = defaultServingSizeOz
    ) -> RecipeStats {
        calculateStats(
            for: recipeIngredients,
            ingredientLookup: ingredientLookup,
            servingSizeOz: servingSizeOz,
            machine: .default
        )
    }

    /// Calculate complete stats for a recipe given its ingredients and target machine
    /// - Parameters:
    ///   - recipeIngredients: Recipe ingredients to analyze
    ///   - ingredientLookup: Function to look up ingredient details by ID
    ///   - servingSizeOz: Size of each serving in ounces (defaults to 8oz)
    ///   - machine: The target slush machine for constraint evaluation
    /// - Returns: Complete recipe statistics
    public func calculateStats(
        for recipeIngredients: [RecipeIngredient],
        ingredientLookup: (UUID) -> Ingredient?,
        servingSizeOz: Double = defaultServingSizeOz,
        machine: SlushiMachine
    ) -> RecipeStats {
        var warnings: [String] = []

        // Convert all ingredients to common format for calculation
        var abvPairs: [(volume: Double, abv: Double)] = []
        var brixPairs: [(volume: Double, brix: Double)] = []
        var totalVolumeMl: Double = 0

        for recipeIngredient in recipeIngredients {
            guard let ingredient = ingredientLookup(recipeIngredient.ingredientId) else {
                warnings.append("Unknown ingredient ID: \(recipeIngredient.ingredientId)")
                continue
            }

            let volumeMl = recipeIngredient.volumeInMl
            totalVolumeMl += volumeMl

            abvPairs.append((volume: volumeMl, abv: ingredient.abv))
            brixPairs.append((volume: volumeMl, brix: ingredient.brix))
        }

        // Calculate final values
        let finalABV = calculateFinalABV(ingredients: abvPairs)
        let finalBrix = calculateFinalBrix(ingredients: brixPairs)
        let freezingPointC = calculateFreezingPointCelsius(abv: finalABV)
        let freezingPointF = calculateFreezingPointFahrenheit(abv: finalABV)

        // Determine slushability using machine constraints
        let slushabilityStatus = SlushabilityStatus.evaluate(abv: finalABV, brix: finalBrix, machine: machine)

        // Add warnings based on machine constraints
        let abvStatus = machine.evaluateABV(finalABV)
        let brixStatus = machine.evaluateBrix(finalBrix)

        switch abvStatus {
        case .exceeded(let message):
            warnings.append(message)
        case .nearLimit(let message):
            warnings.append(message)
        default:
            break
        }

        switch brixStatus {
        case .exceeded(let message):
            warnings.append(message)
        case .nearLimit(let message):
            warnings.append(message)
        default:
            break
        }

        // Calculate volume in oz
        let totalVolumeOz = MeasurementUnit.ml.convert(totalVolumeMl, to: .oz)

        // Calculate servings based on user's serving size preference
        let servings = calculateServings(fromVolumeOz: totalVolumeOz, servingSizeOz: servingSizeOz)

        return RecipeStats(
            totalVolumeOz: totalVolumeOz,
            totalVolumeMl: totalVolumeMl,
            finalABV: finalABV,
            finalBrix: finalBrix,
            freezingPointCelsius: freezingPointC,
            freezingPointFahrenheit: freezingPointF,
            slushabilityStatus: slushabilityStatus,
            servings: servings,
            warnings: warnings,
            machine: machine
        )
    }

    // MARK: - Scaling

    /// Scale a recipe to a target batch size
    /// - Parameters:
    ///   - recipe: The recipe to scale
    ///   - targetSize: Target batch size in ounces
    ///   - ingredientLookup: Function to look up ingredient details
    /// - Returns: A new recipe with scaled ingredient amounts
    public func scaleRecipe(
        _ recipe: Recipe,
        toBatchSize targetSize: Double,
        ingredientLookup: (UUID) -> Ingredient?
    ) -> Recipe {
        // Calculate current total volume
        let currentTotal = recipe.ingredients.reduce(0.0) { $0 + $1.volumeInOz }
        guard currentTotal > 0 else { return recipe }

        let scaleFactor = targetSize / currentTotal

        // Scale all ingredients
        let scaledIngredients = recipe.ingredients.map { ingredient -> RecipeIngredient in
            var scaled = ingredient
            scaled.amount = ingredient.amount * scaleFactor
            return scaled
        }

        var scaledRecipe = recipe
        scaledRecipe.ingredients = scaledIngredients
        scaledRecipe.targetBatchSize = targetSize
        scaledRecipe.modifiedAt = Date()

        return scaledRecipe
    }

    // MARK: - Auto-Balance Calculations

    /// Calculate water needed to reduce ABV to target
    /// - Parameters:
    ///   - currentVolume: Current total volume
    ///   - currentABV: Current ABV percentage
    ///   - targetABV: Desired ABV percentage
    /// - Returns: Amount of water to add (in same units as currentVolume)
    public func waterToReduceABV(
        currentVolume: Double,
        currentABV: Double,
        targetABV: Double
    ) -> Double {
        guard targetABV > 0 && currentABV > targetABV else { return 0 }
        return currentVolume * ((currentABV / targetABV) - 1)
    }

    /// Calculate sweetener needed to increase Brix to target
    /// - Parameters:
    ///   - currentVolume: Current total volume
    ///   - currentBrix: Current Brix
    ///   - targetBrix: Desired Brix
    ///   - sweetenerBrix: Brix of the sweetener to use (default: 50 for 1:1 simple syrup)
    /// - Returns: Amount of sweetener to add (in same units as currentVolume)
    public func sweetenerToIncreaseBrix(
        currentVolume: Double,
        currentBrix: Double,
        targetBrix: Double,
        sweetenerBrix: Double = 50.0
    ) -> Double {
        guard sweetenerBrix > targetBrix && targetBrix > currentBrix else { return 0 }
        return currentVolume * (targetBrix - currentBrix) / (sweetenerBrix - targetBrix)
    }

    /// Calculate water needed to reduce Brix to target
    /// - Parameters:
    ///   - currentVolume: Current total volume
    ///   - currentBrix: Current Brix
    ///   - targetBrix: Desired Brix
    /// - Returns: Amount of water to add (in same units as currentVolume)
    public func waterToReduceBrix(
        currentVolume: Double,
        currentBrix: Double,
        targetBrix: Double
    ) -> Double {
        guard targetBrix > 0 && currentBrix > targetBrix else { return 0 }
        return currentVolume * ((currentBrix / targetBrix) - 1)
    }

    // MARK: - Display Rounding

    /// Round ounces for display (nearest 0.25 oz)
    public func roundForDisplay(oz: Double) -> Double {
        return (oz * 4).rounded() / 4
    }

    /// Round milliliters for display (nearest 5 ml)
    public func roundForDisplay(ml: Double) -> Double {
        return (ml / 5).rounded() * 5
    }

    /// Round percentage for display (1 decimal place)
    public func roundPercent(_ value: Double) -> Double {
        return (value * 10).rounded() / 10
    }
}

// MARK: - Recipe Optimizer

/// Handles automatic recipe balancing and optimization
public final class RecipeOptimizer: Sendable {
    private let calculator: SlushCalculator

    public init(calculator: SlushCalculator = SlushCalculator()) {
        self.calculator = calculator
    }

    /// Auto-balance a recipe to achieve target Brix and ABV ranges
    /// Prefers adjusting existing ingredients over adding new ones
    /// - Parameters:
    ///   - recipe: The recipe to balance
    ///   - targetBrixRange: Target Brix range (default: uses machine optimal range)
    ///   - targetABVRange: Target ABV range (default: uses machine optimal range)
    ///   - ingredientLookup: Function to look up ingredients
    ///   - waterIngredientId: Fallback water ingredient ID if none in recipe
    ///   - sweetenerIngredientId: Fallback sweetener ID if none in recipe
    ///   - sweetenerBrix: Fallback sweetener Brix value
    ///   - machine: The target slush machine for constraints
    ///   - maxIterations: Maximum balancing iterations
    /// - Returns: A balanced recipe
    public func autoBalance(
        recipe: Recipe,
        targetBrixRange: ClosedRange<Double>? = nil,
        targetABVRange: ClosedRange<Double>? = nil,
        ingredientLookup: (UUID) -> Ingredient?,
        waterIngredientId: UUID,
        sweetenerIngredientId: UUID,
        sweetenerBrix: Double = 50.0,
        machine: SlushiMachine = .default,
        maxIterations: Int = 50
    ) -> Recipe {
        // Use machine's optimal ranges if not specified
        let effectiveBrixRange = targetBrixRange ?? machine.optimalBrixRange
        let effectiveABVRange = targetABVRange ?? machine.optimalABVRange
        var workingRecipe = recipe

        // Find existing water and sweetener in the recipe (prefer existing ingredients)
        let (effectiveWaterId, effectiveSweetenerId, effectiveSweetenerBrix) = findExistingBalancingIngredients(
            in: recipe,
            ingredientLookup: ingredientLookup,
            fallbackWaterId: waterIngredientId,
            fallbackSweetenerId: sweetenerIngredientId,
            fallbackSweetenerBrix: sweetenerBrix
        )

        for _ in 0..<maxIterations {
            let stats = calculator.calculateStats(
                for: workingRecipe.ingredients,
                ingredientLookup: ingredientLookup,
                machine: machine
            )

            // Check if we're within acceptable ranges
            let abvOK = effectiveABVRange.contains(stats.finalABV) || stats.finalABV < effectiveABVRange.lowerBound
            let brixOK = effectiveBrixRange.contains(stats.finalBrix)

            if abvOK && brixOK {
                break
            }

            // Priority 1: ABV too high - must add water
            if stats.finalABV > effectiveABVRange.upperBound {
                let waterNeeded = calculator.waterToReduceABV(
                    currentVolume: stats.totalVolumeOz,
                    currentABV: stats.finalABV,
                    targetABV: effectiveABVRange.upperBound
                )
                // Add incrementally (max 10% of current volume per iteration)
                let waterToAdd = min(waterNeeded, stats.totalVolumeOz * 0.1)
                workingRecipe = addIngredient(
                    to: workingRecipe,
                    ingredientId: effectiveWaterId,
                    amount: waterToAdd
                )
                continue
            }

            // Priority 2: Brix too low - add sweetener
            if stats.finalBrix < effectiveBrixRange.lowerBound {
                let sweetenerNeeded = calculator.sweetenerToIncreaseBrix(
                    currentVolume: stats.totalVolumeOz,
                    currentBrix: stats.finalBrix,
                    targetBrix: effectiveBrixRange.lowerBound,
                    sweetenerBrix: effectiveSweetenerBrix
                )
                let sweetenerToAdd = min(sweetenerNeeded, stats.totalVolumeOz * 0.1)
                workingRecipe = addIngredient(
                    to: workingRecipe,
                    ingredientId: effectiveSweetenerId,
                    amount: sweetenerToAdd
                )
                continue
            }

            // Priority 3: Brix too high - add water
            if stats.finalBrix > effectiveBrixRange.upperBound {
                let waterNeeded = calculator.waterToReduceBrix(
                    currentVolume: stats.totalVolumeOz,
                    currentBrix: stats.finalBrix,
                    targetBrix: effectiveBrixRange.upperBound
                )
                let waterToAdd = min(waterNeeded, stats.totalVolumeOz * 0.1)
                workingRecipe = addIngredient(
                    to: workingRecipe,
                    ingredientId: effectiveWaterId,
                    amount: waterToAdd
                )
                continue
            }
        }

        workingRecipe.modifiedAt = Date()
        return workingRecipe
    }

    /// Find existing water and sweetener ingredients in the recipe
    /// Returns (waterId, sweetenerId, sweetenerBrix) - uses existing ingredients if found, fallbacks otherwise
    private func findExistingBalancingIngredients(
        in recipe: Recipe,
        ingredientLookup: (UUID) -> Ingredient?,
        fallbackWaterId: UUID,
        fallbackSweetenerId: UUID,
        fallbackSweetenerBrix: Double
    ) -> (waterId: UUID, sweetenerId: UUID, sweetenerBrix: Double) {
        var foundWaterId: UUID?
        var foundSweetenerId: UUID?
        var foundSweetenerBrix: Double?

        // Look through existing ingredients for water and sweeteners
        for recipeIngredient in recipe.ingredients {
            guard let ingredient = ingredientLookup(recipeIngredient.ingredientId) else { continue }

            // Look for water (0 ABV, 0 Brix, typically in mixer category)
            if ingredient.abv == 0 && ingredient.brix == 0 && foundWaterId == nil {
                if ingredient.category == .mixer || ingredient.name.lowercased().contains("water") {
                    foundWaterId = ingredient.id
                }
            }

            // Look for sweetener (0 ABV, high Brix, in sweetener category)
            if ingredient.abv == 0 && ingredient.brix > 20 && foundSweetenerId == nil {
                if ingredient.category == .sweetener {
                    foundSweetenerId = ingredient.id
                    foundSweetenerBrix = ingredient.brix
                }
            }
        }

        return (
            waterId: foundWaterId ?? fallbackWaterId,
            sweetenerId: foundSweetenerId ?? fallbackSweetenerId,
            sweetenerBrix: foundSweetenerBrix ?? fallbackSweetenerBrix
        )
    }

    /// Optimize a recipe based on user preferences and machine constraints
    /// - Parameters:
    ///   - recipe: The recipe to optimize
    ///   - preferences: User drink preferences
    ///   - ingredientLookup: Function to look up ingredients
    ///   - waterIngredientId: ID of water ingredient
    ///   - sweetenerIngredientId: ID of sweetener ingredient
    ///   - sweetenerBrix: Brix of the sweetener
    ///   - machine: The target slush machine for constraints
    /// - Returns: An optimized recipe
    public func optimizeRecipe(
        _ recipe: Recipe,
        preferences: DrinkPreferences,
        ingredientLookup: (UUID) -> Ingredient?,
        waterIngredientId: UUID,
        sweetenerIngredientId: UUID,
        sweetenerBrix: Double = 50.0,
        machine: SlushiMachine = .default
    ) -> Recipe {
        let targets = preferences.toOptimizationTargets()

        // Clamp targets to machine constraints
        let clampedBrixRange = clampToMachineConstraints(
            range: targets.brixRange,
            machineMin: machine.minBrix,
            machineMax: machine.maxBrix
        )
        let clampedABVRange = clampToMachineConstraints(
            range: targets.abvRange,
            machineMin: 0,
            machineMax: machine.maxABV
        )

        return autoBalance(
            recipe: recipe,
            targetBrixRange: clampedBrixRange,
            targetABVRange: clampedABVRange,
            ingredientLookup: ingredientLookup,
            waterIngredientId: waterIngredientId,
            sweetenerIngredientId: sweetenerIngredientId,
            sweetenerBrix: sweetenerBrix,
            machine: machine
        )
    }

    /// Clamp a target range to machine constraints
    private func clampToMachineConstraints(
        range: ClosedRange<Double>,
        machineMin: Double,
        machineMax: Double
    ) -> ClosedRange<Double> {
        let clampedLow = max(range.lowerBound, machineMin)
        let clampedHigh = min(range.upperBound, machineMax)
        // Ensure valid range
        if clampedLow > clampedHigh {
            return clampedLow...clampedLow
        }
        return clampedLow...clampedHigh
    }

    // MARK: - Private Helpers

    private func addIngredient(
        to recipe: Recipe,
        ingredientId: UUID,
        amount: Double
    ) -> Recipe {
        var updatedRecipe = recipe

        // Check if ingredient already exists in recipe
        if let index = updatedRecipe.ingredients.firstIndex(where: { $0.ingredientId == ingredientId }) {
            updatedRecipe.ingredients[index].amount += amount
        } else {
            // Add new ingredient
            let newIngredient = RecipeIngredient(
                ingredientId: ingredientId,
                amount: amount,
                unit: .oz,
                isLocked: false
            )
            updatedRecipe.ingredients.append(newIngredient)
        }

        return updatedRecipe
    }
}
