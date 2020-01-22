// Databricks notebook source
// MAGIC %md
// MAGIC # Notebook Structure Example (Title)
// MAGIC 
// MAGIC ## Overview
// MAGIC 
// MAGIC | Detail Tag | Information |
// MAGIC |------------|-------------|
// MAGIC |Originally Created By | Paul Andrew ([paul@mrpaulandrew.com](mailto:paul@mrpaulandrew.com)) |
// MAGIC |External References |[https://mrpaulandrew.tech](https://mrpaulandrew.tech) |
// MAGIC |Input Datasets |<ul><li>dbo.SalesOrderHeaders</li><li>dbo.SalesOrderDetails</li></ul>|
// MAGIC |Output Datasets |<ul><li>fact.SalesOrderCount</li></ul>|
// MAGIC |Input Data Source |Azure SQLDB |
// MAGIC |Output Data Source |Azure SQLDB |
// MAGIC 
// MAGIC ## History
// MAGIC 
// MAGIC | Date | Developed By | Reason |
// MAGIC |:----:|--------------|--------|
// MAGIC |27th Nov 2019 | Paul Andrew |Notebook created as an example of how they could be structured. |
// MAGIC |28th Nov 2019 | Paul Andrew |Notebook updated with additional cells. |
// MAGIC |29th Nov 2019 | Paul Andrew |Notebook updated for blog post. |
// MAGIC 
// MAGIC ## Other Details
// MAGIC This Notebook contains many cells with lots of titles and markdown to give details and context for future developers.

// COMMAND ----------

// DBTITLE 1,Load Common Libraries
// MAGIC %run "../Framework/MrPaulAndrew.Common"

// COMMAND ----------

// MAGIC %run "../Framework/MrPaulAndrew.StorageConnections"

// COMMAND ----------

// DBTITLE 1,Set & Get Widgets
dbutils.widgets.text("RunDate","")

// COMMAND ----------

// DBTITLE 1,Log Start
createLogEntry("Example Notebook Structure Start.")

// COMMAND ----------

// DBTITLE 1,Local Methods, Properties & Variables
val outputTableName = "OrderLineCountScala"

import java.sql.Timestamp
import java.text.SimpleDateFormat
import java.util.Date

def getTimestamp(x:Any) : Timestamp = {
    val format = new SimpleDateFormat("yyyy-MM-dd") //expected format of widget
    if (x.toString() == "")
    return null
    else {
        val d = format.parse(x.toString());
        val t = new Timestamp(d.getTime());
        return t
    }
}

// COMMAND ----------

// DBTITLE 1,Extract
val orderHeaderTable = spark.read.jdbc(jdbcUrl, "SalesLT.SalesOrderHeader", connectionProperties)
val orderDetailTable = spark.read.jdbc(jdbcUrl, "SalesLT.SalesOrderDetail", connectionProperties)

//just for testing with SQL
spark.read.jdbc(jdbcUrl, "SalesLT.SalesOrderHeader", connectionProperties).createOrReplaceTempView("temp_salesOrderHeader")
spark.read.jdbc(jdbcUrl, "SalesLT.SalesOrderDetail", connectionProperties).createOrReplaceTempView("temp_salesOrderDetail")

// COMMAND ----------

// DBTITLE 1,Transform
val ordersCount = orderHeaderTable
  .filter(orderHeaderTable("OrderDate").equalTo(getTimestamp(dbutils.widgets.get("RunDate"))))
  .join(orderDetailTable, orderHeaderTable("SalesOrderID") === orderDetailTable("SalesOrderID"), "inner")
  .groupBy("SalesOrderNumber")
  .count()
  .withColumnRenamed("count", "DetailLineCount")
  //.show()


// COMMAND ----------

// DBTITLE 1,Test
// MAGIC %sql
// MAGIC 
// MAGIC select
// MAGIC   oh.SalesOrderNumber,
// MAGIC   count(od.SalesOrderDetailID) as DetailLineCount
// MAGIC from 
// MAGIC   temp_salesOrderHeader as oh
// MAGIC   join temp_salesOrderDetail as od
// MAGIC     on od.SalesOrderID = oh.SalesOrderID
// MAGIC where 
// MAGIC   oh.OrderDate = getArgument("RunDate") --implicit conversion from widget string
// MAGIC group by
// MAGIC   oh.SalesOrderNumber
// MAGIC order by
// MAGIC   oh.SalesOrderNumber

// COMMAND ----------

// DBTITLE 1,Load/Output
ordersCount.write
     .mode(SaveMode.Overwrite) //don't need to keep previous data
     .jdbc(jdbcUrl, outputTableName, connectionProperties)

// COMMAND ----------

// DBTITLE 1,Log End
createLogEntry("Example Notebook Structure End.")