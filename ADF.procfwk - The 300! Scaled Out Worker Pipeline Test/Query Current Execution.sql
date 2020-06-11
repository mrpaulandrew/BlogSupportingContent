SELECT [StageId],[PipelineStatus],COUNT(0) FROM [procfwk].[CurrentExecution] WITH (READPAST) GROUP BY [StageId],[PipelineStatus]

SELECT * FROM [procfwk].[CurrentExecution] WITH (NOLOCK)