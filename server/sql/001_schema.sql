CREATE TABLE [AttendanceTickets] (
    [Id] uniqueidentifier NOT NULL,
    [EmployeeId] uniqueidentifier NOT NULL,
    [CreatedBy] uniqueidentifier NOT NULL,
    [Kind] nvarchar(30) NOT NULL,
    [OriginalEventId] uniqueidentifier NULL,
    [OriginalOccurredAt] datetimeoffset NULL,
    [EventType] nvarchar(20) NOT NULL,
    [ProposedAt] datetimeoffset NOT NULL,
    [Reason] nvarchar(1000) NOT NULL,
    [Status] nvarchar(20) NOT NULL,
    [Response] nvarchar(1000) NULL,
    [ReviewedBy] uniqueidentifier NULL,
    [AppliedEventId] uniqueidentifier NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    [ReviewedAt] datetimeoffset NULL,
    CONSTRAINT [PK_AttendanceTickets] PRIMARY KEY ([Id])
);
GO


CREATE TABLE [Audits] (
    [Id] bigint NOT NULL IDENTITY,
    [Actor] uniqueidentifier NOT NULL,
    [Action] nvarchar(max) NOT NULL,
    [Detail] nvarchar(max) NOT NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_Audits] PRIMARY KEY ([Id])
);
GO


CREATE TABLE [Challenges] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [Purpose] nvarchar(max) NOT NULL,
    [CredentialId] uniqueidentifier NULL,
    [DeviceId] uniqueidentifier NULL,
    [TurnFirst] bit NOT NULL,
    [Consumed] bit NOT NULL,
    [ExpiresAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_Challenges] PRIMARY KEY ([Id])
);
GO


CREATE TABLE [EmailJobs] (
    [Id] uniqueidentifier NOT NULL,
    [EmployeeId] uniqueidentifier NOT NULL,
    [StartDate] date NOT NULL,
    [EndDate] date NOT NULL,
    [Recipient] nvarchar(max) NOT NULL,
    [Subject] nvarchar(max) NOT NULL,
    [Body] nvarchar(max) NOT NULL,
    [Status] nvarchar(max) NOT NULL,
    [ProviderId] nvarchar(max) NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_EmailJobs] PRIMARY KEY ([Id])
);
GO


CREATE TABLE [EmployeeImports] (
    [Id] uniqueidentifier NOT NULL,
    [CreatedBy] uniqueidentifier NOT NULL,
    [PayloadHash] nvarchar(64) NOT NULL,
    [ProtectedResult] nvarchar(max) NOT NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_EmployeeImports] PRIMARY KEY ([Id])
);
GO


CREATE TABLE [Employees] (
    [Id] uniqueidentifier NOT NULL,
    [Code] nvarchar(50) NOT NULL,
    [FullName] nvarchar(200) NOT NULL,
    [Email] nvarchar(max) NULL,
    [Department] nvarchar(200) NULL,
    [JobTitle] nvarchar(200) NULL,
    [Phone] nvarchar(30) NULL,
    [HireDate] date NULL,
    [Active] bit NOT NULL,
    [HourlyRate] decimal(18,2) NOT NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_Employees] PRIMARY KEY ([Id])
);
GO


CREATE TABLE [OnboardingEmails] (
    [Id] uniqueidentifier NOT NULL,
    [ImportId] uniqueidentifier NOT NULL,
    [AccountId] uniqueidentifier NOT NULL,
    [EmployeeId] uniqueidentifier NOT NULL,
    [FullName] nvarchar(200) NOT NULL,
    [Recipient] nvarchar(254) NOT NULL,
    [Sender] nvarchar(500) NULL,
    [Transport] nvarchar(20) NULL,
    [Status] nvarchar(20) NOT NULL,
    [Attempts] int NOT NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    [NextAttemptAt] datetimeoffset NOT NULL,
    [FirstAttemptAt] datetimeoffset NULL,
    [LeaseUntil] datetimeoffset NULL,
    [SentAt] datetimeoffset NULL,
    [ProviderId] nvarchar(200) NULL,
    [LastError] nvarchar(500) NULL,
    CONSTRAINT [PK_OnboardingEmails] PRIMARY KEY ([Id])
);
GO


CREATE TABLE [PayrollRuns] (
    [Id] uniqueidentifier NOT NULL,
    [StartDate] date NOT NULL,
    [EndDate] date NOT NULL,
    [Period] nvarchar(max) NOT NULL,
    [CreatedBy] uniqueidentifier NOT NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_PayrollRuns] PRIMARY KEY ([Id])
);
GO


CREATE TABLE [Sessions] (
    [TokenHash] nvarchar(64) NOT NULL,
    [AccountId] uniqueidentifier NOT NULL,
    [ExpiresAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_Sessions] PRIMARY KEY ([TokenHash])
);
GO


CREATE TABLE [TicketEvidence] (
    [Id] uniqueidentifier NOT NULL,
    [TicketId] uniqueidentifier NOT NULL,
    [FileName] nvarchar(200) NOT NULL,
    [ContentType] nvarchar(50) NOT NULL,
    [Content] varbinary(max) NOT NULL,
    [SizeBytes] int NOT NULL,
    CONSTRAINT [PK_TicketEvidence] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_TicketEvidence_AttendanceTickets_TicketId] FOREIGN KEY ([TicketId]) REFERENCES [AttendanceTickets] ([Id]) ON DELETE CASCADE
);
GO


CREATE TABLE [Accounts] (
    [Id] uniqueidentifier NOT NULL,
    [Email] nvarchar(254) NOT NULL,
    [Role] nvarchar(20) NOT NULL,
    [Active] bit NOT NULL,
    [EmployeeId] uniqueidentifier NULL,
    [MustChangePassword] bit NOT NULL,
    [PasswordHash] nvarchar(max) NOT NULL,
    CONSTRAINT [PK_Accounts] PRIMARY KEY ([Id]),
    CONSTRAINT [CK_Account_Kiosk] CHECK ([Role] <> 'kiosk' OR [EmployeeId] IS NULL),
    CONSTRAINT [FK_Accounts_Employees_EmployeeId] FOREIGN KEY ([EmployeeId]) REFERENCES [Employees] ([Id]) ON DELETE NO ACTION
);
GO


CREATE TABLE [Cards] (
    [Uid] nvarchar(64) NOT NULL,
    [EmployeeId] uniqueidentifier NOT NULL,
    [Active] bit NOT NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_Cards] PRIMARY KEY ([Uid]),
    CONSTRAINT [FK_Cards_Employees_EmployeeId] FOREIGN KEY ([EmployeeId]) REFERENCES [Employees] ([Id]) ON DELETE NO ACTION
);
GO


CREATE TABLE [Events] (
    [Id] uniqueidentifier NOT NULL,
    [EmployeeId] uniqueidentifier NOT NULL,
    [DeviceId] uniqueidentifier NULL,
    [ClientScanId] uniqueidentifier NULL,
    [Type] nvarchar(max) NOT NULL,
    [OccurredAt] datetimeoffset NOT NULL,
    [DeviceTime] datetimeoffset NULL,
    [Source] nvarchar(max) NOT NULL,
    [Flag] nvarchar(max) NULL,
    [CreatedBy] uniqueidentifier NULL,
    [VoidedAt] datetimeoffset NULL,
    [VoidedBy] uniqueidentifier NULL,
    [VoidReason] nvarchar(max) NULL,
    CONSTRAINT [PK_Events] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Events_Employees_EmployeeId] FOREIGN KEY ([EmployeeId]) REFERENCES [Employees] ([Id]) ON DELETE NO ACTION
);
GO


CREATE TABLE [PayrollItems] (
    [RunId] uniqueidentifier NOT NULL,
    [EmployeeId] uniqueidentifier NOT NULL,
    [EmployeeCode] nvarchar(max) NOT NULL,
    [EmployeeName] nvarchar(max) NOT NULL,
    [WorkedMinutes] decimal(18,6) NOT NULL,
    [HourlyRate] decimal(18,2) NOT NULL,
    [GrossPay] decimal(18,2) NOT NULL,
    CONSTRAINT [PK_PayrollItems] PRIMARY KEY ([RunId], [EmployeeId]),
    CONSTRAINT [FK_PayrollItems_PayrollRuns_RunId] FOREIGN KEY ([RunId]) REFERENCES [PayrollRuns] ([Id]) ON DELETE NO ACTION
);
GO


CREATE TABLE [Devices] (
    [Id] uniqueidentifier NOT NULL,
    [Name] nvarchar(max) NOT NULL,
    [RegisteredBy] uniqueidentifier NOT NULL,
    [Active] bit NOT NULL,
    CONSTRAINT [PK_Devices] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Devices_Accounts_RegisteredBy] FOREIGN KEY ([RegisteredBy]) REFERENCES [Accounts] ([Id]) ON DELETE NO ACTION
);
GO


CREATE TABLE [Faces] (
    [Id] uniqueidentifier NOT NULL,
    [UserId] uniqueidentifier NOT NULL,
    [EmployeeId] uniqueidentifier NOT NULL,
    [Embedding] nvarchar(max) NOT NULL,
    [Model] nvarchar(max) NOT NULL,
    [Approved] bit NOT NULL,
    [Revoked] bit NOT NULL,
    [ApprovedBy] uniqueidentifier NULL,
    [CreatedAt] datetimeoffset NOT NULL,
    CONSTRAINT [PK_Faces] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Faces_Accounts_UserId] FOREIGN KEY ([UserId]) REFERENCES [Accounts] ([Id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_Faces_Employees_EmployeeId] FOREIGN KEY ([EmployeeId]) REFERENCES [Employees] ([Id]) ON DELETE NO ACTION
);
GO


CREATE UNIQUE INDEX [IX_Accounts_Email] ON [Accounts] ([Email]);
GO


CREATE UNIQUE INDEX [IX_Accounts_EmployeeId] ON [Accounts] ([EmployeeId]) WHERE [EmployeeId] IS NOT NULL AND [Role] <> 'kiosk';
GO


CREATE INDEX [IX_AttendanceTickets_EmployeeId_CreatedAt] ON [AttendanceTickets] ([EmployeeId], [CreatedAt]);
GO


CREATE INDEX [IX_Cards_EmployeeId] ON [Cards] ([EmployeeId]);
GO


CREATE INDEX [IX_Devices_RegisteredBy] ON [Devices] ([RegisteredBy]);
GO


CREATE UNIQUE INDEX [IX_EmailJobs_EmployeeId_StartDate_EndDate] ON [EmailJobs] ([EmployeeId], [StartDate], [EndDate]);
GO


CREATE UNIQUE INDEX [IX_Employees_Code] ON [Employees] ([Code]);
GO


CREATE UNIQUE INDEX [IX_Events_ClientScanId] ON [Events] ([ClientScanId]) WHERE [ClientScanId] IS NOT NULL;
GO


CREATE INDEX [IX_Events_EmployeeId_OccurredAt] ON [Events] ([EmployeeId], [OccurredAt]);
GO


CREATE INDEX [IX_Faces_EmployeeId] ON [Faces] ([EmployeeId]);
GO


CREATE UNIQUE INDEX [IX_Faces_UserId] ON [Faces] ([UserId]) WHERE [Revoked] = 0;
GO


CREATE UNIQUE INDEX [IX_OnboardingEmails_AccountId] ON [OnboardingEmails] ([AccountId]);
GO


CREATE INDEX [IX_OnboardingEmails_ImportId] ON [OnboardingEmails] ([ImportId]);
GO


CREATE UNIQUE INDEX [IX_PayrollRuns_StartDate_EndDate] ON [PayrollRuns] ([StartDate], [EndDate]);
GO


CREATE INDEX [IX_TicketEvidence_TicketId] ON [TicketEvidence] ([TicketId]);
GO


