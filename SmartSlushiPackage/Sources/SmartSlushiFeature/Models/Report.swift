import Foundation

// MARK: - Report Reason

/// Reasons a user can report a shared recipe
public enum ReportReason: String, CaseIterable, Sendable {
    case inappropriate = "inappropriate"
    case spam = "spam"
    case dangerous = "dangerous"
    case copyright = "copyright"
    case other = "other"

    public var displayName: String {
        switch self {
        case .inappropriate:
            return "Inappropriate Content"
        case .spam:
            return "Spam or Advertising"
        case .dangerous:
            return "Dangerous Recipe"
        case .copyright:
            return "Copyright Violation"
        case .other:
            return "Other"
        }
    }

    public var description: String {
        switch self {
        case .inappropriate:
            return "Contains offensive or inappropriate content"
        case .spam:
            return "Promotes products or services unrelated to recipes"
        case .dangerous:
            return "Contains ingredients or instructions that could be harmful"
        case .copyright:
            return "Uses copyrighted content without permission"
        case .other:
            return "Another issue not listed above"
        }
    }
}

// MARK: - Report

/// Represents a report against a shared recipe
public struct Report: Identifiable, Sendable {
    /// CloudKit record ID (recordName)
    public let id: String

    /// Reference to the SharedRecipe being reported
    public let recipeId: String

    /// Anonymous CloudKit user record ID of the reporter
    public let reporterId: String

    /// Reason for the report
    public let reason: ReportReason

    /// When the report was submitted
    public let reportedAt: Date

    public init(
        id: String,
        recipeId: String,
        reporterId: String,
        reason: ReportReason,
        reportedAt: Date = Date()
    ) {
        self.id = id
        self.recipeId = recipeId
        self.reporterId = reporterId
        self.reason = reason
        self.reportedAt = reportedAt
    }
}

// MARK: - Hashable

extension Report: Hashable {
    public static func == (lhs: Report, rhs: Report) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
