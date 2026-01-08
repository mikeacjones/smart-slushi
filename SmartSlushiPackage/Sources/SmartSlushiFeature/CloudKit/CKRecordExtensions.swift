import CloudKit
import Foundation

// MARK: - SharedRecipe + CKRecord

extension SharedRecipe {
    /// Initialize from a CloudKit record
    public init?(from record: CKRecord) {
        guard record.recordType == CloudKitRecordType.sharedRecipe else {
            return nil
        }

        guard let name = record["name"] as? String,
              let authorId = record["authorId"] as? String else {
            return nil
        }

        // Decode ingredients from JSON data
        let ingredients: [ExportedIngredient]
        if let ingredientsData = record["ingredientsData"] as? Data {
            let decoder = JSONDecoder()
            ingredients = (try? decoder.decode([ExportedIngredient].self, from: ingredientsData)) ?? []
        } else {
            ingredients = []
        }

        let targetUnit: MeasurementUnit
        if let unitRaw = record["targetUnitRaw"] as? String,
           let unit = MeasurementUnit(rawValue: unitRaw) {
            targetUnit = unit
        } else {
            targetUnit = .oz
        }

        self.init(
            id: record.recordID.recordName,
            authorId: authorId,
            name: name,
            description: record["description"] as? String,
            authorNotes: record["authorNotes"] as? String,
            ingredients: ingredients,
            targetBatchSize: record["targetBatchSize"] as? Double ?? 72.0,
            targetUnit: targetUnit,
            publishedAt: record["publishedAt"] as? Date ?? record.creationDate ?? Date(),
            updatedAt: record["updatedAt"] as? Date ?? record.modificationDate ?? Date(),
            finalABV: record["finalABV"] as? Double ?? 0.0,
            finalBrix: record["finalBrix"] as? Double ?? 0.0,
            upvoteCount: record["upvoteCount"] as? Int ?? 0,
            downvoteCount: record["downvoteCount"] as? Int ?? 0,
            reportCount: record["reportCount"] as? Int ?? 0,
            isHidden: record["isHidden"] as? Bool ?? false
        )
    }

    /// Convert to a CloudKit record for saving
    public func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitRecordType.sharedRecipe)

        record["name"] = name
        record["authorId"] = authorId
        record["description"] = description
        record["authorNotes"] = authorNotes

        // Encode ingredients as JSON data
        let encoder = JSONEncoder()
        if let ingredientsData = try? encoder.encode(ingredients) {
            record["ingredientsData"] = ingredientsData
        }

        record["targetBatchSize"] = targetBatchSize
        record["targetUnitRaw"] = targetUnit.rawValue
        record["publishedAt"] = publishedAt
        record["updatedAt"] = updatedAt
        record["finalABV"] = finalABV
        record["finalBrix"] = finalBrix
        record["upvoteCount"] = upvoteCount
        record["downvoteCount"] = downvoteCount
        record["reportCount"] = reportCount
        record["isHidden"] = isHidden

        return record
    }
}

// MARK: - Vote + CKRecord

extension Vote {
    /// Initialize from a CloudKit record
    public init?(from record: CKRecord) {
        guard record.recordType == CloudKitRecordType.vote else {
            return nil
        }

        guard let recipeId = record["recipeId"] as? String,
              let voterId = record["voterId"] as? String else {
            return nil
        }

        self.id = record.recordID.recordName
        self.recipeId = recipeId
        self.voterId = voterId
        self.isUpvote = (record["isUpvote"] as? Int ?? 1) == 1
        self.votedAt = record["votedAt"] as? Date ?? record.creationDate ?? Date()
    }

    /// Convert to a CloudKit record for saving
    public func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitRecordType.vote)

        record["recipeId"] = recipeId
        record["voterId"] = voterId
        record["isUpvote"] = isUpvote ? 1 : 0
        record["votedAt"] = votedAt

        return record
    }
}

// MARK: - Report + CKRecord

extension Report {
    /// Initialize from a CloudKit record
    public init?(from record: CKRecord) {
        guard record.recordType == CloudKitRecordType.report else {
            return nil
        }

        guard let recipeId = record["recipeId"] as? String,
              let reporterId = record["reporterId"] as? String else {
            return nil
        }

        self.id = record.recordID.recordName
        self.recipeId = recipeId
        self.reporterId = reporterId

        if let reasonRaw = record["reason"] as? String,
           let reason = ReportReason(rawValue: reasonRaw) {
            self.reason = reason
        } else {
            self.reason = .other
        }

        self.reportedAt = record["reportedAt"] as? Date ?? record.creationDate ?? Date()
    }

    /// Convert to a CloudKit record for saving
    public func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: CloudKitRecordType.report)

        record["recipeId"] = recipeId
        record["reporterId"] = reporterId
        record["reason"] = reason.rawValue
        record["reportedAt"] = reportedAt

        return record
    }
}
