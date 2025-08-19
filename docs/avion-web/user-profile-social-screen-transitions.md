# User Profile & Social Features Screen Transitions

**Author:** Claude AI  
**Created:** 2025-08-18  
**Compliance:** `.cursor/rules` 準拠  

## 1. Architecture Overview

This document defines comprehensive screen transitions for user profile and social features following the project's DDD principles and Container-Presentation pattern requirements.

### Design Principles

- **Container-Presentation Pattern**: All screens follow the separation of concerns between data fetching containers and presentation components
- **Domain-Driven Design**: State management using Aggregates and Value Objects
- **TDD Compliance**: All components require tests before implementation
- **Type Safety**: Pure TypeScript with comprehensive interface definitions
- **Immutable Updates**: State changes through dedicated methods only

### State Management Architecture

```typescript
// Core Domain Aggregates for User Profile & Social Features
export class UserProfileAggregate {
  private constructor(private state: UserProfileState) {}
  
  static create(initialProfile: UserProfile): UserProfileAggregate
  updateCustomFields(fields: CustomField[]): UserProfileAggregate
  updatePrivacySettings(settings: PrivacySettings): UserProfileAggregate
  updateVerificationStatus(verification: WebsiteVerification): UserProfileAggregate
}

export class SocialRelationshipsAggregate {
  private constructor(private state: SocialState) {}
  
  static create(): SocialRelationshipsAggregate
  updateFollowStatus(userId: string, status: FollowStatus): SocialRelationshipsAggregate
  addToUserList(listId: string, userId: string): SocialRelationshipsAggregate
  updateBlockStatus(userId: string, blocked: boolean): SocialRelationshipsAggregate
}
```

## 2. Profile Management Screen Transitions

### 2.1 Profile Settings Main Screen

**Screen ID:** `ProfileSettingsScreen`  
**Route:** `/settings/profile`

#### Container Component
```typescript
interface ProfileSettingsContainerProps {
  userId: string;
}

interface ProfileSettingsState {
  profile: UserProfile;
  isLoading: boolean;
  errors: Record<string, string>;
  isDirty: boolean;
}

// Custom Hook for Profile Settings Use Case
export function useProfileSettings(userId: string) {
  const [state, setState] = useState<ProfileSettingsState>(initialState);
  
  const updateProfile = useCallback(async (updates: Partial<UserProfile>) => {
    // TDD Implementation Required
  }, [userId]);
  
  return { ...state, updateProfile };
}
```

#### Navigation Flow
```
ProfileSettingsScreen
├── CustomFieldsEditor → `/settings/profile/custom-fields`
├── WebsiteVerification → `/settings/profile/website-verification`
├── PrivacySettings → `/settings/privacy`
└── AccountMigration → `/settings/account/migration`
```

### 2.2 Custom Fields Editor Screen

**Screen ID:** `CustomFieldsEditorScreen`  
**Route:** `/settings/profile/custom-fields`

#### State Management
```typescript
interface CustomFieldsState {
  fields: CustomField[]; // Max 4 fields
  editingIndex: number | null;
  validation: FieldValidation;
  isDirty: boolean;
}

interface CustomField {
  id: string;
  name: string; // Max 20 characters
  value: string; // Max 200 characters
  isVerified: boolean;
  verificationDate?: Date;
}
```

#### Screen Transitions
```
CustomFieldsEditorScreen
├── [Add Field] → FieldEditorModal (overlay)
├── [Edit Field] → FieldEditorModal (overlay)
├── [Verify Website] → WebsiteVerificationFlow
├── [Save Changes] → ProfileSettingsScreen
└── [Cancel] → ProfileSettingsScreen
```

#### Required Components
- `CustomFieldsList` (Presentation)
- `FieldEditorModal` (Container + Presentation)
- `FieldValidationIndicator` (Presentation)
- `WebsiteVerificationBadge` (Presentation)

### 2.3 Website Verification Flow

**Screen ID:** `WebsiteVerificationScreen`  
**Route:** `/settings/profile/website-verification`

#### State Management
```typescript
interface WebsiteVerificationState {
  websiteUrl: string;
  verificationMethod: 'rel-me' | 'dns-txt';
  verificationCode: string;
  verificationStatus: 'pending' | 'checking' | 'verified' | 'failed';
  instructions: VerificationInstructions;
  errorMessage?: string;
}
```

#### Verification Flow
```
WebsiteVerificationScreen
├── [URL Input] → ValidationStep
├── [Method Selection] → InstructionsStep
├── [Verify] → VerificationCheckStep
├── [Success] → ProfileSettingsScreen (verified badge)
└── [Retry] → WebsiteVerificationScreen (reset)
```

#### Required Components
- `URLInputForm` (Container)
- `VerificationMethodSelector` (Presentation)
- `VerificationInstructions` (Presentation)
- `VerificationStatus` (Presentation)

### 2.4 Privacy Settings Screen

**Screen ID:** `PrivacySettingsScreen`  
**Route:** `/settings/privacy`

#### State Management
```typescript
interface PrivacySettingsState {
  accountVisibility: 'public' | 'private' | 'followers-only';
  profileVisibility: ProfileVisibilitySettings;
  followRequests: FollowRequestSettings;
  contentVisibility: ContentVisibilitySettings;
  searchVisibility: SearchVisibilitySettings;
}

interface ProfileVisibilitySettings {
  showFollowCounts: boolean;
  showFollowerList: boolean;
  showFollowingList: boolean;
  showBirthday: boolean;
  showLocation: boolean;
}
```

#### Screen Transitions
```
PrivacySettingsScreen
├── [Account Visibility] → AccountVisibilityModal
├── [Profile Fields] → ProfileFieldsPrivacyModal  
├── [Follow Settings] → FollowPrivacyModal
├── [Content Settings] → ContentPrivacyModal
└── [Search Settings] → SearchPrivacyModal
```

### 2.5 Account Migration Wizard

**Screen ID:** `AccountMigrationWizardScreen`  
**Route:** `/settings/account/migration`

#### Migration Flow State
```typescript
interface MigrationWizardState {
  currentStep: 'prepare' | 'backup' | 'verify' | 'migrate' | 'complete';
  sourceAccount: AccountInfo;
  targetInstance: string;
  migrationData: MigrationData;
  verificationStatus: MigrationVerificationStatus;
  progress: number; // 0-100
}
```

#### Wizard Steps Flow
```
AccountMigrationWizardScreen
├── Step 1: PrepareStep → BackupStep
├── Step 2: BackupStep → VerifyStep
├── Step 3: VerifyStep → MigrateStep
├── Step 4: MigrateStep → CompleteStep
└── Step 5: CompleteStep → ProfileSettingsScreen
```

## 3. Follow System Screen Transitions

### 3.1 Follow Request Management Screen

**Screen ID:** `FollowRequestsScreen`  
**Route:** `/follows/requests`

#### State Management
```typescript
interface FollowRequestsState {
  incomingRequests: FollowRequest[];
  outgoingRequests: FollowRequest[];
  selectedTab: 'incoming' | 'outgoing';
  isLoading: boolean;
  batchActions: BatchActionState;
}

interface FollowRequest {
  id: string;
  userId: string;
  userProfile: UserProfileSummary;
  requestedAt: Date;
  mutualFollowCount: number;
  status: 'pending' | 'accepted' | 'rejected';
}

// Custom Hook for Follow Request Management
export function useFollowRequests() {
  const [state, setState] = useState<FollowRequestsState>(initialState);
  
  const acceptRequest = useCallback(async (requestId: string) => {
    // TDD Implementation Required
  }, []);
  
  const rejectRequest = useCallback(async (requestId: string) => {
    // TDD Implementation Required  
  }, []);
  
  const cancelOutgoingRequest = useCallback(async (requestId: string) => {
    // TDD Implementation Required
  }, []);
  
  return { ...state, acceptRequest, rejectRequest, cancelOutgoingRequest };
}
```

#### Screen Transitions
```
FollowRequestsScreen
├── [Accept Request] → UserProfileScreen (new follower)
├── [Reject Request] → FollowRequestsScreen (updated list)
├── [Cancel Outgoing] → FollowRequestsScreen (updated list)
├── [Batch Accept] → BatchActionConfirmModal
├── [Batch Reject] → BatchActionConfirmModal
└── [View Profile] → UserProfileScreen
```

#### Required Components
- `FollowRequestsList` (Container)
- `FollowRequestCard` (Presentation)
- `MutualFollowIndicator` (Presentation)
- `BatchActionToolbar` (Container)
- `BatchActionConfirmModal` (Container + Presentation)

### 3.2 Follower/Following Lists Screen

**Screen ID:** `FollowListScreen`  
**Route:** `/users/:userId/followers` | `/users/:userId/following`

#### State Management
```typescript
interface FollowListState {
  listType: 'followers' | 'following';
  users: FollowerListItem[];
  filters: FollowListFilters;
  sorting: FollowListSorting;
  pagination: PaginationState;
  selectedUsers: Set<string>; // For batch operations
}

interface FollowerListItem {
  userId: string;
  profile: UserProfileSummary;
  followedAt: Date;
  isMutualFollow: boolean;
  isFollowedBack: boolean;
  relationship: UserRelationshipStatus;
}

interface FollowListFilters {
  mutualOnly: boolean;
  recentActivity: boolean; // Last 30 days
  verifiedOnly: boolean;
  searchQuery: string;
}
```

#### Screen Transitions
```
FollowListScreen
├── [Follow User] → FollowListScreen (updated status)
├── [Unfollow User] → UnfollowConfirmModal
├── [Remove Follower] → RemoveFollowerConfirmModal
├── [Block User] → BlockConfirmModal → BlockedUsersScreen
├── [Mute User] → MuteConfigurationModal
├── [View Profile] → UserProfileScreen
├── [Filter Options] → FilterOptionsModal
└── [Add to List] → UserListSelectorModal
```

### 3.3 Mutual Follow Discovery Screen

**Screen ID:** `MutualFollowsScreen`  
**Route:** `/users/:userId/mutual-follows`

#### State Management
```typescript
interface MutualFollowsState {
  baseUserId: string;
  comparisonUserId: string;
  mutualFollows: MutualFollowItem[];
  suggestedConnections: SuggestedConnectionItem[];
  networkAnalysis: NetworkAnalysisData;
  isLoading: boolean;
}

interface NetworkAnalysisData {
  totalMutualFollows: number;
  connectionStrength: number; // 0-1 score
  commonInterests: string[];
  activityOverlap: number;
}
```

#### Screen Flow
```
MutualFollowsScreen
├── [View Mutual Network] → NetworkVisualizationModal
├── [Discover Connections] → SuggestedConnectionsScreen
├── [Follow Suggestion] → ConfirmFollowModal
└── [Back to Profile] → UserProfileScreen
```

## 4. User Lists Screen Transitions

### 4.1 User Lists Management Screen

**Screen ID:** `UserListsScreen`  
**Route:** `/lists`

#### State Management
```typescript
interface UserListsState {
  ownedLists: UserList[];
  subscribedLists: UserList[];
  selectedTab: 'owned' | 'subscribed';
  searchQuery: string;
  sortBy: ListSortOption;
  viewMode: 'grid' | 'list';
}

interface UserList {
  id: string;
  name: string;
  description?: string;
  memberCount: number;
  subscriberCount: number;
  isPrivate: boolean;
  createdAt: Date;
  lastUpdated: Date;
  owner: UserProfileSummary;
  permissions: ListPermissions;
}

// Custom Hook for User Lists Management
export function useUserLists() {
  const [state, setState] = useState<UserListsState>(initialState);
  
  const createList = useCallback(async (listData: CreateListRequest) => {
    // TDD Implementation Required
  }, []);
  
  const updateList = useCallback(async (listId: string, updates: UpdateListRequest) => {
    // TDD Implementation Required
  }, []);
  
  const deleteList = useCallback(async (listId: string) => {
    // TDD Implementation Required
  }, []);
  
  return { ...state, createList, updateList, deleteList };
}
```

#### Screen Transitions
```
UserListsScreen
├── [Create List] → CreateListScreen
├── [Edit List] → EditListScreen
├── [View List] → UserListDetailScreen
├── [Delete List] → DeleteConfirmModal
├── [Subscribe] → UserListsScreen (updated)
├── [Unsubscribe] → UnsubscribeConfirmModal
└── [Share List] → ShareListModal
```

### 4.2 Create/Edit List Screen

**Screen ID:** `CreateEditListScreen`  
**Route:** `/lists/create` | `/lists/:listId/edit`

#### State Management
```typescript
interface CreateEditListState {
  listData: ListFormData;
  validation: ListValidationState;
  memberSearch: MemberSearchState;
  suggestedMembers: UserProfileSummary[];
  selectedMembers: Set<string>;
  isDirty: boolean;
}

interface ListFormData {
  name: string; // Max 25 characters
  description: string; // Max 100 characters  
  isPrivate: boolean;
  allowSubscriptions: boolean;
  moderationSettings: ListModerationSettings;
}
```

#### Screen Flow
```
CreateEditListScreen
├── Step 1: BasicInfoStep → MemberSelectionStep
├── Step 2: MemberSelectionStep → PermissionsStep
├── Step 3: PermissionsStep → ReviewStep
├── Step 4: ReviewStep → UserListsScreen (success)
├── [Add Members] → MemberSearchModal
├── [Remove Member] → RemoveMemberConfirmModal
└── [Cancel] → UserListsScreen
```

### 4.3 User List Detail & Timeline Screen

**Screen ID:** `UserListDetailScreen`  
**Route:** `/lists/:listId`

#### State Management
```typescript
interface UserListDetailState {
  listInfo: UserListDetail;
  timeline: TimelineState;
  members: ListMemberState;
  permissions: UserListPermissions;
  selectedTab: 'timeline' | 'members' | 'settings';
}

interface ListMemberState {
  members: ListMember[];
  pendingInvitations: PendingInvitation[];
  memberSearch: string;
  sortBy: MemberSortOption;
}
```

#### Screen Transitions
```
UserListDetailScreen
├── [Edit List] → EditListScreen (if owner)
├── [Add Member] → AddMemberModal
├── [Remove Member] → RemoveMemberConfirmModal
├── [Member Profile] → UserProfileScreen
├── [List Settings] → ListSettingsModal
├── [Timeline Item] → DropDetailScreen
└── [Share Timeline] → ShareModal
```

## 5. Block/Mute System Screen Transitions

### 5.1 Block Management Screen

**Screen ID:** `BlockManagementScreen`  
**Route:** `/settings/blocked-users`

#### State Management
```typescript
interface BlockManagementState {
  blockedUsers: BlockedUser[];
  blockedInstances: BlockedInstance[];
  selectedTab: 'users' | 'instances';
  searchQuery: string;
  sortBy: BlockSortOption;
  batchSelected: Set<string>;
}

interface BlockedUser {
  userId: string;
  userProfile: UserProfileSummary;
  blockedAt: Date;
  reason?: string;
  blockType: 'full' | 'content-only' | 'interaction-only';
  expiresAt?: Date;
}

interface BlockedInstance {
  instanceUrl: string;
  instanceInfo: InstanceInfo;
  blockedAt: Date;
  reason: string;
  blockLevel: 'complete' | 'media-only' | 'reports-only';
}

// Custom Hook for Block Management
export function useBlockManagement() {
  const [state, setState] = useState<BlockManagementState>(initialState);
  
  const blockUser = useCallback(async (userId: string, options: BlockOptions) => {
    // TDD Implementation Required
  }, []);
  
  const unblockUser = useCallback(async (userId: string) => {
    // TDD Implementation Required
  }, []);
  
  const blockInstance = useCallback(async (instanceUrl: string, options: InstanceBlockOptions) => {
    // TDD Implementation Required
  }, []);
  
  return { ...state, blockUser, unblockUser, blockInstance };
}
```

#### Screen Transitions
```
BlockManagementScreen
├── [Block User] → BlockUserModal
├── [Unblock User] → UnblockConfirmModal
├── [Block Instance] → BlockInstanceModal
├── [Unblock Instance] → UnblockInstanceConfirmModal
├── [View Profile] → UserProfileScreen (limited view)
├── [Batch Unblock] → BatchUnblockConfirmModal
├── [Edit Block] → EditBlockModal
└── [Block Settings] → BlockSettingsModal
```

#### Required Components
- `BlockedUsersList` (Container)
- `BlockedInstancesList` (Container)
- `BlockUserModal` (Container + Presentation)
- `BlockInstanceModal` (Container + Presentation)
- `BlockReasonSelector` (Presentation)
- `BlockDurationPicker` (Presentation)

### 5.2 Mute Configuration Screen

**Screen ID:** `MuteConfigurationScreen`  
**Route:** `/settings/muted-content`

#### State Management
```typescript
interface MuteConfigurationState {
  mutedUsers: MutedUser[];
  mutedWords: MutedWord[];
  mutedHashtags: MutedHashtag[];
  selectedCategory: 'users' | 'words' | 'hashtags';
  globalMuteSettings: GlobalMuteSettings;
}

interface MutedUser {
  userId: string;
  userProfile: UserProfileSummary;
  mutedAt: Date;
  muteType: MuteType;
  duration: MuteDuration;
  expiresAt?: Date;
  includeRetweets: boolean;
  includeReplies: boolean;
}

type MuteType = 'full' | 'notifications-only' | 'home-timeline' | 'mentions';
type MuteDuration = 'permanent' | '1-hour' | '24-hours' | '7-days' | '30-days' | 'custom';

interface MutedWord {
  id: string;
  pattern: string;
  isRegex: boolean;
  scope: MuteScope[];
  createdAt: Date;
  expiresAt?: Date;
}

type MuteScope = 'home' | 'notifications' | 'public' | 'mentions' | 'conversations';
```

#### Screen Transitions
```
MuteConfigurationScreen
├── [Mute User] → MuteUserModal
├── [Edit Mute] → EditMuteModal
├── [Unmute User] → UnmuteConfirmModal
├── [Add Muted Word] → AddMutedWordModal
├── [Edit Muted Word] → EditMutedWordModal
├── [Delete Muted Word] → DeleteConfirmModal
├── [Regex Builder] → RegexBuilderModal
├── [Import Mute List] → ImportMuteListModal
└── [Export Mute List] → ExportMuteListModal
```

### 5.3 Keyword Muting with Regex Builder

**Screen ID:** `RegexBuilderScreen`  
**Route:** `/settings/muted-content/regex-builder`

#### State Management
```typescript
interface RegexBuilderState {
  pattern: string;
  testText: string;
  matches: RegexMatch[];
  isValid: boolean;
  explanation: RegexExplanation;
  presetPatterns: PresetPattern[];
  selectedPreset?: string;
}

interface RegexMatch {
  match: string;
  startIndex: number;
  endIndex: number;
  groups: string[];
}

interface PresetPattern {
  id: string;
  name: string;
  description: string;
  pattern: string;
  category: 'spam' | 'harassment' | 'politics' | 'sports' | 'crypto' | 'custom';
}
```

#### Screen Flow
```
RegexBuilderScreen
├── [Select Preset] → RegexBuilderScreen (pattern loaded)
├── [Test Pattern] → RegexBuilderScreen (matches shown)
├── [Save Pattern] → MuteConfigurationScreen
├── [Pattern Help] → RegexHelpModal
└── [Cancel] → MuteConfigurationScreen
```

### 5.4 Instance Blocking Interface

**Screen ID:** `InstanceBlockingScreen`  
**Route:** `/settings/blocked-instances`

#### State Management
```typescript
interface InstanceBlockingState {
  blockedInstances: BlockedInstance[];
  suggestedBlocks: SuggestedInstanceBlock[];
  searchQuery: string;
  blockReasons: InstanceBlockReason[];
  importingBlocklist: boolean;
}

interface SuggestedInstanceBlock {
  instanceUrl: string;
  instanceInfo: InstanceInfo;
  reason: string;
  severity: 'high' | 'medium' | 'low';
  reportCount: number;
  lastReportedAt: Date;
}

interface InstanceBlockReason {
  id: string;
  reason: string;
  category: 'spam' | 'harassment' | 'illegal' | 'policy-violation' | 'other';
  isCustom: boolean;
}
```

#### Screen Transitions
```
InstanceBlockingScreen
├── [Block Instance] → BlockInstanceModal
├── [Unblock Instance] → UnblockInstanceConfirmModal
├── [Import Blocklist] → ImportBlocklistModal
├── [Export Blocklist] → ExportBlocklistModal
├── [Instance Info] → InstanceInfoModal
├── [Report Instance] → ReportInstanceModal
└── [Block Settings] → InstanceBlockSettingsModal
```

## 6. Data Management Screen Transitions

### 6.1 Export/Import Wizard

**Screen ID:** `DataManagementWizardScreen`  
**Route:** `/settings/data-management`

#### State Management
```typescript
interface DataManagementState {
  currentOperation: 'export' | 'import' | null;
  exportOptions: ExportOptions;
  importStatus: ImportStatus;
  availableBackups: BackupInfo[];
  dataCategories: DataCategory[];
}

interface ExportOptions {
  includeProfile: boolean;
  includeFollows: boolean;
  includePosts: boolean;
  includeMedia: boolean;
  includeLists: boolean;
  includeBlocks: boolean;
  includeMutes: boolean;
  includeSettings: boolean;
  format: 'json' | 'csv' | 'activitypub';
  dateRange: DateRange;
}

interface ImportStatus {
  isActive: boolean;
  progress: number; // 0-100
  currentStep: ImportStep;
  processedItems: number;
  totalItems: number;
  errors: ImportError[];
}

type ImportStep = 'validating' | 'processing-profile' | 'processing-follows' | 
                  'processing-posts' | 'processing-media' | 'finalizing';
```

#### Wizard Flow
```
DataManagementWizardScreen
├── Export Flow:
│   ├── Step 1: SelectDataStep → FormatSelectionStep
│   ├── Step 2: FormatSelectionStep → DateRangeStep
│   ├── Step 3: DateRangeStep → ExportProgressStep
│   └── Step 4: ExportProgressStep → DownloadStep
└── Import Flow:
    ├── Step 1: FileSelectionStep → ValidationStep
    ├── Step 2: ValidationStep → ConflictResolutionStep
    ├── Step 3: ConflictResolutionStep → ImportProgressStep
    └── Step 4: ImportProgressStep → CompletionStep
```

#### Screen Transitions
```
DataManagementWizardScreen
├── [Start Export] → ExportWizardFlow
├── [Start Import] → ImportWizardFlow
├── [Download Backup] → (Browser download)
├── [Delete Backup] → DeleteBackupConfirmModal
├── [Schedule Export] → ScheduleExportModal
└── [Back to Settings] → ProfileSettingsScreen
```

### 6.2 Account Deactivation Flow

**Screen ID:** `AccountDeactivationScreen`  
**Route:** `/settings/account/deactivation`

#### State Management
```typescript
interface AccountDeactivationState {
  currentStep: DeactivationStep;
  deactivationReason: string;
  feedback: string;
  confirmationChecks: DeactivationChecks;
  reactivationToken: string;
  isProcessing: boolean;
}

interface DeactivationChecks {
  understandsConsequences: boolean;
  hasBackedUpData: boolean;
  confirmsDeactivation: boolean;
  providedFeedback: boolean;
}

type DeactivationStep = 'reason' | 'consequences' | 'backup-reminder' | 
                       'confirmation' | 'processing' | 'complete';
```

#### Flow Steps
```
AccountDeactivationScreen
├── Step 1: ReasonSelectionStep → ConsequencesStep
├── Step 2: ConsequencesStep → BackupReminderStep
├── Step 3: BackupReminderStep → ConfirmationStep
├── Step 4: ConfirmationStep → ProcessingStep
├── Step 5: ProcessingStep → CompletionStep
├── [Cancel] → ProfileSettingsScreen
└── [Go to Backup] → DataManagementWizardScreen
```

### 6.3 Account Deletion Confirmation

**Screen ID:** `AccountDeletionScreen`  
**Route:** `/settings/account/deletion`

#### State Management
```typescript
interface AccountDeletionState {
  currentStep: DeletionStep;
  deletionReason: string;
  finalConfirmation: string; // Must type username
  waitingPeriod: number; // Days until deletion
  cancellationToken: string;
  isProcessing: boolean;
  hasActiveSubscriptions: boolean;
  hasLinkedAccounts: boolean;
}

type DeletionStep = 'warning' | 'data-download' | 'linked-accounts' | 
                   'subscriptions' | 'final-confirmation' | 'scheduled' | 'cancelled';
```

#### Critical Flow
```
AccountDeletionScreen
├── Step 1: DeletionWarningStep → DataDownloadStep
├── Step 2: DataDownloadStep → LinkedAccountsStep
├── Step 3: LinkedAccountsStep → SubscriptionsStep
├── Step 4: SubscriptionsStep → FinalConfirmationStep
├── Step 5: FinalConfirmationStep → ScheduledDeletionStep
├── [Cancel Deletion] → CancelDeletionScreen
├── [Download Data] → DataManagementWizardScreen
└── [Emergency Cancel] → EmergencyContactModal
```

## 7. State Management Architecture & DDD Compliance

### 7.1 Domain Aggregates Design

```typescript
// Root Aggregate for User Profile & Social Features
export class UserSocialAggregate {
  private constructor(
    private userId: string,
    private profile: UserProfileAggregate,
    private relationships: SocialRelationshipsAggregate,
    private lists: UserListsAggregate,
    private privacy: PrivacyControlAggregate,
    private moderation: ModerationAggregate
  ) {}

  static async create(userId: string): Promise<UserSocialAggregate> {
    // Factory method with async initialization
    const profile = await UserProfileAggregate.load(userId);
    const relationships = await SocialRelationshipsAggregate.load(userId);
    const lists = await UserListsAggregate.load(userId);
    const privacy = await PrivacyControlAggregate.load(userId);
    const moderation = await ModerationAggregate.load(userId);
    
    return new UserSocialAggregate(userId, profile, relationships, lists, privacy, moderation);
  }

  // Profile Management Operations
  updateProfile(updates: ProfileUpdates): UserSocialAggregate {
    const updatedProfile = this.profile.applyUpdates(updates);
    return new UserSocialAggregate(
      this.userId, updatedProfile, this.relationships, 
      this.lists, this.privacy, this.moderation
    );
  }

  // Follow Operations
  sendFollowRequest(targetUserId: string): UserSocialAggregate {
    const updatedRelationships = this.relationships.sendFollowRequest(targetUserId);
    return new UserSocialAggregate(
      this.userId, this.profile, updatedRelationships,
      this.lists, this.privacy, this.moderation
    );
  }

  // List Operations
  createUserList(listData: CreateListData): UserSocialAggregate {
    const updatedLists = this.lists.createList(listData);
    return new UserSocialAggregate(
      this.userId, this.profile, this.relationships,
      updatedLists, this.privacy, this.moderation
    );
  }

  // Privacy Operations
  updatePrivacySettings(settings: PrivacySettings): UserSocialAggregate {
    const updatedPrivacy = this.privacy.updateSettings(settings);
    return new UserSocialAggregate(
      this.userId, this.profile, this.relationships,
      this.lists, updatedPrivacy, this.moderation
    );
  }

  // Moderation Operations
  blockUser(targetUserId: string, options: BlockOptions): UserSocialAggregate {
    const updatedModeration = this.moderation.blockUser(targetUserId, options);
    return new UserSocialAggregate(
      this.userId, this.profile, this.relationships,
      this.lists, this.privacy, updatedModeration
    );
  }

  // Read-only access methods
  getProfile(): UserProfile { return this.profile.toValueObject(); }
  getFollowStatus(targetUserId: string): FollowStatus { 
    return this.relationships.getFollowStatus(targetUserId); 
  }
  getUserLists(): UserList[] { return this.lists.getAllLists(); }
  isBlocked(targetUserId: string): boolean { 
    return this.moderation.isUserBlocked(targetUserId); 
  }
}
```

### 7.2 Use Case Layer with Custom Hooks

```typescript
// Profile Management Use Cases
export function useProfileManagement(userId: string) {
  const [aggregate, setAggregate] = useState<UserSocialAggregate | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [errors, setErrors] = useState<Record<string, string>>({});

  useEffect(() => {
    UserSocialAggregate.create(userId)
      .then(setAggregate)
      .catch(error => setErrors({ general: error.message }))
      .finally(() => setIsLoading(false));
  }, [userId]);

  const updateProfile = useCallback(async (updates: ProfileUpdates) => {
    if (!aggregate) return;
    
    try {
      setIsLoading(true);
      const updatedAggregate = aggregate.updateProfile(updates);
      await persistAggregate(updatedAggregate);
      setAggregate(updatedAggregate);
    } catch (error) {
      setErrors({ profile: error.message });
    } finally {
      setIsLoading(false);
    }
  }, [aggregate]);

  const updateCustomFields = useCallback(async (fields: CustomField[]) => {
    if (!aggregate) return;
    
    try {
      const updatedAggregate = aggregate.updateProfile({ customFields: fields });
      await persistAggregate(updatedAggregate);
      setAggregate(updatedAggregate);
    } catch (error) {
      setErrors({ customFields: error.message });
    }
  }, [aggregate]);

  return {
    profile: aggregate?.getProfile(),
    isLoading,
    errors,
    updateProfile,
    updateCustomFields
  };
}

// Follow System Use Cases
export function useFollowManagement(userId: string) {
  const [aggregate, setAggregate] = useState<UserSocialAggregate | null>(null);

  const sendFollowRequest = useCallback(async (targetUserId: string) => {
    if (!aggregate) return;
    
    try {
      const updatedAggregate = aggregate.sendFollowRequest(targetUserId);
      await persistAggregate(updatedAggregate);
      setAggregate(updatedAggregate);
    } catch (error) {
      throw new FollowRequestError(error.message);
    }
  }, [aggregate]);

  const acceptFollowRequest = useCallback(async (requestId: string) => {
    if (!aggregate) return;
    
    try {
      const updatedAggregate = aggregate.acceptFollowRequest(requestId);
      await persistAggregate(updatedAggregate);
      setAggregate(updatedAggregate);
    } catch (error) {
      throw new FollowRequestError(error.message);
    }
  }, [aggregate]);

  return {
    followRequests: aggregate?.getPendingFollowRequests(),
    mutualFollows: aggregate?.getMutualFollows(),
    sendFollowRequest,
    acceptFollowRequest
  };
}
```

### 7.3 Component Architecture

```typescript
// Container Component Pattern
interface ProfileSettingsContainerProps {
  userId: string;
}

export const ProfileSettingsContainer: React.FC<ProfileSettingsContainerProps> = ({ userId }) => {
  const {
    profile,
    isLoading,
    errors,
    updateProfile,
    updateCustomFields
  } = useProfileManagement(userId);

  const handleProfileUpdate = useCallback(async (updates: ProfileUpdates) => {
    try {
      await updateProfile(updates);
      // Handle success (e.g., show toast notification)
    } catch (error) {
      // Handle error (e.g., show error message)
    }
  }, [updateProfile]);

  if (isLoading) {
    return <ProfileSettingsLoadingState />;
  }

  if (!profile) {
    return <ProfileSettingsErrorState errors={errors} />;
  }

  return (
    <ProfileSettingsPresentation
      profile={profile}
      onProfileUpdate={handleProfileUpdate}
      onCustomFieldsUpdate={updateCustomFields}
      errors={errors}
    />
  );
};

// Presentation Component Pattern
interface ProfileSettingsPresentationProps {
  profile: UserProfile;
  onProfileUpdate: (updates: ProfileUpdates) => Promise<void>;
  onCustomFieldsUpdate: (fields: CustomField[]) => Promise<void>;
  errors: Record<string, string>;
}

export const ProfileSettingsPresentation: React.FC<ProfileSettingsPresentationProps> = ({
  profile,
  onProfileUpdate,
  onCustomFieldsUpdate,
  errors
}) => {
  const [formState, setFormState] = useState(() => profileToFormState(profile));

  const handleSubmit = useCallback(async (e: FormEvent) => {
    e.preventDefault();
    const updates = formStateToProfileUpdates(formState);
    await onProfileUpdate(updates);
  }, [formState, onProfileUpdate]);

  return (
    <form onSubmit={handleSubmit}>
      <ProfileBasicInfoFields
        displayName={formState.displayName}
        bio={formState.bio}
        onDisplayNameChange={/* handler */}
        onBioChange={/* handler */}
        errors={errors}
      />
      
      <CustomFieldsEditor
        fields={formState.customFields}
        onFieldsChange={onCustomFieldsUpdate}
        maxFields={4}
        errors={errors}
      />
      
      <ProfileImageUpload
        avatarUrl={formState.avatarUrl}
        headerUrl={formState.headerUrl}
        onAvatarChange={/* handler */}
        onHeaderChange={/* handler */}
      />
      
      <FormActions>
        <Button type="submit" disabled={!formState.isDirty}>
          Save Changes
        </Button>
      </FormActions>
    </form>
  );
};
```

## 8. Testing Strategy & TDD Compliance

### 8.1 Domain Layer Tests

```typescript
describe('UserSocialAggregate', () => {
  describe('Profile Management', () => {
    it('should update display name within character limit', () => {
      // Arrange
      const aggregate = UserSocialAggregate.create(testUserId);
      const updates = { displayName: 'New Display Name' };
      
      // Act
      const result = aggregate.updateProfile(updates);
      
      // Assert
      expect(result.getProfile().displayName).toBe('New Display Name');
    });

    it('should reject display name exceeding character limit', () => {
      // Arrange
      const aggregate = UserSocialAggregate.create(testUserId);
      const longName = 'a'.repeat(51); // Exceeds 50 char limit
      const updates = { displayName: longName };
      
      // Act & Assert
      expect(() => aggregate.updateProfile(updates))
        .toThrow(ProfileValidationError);
    });
  });

  describe('Custom Fields Management', () => {
    it('should allow up to 4 custom fields', () => {
      // Table-driven test implementation
      const testCases = [
        { fields: [], expected: true },
        { fields: createFields(4), expected: true },
        { fields: createFields(5), expected: false }
      ];

      testCases.forEach(({ fields, expected }) => {
        const aggregate = UserSocialAggregate.create(testUserId);
        
        if (expected) {
          expect(() => aggregate.updateProfile({ customFields: fields }))
            .not.toThrow();
        } else {
          expect(() => aggregate.updateProfile({ customFields: fields }))
            .toThrow(TooManyCustomFieldsError);
        }
      });
    });
  });
});
```

### 8.2 Use Case Layer Tests

```typescript
describe('useProfileManagement', () => {
  it('should load user profile on mount', async () => {
    // Arrange
    const mockAggregate = createMockUserSocialAggregate();
    vi.spyOn(UserSocialAggregate, 'create').mockResolvedValue(mockAggregate);
    
    // Act
    const { result } = renderHook(() => useProfileManagement('test-user-id'));
    
    // Assert
    await waitFor(() => {
      expect(result.current.profile).toBeDefined();
      expect(result.current.isLoading).toBe(false);
    });
  });

  it('should handle profile update errors', async () => {
    // Arrange
    const mockAggregate = createMockUserSocialAggregate();
    mockAggregate.updateProfile = vi.fn().mockImplementation(() => {
      throw new ProfileValidationError('Invalid display name');
    });
    
    const { result } = renderHook(() => useProfileManagement('test-user-id'));
    
    // Act
    await act(async () => {
      await result.current.updateProfile({ displayName: '' });
    });
    
    // Assert
    expect(result.current.errors.profile).toBe('Invalid display name');
  });
});
```

### 8.3 Component Tests

```typescript
describe('ProfileSettingsPresentation', () => {
  const defaultProps = {
    profile: createMockUserProfile(),
    onProfileUpdate: vi.fn(),
    onCustomFieldsUpdate: vi.fn(),
    errors: {}
  };

  it('should render profile form with current values', () => {
    // Arrange & Act
    render(<ProfileSettingsPresentation {...defaultProps} />);
    
    // Assert
    expect(screen.getByDisplayValue(defaultProps.profile.displayName)).toBeInTheDocument();
    expect(screen.getByDisplayValue(defaultProps.profile.bio)).toBeInTheDocument();
  });

  it('should call onProfileUpdate when form is submitted', async () => {
    // Arrange
    const onProfileUpdate = vi.fn();
    render(
      <ProfileSettingsPresentation 
        {...defaultProps} 
        onProfileUpdate={onProfileUpdate} 
      />
    );
    
    // Act
    await userEvent.type(screen.getByLabelText(/display name/i), 'Updated Name');
    await userEvent.click(screen.getByRole('button', { name: /save changes/i }));
    
    // Assert
    expect(onProfileUpdate).toHaveBeenCalledWith(
      expect.objectContaining({
        displayName: expect.stringContaining('Updated Name')
      })
    );
  });
});
```

## 9. Performance Considerations

### 9.1 State Optimization
- **Memoization**: Use React.memo for presentation components
- **Selective Updates**: Only re-render affected components
- **Lazy Loading**: Load heavy data on demand (e.g., user lists, followers)

### 9.2 Data Loading
- **GraphQL Fragments**: Minimize data fetching
- **Caching Strategy**: Apollo Client cache with proper invalidation
- **Optimistic Updates**: Immediate UI feedback for user actions

### 9.3 Bundle Optimization
- **Code Splitting**: Lazy load screens and heavy components
- **Tree Shaking**: Remove unused code
- **Dynamic Imports**: Load features on demand

This comprehensive design provides a complete framework for implementing user profile and social features with proper screen transitions, following DDD principles and .cursor/rules requirements.

<function_calls>
<invoke name="TodoWrite">
<parameter name="todos">[{"id": "profile-management", "content": "Design Profile Management screen transitions (custom fields editor, website verification, privacy settings, account migration)", "status": "completed"}, {"id": "follow-system", "content": "Design Follow System screen transitions (follow request management, mutual follow indicators, follower/following lists)", "status": "in_progress"}, {"id": "user-lists", "content": "Design User Lists screen transitions (list creation/editing, member management, privacy settings, timeline viewer)", "status": "pending"}, {"id": "block-mute-system", "content": "Design Block/Mute System screen transitions (block management, mute configuration, keyword muting, instance blocking)", "status": "pending"}, {"id": "data-management", "content": "Design Data Management screen transitions (export/import wizard, account deactivation, account deletion)", "status": "pending"}, {"id": "state-management", "content": "Define state management needs and component architecture following DDD principles", "status": "pending"}]