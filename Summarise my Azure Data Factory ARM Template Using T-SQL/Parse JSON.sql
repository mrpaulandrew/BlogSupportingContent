DECLARE @ARMJson NVARCHAR(MAX)	
SELECT @ARMJson = [ARMTemplate] from [dbo].[ArmTemplates]


/* ------------------------------------------------------------
						data factory name
------------------------------------------------------------ */
SELECT
	FactoryName.[defaultValue] AS DataFactoryName
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH
		(
		[parameters] NVARCHAR(MAX) AS JSON
		) AS Params
	CROSS APPLY OPENJSON (Params.[parameters]) WITH
		(
		[factoryName] NVARCHAR(MAX) AS JSON
		) AS FactoryDetails
	CROSS APPLY OPENJSON (FactoryDetails.[factoryName]) WITH
		(
		[type] NVARCHAR(128),
		[metadata] NVARCHAR(128),
		[defaultValue] NVARCHAR(128)
		) AS FactoryName

/* ------------------------------------------------------------
						component summary
------------------------------------------------------------ */
SELECT 
	UPPER(LEFT(REPLACE(ResourceDetails.[type],'Microsoft.DataFactory/factories/',''),1)) +
	RIGHT(REPLACE(ResourceDetails.[type],'Microsoft.DataFactory/factories/',''),
		LEN(REPLACE(ResourceDetails.[type],'Microsoft.DataFactory/factories/',''))-1) AS 'ComponentType',
	COUNT(*) AS 'Count'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails
GROUP BY
	ResourceDetails.[type]

UNION SELECT 
	'Activities',
	COUNT(ActivityDetails.[name]) AS 'Count'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails
	
	--pipeline details
	CROSS APPLY OPENJSON (ResourceDetails.[properties]) WITH
		(
		[activities] NVARCHAR(MAX) AS JSON,
		[description] NVARCHAR(MAX)
		) AS Properties
	
	--activity details for count
	CROSS APPLY OPENJSON (Properties.[activities]) WITH
		(
		[name] NVARCHAR(MAX)
		) AS ActivityDetails	
WHERE
	ResourceDetails.[type] = 'Microsoft.DataFactory/factories/pipelines'	


/* ------------------------------------------------------------
						pipeline information
------------------------------------------------------------ */
SELECT 
	REPLACE(SUBSTRING(ResourceDetails.[name], CHARINDEX('/',ResourceDetails.[name])+1, 50),''')]','') AS 'PipelineName',
	Properties.[description] AS 'Description',
	Folder.[name] AS 'FolderName',
	COUNT(ActivityDetails.[name]) AS 'ActivityCount'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails
	
	--pipeline details
	CROSS APPLY OPENJSON (ResourceDetails.[properties]) WITH
		(
		[activities] NVARCHAR(MAX) AS JSON,
		[description] NVARCHAR(MAX),
		[folder] NVARCHAR(MAX) AS JSON
		) AS Properties
	
	--folder details
	CROSS APPLY OPENJSON (Properties.[folder]) WITH
		(
		[name] NVARCHAR(500)
		) AS Folder

	--activity details for count
	CROSS APPLY OPENJSON (Properties.[activities]) WITH
		(
		[name] NVARCHAR(MAX)
		) AS ActivityDetails
WHERE
	ResourceDetails.[type] = 'Microsoft.DataFactory/factories/pipelines'			
GROUP BY
	ResourceDetails.[name],
	Properties.[description],
	Folder.[name]


/* ------------------------------------------------------------
						activity information
------------------------------------------------------------ */
SELECT 
	ActivityDetails.[name] AS 'ActivityName',
	ActivityDetails.[type] AS 'Type',
	ActivityDetails.[description] AS 'Description',
	REPLACE(SUBSTRING(ResourceDetails.[name], CHARINDEX('/',ResourceDetails.[name])+1, 50),''')]','') AS 'BelongsToPipeline'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails
	
	--pipeline details
	CROSS APPLY OPENJSON (ResourceDetails.[properties]) WITH
		(
		[activities] NVARCHAR(MAX) AS JSON,
		[description] NVARCHAR(MAX)
		) AS Properties
	
	--activity details
	CROSS APPLY OPENJSON (Properties.[activities]) WITH
		(
		[name] NVARCHAR(MAX),
		[description] NVARCHAR(MAX),
		[type] NVARCHAR(500)
		) AS ActivityDetails	
WHERE
	ResourceDetails.[type] = 'Microsoft.DataFactory/factories/pipelines'


/* ------------------------------------------------------------
						linked service information
------------------------------------------------------------ */
SELECT
	REPLACE(SUBSTRING(ResourceDetails.[name], CHARINDEX('/',ResourceDetails.[name])+1, 50),''')]','') AS 'LinkedServiceName',
	Properties.[type] AS 'Type',
	CASE
		WHEN ResourceDetails.[properties] LIKE '%AzureKeyVaultSecret%' THEN 'Yes'
		ELSE 'No'
	END AS 'UsingKeyVault'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails

	--linked service details
	CROSS APPLY OPENJSON (ResourceDetails.[properties]) WITH
		(
		[type] NVARCHAR(MAX)
		) AS Properties

WHERE
	ResourceDetails.[type] = 'Microsoft.DataFactory/factories/linkedServices'



/* ------------------------------------------------------------
						dataset information
------------------------------------------------------------ */
SELECT 
	REPLACE(SUBSTRING(ResourceDetails.[name], CHARINDEX('/',ResourceDetails.[name])+1, 50),''')]','') AS 'DatasetName',
	Properties.[type] AS 'Type',
	Folder.[name] AS 'FolderName',
	RelatedLinkedService.[referenceName] AS 'ConnectedToLinkedService'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails

	--dataset details
	CROSS APPLY OPENJSON (ResourceDetails.[properties]) WITH
		(
		[linkedServiceName] NVARCHAR(MAX) AS JSON,
		[type] NVARCHAR(MAX),
		[folder] NVARCHAR(MAX) AS JSON
		) AS Properties

	--folder details
	CROSS APPLY OPENJSON (Properties.[folder]) WITH
		(
		[name] NVARCHAR(500)
		) AS Folder
		
	--linked service connection
	CROSS APPLY OPENJSON (Properties.[linkedServiceName]) WITH
		(
		[referenceName] NVARCHAR(500)
		) AS RelatedLinkedService
WHERE
	ResourceDetails.[type] = 'Microsoft.DataFactory/factories/datasets'


/* ------------------------------------------------------------
				integration runtime information
------------------------------------------------------------ */
SELECT 
	REPLACE(SUBSTRING(ResourceDetails.[name], CHARINDEX('/',ResourceDetails.[name])+1, 50),''')]','') AS 'IntegrationRuntimeName',
	Properties.[type] AS 'Type'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails

	--ir details
	CROSS APPLY OPENJSON (ResourceDetails.[properties]) WITH
		(
		[type] NVARCHAR(500)
		) AS Properties
WHERE
	ResourceDetails.[type] = 'Microsoft.DataFactory/factories/integrationRuntimes'


/* ------------------------------------------------------------
						dataflow information
------------------------------------------------------------ */
SELECT 
	REPLACE(SUBSTRING(ResourceDetails.[name], CHARINDEX('/',ResourceDetails.[name])+1, 50),''')]','') AS 'DataFlowName',
	Properties.[type] AS 'Type'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails

	--df details
	CROSS APPLY OPENJSON (ResourceDetails.[properties]) WITH
		(
		[type] NVARCHAR(500)
		) AS Properties
WHERE
	ResourceDetails.[type] = 'Microsoft.DataFactory/factories/dataflows'


/* ------------------------------------------------------------
						trigger information
------------------------------------------------------------ */
SELECT 
	REPLACE(SUBSTRING(ResourceDetails.[name], CHARINDEX('/',ResourceDetails.[name])+1, 50),''')]','') AS 'TriggerName',
	Properties.[type] AS 'Type',
	Properties.[runtimeState] AS 'Status'
FROM 
	--top level template
	OPENJSON(@ARMJson) WITH 
		(
		[resources] NVARCHAR(MAX) AS JSON
		) AS ResourceArray
	
	--resource details
	CROSS APPLY OPENJSON (ResourceArray.[resources]) WITH 
		(
		[name] NVARCHAR(MAX), 
		[type] NVARCHAR(500),
		[apiVersion] DATE,
		[properties] NVARCHAR(MAX) AS JSON
		) AS ResourceDetails

	--trigger details
	CROSS APPLY OPENJSON (ResourceDetails.[properties]) WITH
		(
		[runtimeState] NVARCHAR(500),
		[type] NVARCHAR(500)
		) AS Properties
WHERE
	ResourceDetails.[type] = 'Microsoft.DataFactory/factories/triggers'