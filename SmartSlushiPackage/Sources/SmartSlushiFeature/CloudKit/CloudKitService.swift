import CloudKit
import Foundation

// MARK: - CloudKit Record Types

/// Record type identifiers for CloudKit public database
public enum CloudKitRecordType {
    public static let sharedRecipe = "SharedRecipe"
    public static let vote = "Vote"
    public static let report = "Report"
}

// MARK: - CloudKit Errors

/// Errors that can occur during CloudKit operations
public enum CloudKitError: Error, LocalizedError {
    case notAuthenticated
    case networkUnavailable
    case serverError(Error)
    case recordNotFound
    case duplicateVote
    case alreadyReported
    case permissionDenied
    case quotaExceeded
    case invalidData(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign into iCloud to access community recipes."
        case .networkUnavailable:
            return "No network connection. Please check your internet and try again."
        case .serverError(let error):
            return "Server error: \(error.localizedDescription)"
        case .recordNotFound:
            return "The requested recipe could not be found."
        case .duplicateVote:
            return "You have already voted on this recipe."
        case .alreadyReported:
            return "You have already reported this recipe."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        case .quotaExceeded:
            return "CloudKit quota exceeded. Please try again later."
        case .invalidData(let message):
            return "Invalid data: \(message)"
        }
    }
}

// MARK: - CloudKit Service

/// Actor that handles all CloudKit public database operations for shared recipes
public actor CloudKitService {
    /// The CloudKit container
    private let container: CKContainer

    /// The public database for shared recipes
    private let publicDB: CKDatabase

    /// Cached user record ID
    private var cachedUserRecordID: CKRecord.ID?

    /// Shared instance using the app's default CloudKit container
    public static let shared = CloudKitService()

    /// Initialize with the default container (auto-created by Xcode based on bundle ID)
    public init() {
        self.container = CKContainer.default()
        self.publicDB = container.publicCloudDatabase
    }

    /// Initialize with a custom container identifier
    public init(containerIdentifier: String) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.publicDB = container.publicCloudDatabase
    }

    // MARK: - User Identity

    /// Fetch the current user's anonymous CloudKit record ID
    /// This ID is unique per user per container but doesn't reveal personal info
    public func fetchUserRecordID() async throws -> String {
        if let cached = cachedUserRecordID {
            return cached.recordName
        }

        do {
            let recordID = try await container.userRecordID()
            cachedUserRecordID = recordID
            return recordID.recordName
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Check if the user is signed into iCloud
    public func isUserAuthenticated() async -> Bool {
        do {
            let status = try await container.accountStatus()
            return status == .available
        } catch {
            return false
        }
    }

    // MARK: - Shared Recipes

    /// Publish a recipe to the public database
    public func publishRecipe(_ recipe: SharedRecipe) async throws -> SharedRecipe {
        let record = recipe.toCKRecord()

        do {
            let savedRecord = try await publicDB.save(record)
            guard let publishedRecipe = SharedRecipe(from: savedRecord) else {
                throw CloudKitError.invalidData("Failed to parse saved record")
            }
            return publishedRecipe
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Fetch shared recipes with query options
    public func fetchRecipes(
        query: SharedRecipeQuery,
        cursor: CKQueryOperation.Cursor? = nil
    ) async throws -> (recipes: [SharedRecipe], cursor: CKQueryOperation.Cursor?) {
        let predicate: NSPredicate

        if let searchText = query.searchText, !searchText.isEmpty {
            // Search by name (case-insensitive contains)
            predicate = NSPredicate(
                format: "isHidden == %@ AND (name CONTAINS[cd] %@ OR authorNotes CONTAINS[cd] %@)",
                NSNumber(value: false),
                searchText,
                searchText
            )
        } else {
            // Just filter out hidden recipes
            predicate = NSPredicate(format: "isHidden == %@", NSNumber(value: false))
        }

        let ckQuery = CKQuery(recordType: CloudKitRecordType.sharedRecipe, predicate: predicate)
        ckQuery.sortDescriptors = query.sortDescriptors

        do {
            let (matchResults, queryCursor) = try await publicDB.records(
                matching: ckQuery,
                resultsLimit: query.limit
            )

            var recipes: [SharedRecipe] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let recipe = SharedRecipe(from: record) {
                        recipes.append(recipe)
                    }
                case .failure:
                    // Skip failed records
                    continue
                }
            }

            return (recipes, queryCursor)
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Continue fetching recipes with a cursor
    public func fetchMoreRecipes(
        cursor: CKQueryOperation.Cursor
    ) async throws -> (recipes: [SharedRecipe], cursor: CKQueryOperation.Cursor?) {
        do {
            let (matchResults, queryCursor) = try await publicDB.records(continuingMatchFrom: cursor)

            var recipes: [SharedRecipe] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let recipe = SharedRecipe(from: record) {
                        recipes.append(recipe)
                    }
                case .failure:
                    continue
                }
            }

            return (recipes, queryCursor)
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Fetch a single recipe by ID
    public func fetchRecipe(id: String) async throws -> SharedRecipe? {
        let recordID = CKRecord.ID(recordName: id)

        do {
            let record = try await publicDB.record(for: recordID)
            return SharedRecipe(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Fetch recipes published by the current user
    public func fetchMyRecipes() async throws -> [SharedRecipe] {
        let userId = try await fetchUserRecordID()

        let predicate = NSPredicate(format: "authorId == %@", userId)
        let query = CKQuery(recordType: CloudKitRecordType.sharedRecipe, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "publishedAt", ascending: false)]

        do {
            let (matchResults, _) = try await publicDB.records(matching: query)

            var recipes: [SharedRecipe] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let recipe = SharedRecipe(from: record) {
                        recipes.append(recipe)
                    }
                case .failure:
                    continue
                }
            }

            return recipes
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Delete a published recipe (only the author can delete)
    public func deleteRecipe(id: String) async throws {
        let recordID = CKRecord.ID(recordName: id)

        do {
            try await publicDB.deleteRecord(withID: recordID)
        } catch {
            throw mapCloudKitError(error)
        }
    }

    // MARK: - Voting

    /// Submit or update a vote for a recipe
    public func submitVote(recipeId: String, isUpvote: Bool) async throws -> Vote {
        let userId = try await fetchUserRecordID()

        // Check for existing vote
        if let existingVote = try await fetchUserVote(recipeId: recipeId) {
            if existingVote.isUpvote == isUpvote {
                // Same vote type, no change needed
                return existingVote
            }
            // Different vote type, delete old and create new
            try await removeVote(voteId: existingVote.id)
        }

        // Create new vote record
        let record = CKRecord(recordType: CloudKitRecordType.vote)
        record["recipeId"] = recipeId
        record["voterId"] = userId
        record["isUpvote"] = isUpvote ? 1 : 0
        record["votedAt"] = Date()

        do {
            let savedRecord = try await publicDB.save(record)

            // Update the recipe's vote count
            try await updateRecipeVoteCount(recipeId: recipeId, isUpvote: isUpvote, increment: true)

            guard let vote = Vote(from: savedRecord) else {
                throw CloudKitError.invalidData("Failed to parse saved vote")
            }
            return vote
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Remove a vote
    public func removeVote(voteId: String) async throws {
        let recordID = CKRecord.ID(recordName: voteId)

        // First fetch the vote to get recipe info
        do {
            let record = try await publicDB.record(for: recordID)
            guard let vote = Vote(from: record) else {
                throw CloudKitError.invalidData("Invalid vote record")
            }

            // Delete the vote
            try await publicDB.deleteRecord(withID: recordID)

            // Update the recipe's vote count
            try await updateRecipeVoteCount(
                recipeId: vote.recipeId,
                isUpvote: vote.isUpvote,
                increment: false
            )
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Fetch the current user's vote for a recipe
    public func fetchUserVote(recipeId: String) async throws -> Vote? {
        let userId = try await fetchUserRecordID()

        let predicate = NSPredicate(
            format: "recipeId == %@ AND voterId == %@",
            recipeId,
            userId
        )
        let query = CKQuery(recordType: CloudKitRecordType.vote, predicate: predicate)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)

            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    return Vote(from: record)
                case .failure:
                    continue
                }
            }
            return nil
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Fetch user's votes for multiple recipes (batch operation)
    public func fetchUserVotes(recipeIds: [String]) async throws -> [String: Vote] {
        guard !recipeIds.isEmpty else { return [:] }

        let userId = try await fetchUserRecordID()

        let predicate = NSPredicate(
            format: "voterId == %@ AND recipeId IN %@",
            userId,
            recipeIds
        )
        let query = CKQuery(recordType: CloudKitRecordType.vote, predicate: predicate)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: recipeIds.count)

            var votes: [String: Vote] = [:]
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    if let vote = Vote(from: record) {
                        votes[vote.recipeId] = vote
                    }
                case .failure:
                    continue
                }
            }
            return votes
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Update a recipe's vote count
    private func updateRecipeVoteCount(recipeId: String, isUpvote: Bool, increment: Bool) async throws {
        let recordID = CKRecord.ID(recordName: recipeId)

        do {
            let record = try await publicDB.record(for: recordID)

            let countKey = isUpvote ? "upvoteCount" : "downvoteCount"
            let currentCount = record[countKey] as? Int ?? 0
            let newCount = increment ? currentCount + 1 : max(0, currentCount - 1)
            record[countKey] = newCount

            _ = try await publicDB.save(record)
        } catch {
            // Log but don't fail the vote operation
            print("Failed to update vote count: \(error)")
        }
    }

    // MARK: - Reporting

    /// Submit a report for a recipe
    public func submitReport(recipeId: String, reason: ReportReason) async throws -> Report {
        let userId = try await fetchUserRecordID()

        // Check if already reported
        if try await hasReported(recipeId: recipeId) {
            throw CloudKitError.alreadyReported
        }

        // Create report record
        let record = CKRecord(recordType: CloudKitRecordType.report)
        record["recipeId"] = recipeId
        record["reporterId"] = userId
        record["reason"] = reason.rawValue
        record["reportedAt"] = Date()

        do {
            let savedRecord = try await publicDB.save(record)

            // Update the recipe's report count
            try await updateRecipeReportCount(recipeId: recipeId)

            guard let report = Report(from: savedRecord) else {
                throw CloudKitError.invalidData("Failed to parse saved report")
            }
            return report
        } catch let error as CloudKitError {
            throw error
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Check if the current user has reported a recipe
    public func hasReported(recipeId: String) async throws -> Bool {
        let userId = try await fetchUserRecordID()

        let predicate = NSPredicate(
            format: "recipeId == %@ AND reporterId == %@",
            recipeId,
            userId
        )
        let query = CKQuery(recordType: CloudKitRecordType.report, predicate: predicate)

        do {
            let (matchResults, _) = try await publicDB.records(matching: query, resultsLimit: 1)
            return !matchResults.isEmpty
        } catch {
            throw mapCloudKitError(error)
        }
    }

    /// Update a recipe's report count and potentially hide it
    private func updateRecipeReportCount(recipeId: String) async throws {
        let recordID = CKRecord.ID(recordName: recipeId)

        do {
            let record = try await publicDB.record(for: recordID)

            let currentCount = record["reportCount"] as? Int ?? 0
            let newCount = currentCount + 1
            record["reportCount"] = newCount

            // Auto-hide if too many reports (threshold: 5)
            if newCount >= 5 {
                record["isHidden"] = true
            }

            _ = try await publicDB.save(record)
        } catch {
            // Log but don't fail the report operation
            print("Failed to update report count: \(error)")
        }
    }

    // MARK: - Error Mapping

    /// Map CloudKit errors to domain-specific errors
    private func mapCloudKitError(_ error: Error) -> CloudKitError {
        guard let ckError = error as? CKError else {
            return .serverError(error)
        }

        switch ckError.code {
        case .notAuthenticated:
            return .notAuthenticated
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .unknownItem:
            return .recordNotFound
        case .permissionFailure:
            return .permissionDenied
        case .quotaExceeded:
            return .quotaExceeded
        default:
            return .serverError(error)
        }
    }
}
