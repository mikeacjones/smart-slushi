import Foundation

// MARK: - Vote

/// Represents a user's vote on a shared recipe
public struct Vote: Identifiable, Sendable {
    /// CloudKit record ID (recordName)
    public let id: String

    /// Reference to the SharedRecipe being voted on
    public let recipeId: String

    /// Anonymous CloudKit user record ID of the voter
    public let voterId: String

    /// True for upvote, false for downvote
    public let isUpvote: Bool

    /// When the vote was cast
    public let votedAt: Date

    public init(
        id: String,
        recipeId: String,
        voterId: String,
        isUpvote: Bool,
        votedAt: Date = Date()
    ) {
        self.id = id
        self.recipeId = recipeId
        self.voterId = voterId
        self.isUpvote = isUpvote
        self.votedAt = votedAt
    }
}

// MARK: - Hashable

extension Vote: Hashable {
    public static func == (lhs: Vote, rhs: Vote) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Vote State

/// Represents the user's current vote state for a recipe
public enum VoteState: Equatable, Sendable {
    case none
    case upvoted(Vote)
    case downvoted(Vote)

    public var isUpvoted: Bool {
        if case .upvoted = self { return true }
        return false
    }

    public var isDownvoted: Bool {
        if case .downvoted = self { return true }
        return false
    }

    public var vote: Vote? {
        switch self {
        case .none:
            return nil
        case .upvoted(let vote), .downvoted(let vote):
            return vote
        }
    }

    public init(from vote: Vote?) {
        guard let vote = vote else {
            self = .none
            return
        }
        self = vote.isUpvote ? .upvoted(vote) : .downvoted(vote)
    }
}
