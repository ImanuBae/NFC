-- Sample weekdays for NV01-NV04, August and September 2026 (UTC+7).
-- Run with sqlcmd -S localhost -d NfcAttendance -E -C -b -i server/seed-august-september-2026.sql
-- Re-runnable before payroll close. Existing unrelated attendance is preserved.
-- No payroll close, employee/rate changes, or email jobs are created.
USE [NfcAttendance];
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Start datetimeoffset = '2026-08-01T00:00:00+07:00';
    DECLARE @End datetimeoffset = '2026-10-01T00:00:00+07:00';
    DECLARE @Marker nvarchar(200) = N'DEMO_AUG_SEP2026_V1';
    DECLARE @Actor uniqueidentifier = (SELECT TOP 1 Id FROM dbo.Accounts WHERE Role = 'admin' AND Active = 1 ORDER BY Email);
    IF @Actor IS NULL THROW 50001, 'An active administrator is required.', 1;
    SELECT Id, Code, HourlyRate INTO #Employees FROM dbo.Employees WITH (UPDLOCK, HOLDLOCK)
        WHERE Code IN ('NV01','NV02','NV03','NV04') AND Active = 1;
    IF (SELECT COUNT(*) FROM #Employees) <> 4
        THROW 50002, 'Expected four active employees NV01-NV04; nothing inserted.', 1;
    IF EXISTS (SELECT 1 FROM dbo.PayrollRuns WITH (UPDLOCK, HOLDLOCK)
        WHERE StartDate < '2026-10-01' AND EndDate > '2026-08-01')
        THROW 50003, 'The sample overlaps a closed payroll period; nothing inserted.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Events WITH (UPDLOCK, HOLDLOCK)
        WHERE EmployeeId IN (SELECT Id FROM #Employees) AND OccurredAt >= @Start AND OccurredAt < @End
        AND (Flag IS NULL OR Flag <> @Marker OR Source <> 'manual' OR VoidedAt IS NOT NULL))
        THROW 50004, 'The period already contains other attendance; existing data was preserved.', 1;

    ;WITH Days AS (
        SELECT 0 AS n UNION ALL SELECT n+1 FROM Days WHERE n < 60
    ), Weekdays AS (
        SELECT DATEADD(day,n,@Start) AS WorkDate FROM Days
        WHERE DATEDIFF(day, CONVERT(date,'19000101'), CONVERT(date,DATEADD(day,n,@Start))) % 7 < 5
    )
    SELECT WorkDate, MONTH(WorkDate) AS WorkMonth,
        ROW_NUMBER() OVER (PARTITION BY MONTH(WorkDate) ORDER BY WorkDate) AS WorkDayNumber
    INTO #Days FROM Weekdays;

    -- Positions refer to weekdays within each month, so every scenario occurs.
    -- NV01: full attendance. NV02: one absence. NV03: two absences.
    -- NV04: one missing afternoon checkout; that unfinished session earns no pay.
    SELECT e.Id AS EmployeeId, e.Code, e.HourlyRate, d.WorkDate, d.WorkMonth,
        CASE WHEN e.Code='NV02' AND d.WorkDayNumber IN (2,7,12,17) THEN 15
             WHEN e.Code='NV03' AND d.WorkDayNumber IN (4,14) THEN 30
             WHEN e.Code='NV04' AND d.WorkDayNumber IN (3,10,18) THEN 10 ELSE 0 END AS LateMinutes,
        CASE WHEN e.Code='NV02' AND d.WorkDayNumber IN (5,15) THEN 30
             WHEN e.Code='NV03' AND d.WorkDayNumber=9 THEN 60
             WHEN e.Code='NV04' AND d.WorkDayNumber IN (6,13,19) THEN 15 ELSE 0 END AS EarlyMinutes,
        CASE WHEN e.Code='NV04' AND d.WorkDayNumber=16 THEN 1 ELSE 0 END AS MissingCheckout
    INTO #Shifts FROM #Employees e CROSS JOIN #Days d
    WHERE NOT (e.Code='NV02' AND d.WorkDayNumber=8)
      AND NOT (e.Code='NV03' AND d.WorkDayNumber IN (6,16));

    SELECT s.EmployeeId, v.EventType, DATEADD(minute,v.MinuteOfDay,s.WorkDate) AS OccurredAt
    INTO #Planned FROM #Shifts s CROSS APPLY (VALUES
        ('check_in', 540+s.LateMinutes), ('check_out',720),
        ('check_in',780), ('check_out',1080-s.EarlyMinutes)
    ) v(EventType,MinuteOfDay)
    WHERE NOT (s.MissingCheckout=1 AND v.EventType='check_out' AND v.MinuteOfDay>780);

    -- Refuse unexpected rows even when they carry this script's marker.
    IF EXISTS (SELECT 1 FROM dbo.Events e
        WHERE e.EmployeeId IN (SELECT Id FROM #Employees) AND e.OccurredAt >= @Start AND e.OccurredAt < @End
        AND NOT EXISTS (SELECT 1 FROM #Planned p WHERE p.EmployeeId=e.EmployeeId AND p.EventType=e.Type AND p.OccurredAt=e.OccurredAt))
        THROW 50005, 'Sample rows differ from the expected schedule; existing data was preserved.', 1;

    INSERT dbo.Events (Id,EmployeeId,DeviceId,ClientScanId,Type,OccurredAt,DeviceTime,Source,Flag,CreatedBy,VoidedAt,VoidedBy,VoidReason)
    SELECT NEWID(),p.EmployeeId,NULL,NULL,p.EventType,p.OccurredAt,NULL,'manual',@Marker,@Actor,NULL,NULL,NULL
    FROM #Planned p WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Events e WHERE e.EmployeeId=p.EmployeeId AND e.Type=p.EventType
            AND e.OccurredAt=p.OccurredAt AND e.Flag=@Marker AND e.VoidedAt IS NULL);
    DECLARE @Inserted int = @@ROWCOUNT;
    IF (SELECT COUNT(*) FROM dbo.Events WHERE EmployeeId IN (SELECT Id FROM #Employees)
        AND OccurredAt >= @Start AND OccurredAt < @End) <> (SELECT COUNT(*) FROM #Planned)
        THROW 50006, 'Sample row count differs from the expected schedule; rolled back.', 1;
    IF @Inserted > 0
        INSERT dbo.Audits (Actor,Action,Detail,CreatedAt)
        VALUES (@Actor,'seed_demo_attendance',CONCAT(@Marker,'; inserted=',@Inserted,'; employees=NV01-NV04; payroll remains open'),SYSDATETIMEOFFSET());
    COMMIT TRANSACTION;

    SELECT @Inserted AS NewlyInsertedEvents, (SELECT COUNT(*) FROM #Planned) AS SampleEvents;
    SELECT WorkMonth,Code,COUNT(*) AS DaysWorked,
        SUM(480-LateMinutes-EarlyMinutes-300*MissingCheckout) AS WorkedMinutes,
        SUM(CASE WHEN LateMinutes>0 THEN 1 ELSE 0 END) AS LateDays,
        SUM(CASE WHEN EarlyMinutes>0 THEN 1 ELSE 0 END) AS EarlyDays,
        SUM(MissingCheckout) AS MissingCheckout,
        ROUND(SUM(480-LateMinutes-EarlyMinutes-300*MissingCheckout)/60.0*HourlyRate,0) AS GrossPay
    FROM #Shifts GROUP BY WorkMonth,Code,HourlyRate ORDER BY WorkMonth,Code;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
