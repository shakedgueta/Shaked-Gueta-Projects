-- 1 --
SELECT TOP 5 P.name AS ProductName, SUM(SOD.LineTotal) AS TotalSales
FROM Sales.SalesOrderDetail AS SOD
INNER JOIN 
    Production.Product AS P ON SOD.ProductID = P.ProductID
GROUP BY 
    P.Name
ORDER BY 
    TotalSales DESC

-- 2 --
SELECT PC.Name AS ProductCategory, AVG(SOD.UnitPrice) AS AverageUnitPrice
FROM Sales.SalesOrderDetail AS SOD
INNER JOIN 
    Production.Product AS P ON SOD.ProductID = P.ProductID
INNER JOIN 
    Production.ProductSubCategory AS PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
INNER JOIN 
    Production.ProductCategory AS PC ON PSC.ProductCategoryID = PC.ProductCategoryID
WHERE 
PC.Name IN ('Bikes', 'Components')
GROUP BY 
    PC.Name

-- 3 --
SELECT P.Name AS ProductName, COUNT(SOD.OrderQty) AS TotalOrderQty
FROM Sales.SalesOrderDetail AS SOD
INNER JOIN 
    Production.Product AS P ON SOD.ProductID = P.ProductID
INNER JOIN 
    Production.ProductSubCategory AS PSC ON P.ProductSubcategoryID = PSC.ProductSubcategoryID
INNER JOIN 
    Production.ProductCategory AS PC ON PSC.ProductCategoryID = PC.ProductCategoryID
WHERE 
    PC.Name NOT IN ('Components', 'Clothing')
GROUP BY 
    P.Name
ORDER BY 
    TotalOrderQty DESC

-- 4 --
SELECT TOP 3 ST.Name AS TerritoryName, SUM(SOH.SubTotal) AS TotalSales
FROM Sales.SalesOrderHeader AS SOH
INNER JOIN 
    Sales.SalesTerritory AS ST ON SOH.TerritoryID = ST.TerritoryID
GROUP BY 
    ST.Name
ORDER BY 
    TotalSales DESC

-- 5 --
SELECT C.CustomerID, CONCAT(P.FirstName, ' ', P.LastName) AS FullName
FROM [Sales].[Customer] AS C
INNER JOIN 
    person.Person AS P ON C.PersonID = P.BusinessEntityID
LEFT JOIN 
    Sales.SalesOrderHeader AS SOH ON C.CustomerID = SOH.CustomerID
WHERE SOH.SalesOrderID IS NULL

-- 6 --
DELETE FROM [Sales].[SalesTerritory]
WHERE TerritoryID NOT IN (
    SELECT DISTINCT TerritoryID 
    FROM [Sales].[SalesPerson]
    WHERE TerritoryID IS NOT NULL)

-- 7 --
INSERT INTO [Sales].[SalesTerritory] (Name)
SELECT ST.Name
FROM AdventureWorks2022.Sales.SalesTerritory AS ST
WHERE ST.TerritoryID NOT IN (
    SELECT SP.TerritoryID
    FROM [Sales].[SalesPerson] AS SP
    WHERE SP.TerritoryID IS NOT NULL)

-- 8 --
SELECT P.FirstName, P.LastName
FROM AdventureWorks2022.Person.Person AS P
INNER JOIN Sales.Customer AS C
    ON P.BusinessEntityID = C.PersonID
INNER JOIN Sales.SalesOrderHeader AS SOH
    ON C.CustomerID = SOH.CustomerID
GROUP BY P.FirstName, P.LastName
HAVING COUNT(SOH.SalesOrderID) > 20;

-- 9 --
SELECT GroupName, COUNT(DepartmentID) AS DepartmentCount
FROM HumanResources.Department
GROUP BY GroupName
HAVING COUNT(DepartmentID) > 2;

-- 10 --
SELECT P.FirstName + ' ' + P.MiddleName + ' ' +P.LastName AS FullName , D.Name AS DepartmentName, S.Name AS ShiftName
FROM HumanResources.EmployeeDepartmentHistory AS EDH
INNER JOIN HumanResources.Employee AS E
    ON EDH.BusinessEntityID = E.BusinessEntityID
INNER JOIN Person.Person AS P
    ON EDH.BusinessEntityID = P.BusinessEntityID
INNER JOIN HumanResources.Department AS D
    ON EDH.DepartmentID = D.DepartmentID
INNER JOIN HumanResources.Shift AS S
    ON EDH.ShiftID = S.ShiftID
WHERE EDH.StartDate > '2010-01-01'
AND (D.GroupName = 'Quality Assurance' OR D.GroupName = 'Manufacturing')










