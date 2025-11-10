Lab 7 – Stored Procedures and Secure Dynamic SQL Programming

Course: SQL Server Development
Database: AdventureWorks2022

Student:
Asish Anisetti (N01738397)

Overview:
This lab focuses on building secure and reusable stored procedures using parameterized dynamic SQL (sp_executesql), error handling, transactions, and control-of-flow logic. All procedures are created inside the Reporting schema and every execution or error is recorded in the ExecutionLog table.

Procedures:
1. GetSalesByTerritory – Displays total sales and order count by specific territory.
2. DynamicSalesReport – Generates dynamic and flexible sales reports using parameters for territory, salesperson, and date range.
3. SecureProductSearch – Demonstrates prevention of SQL injection using parameterized dynamic SQL.
4. CheckInventoryLevel – Uses IF-ELSE control logic and an OUTPUT parameter to show inventory status.
5. SafeUpdateProductCost – Updates product cost securely with transaction management, TRY...CATCH error handling, and logging.

Test Executions:
EXEC Reporting.GetSalesByTerritory @Territory = 'Northwest'
EXEC Reporting.DynamicSalesReport @Territory = 'Northwest', @StartDate = '2013-01-01', @EndDate = '2013-12-31'
EXEC Reporting.SecureProductSearch @Category = 'Mountain'
DECLARE @Status NVARCHAR(20)
EXEC Reporting.CheckInventoryLevel @ProductID = 776, @Status = @Status OUTPUT
PRINT @Status
EXEC Reporting.SafeUpdateProductCost @ProductID = 776, @NewListPrice = 1500.00
EXEC Reporting.SafeUpdateProductCost @ProductID = 999999, @NewListPrice = 1500.00

Notes:
- All procedures and logs are inside the Reporting schema.
- Dynamic SQL is parameterized to avoid SQL injection.
- Transactions and error handling ensure data integrity.
- Submit only the GitHub repository link containing this file and the .sql script.
