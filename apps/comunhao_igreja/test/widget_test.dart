import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:comunhao_igreja/church_admin_app.dart';
import 'package:comunhao_shared/comunhao_shared.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows church admin auth shell', (tester) async {
    await tester.pumpWidget(
      ChurchAdminApp(
        authRepository: _FakeAuthRepository(),
        backofficeRepository: _FakeBackofficeRepository(),
        financeRepository: _FakeFinanceRepository(),
        calendarRepository: _FakeCalendarRepository(),
        operationsRepository: _FakeOperationsRepository(),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 400));

    expect(find.text('Comunhao Igreja'), findsWidgets);
    expect(find.text('Conta do pastor'), findsOneWidget);
  });
}

class _FakeCalendarRepository implements CalendarRepository {
  @override
  Future<void> checkInWithQrPayload(String qrPayload) async {}

  @override
  Future<void> closeEventCheckin(String occurrenceId) async {}

  @override
  Future<PlatformCalendarMetrics> fetchPlatformCalendarMetrics() async =>
      const PlatformCalendarMetrics(
        churches: 0,
        events: 0,
        upcomingEvents: 0,
        openCheckins: 0,
        attendances: 0,
        birthdaysNext31Days: 0,
      );

  @override
  Future<EventAttendanceSummary> fetchAttendanceSummary(String eventId) async =>
      const EventAttendanceSummary(
        total: 0,
        members: 0,
        visitors: 0,
        children: 0,
        manual: 0,
        qr: 0,
      );

  @override
  Future<List<EventAttendanceRow>> fetchAttendanceRows(String eventId) async =>
      const [];

  @override
  Future<List<ChurchBirthdayMember>> fetchBirthdays(
    String churchId, {
    int days = 31,
  }) async =>
      const [];

  @override
  Future<List<CalendarEventOccurrence>> fetchOccurrences(
    String churchId, {
    String? eventId,
  }) async =>
      const [];

  @override
  Future<List<CalendarEventOccurrence>> generateEventOccurrences(
    String eventId,
  ) async =>
      const [];

  @override
  Future<void> manualCheckInEvent({
    required String eventId,
    String? occurrenceId,
    String? profileId,
    String? visitorName,
    String? visitorPhone,
    String? notes,
  }) async {}

  @override
  Future<ChildCheckinRecord> manualChildCheckInEvent({
    required String eventId,
    String? occurrenceId,
    required String childName,
    String? guardianName,
    String? guardianPhone,
    String? roomName,
    String? notes,
  }) async =>
      ChildCheckinRecord(
        id: 'child-checkin',
        childName: childName,
        securityCode: 'ABC123',
        checkedInAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  Future<ChildCheckinRecord> checkOutChildEvent({
    required String childCheckinId,
    required String securityCode,
    String? pickupPerson,
  }) async =>
      ChildCheckinRecord(
        id: childCheckinId,
        childName: 'Crianca',
        securityCode: securityCode,
        checkedInAt: DateTime.fromMillisecondsSinceEpoch(0),
        checkedOutAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  Future<String> openEventCheckin(String occurrenceId,
          {int minutes = 180}) async =>
      'demo-token';

  @override
  Future<int> prepareInternalReminders(String churchId) async => 0;

  @override
  Future<void> sendBirthdayMessage({
    required String churchId,
    required String profileId,
    required String message,
  }) async {}
}

class _FakeOperationsRepository implements OperationsRepository {
  static const _metrics = OperationalMetrics(
    ministriesActive: 0,
    groupsActive: 0,
    tasksPending: 0,
    tasksOverdue: 0,
    rostersPending: 0,
    assetsMaintenance: 0,
    maintenancePending: 0,
    documentsExpiring: 0,
    reservationsPending: 0,
    purchasesPending: 0,
    stockLow: 0,
  );

  @override
  Future<void> clearDemoData(String churchId) async {}

  @override
  Future<PlatformOperationalMetrics> fetchPlatformOperationalMetrics() async =>
      const PlatformOperationalMetrics(
        ministries: 0,
        groups: 0,
        tasksOpen: 0,
        tasksOverdue: 0,
        rostersPending: 0,
        assets: 0,
        assetsMaintenance: 0,
        purchaseRequestsPending: 0,
        volunteerOpportunitiesOpen: 0,
        joinRequestsPending: 0,
      );

  @override
  Future<MemberOperationsSnapshot> fetchMemberOperations({
    required String churchId,
    required String membershipId,
  }) async =>
      const MemberOperationsSnapshot(
        metrics: _metrics,
        groups: [],
        tasks: [],
        rosters: [],
        joinRequests: [],
        opportunities: [],
        applications: [],
      );

  @override
  Future<OperationsSnapshot> fetchSnapshot(String churchId) async =>
      const OperationsSnapshot(
        metrics: _metrics,
        groups: [],
        tasks: [],
        rosters: [],
        maintenance: [],
        documents: [],
        purchases: [],
        inventory: [],
      );

  @override
  Future<ChurchGroup> saveGroup({
    String? groupId,
    required String churchId,
    String? ministryId,
    required String name,
    required String groupType,
    String? description,
    String? location,
    String? usualDay,
    String? usualTime,
  }) async =>
      ChurchGroup(
        id: groupId ?? 'group',
        churchId: churchId,
        name: name,
        groupType: groupType,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  Future<ChurchDocument> saveDocument({
    String? documentId,
    required String churchId,
    required String title,
    required String documentType,
    String? description,
    DateTime? validUntil,
    required String confidentiality,
    String? storageBucket,
    String? storagePath,
  }) async =>
      ChurchDocument(
        id: documentId ?? 'document',
        title: title,
        documentType: documentType,
        validUntil: validUntil,
        confidentiality: confidentiality,
      );

  @override
  Future<InventoryItem> saveInventoryItem({
    String? itemId,
    required String churchId,
    String? ministryId,
    required String name,
    required String unit,
    required num quantityCurrent,
    required num quantityMinimum,
    String? location,
  }) async =>
      InventoryItem(
        id: itemId ?? 'inventory',
        name: name,
        unit: unit,
        quantityCurrent: quantityCurrent,
        quantityMinimum: quantityMinimum,
      );

  @override
  Future<MinistryJoinRequest> createMinistryJoinRequest({
    required String churchId,
    required String membershipId,
    String? ministryId,
    String? groupId,
    String? interest,
    String? experience,
  }) async =>
      MinistryJoinRequest(
        id: 'join-request',
        churchId: churchId,
        interest: interest,
        experience: experience,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  Future<VolunteerApplication> applyToVolunteerOpportunity({
    required String opportunityId,
    required String membershipId,
    String? notes,
  }) async =>
      VolunteerApplication(
        id: 'application',
        opportunityId: opportunityId,
        notes: notes,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  @override
  Future<ServiceRoster> respondToRoster({
    required String rosterId,
    required String status,
    String? notes,
  }) async =>
      ServiceRoster(
        id: rosterId,
        churchId: 'church',
        roleTitle: 'Escala',
        startsAt: DateTime.fromMillisecondsSinceEpoch(0),
        status: status,
      );

  @override
  Future<MaintenanceRequest> saveMaintenance({
    String? maintenanceId,
    required String churchId,
    String? assetId,
    required String problem,
    required String priority,
    String? supplier,
    num? estimatedCost,
    DateTime? expectedAt,
  }) async =>
      MaintenanceRequest(
        id: maintenanceId ?? 'maintenance',
        churchId: churchId,
        problem: problem,
        priority: priority,
        expectedAt: expectedAt,
      );

  @override
  Future<PurchaseRequest> savePurchaseRequest({
    String? requestId,
    required String churchId,
    String? ministryId,
    required String requestedByMembershipId,
    required String itemName,
    required int quantity,
    String? justification,
    num? estimatedAmount,
  }) async =>
      PurchaseRequest(
        id: requestId ?? 'purchase',
        itemName: itemName,
        quantity: quantity,
        estimatedAmount: estimatedAmount,
      );

  @override
  Future<ServiceRoster> saveRoster({
    String? rosterId,
    required String churchId,
    String? ministryId,
    required String roleTitle,
    required String assignedMembershipId,
    required DateTime startsAt,
    DateTime? endsAt,
    String? location,
    String? instructions,
  }) async =>
      ServiceRoster(
        id: rosterId ?? 'roster',
        churchId: churchId,
        roleTitle: roleTitle,
        startsAt: startsAt,
        location: location,
      );

  @override
  Future<OperationalTask> saveTask({
    String? taskId,
    required String churchId,
    String? ministryId,
    String? groupId,
    required String title,
    String? description,
    String? responsibleMembershipId,
    required String priority,
    required String status,
    DateTime? dueAt,
  }) async =>
      OperationalTask(
        id: taskId ?? 'task',
        churchId: churchId,
        title: title,
        description: description,
        priority: priority,
        status: status,
        dueAt: dueAt,
      );
}

class _FakeAuthRepository implements ComunhaoAuthRepository {
  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  Session? get currentSession => null;

  @override
  User? get currentUser => null;

  @override
  Future<void> resendPhoneOtp({required String phone}) async {}

  @override
  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<AuthResponse> signUpWithPhone({
    required String fullName,
    required String phone,
    required String password,
    String? birthDate,
    Map<String, dynamic> metadata = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) {
    throw UnimplementedError();
  }
}

class _FakeBackofficeRepository implements BackofficeRepository {
  @override
  Future<Map<String, dynamic>> createPaysuiteCheckout({
    required num amountMzn,
    required String provider,
    required String phone,
    required String description,
  }) async =>
      <String, dynamic>{};

  @override
  Future<ChurchSubscription> adminUpdateChurchSubscription({
    required String churchId,
    required String status,
    String? planCode,
    int? periodDays,
    int? graceDays,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<ChurchApplication>> fetchApplicationsForReview() async =>
      const [];

  @override
  Future<List<ManagedAnnouncement>> fetchChurchAnnouncements(
    String churchId,
  ) async =>
      const [];

  @override
  Future<List<ManagedCampaign>> fetchChurchCampaigns(String churchId) async =>
      const [];

  @override
  Future<List<ChurchOverview>> fetchChurchOverviews() async => const [];

  @override
  Future<List<ManagedEvent>> fetchChurchEvents(String churchId) async =>
      const [];

  @override
  Future<List<ManagedMember>> fetchChurchMembers(String churchId) async =>
      const [];

  @override
  Future<List<ManagedPrayerRequest>> fetchChurchPrayerRequests(
    String churchId, {
    int limit = 10,
  }) async =>
      const [];

  @override
  Future<List<ManagedPrayerResponse>> fetchPrayerRequestResponses(
    String prayerRequestId,
  ) async =>
      const [];

  @override
  Future<ManagedPrayerResponse> respondToPrayerRequest({
    required String prayerRequestId,
    required String body,
  }) async =>
      ManagedPrayerResponse(
        id: 'response-1',
        prayerRequestId: prayerRequestId,
        churchId: 'church-1',
        responderProfileId: 'pastor-1',
        body: body,
        createdAt: DateTime(2026, 1, 1),
      );

  @override
  Future<List<ChurchAsset>> fetchChurchAssets(String churchId) async =>
      const [];

  @override
  Future<List<ChurchExpense>> fetchChurchExpenses(String churchId) async =>
      const [];

  @override
  Future<List<ChurchCommunication>> fetchChurchCommunications(
    String churchId,
  ) async =>
      const [];

  @override
  Future<List<ChurchMinistry>> fetchChurchMinistries(String churchId) async =>
      const [];

  @override
  Future<List<ChurchVisitor>> fetchChurchVisitors(String churchId) async =>
      const [];

  @override
  Future<List<String>> fetchCurrentPlatformRoles() async => const [];

  @override
  Future<List<PlatformAuditLog>> fetchPlatformAuditLogs({
    int limit = 100,
    String? churchId,
  }) async =>
      const [];

  @override
  Future<PlatformDashboardSnapshot> fetchPlatformDashboard() async =>
      const PlatformDashboardSnapshot(
        totalChurches: 0,
        activeChurches: 0,
        inactiveChurches: 0,
        totalMembers: 0,
        totalPastors: 0,
        pendingApplications: 0,
        pendingPlanRequests: 0,
        pendingWithdrawals: 0,
        monthRevenue: 0,
      );

  @override
  Future<LaunchReadinessSnapshot> fetchLaunchReadiness() async =>
      const LaunchReadinessSnapshot(
        classification: 'not_ready',
        blockers: 0,
        criticalOpen: 0,
        checklist: [],
        integrations: [],
        storage: [],
        vidaNova: {},
        demoSummary: {},
      );

  @override
  Future<LaunchChecklistItem> updateLaunchChecklistItem({
    required String itemKey,
    required String status,
    String? notes,
    String? responsible,
  }) async =>
      LaunchChecklistItem(
        itemKey: itemKey,
        title: 'Item',
        category: 'Teste',
        status: status,
        isCritical: true,
      );

  @override
  Future<List<PlatformUser>> fetchPlatformUsers() async => const [];

  @override
  Future<ChurchSubscription?> fetchChurchSubscription(String churchId) async =>
      null;

  @override
  Future<List<ChurchSubscriptionRequest>> fetchChurchSubscriptionRequests(
    String churchId,
  ) async =>
      const [];

  @override
  Future<List<ManagedChurch>> fetchManagedChurches() async => const [];

  @override
  Future<void> updateManagedChurchName({
    required String churchId,
    required String name,
  }) async {}

  @override
  Future<void> updateManagedChurchProfile({
    required String churchId,
    required String name,
    String? phone,
    String? email,
    String? tagline,
    String? logoUrl,
    String? primaryColor,
    String? secondaryColor,
  }) async {}

  @override
  Future<Map<String, dynamic>> deleteManagedChurch(String churchId) async =>
      const {};

  @override
  Future<List<ChurchApplication>> fetchOwnChurchApplications() async =>
      const [];

  @override
  Future<List<ChurchSubscriptionRequest>>
      fetchPendingSubscriptionRequests() async => const [];

  @override
  Future<List<SubscriptionPlan>> fetchSubscriptionPlans() async => const [];

  @override
  Future<ChurchSubscriptionRequest> requestSubscriptionPlan({
    required String churchId,
    required String planCode,
    String? paymentProvider,
    String? payerPhone,
    String? paymentReference,
    String? paymentNotes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String?> reviewChurchApplication({
    required String applicationId,
    required String decision,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchSubscription?> reviewSubscriptionRequest({
    required String requestId,
    required String decision,
    int? periodDays,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchApplication> saveChurchApplication(
    ChurchApplication application,
  ) {
    throw UnimplementedError();
  }

  @override
  Future<ManagedAnnouncement> saveChurchAnnouncement({
    String? announcementId,
    required String churchId,
    required String title,
    required String body,
    String? imageUrl,
    required bool pinned,
    DateTime? publishedAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ManagedCampaign> saveChurchCampaign({
    String? campaignId,
    required String churchId,
    required String title,
    String? description,
    String? imageUrl,
    num? targetAmount,
    DateTime? startAt,
    DateTime? endAt,
    required bool active,
    required String status,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ManagedEvent> saveChurchEvent({
    String? eventId,
    required String churchId,
    required String title,
    required String eventType,
    String? description,
    String? location,
    String? category,
    String? status,
    String? visibility,
    String? coverImageUrl,
    String? recurrenceRule,
    bool? attendanceRequired,
    bool? isPublic,
    num? registrationFeeMzn,
    required DateTime startsAt,
    DateTime? endsAt,
    required bool registrationRequired,
    int? capacity,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PlatformUser> setPlatformRole({
    required String profileId,
    required String role,
    required bool active,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchAsset> saveChurchAsset({
    String? assetId,
    required String churchId,
    required String category,
    required String name,
    required int quantity,
    required String itemCondition,
    String? location,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchExpense> saveChurchExpense({
    String? expenseId,
    required String churchId,
    required String category,
    required String title,
    required num amount,
    required DateTime spentAt,
    String? notes,
    String? vendorName,
    String? paymentMethod,
    String? paymentReference,
    String? proofUrl,
    String? costCenter,
    String status = 'paid',
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchCommunication> saveChurchCommunication({
    String? communicationId,
    required String churchId,
    required String channel,
    required String audienceType,
    String? targetRole,
    String? ministryId,
    String? membershipId,
    required String title,
    required String body,
    required String status,
    DateTime? scheduledAt,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchMinistry> saveChurchMinistry({
    String? ministryId,
    required String churchId,
    required String name,
    String? description,
    String? leaderMembershipId,
    required bool active,
    required List<String> memberMembershipIds,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchVisitor> saveChurchVisitor({
    String? visitorId,
    required String churchId,
    required String fullName,
    String? phone,
    required String status,
    required DateTime firstVisitAt,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchOverview> setChurchActiveState({
    required String churchId,
    required bool active,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchApplication> submitChurchApplication(String applicationId) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchOverview> transferChurchOwnership({
    required String churchId,
    required String newOwnerProfileId,
    String newRole = 'pastor',
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>> resetChurchWorkspace({
    required String churchId,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteChurchAnnouncement(String announcementId) async {}

  @override
  Future<void> archiveChurchCampaign(String campaignId) async {}

  @override
  Future<void> deleteChurchAsset(String assetId) async {}

  @override
  Future<void> deleteChurchExpense(String expenseId) async {}

  @override
  Future<void> deleteChurchCommunication(String communicationId) async {}

  @override
  Future<void> deleteChurchEvent(String eventId) async {}

  @override
  Future<void> deleteChurchMinistry(String ministryId) async {}

  @override
  Future<void> deleteChurchVisitor(String visitorId) async {}

  @override
  Future<ManagedMember> updateChurchMember({
    required String membershipId,
    String? role,
    String? status,
  }) {
    throw UnimplementedError();
  }
}

class _FakeFinanceRepository implements FinanceRepository {
  @override
  Future<ChurchContribution> confirmChurchContribution({
    required String donationId,
    String? internalNote,
    String? idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchContribution> createChurchContribution({
    required String churchId,
    required String contributionType,
    required num amount,
    required String method,
    String? provider,
    String? campaignId,
    String? memberProfileId,
    String? payerPhone,
    String? reference,
    String? proofUrl,
    String? notes,
    bool confirmImmediately = false,
    String? idempotencyKey,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletWithdrawalRequest> createWithdrawalRequest({
    required String ownerType,
    required String provider,
    required num amount,
    required String destinationNumber,
    String? churchId,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<List<WalletProviderSummary>> fetchWalletDashboard({
    required String ownerType,
    String? churchId,
  }) async =>
      const [];

  @override
  Future<List<ChurchContribution>> fetchChurchContributions({
    required String churchId,
    int limit = 100,
    String? status,
  }) async =>
      const [];

  @override
  Future<ChurchFinanceSnapshot> fetchChurchFinanceSnapshot({
    required String churchId,
    bool includeDemo = false,
  }) async =>
      ChurchFinanceSnapshot.empty();

  @override
  Future<List<WalletLedgerEntry>> fetchWalletLedger({
    required String ownerType,
    String? churchId,
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<List<WalletWithdrawalRequest>> fetchWithdrawalRequests({
    String? ownerType,
    String? churchId,
    int limit = 50,
  }) async =>
      const [];

  @override
  Future<String> recordMemberDonation({
    required String churchId,
    required String donationType,
    required num amount,
    required String provider,
    String? campaignId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletLedgerEntry> recordPlatformRevenue({
    required String provider,
    required num amount,
    String entryType = 'subscription_payment',
    String? description,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<WalletWithdrawalRequest> reviewWithdrawalRequest({
    required String requestId,
    required String status,
    String? notes,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<ChurchContribution> rejectChurchContribution({
    required String donationId,
    required String reason,
  }) {
    throw UnimplementedError();
  }
}
