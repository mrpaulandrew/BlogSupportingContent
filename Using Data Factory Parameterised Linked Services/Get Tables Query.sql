SELECT 
	s.name + '.' + o.name AS TableName
FROM 
	sys.objects o
	INNER JOIN sys.schemas s
		ON o.schema_id = s.schema_id
WHERE
	s.name = 'SalesLT'
	AND o.type = 'U'