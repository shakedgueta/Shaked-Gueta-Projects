-- 1 --
WITH cte AS (
    SELECT 
        YEAR(OrderDate) AS OrderYear,
        COUNT(DISTINCT MONTH(OrderDate)) AS YearlyMonthCount,
        SUM(Quantity * UnitPrice) AS YearlyIncome,
        SUM(Quantity * UnitPrice) / COUNT(DISTINCT MONTH(OrderDate)) * 12 AS LinearYearlyIncome
    FROM sales.Orders o
    INNER JOIN 
        sales.Invoices i ON o.OrderID = i.OrderID
    INNER JOIN 
        sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
    GROUP BY YEAR(OrderDate)
)
SELECT OrderYear, YearlyMonthCount, YearlyIncome, LinearYearlyIncome,
    LAG(LinearYearlyIncome) OVER (ORDER BY OrderYear) AS Prev_LinearYearlyIncome,
    (LinearYearlyIncome / LAG(LinearYearlyIncome) OVER (ORDER BY OrderYear) - 1) * 100 AS Ratio
FROM cte;


-- 2 --
WITH cte AS (
    SELECT 
        YEAR(OrderDate) AS TheYear,
        DATEPART(QUARTER, OrderDate) AS TheQuarter,
        c.CustomerName,
        SUM(il.Quantity * il.UnitPrice) AS IncomePerYear
    FROM sales.Orders o
    INNER JOIN 
        sales.Invoices i ON o.OrderID = i.OrderID
    INNER JOIN 
        sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
    INNER JOIN 
        sales.Customers c ON o.CustomerID = c.CustomerID
    GROUP BY 
        YEAR(OrderDate),
        DATEPART(QUARTER, OrderDate),
        c.CustomerName
),
RankedIncome AS (
    SELECT TheYear, TheQuarter, CustomerName, IncomePerYear,
        ROW_NUMBER() OVER (PARTITION BY TheYear, TheQuarter ORDER BY IncomePerYear DESC) AS Rank
    FROM cte
)
SELECT TheYear, TheQuarter, CustomerName, IncomePerYear,
    Rank AS DNR
FROM RankedIncome
WHERE Rank <= 5
ORDER BY TheYear, TheQuarter, Rank


-- 3 --
WITH cte AS (
    SELECT il.StockItemID, si.StockItemName,
        SUM(il.ExtendedPrice - il.TaxAmount) AS TotalProfit
    FROM sales.InvoiceLines il
    INNER JOIN 
        warehouse.StockItems si ON il.StockItemID = si.StockItemID
    GROUP BY il.StockItemID, si.StockItemName
)
SELECT TOP 10
    StockItemID,
    StockItemName,
    TotalProfit
FROM cte
ORDER BY TotalProfit DESC


-- 4 --
WITH cte AS (
    SELECT si.StockItemID, si.StockItemName, si.UnitPrice, si.RecommendedRetailPrice,
        ROUND(si.RecommendedRetailPrice - si.UnitPrice, 2) AS NominalProductProfit
    FROM warehouse.StockItems si
    WHERE GETDATE() BETWEEN si.ValidFrom AND si.ValidTo 
),
RankedItems AS (
    SELECT 
        ROW_NUMBER() OVER (ORDER BY NominalProductProfit DESC) AS Rn,
        StockItemID,
        StockItemName,
        UnitPrice,
        RecommendedRetailPrice,
        NominalProductProfit,
        DENSE_RANK() OVER (ORDER BY NominalProductProfit DESC) AS DNR
    FROM cte
)
SELECT 
    Rn,
    StockItemID,
    StockItemName,
    UnitPrice,
    RecommendedRetailPrice,
    NominalProductProfit,
    DNR
FROM RankedItems
ORDER BY Rn


-- 5 --
WITH cte AS (
    SELECT s.SupplierID,
        CONCAT(s.SupplierID, ' - ', s.SupplierName) AS SupplierDetails,
        CONCAT(si.StockItemID, ' ', si.StockItemName) AS ProductDetail
    FROM purchasing.Suppliers s
    INNER JOIN 
        warehouse.StockItems si ON s.SupplierID = si.SupplierID
),
AggregatedProducts AS (
    SELECT s.SupplierID, SupplierDetails,
        STRING_AGG(ProductDetail, ' / ') AS ProductDetails
    FROM cte s
    GROUP BY s.SupplierID, SupplierDetails
)
SELECT SupplierDetails, ProductDetails
FROM AggregatedProducts
ORDER BY SupplierID


-- 6 --
WITH cte AS (
    SELECT c.CustomerID, ct.CityName, co.CountryName, co.Continent, co.Region,
        SUM(il.ExtendedPrice) AS TotalExtendedPrice
    FROM sales.Customers c
    INNER JOIN 
        application.Cities ct ON c.PostalCityID = ct.CityID
    INNER JOIN 
        application.StateProvinces sp ON ct.StateProvinceID = sp.StateProvinceID
    INNER JOIN 
        application.Countries co ON sp.CountryID = co.CountryID
    INNER JOIN 
        sales.Invoices i ON c.CustomerID = i.CustomerID
    INNER JOIN 
        sales.InvoiceLines il ON i.InvoiceID = il.InvoiceID
    GROUP BY c.CustomerID, ct.CityName, co.CountryName, co.Continent, co.Region
)
SELECT TOP 5
    CustomerID,
    CityName,
    CountryName,
    Continent,
    Region,
    CAST(TotalExtendedPrice AS DECIMAL(12, 2)) AS TotalExtendedPrice
FROM cte
ORDER BY TotalExtendedPrice DESC

-- 7 --
WITH cte AS (
    SELECT OrderYear, OrderMonth,
        SUM(Quantity * UnitPrice) AS MonthlyTotal
    FROM (
        SELECT 
            YEAR(O.OrderDate) AS OrderYear,
            MONTH(O.OrderDate) AS OrderMonth,
            OL.Quantity, OL.UnitPrice
        FROM [Sales].[Orders] O
        INNER JOIN [Sales].[Invoices] I ON I.OrderID = O.OrderID
        INNER JOIN [Sales].[OrderLines] OL ON OL.OrderID = O.OrderID
        INNER JOIN [Warehouse].[StockItems] SI ON OL.StockItemID = SI.StockItemID
    ) a
    GROUP BY OrderYear, OrderMonth

    UNION ALL

    SELECT OrderYear,
        NULL AS OrderMonth,
        NULL AS MonthlyTotal
    FROM (
        SELECT 
            YEAR(O.OrderDate) AS OrderYear,
            MONTH(O.OrderDate) AS OrderMonth,
            SUM(OL.Quantity * OL.UnitPrice) AS MonthlyTotal
        FROM [Sales].[Orders] O
        INNER JOIN [Sales].[OrderLines] OL ON OL.OrderID = O.OrderID
        GROUP BY YEAR(O.OrderDate), MONTH(O.OrderDate)
    ) a
    GROUP BY OrderYear
)

SELECT OrderYear,
    CASE 
        WHEN OrderMonth IS NULL THEN 'Grand Total'
        ELSE CAST(OrderMonth AS VARCHAR)
    END AS OrderMonth,
    CASE 
        WHEN OrderMonth IS NULL THEN 
            SUM(MonthlyTotal) OVER (PARTITION BY OrderYear)
        ELSE 
            MonthlyTotal
    END AS MonthlyTotal,
    CASE 
        WHEN OrderMonth IS NULL THEN 
            SUM(MonthlyTotal) OVER (PARTITION BY OrderYear)
        ELSE 
            SUM(MonthlyTotal) OVER (PARTITION BY OrderYear ORDER BY ISNULL(OrderMonth, 13))
    END AS CumulativeTotal
FROM cte
ORDER BY 
    OrderYear,
    ISNULL(OrderMonth, 13)

-- 8 --
WITH CTE AS (
    SELECT 
        YEAR(OrderDate) AS OrderYear,
        MONTH(OrderDate) AS OrderMonth,
        COUNT(OrderID) AS OrderCount
    FROM Sales.Orders
    GROUP BY YEAR(OrderDate), MONTH(OrderDate)
)
SELECT OrderMonth,
    ISNULL([2013], 0) AS [2013],
    ISNULL([2014], 0) AS [2014],
    ISNULL([2015], 0) AS [2015],
    ISNULL([2016], 0) AS [2016]
FROM CTE
PIVOT (
    SUM(OrderCount)
    FOR OrderYear IN ([2013], [2014], [2015], [2016])
) AS p
ORDER BY OrderMonth

-- 9 --
WITH CustomerOrders AS (
    SELECT o.CustomerID, c.CustomerName, o.OrderDate,
        LAG(o.OrderDate) OVER (PARTITION BY o.CustomerID ORDER BY o.OrderDate) AS PreviousOrderDate
    FROM sales.Orders o
    JOIN sales.Customers c ON o.CustomerID = c.CustomerID
),
OrderIntervals AS (
    SELECT CustomerID, CustomerName, OrderDate, PreviousOrderDate,
        DATEDIFF(DAY, PreviousOrderDate, OrderDate) AS DaysSinceLastOrder
    FROM CustomerOrders
),
AverageIntervals AS (
    SELECT CustomerID,
        CAST(ROUND(AVG(CAST(NULLIF(DATEDIFF(DAY, PreviousOrderDate, OrderDate), 0) AS FLOAT)), 0) AS INT) AS AvgDaysBetweenOrders
    FROM CustomerOrders
    WHERE PreviousOrderDate IS NOT NULL
    GROUP BY CustomerID
)
SELECT o.CustomerID, o.CustomerName, o.OrderDate, o.PreviousOrderDate,
    ISNULL(o.DaysSinceLastOrder, 0) AS DaysSinceLastOrder,
    ISNULL(a.AvgDaysBetweenOrders, 0) AS AvgDaysBetweenOrders,
    CASE 
        WHEN o.DaysSinceLastOrder > 2 * ISNULL(a.AvgDaysBetweenOrders, 0) THEN 'Potential Churn'
        ELSE 'Active'
    END AS CustomerStatus
FROM OrderIntervals o
LEFT JOIN AverageIntervals a
ON o.CustomerID = a.CustomerID
ORDER BY o.CustomerID, o.OrderDate


-- 10 --
SELECT *, CONCAT(CAST(CAST(customerCount AS DECIMAL(5,2)) / totalCustCount * 100.0 AS DECIMAL(5,2)), '%') AS Percentage
FROM (
       SELECT CustomerCategoryName,COUNT(DISTINCT customerName) AS customerCount,
       SUM(COUNT(DISTINCT customerName)) OVER () AS totalCustCount
        FROM
            (
             SELECT cc.CustomerCategoryName,
                    CASE 
                        WHEN CustomerName LIKE 'Wingtip%' THEN 'Wingtip'
                        WHEN CustomerName LIKE 'tailspin%' THEN 'tailspin'
                        ELSE CustomerName 
                    END AS customerName
                FROM sales.CustomerCategories AS cc 
                INNER JOIN sales.Customers AS c ON cc.CustomerCategoryID = c.CustomerCategoryID
            ) AS a
        GROUP BY CustomerCategoryName
    ) AS b