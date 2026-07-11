//
//  CloudKitShareHelper.swift
//  YouShu
//
//  Creates a CKShare using the raw CloudKit API with the correct
//  zone for NSPersistentCloudKitContainer (com.apple.coredata.cloudkit.zone).
//  The share is saved to CloudKit and then the system sharing UI is presented.
//

import SwiftUI
import CloudKit

// MARK: - Public API

@MainActor
func presentCloudSharingController(
    ledgerID: UUID,
    ledgerName: String,
    containerID: String
) {
    let ckContainer = CKContainer(identifier: containerID)
    let database = ckContainer.privateCloudDatabase

    // NSPersistentCloudKitContainer stores records in this zone within
    // the private database.
    let zoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )

    let uuidString = ledgerID.uuidString

    // Try to find the record by its CD_id field rather than guessing
    // the CKRecord name (which is derived from NSManagedObjectID).
    findRecord(database: database, zoneID: zoneID, uuidString: uuidString, retriesLeft: 8) { rootRecord in
        guard let rootRecord = rootRecord else {
            DispatchQueue.main.async {
                showAlert(title: "分享失败",
                          message: "账本尚未同步到 iCloud。\n请确认 iCloud 云盘已开启，等待数据同步完成后重试。")
            }
            return
        }
        proceedWithShare(rootRecord: rootRecord, ledgerName: ledgerName, database: database, ckContainer: ckContainer)
    }
}

// MARK: - Record lookup

/// Search for a FamilyLedger CKRecord by its UUID, with retries for
/// not-yet-synced data.
private func findRecord(
    database: CKDatabase,
    zoneID: CKRecordZone.ID,
    uuidString: String,
    retriesLeft: Int,
    completion: @escaping (CKRecord?) -> Void
) {
    // Try query by CD_id field — this works regardless of the actual record name.
    // Core Data stores UUIDs as lowercase strings in CK, but we try both cases.
    let candidates = [uuidString, uuidString.uppercased()]
    var candidateIndex = 0
    var lastError: Error?

    func tryNextCandidate() {
        guard candidateIndex < candidates.count else {
            // All candidates exhausted; try direct record-name fetch as last resort
            tryDirectFetch()
            return
        }

        let value = candidates[candidateIndex]
        let predicate = NSPredicate(format: "CD_id == %@", value)
        let query = CKQuery(recordType: "CD_FamilyLedger", predicate: predicate)

        database.perform(query, inZoneWith: zoneID) { records, error in
            if let record = records?.first {
                print("✅ Found record via CKQuery [\(value.suffix(8))], recordName=\(record.recordID.recordName)")
                completion(record)
                return
            }
            lastError = error
            candidateIndex += 1
            tryNextCandidate()
        }
    }

    func tryDirectFetch() {
        // Last resort: try direct record-name fetch (zone + default zone)
        let zoneRecordID = CKRecord.ID(recordName: uuidString, zoneID: zoneID)
        database.fetch(withRecordID: zoneRecordID) { record, error in
            if let record = record {
                print("✅ Found via direct fetch (zone), recordName=\(record.recordID.recordName)")
                completion(record)
                return
            }
            let defaultID = CKRecord.ID(recordName: uuidString)
            database.fetch(withRecordID: defaultID) { record2, _ in
                if let record2 = record2 {
                    print("✅ Found via direct fetch (default zone)")
                    completion(record2)
                    return
                }

                // Not found — retry with backoff
                if retriesLeft > 0 {
                    let delay = Double(8 - retriesLeft + 1) * 2.0  // 2, 4, 6, ... seconds
                    print("⏳ Record not found, retrying in \(delay)s (\(retriesLeft) retries left)")
                    DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                        findRecord(database: database, zoneID: zoneID,
                                   uuidString: uuidString, retriesLeft: retriesLeft - 1,
                                   completion: completion)
                    }
                } else {
                    if let err = lastError {
                        print("❌ All lookups failed, last error: \(err.localizedDescription)")
                    } else {
                        print("❌ Record not found after all attempts")
                    }
                    completion(nil)
                }
            }
        }
    }

    tryNextCandidate()
}

// MARK: - Share creation

private func proceedWithShare(
    rootRecord: CKRecord,
    ledgerName: String,
    database: CKDatabase,
    ckContainer: CKContainer
) {
    let share = CKShare(rootRecord: rootRecord)
    share[CKShare.SystemFieldKey.title] = "\(ledgerName) · 家庭账本" as NSString
    share.publicPermission = .none

    DispatchQueue.main.async {
        let controller = UICloudSharingController { (_, preparationHandler) in
            // CloudKit requires rootRecord + share to be saved in the same operation.
            let operation = CKModifyRecordsOperation(recordsToSave: [share, rootRecord],
                                                      recordIDsToDelete: nil)
            operation.savePolicy = .ifServerRecordUnchanged
            operation.modifyRecordsCompletionBlock = { _, _, error in
                if let error = error {
                    print("❌ Atomic save error: \(error.localizedDescription)")
                } else {
                    print("✅ CKShare + rootRecord saved atomically")
                }
                preparationHandler(share, ckContainer, error)
            }
            database.add(operation)
        }
        controller.availablePermissions = [.allowReadWrite, .allowPrivate]
        controller.modalPresentationStyle = .formSheet
        presentFromTopViewController(controller)
    }
}

// MARK: - Presentation helpers

private func presentFromTopViewController(_ controller: UIViewController) {
    guard let windowScene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
        let rootVC = windowScene.keyWindow?.rootViewController else {
        print("⚠️ Cannot present CloudKit share: no active window scene")
        return
    }

    var topVC = rootVC
    while let presented = topVC.presentedViewController {
        topVC = presented
    }

    topVC.present(controller, animated: true)
}

private func showAlert(title: String, message: String) {
    guard let windowScene = UIApplication.shared.connectedScenes
        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
        let rootVC = windowScene.keyWindow?.rootViewController else { return }

    var topVC = rootVC
    while let presented = topVC.presentedViewController {
        topVC = presented
    }

    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "好", style: .default))
    topVC.present(alert, animated: true)
}


