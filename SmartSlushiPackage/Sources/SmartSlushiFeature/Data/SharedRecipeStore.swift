import CloudKit
import Foundation
import Observation

// MARK: - Shared Recipe Store Errors

/// Errors that can occur in the shared recipe store
public enum SharedRecipeStoreError: Error, LocalizedError {
    case notAuthenticated
    case networkError(Error)
    case publishFailed(Error)
    case voteFailed(Error)
    case reportFailed(Error)
    case alreadyReported
    case recipeNotFound

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign into iCloud to access community recipes."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .publishFailed(let error):
            return "Failed to publish recipe: \(error.localizedDescription)"
        case .voteFailed(let error):
            return "Failed to submit vote: \(error.localizedDescription)"
        case .reportFailed(let error):
            return "Failed to submit report: \(error.localizedDescription)"
        case .alreadyReported:
            return "You have already reported this recipe."
        case .recipeNotFound:
            return "Recipe not found."
        }
    }
}

// MARK: - Shared Recipe Store

/// Manages shared recipes from CloudKit public database
@available(iOS 17.0, macOS 14.0, *)
@Observable
@MainActor
public final class SharedRecipeStore {
    // MARK: - State

    /// Loaded shared recipes
    public private(set) var recipes: [SharedRecipe] = []

    /// User's votes indexed by recipe ID
    public private(set) var userVotes: [String: Vote] = [:]

    /// Whether initial load is in progress
    public private(set) var isLoading = false

    /// Whether more results are being loaded
    public private(set) var isLoadingMore = false

    /// Current error if any
    public private(set) var error: SharedRecipeStoreError?

    /// Whether there are more results to load
    public private(set) var hasMoreResults = false

    /// Search text filter
    public var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    await refresh()
                }
            }
        }
    }

    /// Sort order
    public var sortOrder: SharedRecipeQuery.SortOrder = .mostRecent {
        didSet {
            if sortOrder != oldValue {
                Task {
                    await refresh()
                }
            }
        }
    }

    // Publishing state
    public private(set) var isPublishing = false
    public private(set) var publishError: Error?

    // User's published recipes
    public private(set) var myPublishedRecipes: [SharedRecipe] = []
    public private(set) var isLoadingMyRecipes = false

    // MARK: - Private

    private let cloudKitService: CloudKitService
    private var currentCursor: CKQueryOperation.Cursor?
    private var searchDebounceTask: Task<Void, Never>?

    // MARK: - Initialization

    public init(cloudKitService: CloudKitService = CloudKitService.shared) {
        self.cloudKitService = cloudKitService
    }

    // MARK: - Loading

    /// Load initial shared recipes
    public func loadRecipes() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        let query = SharedRecipeQuery(
            searchText: searchText.isEmpty ? nil : searchText,
            sortOrder: sortOrder
        )

        do {
            let (fetchedRecipes, cursor) = try await cloudKitService.fetchRecipes(query: query)
            recipes = fetchedRecipes
            currentCursor = cursor
            hasMoreResults = cursor != nil

            // Fetch user's votes for these recipes
            await loadUserVotes(for: fetchedRecipes)
        } catch let cloudKitError as CloudKitError {
            error = mapError(cloudKitError)
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
    }

    /// Load more recipes (pagination)
    public func loadMoreRecipes() async {
        guard !isLoadingMore, let cursor = currentCursor else { return }

        isLoadingMore = true

        do {
            let (fetchedRecipes, newCursor) = try await cloudKitService.fetchMoreRecipes(cursor: cursor)
            recipes.append(contentsOf: fetchedRecipes)
            currentCursor = newCursor
            hasMoreResults = newCursor != nil

            // Fetch user's votes for new recipes
            await loadUserVotes(for: fetchedRecipes)
        } catch {
            // Don't set error for pagination failures, just log
            print("Failed to load more recipes: \(error)")
        }

        isLoadingMore = false
    }

    /// Refresh recipes from the server
    public func refresh() async {
        currentCursor = nil
        await loadRecipes()
    }

    /// Load user's votes for a set of recipes
    private func loadUserVotes(for recipes: [SharedRecipe]) async {
        let recipeIds = recipes.map { $0.id }
        guard !recipeIds.isEmpty else { return }

        do {
            let votes = try await cloudKitService.fetchUserVotes(recipeIds: recipeIds)
            for (recipeId, vote) in votes {
                userVotes[recipeId] = vote
            }
        } catch {
            // Don't fail - votes are supplementary info
            print("Failed to load user votes: \(error)")
        }
    }

    // MARK: - Publishing

    /// Publish a SavedRecipe to the community
    public func publishRecipe(
        from savedRecipe: SavedRecipe,
        authorNotes: String?,
        ingredientLookup: @escaping (UUID) -> Ingredient?,
        calculator: SlushCalculator
    ) async throws -> SharedRecipe {
        isPublishing = true
        publishError = nil

        defer { isPublishing = false }

        do {
            // Get user ID
            let authorId = try await cloudKitService.fetchUserRecordID()

            // Calculate stats
            let stats = calculator.calculateStats(
                for: savedRecipe.ingredients,
                ingredientLookup: ingredientLookup
            )

            // Create shared recipe
            let sharedRecipe = SharedRecipe.create(
                from: savedRecipe,
                authorId: authorId,
                authorNotes: authorNotes,
                ingredientLookup: ingredientLookup,
                stats: stats
            )

            // Publish to CloudKit
            let published = try await cloudKitService.publishRecipe(sharedRecipe)

            // Add to my published recipes
            myPublishedRecipes.insert(published, at: 0)

            return published
        } catch let cloudKitError as CloudKitError {
            let storeError = mapError(cloudKitError)
            publishError = storeError
            throw storeError
        } catch {
            let storeError = SharedRecipeStoreError.publishFailed(error)
            publishError = storeError
            throw storeError
        }
    }

    /// Publish a Recipe to the community
    public func publishRecipe(
        from recipe: Recipe,
        authorNotes: String?,
        ingredientLookup: @escaping (UUID) -> Ingredient?,
        calculator: SlushCalculator
    ) async throws -> SharedRecipe {
        isPublishing = true
        publishError = nil

        defer { isPublishing = false }

        do {
            // Get user ID
            let authorId = try await cloudKitService.fetchUserRecordID()

            // Calculate stats
            let stats = calculator.calculateStats(
                for: recipe.ingredients,
                ingredientLookup: ingredientLookup
            )

            // Create shared recipe
            let sharedRecipe = SharedRecipe.create(
                from: recipe,
                authorId: authorId,
                authorNotes: authorNotes,
                ingredientLookup: ingredientLookup,
                stats: stats
            )

            // Publish to CloudKit
            let published = try await cloudKitService.publishRecipe(sharedRecipe)

            // Add to my published recipes
            myPublishedRecipes.insert(published, at: 0)

            return published
        } catch let cloudKitError as CloudKitError {
            let storeError = mapError(cloudKitError)
            publishError = storeError
            throw storeError
        } catch {
            let storeError = SharedRecipeStoreError.publishFailed(error)
            publishError = storeError
            throw storeError
        }
    }

    /// Delete own published recipe
    public func deletePublishedRecipe(_ recipe: SharedRecipe) async throws {
        do {
            try await cloudKitService.deleteRecipe(id: recipe.id)
            myPublishedRecipes.removeAll { $0.id == recipe.id }
            recipes.removeAll { $0.id == recipe.id }
        } catch {
            throw SharedRecipeStoreError.networkError(error)
        }
    }

    /// Load user's published recipes
    public func loadMyPublishedRecipes() async {
        guard !isLoadingMyRecipes else { return }

        isLoadingMyRecipes = true

        do {
            myPublishedRecipes = try await cloudKitService.fetchMyRecipes()
        } catch {
            print("Failed to load my published recipes: \(error)")
        }

        isLoadingMyRecipes = false
    }

    // MARK: - Voting

    /// Upvote a recipe
    public func upvote(_ recipe: SharedRecipe) async {
        await submitVote(for: recipe, isUpvote: true)
    }

    /// Downvote a recipe
    public func downvote(_ recipe: SharedRecipe) async {
        await submitVote(for: recipe, isUpvote: false)
    }

    /// Toggle vote - if already voted same way, remove vote
    public func toggleUpvote(_ recipe: SharedRecipe) async {
        if let existingVote = userVotes[recipe.id], existingVote.isUpvote {
            await removeVote(from: recipe)
        } else {
            await upvote(recipe)
        }
    }

    /// Toggle downvote - if already voted same way, remove vote
    public func toggleDownvote(_ recipe: SharedRecipe) async {
        if let existingVote = userVotes[recipe.id], !existingVote.isUpvote {
            await removeVote(from: recipe)
        } else {
            await downvote(recipe)
        }
    }

    private func submitVote(for recipe: SharedRecipe, isUpvote: Bool) async {
        // Optimistically update UI
        let previousVote = userVotes[recipe.id]
        applyLocalVoteDelta(
            for: recipe,
            removing: previousVote.map(\.isUpvote),
            adding: isUpvote
        )

        do {
            let vote = try await cloudKitService.submitVote(recipeId: recipe.id, isUpvote: isUpvote)
            userVotes[recipe.id] = vote
        } catch {
            // Undo optimistic update
            applyLocalVoteDelta(
                for: recipe,
                removing: isUpvote,
                adding: previousVote.map(\.isUpvote)
            )
            print("Failed to submit vote: \(error)")
        }
    }

    /// Remove vote from a recipe
    public func removeVote(from recipe: SharedRecipe) async {
        guard let existingVote = userVotes[recipe.id] else { return }

        // Optimistically update UI
        let previousVote = existingVote
        applyLocalVoteDelta(
            for: recipe,
            removing: previousVote.isUpvote,
            adding: nil
        )
        userVotes[recipe.id] = nil

        do {
            try await cloudKitService.removeVote(voteId: existingVote.id)
        } catch {
            // Restore on failure
            userVotes[recipe.id] = previousVote
            applyLocalVoteDelta(
                for: recipe,
                removing: nil,
                adding: previousVote.isUpvote
            )
            print("Failed to remove vote: \(error)")
        }
    }

    /// Get the user's vote state for a recipe
    public func voteState(for recipe: SharedRecipe) -> VoteState {
        VoteState(from: userVotes[recipe.id])
    }

    /// Apply a vote-count delta: optionally remove one vote type and/or add another.
    private func applyLocalVoteDelta(
        for recipe: SharedRecipe,
        removing: Bool?,
        adding: Bool?
    ) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }

        var upvotes = recipes[index].upvoteCount
        var downvotes = recipes[index].downvoteCount

        if let removing {
            if removing {
                upvotes = max(0, upvotes - 1)
            } else {
                downvotes = max(0, downvotes - 1)
            }
        }

        if let adding {
            if adding {
                upvotes += 1
            } else {
                downvotes += 1
            }
        }

        recipes[index] = recipes[index].withVoteCounts(upvotes: upvotes, downvotes: downvotes)
    }

    // MARK: - Reporting

    /// Report a recipe
    public func reportRecipe(_ recipe: SharedRecipe, reason: ReportReason) async throws {
        do {
            _ = try await cloudKitService.submitReport(recipeId: recipe.id, reason: reason)
        } catch let cloudKitError as CloudKitError {
            if case .alreadyReported = cloudKitError {
                throw SharedRecipeStoreError.alreadyReported
            }
            throw SharedRecipeStoreError.reportFailed(cloudKitError)
        } catch {
            throw SharedRecipeStoreError.reportFailed(error)
        }
    }

    /// Check if user has reported a recipe
    public func hasReported(_ recipe: SharedRecipe) async -> Bool {
        do {
            return try await cloudKitService.hasReported(recipeId: recipe.id)
        } catch {
            return false
        }
    }

    // MARK: - Import

    /// Convert a shared recipe to a local Recipe for importing
    public func importToPersonal(_ sharedRecipe: SharedRecipe, database: IngredientDatabase) -> Recipe {
        sharedRecipe.toRecipe(using: database)
    }

    // MARK: - Helpers

    private func mapError(_ cloudKitError: CloudKitError) -> SharedRecipeStoreError {
        switch cloudKitError {
        case .notAuthenticated:
            return .notAuthenticated
        case .alreadyReported:
            return .alreadyReported
        default:
            return .networkError(cloudKitError)
        }
    }
}
