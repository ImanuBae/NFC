-- Re-runnable sample attendance for NV01-NV04. No payroll close or email send.
USE [NfcAttendance];
SET NOCOUNT ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN TRY
    BEGIN TRANSACTION;
    DECLARE @Start datetimeoffset = '2026-10-01T00:00:00+07:00';
    DECLARE @End datetimeoffset = '2026-11-01T00:00:00+07:00';
    DECLARE @Marker nvarchar(200) = N'DEMO_OCT2026_V1 - Du lieu mau thang 10/2026';
    DECLARE @Actor uniqueidentifier = (SELECT TOP 1 Id FROM dbo.Accounts WHERE Role = 'admin' AND Active = 1 ORDER BY Email);
    IF @Actor IS NULL THROW 50001, 'An active administrator is required.', 1;
    SELECT Id, Code INTO #Employees FROM dbo.Employees WITH (UPDLOCK, HOLDLOCK)
        WHERE Code IN ('NV01','NV02','NV03','NV04') AND Active = 1;
    IF (SELECT COUNT(*) FROM #Employees) <> 4
        THROW 50002, 'Expected four active employees NV01-NV04; nothing inserted.', 1;
    IF EXISTS (SELECT 1 FROM dbo.PayrollRuns WITH (UPDLOCK, HOLDLOCK)
        WHERE StartDate < '2026-11-01' AND EndDate > '2026-10-01')
        THROW 50003, 'October overlaps a closed payroll period; nothing inserted.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Events WITH (UPDLOCK, HOLDLOCK)
        WHERE EmployeeId IN (SELECT Id FROM #Employees) AND OccurredAt >= @Start AND OccurredAt < @End
        AND (Flag IS NULL OR Flag <> @Marker OR Source <> 'manual' OR VoidedAt IS NOT NULL))
        THROW 50004, 'October already contains other attendance; existing data was preserved.', 1;

    ;WITH Days AS (
        SELECT 0 AS n UNION ALL SELECT n+1 FROM Days WHERE n < 30
    )
    SELECT DATEADD(day,n,@Start) AS WorkDate, DAY(DATEADD(day,n,@Start)) AS DayNumber
    INTO #Days FROM Days
    WHERE DATEDIFF(day, CONVERT(date,'19000101'), CONVERT(date,DATEADD(day,n,@Start))) % 7 < 5;

    SELECT e.Id AS EmployeeId, e.Code, d.WorkDate, d.DayNumber,
        CASE WHEN e.Code='NV02' AND d.DayNumber IN (5,12,19,26) THEN 15
             WHEN e.Code='NV03' AND d.DayNumber IN (6,20) THEN 30
             WHEN e.Code='NV04' AND d.DayNumber IN (1,15,29) THEN 10 ELSE 0 END AS LateMinutes,
        CASE WHEN e.Code='NV02' AND d.DayNumber IN (7,21) THEN 30
             WHEN e.Code='NV03' AND d.DayNumber=14 THEN 60
             WHEN e.Code='NV04' AND d.DayNumber IN (8,22,30) THEN 15 ELSE 0 END AS EarlyMinutes
    INTO #Shifts FROM #Employees e CROSS JOIN #Days d
    WHERE NOT (e.Code='NV02' AND d.DayNumber=9)
      AND NOT (e.Code='NV03' AND d.DayNumber IN (2,16));

    SELECT s.EmployeeId, s.Code, v.EventType, DATEADD(minute,v.MinuteOfDay,s.WorkDate) AS OccurredAt
    INTO #Planned FROM #Shifts s CROSS APPLY (VALUES
        ('check_in', 540+s.LateMinutes), ('check_out',720),
        ('check_in',780), ('check_out',1080-s.EarlyMinutes)
    ) v(EventType,MinuteOfDay);

    INSERT dbo.Events (Id,EmployeeId,DeviceId,ClientScanId,Type,OccurredAt,DeviceTime,Source,Flag,CreatedBy,VoidedAt,VoidedBy,VoidReason)
    SELECT NEWID(),p.EmployeeId,NULL,NULL,p.EventType,p.OccurredAt,NULL,'manual',@Marker,@Actor,NULL,NULL,NULL
    FROM #Planned p WHERE NOT EXISTS (
        SELECT 1 FROM dbo.Events e WHERE e.EmployeeId=p.EmployeeId AND e.Type=p.EventType
            AND e.OccurredAt=p.OccurredAt AND e.Flag=@Marker AND e.VoidedAt IS NULL);
    DECLARE @Inserted int = @@ROWCOUNT;
    IF (SELECT COUNT(*) FROM dbo.Events WHERE EmployeeId IN (SELECT Id FROM #Employees)
        AND OccurredAt >= @Start AND OccurredAt < @End) <> (SELECT COUNT(*) FROM #Planned)
        THROW 50005, 'Sample rows differ from expected schedule; rolled back.', 1;
    IF @Inserted > 0
        INSERT dbo.Audits (Actor,Action,Detail,CreatedAt)
        VALUES (@Actor,'seed_demo_attendance',CONCAT(@Marker,'; inserted=',@Inserted,'; employees=NV01-NV04; payroll remains open'),SYSDATETIMEOFFSET());
    COMMIT TRANSACTION;

    SELECT @Inserted AS NewlyInsertedEvents, (SELECT COUNT(*) FROM #Planned) AS SampleEvents;
    SELECT Code,COUNT(*) AS WorkDays,SUM(480-LateMinutes-EarlyMinutes) AS WorkedMinutes,
        SUM(CASE WHEN LateMinutes>0 THEN 1 ELSE 0 END) AS LateDays,
        SUM(CASE WHEN EarlyMinutes>0 THEN 1 ELSE 0 END) AS EarlyDays
    FROM #Shifts GROUP BY Code ORDER BY Code;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
