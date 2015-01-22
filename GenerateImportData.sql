
-- =============================================
-- Author:		Eduardo Cuomo
-- Create date:	11/07/2014
-- Description: Generates Data Import SQL.
-- =============================================
CREATE PROCEDURE [dbo].[GenerateImportData]
	@TableName	NVARCHAR(MAX)	-- Table Name
AS

SET NOCOUNT ON

DECLARE @InsertSql	NVARCHAR(MAX)
DECLARE @RowSql		NVARCHAR(MAX)
DECLARE @ColName	NVARCHAR(MAX)
DECLARE @ColType	NVARCHAR(MAX)

SET @InsertSql = N'SET IDENTITY_INSERT [' + @TableName + N'] ON;'
	+ CHAR(13) + CHAR(13) + N'INSERT INTO [' + @TableName + N'] ('

DECLARE ColumnsCursor CURSOR DYNAMIC FOR
	SELECT C.COLUMN_NAME, C.DATA_TYPE
	FROM INFORMATION_SCHEMA.COLUMNS AS C
	WHERE C.TABLE_NAME = @TableName
	ORDER BY ORDINAL_POSITION

OPEN ColumnsCursor

FETCH FIRST FROM ColumnsCursor INTO @ColName, @ColType

WHILE (@@FETCH_STATUS = 0) BEGIN
	IF (@RowSql IS NULL) BEGIN
		SET @RowSql = CHAR(13) + N'	+ '
	END ELSE BEGIN
		SET @RowSql = @RowSql + CHAR(13) + N'	+ '', '' + '
		SET @InsertSql = @InsertSql + N', '
	END
	
	-- COL
	SET @InsertSql = @InsertSql + N'[' + @ColName + N']'
	
	-- ROW
	--SET @RowSql = @RowSql + '' + '('
	SET @RowSql = @RowSql + '('
	IF ((@ColType LIKE '%CHAR%') OR (@ColType LIKE '%TEXT%')) BEGIN
		-- String
		SET @RowSql = @RowSql + N'CASE WHEN ([' + @ColName + '] IS NULL) THEN ''NULL'' ELSE '''''''' + REPLACE([' + @ColName + '], '''''''', '''''''''''') + '''''''' END'
	END ELSE IF ((@ColType LIKE '%DATE%') OR (@ColType LIKE '%TIME%')) BEGIN
		-- Date / Time
		SET @RowSql = @RowSql + N'CASE WHEN ([' + @ColName + '] IS NULL) THEN ''NULL'' ELSE '''''''' + CONVERT(VARCHAR, [' + @ColName + ']) + '''''''' END'
	END ELSE BEGIN
		-- Other (Number)
		SET @RowSql = @RowSql + N'CASE WHEN ([' + @ColName + '] IS NULL) THEN ''NULL'' ELSE CONVERT(VARCHAR, [' + @ColName + ']) END'
	END
	SET @RowSql = @RowSql + ')'
	
	-- Next
	FETCH NEXT FROM ColumnsCursor INTO @ColName, @ColType
END

CLOSE ColumnsCursor 
DEALLOCATE ColumnsCursor

SET @InsertSql = @InsertSql + ')' + CHAR(13) + 'VALUES'

IF OBJECT_ID('tempdb..##TmpExportData') IS NOT NULL DROP TABLE ##TmpExportData

SET @RowSql = N'SELECT ''	, (''' + @RowSql + CHAR(13) + N'	+ '')'' AS Q'
	+ CHAR(13) + N'INTO ##TmpExportData'
	+ CHAR(13) + N'FROM' + CHAR(13) + N'	[' + @TableName + N']'
EXECUTE sp_executesql @RowSql

-- Add Rows
DECLARE RowsCursor CURSOR DYNAMIC FOR
	SELECT * FROM ##TmpExportData

OPEN RowsCursor

DECLARE @Q		AS NVARCHAR(MAX)
DECLARE @First	AS BIT = 1
FETCH FIRST FROM RowsCursor INTO @Q

WHILE (@@FETCH_STATUS = 0) BEGIN
	IF (@First = 1) BEGIN
		SET @First = 0
		SET @Q = N'	 ' + SUBSTRING(@Q, 3, LEN(@Q) - 2)
	END
	SET @InsertSql = @InsertSql + CHAR(13) + @Q
	-- Next
	FETCH NEXT FROM RowsCursor INTO @Q
END

CLOSE RowsCursor
DEALLOCATE RowsCursor


-- End
SET @InsertSql = @InsertSql + ';' + CHAR(13) + CHAR(13) + N'SET IDENTITY_INSERT [' + @TableName + N'] OFF;'

-- Show Query
SELECT '--' + CHAR(13) + CHAR(13) + @InsertSql + CHAR(13) + CHAR(13) + '--' AS [processing-instruction(x)] FOR XML PATH('')
