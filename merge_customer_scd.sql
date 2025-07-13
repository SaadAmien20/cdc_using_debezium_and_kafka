CREATE OR ALTER PROCEDURE dbo.merge_customer_scd
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Step 1: Process all creates (only if the ID doesn't exist at all)
    INSERT INTO dbo.customer_scd (id, name, email, start_date, end_date, current_flag, [__op], [__source_ts_ms])
    SELECT 
        s.id, 
        s.name, 
        s.email, 
        DATEADD(HOUR, 3, 
            DATEADD(millisecond, s.[__source_ts_ms] % 1000, 
                DATEADD(second, s.[__source_ts_ms] / 1000, '1970-01-01')
            )
        ) AS start_date,
        NULL AS end_date,
        1 AS current_flag,
        s.[__op],
        s.[__source_ts_ms]
    FROM cdc_customers_events s
    WHERE s.[__op] = 'c'
    AND NOT EXISTS (
        SELECT 1 
        FROM dbo.customer_scd scd 
        WHERE scd.id = s.id
    );
    
    -- Step 2: Process updates (whether record was loaded before or not)
    -- First identify all records that need updates
    WITH UpdatesToProcess AS (
        SELECT 
            s.id,
            s.name,
            s.email,
            s.[__op],
            s.[__source_ts_ms],
            s.[__deleted],
            ROW_NUMBER() OVER (PARTITION BY s.id ORDER BY s.[__source_ts_ms] DESC) as rn
        FROM cdc_customers_events s
        WHERE s.[__op] IN ('u', 'c')
        AND (s.[__deleted] = 'false' OR s.[__deleted] IS NULL)
        AND EXISTS (
            SELECT 1 
            FROM dbo.customer_scd scd 
            WHERE scd.id = s.id
        )
    )
    -- Close current version if data has changed
    UPDATE scd
    SET 
        scd.end_date = DATEADD(HOUR, 3, 
                              DATEADD(millisecond, u.[__source_ts_ms] % 1000, 
                                  DATEADD(second, u.[__source_ts_ms] / 1000, '1970-01-01')
                              )
                          ),
        scd.current_flag = 0
    FROM dbo.customer_scd scd
    JOIN UpdatesToProcess u ON scd.id = u.id
    WHERE scd.current_flag = 1
    AND u.rn = 1
    AND (
        scd.name <> u.name OR 
        (scd.name IS NULL AND u.name IS NOT NULL) OR 
        (scd.name IS NOT NULL AND u.name IS NULL) OR
        scd.email <> u.email OR 
        (scd.email IS NULL AND u.email IS NOT NULL) OR 
        (scd.email IS NOT NULL AND u.email IS NULL)
    );
    
    -- Insert new version of updated records
    WITH LatestUpdates AS (
        SELECT 
            s.id,
            s.name,
            s.email,
            s.[__op],
            s.[__source_ts_ms],
            ROW_NUMBER() OVER (PARTITION BY s.id ORDER BY s.[__source_ts_ms] DESC) as rn
        FROM cdc_customers_events s
        WHERE s.[__op] IN ('u', 'c')
        AND (s.[__deleted] = 'false' OR s.[__deleted] IS NULL)
    )
    INSERT INTO dbo.customer_scd (id, name, email, start_date, end_date, current_flag, [__op], [__source_ts_ms])
    SELECT 
        u.id, 
        u.name, 
        u.email, 
        DATEADD(HOUR, 3, 
               DATEADD(millisecond, u.[__source_ts_ms] % 1000, 
                   DATEADD(second, u.[__source_ts_ms] / 1000, '1970-01-01')
               )
           ) AS start_date,
        NULL AS end_date,
        1 AS current_flag,
        u.[__op],
        u.[__source_ts_ms]
    FROM LatestUpdates u
    WHERE u.rn = 1
    AND EXISTS (
        SELECT 1 
        FROM dbo.customer_scd scd 
        WHERE scd.id = u.id
    )
    AND NOT EXISTS (
        SELECT 1 
        FROM dbo.customer_scd scd 
        WHERE scd.id = u.id 
        AND scd.current_flag = 1
        AND ISNULL(scd.name, '') = ISNULL(u.name, '')
        AND ISNULL(scd.email, '') = ISNULL(u.email, '')
    );
    
    -- Step 3: Process deletes
    UPDATE dbo.customer_scd
    SET 
        end_date = DATEADD(HOUR, 3, 
                          DATEADD(millisecond, s.[__source_ts_ms] % 1000, 
                              DATEADD(second, s.[__source_ts_ms] / 1000, '1970-01-01')
                          )
                      ),
        current_flag = 0,
        [__op] = s.[__op]
    FROM dbo.customer_scd scd
    JOIN cdc_customers_events s ON scd.id = s.id
    WHERE (s.[__op] = 'd' OR s.[__deleted] = 'true')
    AND scd.current_flag = 1;
    
    -- Truncate staging table after processing
    TRUNCATE TABLE cdc_customers_events;
END;
