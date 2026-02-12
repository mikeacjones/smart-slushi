import CloudKit
import Foundation

// MARK: - Shared Recipe Query

/// Configuration for querying shared recipes from CloudKit
public struct SharedRecipeQuery: Sendable {
    /// Search text to filter by name or author notes
    public var searchText: String?

    /// How to sort the results
    public var sortOrder: SortOrder

    /// Maximum number of results to return per page
    public var limit: Int

    /// Sort order options for shared recipes
    public enum SortOrder: String, CaseIterable, Sendable {
        case mostRecent = "Most Recent"
        case mostPopular = "Most Popular"
        case topRated = "Top Rated"

        /// Icon for display in UI
        public var icon: String {
            switch self {
            case .mostRecent:
                return "clock"
            case .mostPopular:
                return "flame"
            case .topRated:
                return "star"
            }
        }

        /// Description for accessibility
        public var description: String {
            switch self {
            case .mostRecent:
                return "Sort by newest first"
            case .mostPopular:
                return "Sort by highest score (upvotes minus downvotes)"
            case .topRated:
                return "Sort by most upvotes"
            }
        }
    }

    public init(
        searchText: String? = nil,
        sortOrder: SortOrder = .mostRecent,
        limit: Int = 20
    ) {
        self.searchText = searchText
        self.sortOrder = sortOrder
        self.limit = limit
    }

    /// Get the CloudKit sort descriptors for this query
    var sortDescriptors: [NSSortDescriptor] {
        switch sortOrder {
        case .mostRecent:
            return [
                NSSortDescriptor(key: "publishedAt", ascending: false)
            ]
        case .mostPopular:
            // Sort by score (upvotes - downvotes) descending
            // CloudKit doesn't support computed fields, so approximate by:
            // 1) More upvotes, 2) fewer downvotes, 3) newer recency.
            return [
                NSSortDescriptor(key: "upvoteCount", ascending: false),
                NSSortDescriptor(key: "downvoteCount", ascending: true),
                NSSortDescriptor(key: "publishedAt", ascending: false)
            ]
        case .topRated:
            return [
                NSSortDescriptor(key: "upvoteCount", ascending: false),
                NSSortDescriptor(key: "publishedAt", ascending: false)
            ]
        }
    }
}
