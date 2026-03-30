import Foundation

struct CollaborationContext {
    let profile: UserProfilePayload
    let inventoryMembers: [InventoryMemberPayload]
    let pendingInvites: [InventoryInvitePayload]
    let sharedInvites: [InventoryInvitePayload]

    var inventoryId: String {
        profile.inventoryId ?? profile.id
    }
}

enum CollaborationService {
    static func loadContext(userId: String, email: String) async throws -> CollaborationContext {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let profile = try await ensureUserProfile(userId: userId, email: normalizedEmail)
        let inventoryId = profile.inventoryId ?? userId

        async let members = SupabaseDataService.fetchInventoryMembers(inventoryId: inventoryId)
        async let invites = SupabaseDataService.fetchPendingInventoryInvites(email: normalizedEmail)
        async let sharedInvites = SupabaseDataService.fetchInventoryInvites(inventoryId: inventoryId)

        return try await CollaborationContext(
            profile: profile,
            inventoryMembers: members,
            pendingInvites: invites,
            sharedInvites: sharedInvites
        )
    }

    static func sendInvite(
        invitedEmail: String,
        fromUserId: String,
        fromUserEmail: String,
        currentProfile: UserProfilePayload?
    ) async throws -> String {
        let normalizedEmail = invitedEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else {
            throw DataServiceError.serverError("Invite email cannot be empty.")
        }

        let normalizedSenderEmail = fromUserEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedEmail != normalizedSenderEmail else {
            throw DataServiceError.serverError("Use another family member's email.")
        }

        let profile = try await resolvedProfile(userId: fromUserId, email: normalizedSenderEmail, currentProfile: currentProfile)
        let inventoryId = profile.inventoryId ?? fromUserId
        let existingProfile = try await SupabaseDataService.fetchUserProfile(email: normalizedEmail)

        if existingProfile?.inventoryId == inventoryId {
            throw DataServiceError.serverError("\(normalizedEmail) is already in this inventory.")
        }

        let pendingInvites = try await SupabaseDataService.fetchPendingInventoryInvites(email: normalizedEmail)
        if pendingInvites.contains(where: { $0.inventoryId == inventoryId }) {
            throw DataServiceError.serverError("An invite is already pending for \(normalizedEmail).")
        }

        let invite = InventoryInvitePayload(
            id: UUID(),
            inventoryId: inventoryId,
            invitedEmail: normalizedEmail,
            invitedByUserId: fromUserId,
            invitedByEmail: fromUserEmail,
            status: "pending",
            createdAt: Date()
        )
        _ = try await SupabaseDataService.createInventoryInvite(invite)
        return normalizedEmail
    }

    static func acceptInvite(
        _ invite: InventoryInvitePayload,
        userId: String,
        userEmail: String,
        currentProfile: UserProfilePayload?
    ) async throws -> String {
        let normalizedEmail = userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let profile = try await resolvedProfile(userId: userId, email: normalizedEmail, currentProfile: currentProfile)

        try await migrateOwnedItems(userId: userId, to: invite.inventoryId)

        let payload = UserProfilePayload(
            id: userId,
            email: normalizedEmail,
            defaultCurrency: profile.defaultCurrency,
            inventoryId: invite.inventoryId
        )
        _ = try await SupabaseDataService.upsertUserProfile(payload)

        var acceptedInvite = invite
        acceptedInvite.status = "accepted"
        _ = try await SupabaseDataService.updateInventoryInvite(acceptedInvite)

        return invite.inventoryId
    }

    static func removeAccess(email: String, memberId: String?, invite: InventoryInvitePayload?) async throws {
        if let invite {
            if invite.status == "accepted" {
                try await revokeAcceptedAccess(email: email, memberId: memberId)
            }
            try await SupabaseDataService.deleteInventoryInvite(id: invite.id)
            return
        }

        try await revokeAcceptedAccess(email: email, memberId: memberId)
    }

    private static func revokeAcceptedAccess(email: String, memberId: String?) async throws {
        let profile: UserProfilePayload?
        if let memberId {
            profile = try await SupabaseDataService.fetchUserProfile(userId: memberId)
        } else {
            profile = try await SupabaseDataService.fetchUserProfile(email: email)
        }

        guard var profile else {
            throw DataServiceError.serverError("Could not find a profile for \(email).")
        }

        profile.inventoryId = profile.id
        _ = try await SupabaseDataService.upsertUserProfile(profile)
    }

    private static func migrateOwnedItems(userId: String, to inventoryId: String) async throws {
        let ownedItems = try await SupabaseDataService.fetchItems(userId: userId)
        let itemsToMove = ownedItems.filter { $0.inventoryId != inventoryId }

        guard !itemsToMove.isEmpty else { return }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for item in itemsToMove {
                group.addTask {
                    var updatedItem = item
                    updatedItem.inventoryId = inventoryId
                    _ = try await SupabaseDataService.updateItem(id: item.id, updatedItem)
                }
            }

            try await group.waitForAll()
        }
    }

    private static func ensureUserProfile(userId: String, email: String) async throws -> UserProfilePayload {
        if let existingProfile = try await SupabaseDataService.fetchUserProfile(userId: userId) {
            return existingProfile
        }

        let payload = UserProfilePayload(
            id: userId,
            email: email,
            defaultCurrency: nil,
            inventoryId: userId
        )
        return try await SupabaseDataService.upsertUserProfile(payload)
    }

    private static func resolvedProfile(
        userId: String,
        email: String,
        currentProfile: UserProfilePayload?
    ) async throws -> UserProfilePayload {
        if let currentProfile {
            return currentProfile
        }

        return try await ensureUserProfile(userId: userId, email: email)
    }
}
