# 🔧 Architecture & Configuration

## 🔄 Debezium Configuration for PostgreSQL Replica
**Connector Config:**
[debezium-postgres-connection.json](./setup/debezium-postgres-connection.json)

**Deploy Command:**
```bash
curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" --data @debezium-postgres-connection.json
```
**Debezium Sink Configuration for SQL Server**
***Connector Config:***
[sqlserver-sink-connector.json](./setup/sqlserver-sink-connector.json)
```bash
curl -X POST http://localhost:8083/connectors -H "Content-Type: application/json" --data @sqlserver-sink-connector.json
```
**🔍 Kafka Debugging Commands**
***List Topics:***
```bash
docker exec -it kafka-cdc-kafka-1 /usr/bin/kafka-topics --list --bootstrap-server localhost:9092
```
** View Messages in Topic:**
```bash
docker run --rm --network container:kafka-cdc-kafka-1 confluentinc/cp-enterprise-kafka:5.5.3 \
  kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic replica.public.customers --from-beginning --max-messages 5
```
***Delete Connector:***
```bash
curl -X DELETE http://localhost:8083/connectors/sqlserver-sink
```
**Restart Connector:**
```bash
curl -X POST http://localhost:8083/connectors/sqlserver-scd2-sink/restart
```
**🧾 Track Changes (SCD Type 2)**
***💡 Note: Deletions are hard deletes in production app.***
**Step 1: Create Dimension Table**
```sql
CREATE TABLE [dbo].[customer_Dim](
	[scd_id] [int] IDENTITY(1,1) NOT NULL,
	[id] [int] NOT NULL,
	  NULL,
	  NULL,
	[start_date] [datetime] NOT NULL,
	[end_date] [datetime] NULL,
	[current_flag] [bit] NOT NULL,
	  NULL,
	[__source_ts_ms] [bigint] NULL
);

Step 2: Merge Logic Stored Procedure
CREATE OR ALTER PROCEDURE dbo.merge_customer_scd
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Create logic
    -- Update logic
    -- Insert updated versions
    -- Handle deletes
    -- Truncate staging
    -- (Code provided above in full)
END;
Step 3: Execute Procedure
EXEC merge_customer_scd;
```


