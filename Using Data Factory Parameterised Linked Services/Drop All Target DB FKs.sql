SELECT 
	'ALTER TABLE SalesLT.' + SUBSTRING(REPLACE(name,'FK_',''),0,CHARINDEX('_',REPLACE(name,'FK_',''))) + ' ' + 
	'DROP CONSTRAINT ' + name 
FROM 
	sys.objects 
WHERE 
	type = 'f'

