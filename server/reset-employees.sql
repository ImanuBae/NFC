-- Reset employee data in the local demo database; retain admin/kiosk access.
USE [NfcAttendance];
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRY
    BEGIN TRANSACTION;
    SELECT Id INTO #EmployeeIds FROM dbo.Employees WITH (TABLOCKX, HOLDLOCK);
    SELECT Id INTO #AccountIds FROM dbo.Accounts WITH (TABLOCKX, HOLDLOCK)
        WHERE Role IN ('employee', 'manager');
    DECLARE @Admin uniqueidentifier = (SELECT TOP 1 Id FROM dbo.Accounts WHERE Role = 'admin' AND Active = 1);
    IF @Admin IS NULL THROW 50001, 'Reset requires an active administrator.', 1;
    IF EXISTS (SELECT 1 FROM dbo.OnboardingEmails WHERE Status = 'sending')
        THROW 50002, 'Email delivery is in progress; retry after it finishes.', 1;
    SELECT Id INTO #References FROM #EmployeeIds
        UNION SELECT Id FROM #AccountIds
        UNION SELECT Id FROM dbo.Events WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds)
        UNION SELECT Id FROM dbo.Faces WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds)
        UNION SELECT Id FROM dbo.EmployeeImports;
    DECLARE @Counts TABLE (Entity varchar(40), Deleted int);
    DELETE dbo.OnboardingEmails;
    INSERT @Counts VALUES ('OnboardingEmails', @@ROWCOUNT);
    DELETE dbo.EmployeeImports;
    INSERT @Counts VALUES ('EmployeeImports', @@ROWCOUNT);
    DELETE dbo.Sessions WHERE AccountId IN (SELECT Id FROM #AccountIds);
    DELETE dbo.Challenges WHERE UserId IN (SELECT Id FROM #AccountIds)
        OR CredentialId IN (SELECT Id FROM dbo.Faces WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds));
    DELETE dbo.Faces WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds) OR UserId IN (SELECT Id FROM #AccountIds);
    INSERT @Counts VALUES ('Faces', @@ROWCOUNT);
    DELETE dbo.Cards WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds);
    INSERT @Counts VALUES ('Cards', @@ROWCOUNT);
    DELETE dbo.Events WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds);
    INSERT @Counts VALUES ('Events', @@ROWCOUNT);
    IF OBJECT_ID('dbo.AttendanceTickets', 'U') IS NOT NULL
        DELETE dbo.AttendanceTickets WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds);
    DELETE dbo.EmailJobs WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds);
    DELETE dbo.PayrollItems WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds);
    DELETE dbo.PayrollRuns WHERE NOT EXISTS (SELECT 1 FROM dbo.PayrollItems i WHERE i.RunId = PayrollRuns.Id);
    DELETE dbo.Audits WHERE Actor IN (SELECT Id FROM #AccountIds)
        OR Action = 'import_employees'
        OR EXISTS (SELECT 1 FROM #References r WHERE Detail LIKE '%' + CONVERT(varchar(36), r.Id) + '%');
    UPDATE dbo.Devices SET RegisteredBy = @Admin WHERE RegisteredBy IN (SELECT Id FROM #AccountIds);
    UPDATE dbo.Accounts SET EmployeeId = NULL WHERE EmployeeId IN (SELECT Id FROM #EmployeeIds)
        AND Id NOT IN (SELECT Id FROM #AccountIds);
    DELETE dbo.Accounts WHERE Id IN (SELECT Id FROM #AccountIds);
    INSERT @Counts VALUES ('EmployeeAccounts', @@ROWCOUNT);
    DELETE dbo.Employees WHERE Id IN (SELECT Id FROM #EmployeeIds);
    INSERT @Counts VALUES ('Employees', @@ROWCOUNT);
    IF EXISTS (SELECT 1 FROM dbo.Employees) OR EXISTS (SELECT 1 FROM dbo.Accounts WHERE Role IN ('employee', 'manager'))
        THROW 50003, 'Employee reset verification failed.', 1;
    INSERT dbo.Audits (Actor, Action, Detail, CreatedAt)
        VALUES (@Admin, 'reset_test_employees', 'Cleared all employee data at user request for Excel import testing.', SYSDATETIMEOFFSET());
    COMMIT TRANSACTION;
    SELECT * FROM @Counts;
    SELECT COUNT(*) RemainingEmployees FROM dbo.Employees;
    SELECT Role, COUNT(*) RemainingAccounts FROM dbo.Accounts GROUP BY Role;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
