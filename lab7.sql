USE AdventureWorks2022;
GO

-- 1. Create schema for reporting and DSL-based stored procedures
CREATE SCHEMA Reporting AUTHORIZATION dbo;
GO

-- 2. Create logging table for execution and error tracking
CREATE TABLE Reporting.ExecutionLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    ProcedureName NVARCHAR(100),
    ExecutedSQL NVARCHAR(MAX),
    ExecutionDate DATETIME DEFAULT GETDATE(),
    ErrorMessage NVARCHAR(4000)
);
GO

-- Confirmation message
PRINT '✅ Reporting schema and ExecutionLog table created successfully.';
GO

SELECT * FROM sys.schemas WHERE name = 'Reporting';
SELECT * FROM Reporting.ExecutionLog;






-- Task 2 – Basic Stored Procedure


USE AdventureWorks2022;
GO

CREATE OR ALTER PROCEDURE Reporting.GetSalesByTerritory
    @Territory NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        t.Name AS Territory,
        COUNT(DISTINCT s.SalesOrderID) AS OrdersCount,
        SUM(s.SubTotal) AS TotalSales
    FROM Sales.SalesOrderHeader AS s
    INNER JOIN Sales.SalesTerritory AS t
        ON s.TerritoryID = t.TerritoryID
    WHERE t.Name = @Territory
    GROUP BY t.Name;
END;
GO

-- Test Execution
EXEC Reporting.GetSalesByTerritory @Territory = 'Northwest';
GO







-- Task 3 – Implement Secure Dynamic SQL

USE AdventureWorks2022;
GO

CREATE OR ALTER PROCEDURE Reporting.DynamicSalesReport
    @Territory   NVARCHAR(50)  = NULL,
    @SalesPerson NVARCHAR(100) = NULL,
    @StartDate   DATE          = NULL,
    @EndDate     DATE          = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @SQL NVARCHAR(MAX);

    -- Base query
    SET @SQL = N'
        SELECT 
            t.Name AS Territory,
            p.FirstName + '' '' + p.LastName AS SalesPerson,
            SUM(s.SubTotal) AS TotalSales
        FROM Sales.SalesOrderHeader s
        INNER JOIN Sales.SalesTerritory t ON s.TerritoryID = t.TerritoryID
        INNER JOIN Sales.SalesPerson sp ON s.SalesPersonID = sp.BusinessEntityID
        INNER JOIN Person.Person p ON sp.BusinessEntityID = p.BusinessEntityID
        WHERE 1 = 1';

    -- Optional filters
    IF @Territory IS NOT NULL 
        SET @SQL += N' AND t.Name = @Territory';
    IF @SalesPerson IS NOT NULL 
        SET @SQL += N' AND (p.FirstName + '' '' + p.LastName) = @SalesPerson';
    IF @StartDate IS NOT NULL 
        SET @SQL += N' AND s.OrderDate >= @StartDate';
    IF @EndDate IS NOT NULL 
        SET @SQL += N' AND s.OrderDate <= @EndDate';

    SET @SQL += N' GROUP BY t.Name, p.FirstName, p.LastName
                  ORDER BY TotalSales DESC;';

    BEGIN TRY
        -- Log successful execution
        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutedSQL)
        VALUES ('Reporting.DynamicSalesReport', @SQL);

        -- Secure dynamic execution
        EXEC sp_executesql
            @SQL,
            N'@Territory NVARCHAR(50), @SalesPerson NVARCHAR(100), @StartDate DATE, @EndDate DATE',
            @Territory, @SalesPerson, @StartDate, @EndDate;
    END TRY

    BEGIN CATCH
        -- Log error details
        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutedSQL, ErrorMessage)
        VALUES ('Reporting.DynamicSalesReport', @SQL, ERROR_MESSAGE());
    END CATCH
END;
GO


-- Example 1 – Filter by Territory
EXEC Reporting.DynamicSalesReport @Territory = 'Northwest';

-- Example 2 – Filter by Salesperson
EXEC Reporting.DynamicSalesReport @SalesPerson = 'Stephen Jiang';

-- Example 3 – Filter by Date Range
EXEC Reporting.DynamicSalesReport @StartDate = '2013-01-01', @EndDate = '2013-12-31';

-- Example 4 – Combined Filters
EXEC Reporting.DynamicSalesReport 
    @Territory = 'Northwest',
    @SalesPerson = 'Stephen Jiang',
    @StartDate = '2013-01-01',
    @EndDate = '2013-12-31';


    SELECT TOP 10 * 
FROM Reporting.ExecutionLog
ORDER BY ExecutionDate DESC;







-- Task 4 – SQL Injection Prevention

USE AdventureWorks2022;
GO

-- ❌ Vulnerable Implementation (Unsafe Dynamic SQL)
CREATE OR ALTER PROCEDURE Reporting.VulnerableProductSearch
    @Category NVARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX) = N'
        SELECT ProductID, Name 
        FROM Production.Product
        WHERE Name LIKE ''%' + @Category + '%''';
    
    PRINT 'Executing vulnerable dynamic SQL...';
    EXEC(@SQL);
END;
GO


-- ✅ Secure Implementation (Parameterized Dynamic SQL)
CREATE OR ALTER PROCEDURE Reporting.SecureProductSearch
    @Category NVARCHAR(100)
AS
BEGIN
    DECLARE @SQL NVARCHAR(MAX) = N'
        SELECT ProductID, Name 
        FROM Production.Product
        WHERE Name LIKE @Pattern';
    
    DECLARE @Pattern NVARCHAR(102) = N'%' + @Category + N'%';

    PRINT 'Executing secure parameterized SQL...';
    EXEC sp_executesql 
        @SQL, 
        N'@Pattern NVARCHAR(102)', 
        @Pattern;
END;
GO


EXEC Reporting.VulnerableProductSearch @Category = 'Mountain';
EXEC Reporting.SecureProductSearch @Category = 'Mountain';



-- Task 5 – Control-of-Flow and Output Parameters


USE AdventureWorks2022;
GO

CREATE OR ALTER PROCEDURE Reporting.CheckInventoryLevel
    @ProductID INT,
    @Status NVARCHAR(20) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Qty INT;

    -- Retrieve total quantity available for the given product
    SELECT @Qty = SUM(Quantity)
    FROM Production.ProductInventory
    WHERE ProductID = @ProductID;

    -- Control-of-flow logic for categorizing stock levels
    IF @Qty IS NULL
        SET @Status = 'Unknown';
    ELSE IF @Qty < 50
        SET @Status = 'Low';
    ELSE
        SET @Status = 'Sufficient';
END;
GO

-- Test Execution
DECLARE @ProductStatus NVARCHAR(20);
EXEC Reporting.CheckInventoryLevel 
    @ProductID = 776, 
    @Status = @ProductStatus OUTPUT;

-- Display the output result
PRINT @ProductStatus;
GO


DECLARE @ProductStatus NVARCHAR(20);
EXEC Reporting.CheckInventoryLevel @ProductID = 776, @Status = @ProductStatus OUTPUT;
PRINT @ProductStatus;


SELECT name, schema_id, type_desc
FROM sys.objects
WHERE name = 'CheckInventoryLevel';



-- Task 6 – Error Handling and Logging


USE AdventureWorks2022;
GO

CREATE OR ALTER PROCEDURE Reporting.SafeUpdateProductCost
    @ProductID INT,
    @NewListPrice MONEY
AS
BEGIN
    BEGIN TRAN;

    BEGIN TRY
        -- Attempt to update the product's list price
        UPDATE Production.Product
        SET ListPrice = @NewListPrice
        WHERE ProductID = @ProductID;

        -- Validate update success
        IF @@ROWCOUNT = 0
            THROW 51000, 'Product not found', 1;

        -- Commit if successful
        COMMIT TRAN;

        -- Log success
        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutedSQL, ErrorMessage)
        VALUES ('Reporting.SafeUpdateProductCost', 
                CONCAT('UPDATE Production.Product SET ListPrice = ', @NewListPrice, ' WHERE ProductID = ', @ProductID),
                NULL);
    END TRY

    BEGIN CATCH
        -- Rollback if any error occurred
        IF XACT_STATE() <> 0 ROLLBACK TRAN;

        -- Log failure details
        INSERT INTO Reporting.ExecutionLog (ProcedureName, ExecutedSQL, ErrorMessage)
        VALUES ('Reporting.SafeUpdateProductCost', 
                'UPDATE Production.Product...', 
                ERROR_MESSAGE());

        -- Re-throw the error for client visibility
        THROW;
    END CATCH;
END;
GO


EXEC Reporting.SafeUpdateProductCost @ProductID = 776, @NewListPrice = 1500.00;


EXEC Reporting.SafeUpdateProductCost @ProductID = 999999, @NewListPrice = 1500.00;


SELECT TOP 10 * 
FROM Reporting.ExecutionLog 
WHERE ProcedureName = 'Reporting.SafeUpdateProductCost'
ORDER BY ExecutionDate DESC;
