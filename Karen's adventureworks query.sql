
/*CREATING THE FOUR DIM TABLES*/

--CREATING DATE DIM TABLE
CREATE TABLE Date_Dim (
    date_key INT PRIMARY KEY,    -- Date in YYYYMMDD format
    full_date DATE,              -- Full date in standard format
    day INT,                     -- Day of the month
    month INT,                   -- Month number (1-12)
    year INT,                    -- Year
    quarter INT,                 -- Quarter of the year (1-4)
    day_of_week INT,             -- Day of the week (1=Monday, 7=Sunday)
	week INT,                    -- Week of the year (1- 12)
    month_name NVARCHAR(20),     -- Name of the month (e.g., January)
    is_weekend BIT               -- Flag to indicate if it's a weekend (1 for yes, 0 for no)
);


SELECT*
FROM Date_Dim;

--CREATING CUSTOMER DIMM TABLE
CREATE TABLE Customer_Dimm (
    customer_key INT PRIMARY KEY,     -- Unique customer identifier
    customer_name NVARCHAR(100),      -- Customer name
    address NVARCHAR(255),            -- Customer address
    city NVARCHAR(100),               -- Customer city
    state NVARCHAR(50),               -- Customer state
    country NVARCHAR(50),             -- Customer country
    phone NVARCHAR(20),               -- Customer phone number
    email NVARCHAR(100)               -- Customer email address
);

--CREATING PRODUCT DIMM TABLE
CREATE TABLE Product_Dimm (
    product_key INT PRIMARY KEY,         -- Unique product identifier
    product_name NVARCHAR(100),          -- Product name
    product_category NVARCHAR(50),       -- Category of the product
    product_subcategory NVARCHAR(50),    -- Subcategory of the product
    price DECIMAL(10, 2),                -- Product price
    product_description NVARCHAR(255)    -- Product description
);

--CREATING EMPLOYEE DIMM TABLE
CREATE TABLE Employee_Dimm (
    employee_key INT PRIMARY KEY,  -- Unique key for each employee
    employee_name VARCHAR(255),
    job_title VARCHAR(100),
    department VARCHAR(100),
    hire_date DATE,
    full_name VARCHAR(255)  -- Combination of first and last names
);
 



--INSERTING DATA INTO THE DATE_DIMM TABLE
DECLARE @date DATE = '2000-01-01';

WHILE @date <= GETDATE()
BEGIN
INSERT INTO Date_Dim (date_key, full_date, year, quarter, month, day, week, day_of_week)
    VALUES (
        CONVERT(INT, CONVERT(VARCHAR, YEAR(@date)) + RIGHT('0' + CONVERT(VARCHAR, MONTH(@date)), 2) + RIGHT('0' + CONVERT(VARCHAR, DAY(@date)), 2)),  -- date_key as YYYYMMDD
        @date,                  -- full_date
        YEAR(@date),            -- year
        DATEPART(QUARTER, @date), -- quarter
        MONTH(@date),           -- month
        DAY(@date),             -- day
        DATEPART(WEEK, @date),  -- week
        DATEPART(WEEKDAY, @date) -- day_of_week
    );
    SET @date = DATEADD(DAY, 1, @date);
END

SELECT *
FROM Date_Dim

ALTER TABLE Date_Dim
DROP COLUMN [month_name],[is_weekend]



--INSERTING DATA INTO THE EMPLOYEE_DIMM

INSERT INTO Employee_Dimm (employee_key, employee_name, job_title, department, hire_date, full_name)

SELECT 
    e.BusinessEntityID AS employee_key,
    pp.FirstName + ' ' + pp.LastName AS employee_name,
    e.JobTitle AS job_title,
    d.Name AS department,
    e.HireDate AS hire_date,
    pp.FirstName + ' ' + pp.LastName AS full_name

FROM HumanResources.Employee e

JOIN HumanResources.EmployeeDepartmentHistory edh ON e.BusinessEntityID = edh.BusinessEntityID
JOIN HumanResources.Department d ON edh.DepartmentID = d.DepartmentID
JOIN Person.Person pp ON e.BusinessEntityID = pp.BusinessEntityID

WHERE edh.EndDate IS NULL  -- Select only current department entries, if applicable
AND NOT EXISTS (

SELECT 1

FROM Employee_Dimm ed

WHERE ed.employee_key = e.BusinessEntityID
);

SELECT *
FROM Employee_Dimm

ALTER TABLE Employee_Dimm
DROP COLUMN full_name

--INSERTING DATA INTO THE CUSTOMER_DIMM

WITH CustomerData AS (
SELECT 
        c.CustomerID AS customer_key,
        a.AddressLine1 AS [address],
        p.FirstName + ' ' + p.LastName AS customer_name,
        e.EmailAddress AS [email],
        ph.PhoneNumber AS [phone],
        a.City,
        sp.Name AS [state],
        cr.Name AS [country],
        ROW_NUMBER() OVER(PARTITION BY c.CustomerID ORDER BY e.ModifiedDate DESC) AS rn  -- Choose based on the latest email modified date

FROM Sales.Customer c
    JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
    JOIN Person.EmailAddress e ON p.BusinessEntityID = e.BusinessEntityID
    JOIN Person.PersonPhone ph ON p.BusinessEntityID = ph.BusinessEntityID
    JOIN Person.BusinessEntityAddress bea ON c.PersonID = bea.BusinessEntityID
    JOIN Person.Address a ON bea.AddressID = a.AddressID
    JOIN Person.StateProvince sp ON a.StateProvinceID = sp.StateProvinceID
    JOIN Person.CountryRegion cr ON sp.CountryRegionCode = cr.CountryRegionCode
)
INSERT INTO Customer_Dimm(customer_key, [address], customer_name, [email], [phone], city, [state], [country])
SELECT 
    customer_key, 
    [address], 
    customer_name, 
    [email], 
    [phone], 
    city, 
    [state], 
    [country]

FROM CustomerData

WHERE rn = 1  -- Only take the first row per customer
AND NOT EXISTS (

SELECT 1

FROM Customer_Dimm cd

WHERE cd.customer_key = customer_key
);

SELECT *
FROM [dbo].[Customer_Dimm]





--INSERTING DATA INTO THE PRODUCT_DIMM

WITH ProductData AS (
SELECT 
        p.ProductID AS product_key,
        p.Name AS product_name,
        pc.Name AS product_category,
        psc.Name AS product_subcategory,
        pp.ListPrice AS [price],
        pd.Description AS product_description,
        ROW_NUMBER() OVER(PARTITION BY p.ProductID ORDER BY pp.ModifiedDate DESC) AS rn -- Ordering by latest price

FROM Production.Product p
    JOIN Production.ProductSubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
    JOIN Production.ProductCategory pc ON psc.ProductCategoryID = pc.ProductCategoryID
    JOIN Production.ProductListPriceHistory pp ON p.ProductID = pp.ProductID
    JOIN Production.ProductModelProductDescriptionCulture pmpdc ON p.ProductModelID = pmpdc.ProductModelID
    JOIN Production.ProductDescription pd ON pmpdc.ProductDescriptionID = pd.ProductDescriptionID

WHERE pmpdc.CultureID = 'en'  -- Optional: filter for English descriptions if applicable
)
INSERT INTO Product_Dimm(product_key, product_name, product_category, product_subcategory, [price], [product_description])
SELECT 
    product_key,
    product_name,
    product_category,
    product_subcategory,
    [price],
    product_description

FROM ProductData

WHERE rn = 1  -- Ensures only one row per product is inserted
AND NOT EXISTS (

SELECT 1

FROM Product_Dimm pdim

WHERE pdim.product_key = product_key
);


SELECT *
FROM [dbo].[Product_Dimm];

------------CREATING THE FACTSALE TABLE AND INSERTING DATA

CREATE TABLE FactSale (
    fact_sales_id INT IDENTITY(1,1) PRIMARY KEY,
    order_date_key INT,
    customer_key INT,
    product_key INT,
    total_sales_amount DECIMAL(10, 2),
    quantity_sold INT
);

SELECT *
FROM FactSale;

--INSERTING DATA INTO FACTSALE TABLE
WITH SalesDataCTE AS (
    SELECT 
        CONVERT(INT, CONVERT(VARCHAR, YEAR(soh.OrderDate)) + 
            RIGHT('0' + CONVERT(VARCHAR, MONTH(soh.OrderDate)), 2) + 
            RIGHT('0' + CONVERT(VARCHAR, DAY(soh.OrderDate)), 2)) AS order_date_key,
        soh.CustomerID AS customer_key,
        sod.ProductID AS product_key,
        SUM(sod.LineTotal) AS total_sales_amount,
        SUM(sod.OrderQty) AS quantity_sold
    FROM Sales.SalesOrderHeader soh
    JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID
    GROUP BY 
        soh.OrderDate, 
        soh.CustomerID, 
        sod.ProductID
)
INSERT INTO FactSale (order_date_key, customer_key, product_key, total_sales_amount, quantity_sold)

SELECT order_date_key, customer_key, product_key, total_sales_amount, quantity_sold
FROM SalesDataCTE;

SELECT *
FROM FactSale;

ALTER TABLE FactSale
ADD SalesRepID int;



--ADDING EMPLOYEE KEYS AND NAME OF THE SALES REPRESENTATIVES TO FACTSALE TABLE

UPDATE fs

SET fs.[SalesRepID] = e.employee_key

FROM FactSale fs

JOIN Sales.SalesOrderHeader soh ON fs.order_date_key = CONVERT(INT, CONVERT(VARCHAR, YEAR(soh.OrderDate)) + 
                                                         RIGHT('0' + CONVERT(VARCHAR, MONTH(soh.OrderDate)), 2) + 
                                                         RIGHT('0' + CONVERT(VARCHAR, DAY(soh.OrderDate)), 2))

JOIN Employee_Dimm e ON soh.SalesPersonID = e.employee_key


--ADDING THE EMPLOYEE KEY IN THE SALESREPID COLUMN

UPDATE fs

SET fs.SalesRepID = soh.SalesPersonID

FROM FactSale fs

JOIN Sales.SalesOrderHeader soh ON fs.fact_sales_id = soh.SalesOrderID; -- Or a matching key between `FactSale` and `SalesOrderHeader`

--ADDING THE CORRESPONDING SALESREP NAME

SELECT fs.SalesRepID, e.employee_name
FROM FactSale fs
LEFT JOIN Employee_Dimm e ON fs.SalesRepID = e.employee_key;

--ADDING A NEW COLUMN, "SALES REP NAME" COLUMN TO FACTSALE TABLE
ALTER TABLE FactSale
ADD SalesRepName VARCHAR(255)

UPDATE fs
SET fs.SalesRepName = e.employee_name
FROM FactSale fs
JOIN Employee_Dimm e ON fs.SalesRepID = e.employee_key;



--CHECKING TOTAL AMOUNT OF NULL IN SALESREPID COLUMN
SELECT *
FROM FactSale
WHERE SalesRepID IS NULL;


--CROSSCHECKED WITH THE SALESPERSON ID COLUMN IN SALESORDERHEADER TABLE

SELECT soh.*

FROM Sales.SalesOrderHeader soh

WHERE soh.SalesOrderID IN (

SELECT fact_sales_id 

FROM FactSale 

WHERE SalesRepID IS NULL
);


--CHANGING THE NULL TO UNKNOWN

INSERT INTO Employee_Dimm (employee_key, employee_name, job_title)
VALUES (0, 'Unknown', 'Sales Representative');

--UPDATING THE FACTSALE TABLE
UPDATE FactSale
SET SalesRepID = 0, SalesRepName = 'Unknown'
WHERE SalesRepID IS NULL;

select*
from FactSale;


--DATA ANALYSIS

/* A. Sales Analysis:
Examine sales performance by product, region, and sales representative.*/

SELECT 
    p.product_name AS Product,
    c.city AS Region,
    fs.SalesRepName AS Sales_Representative,
    fs.SalesRepID AS SalesRepID,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold,
    COUNT(fs.fact_sales_id) AS Total_Orders
FROM 
    FactSale fs
JOIN 
    Product_Dimm p ON fs.product_key = p.product_key
JOIN 
    Customer_Dimm c ON fs.customer_key = c.customer_key
JOIN 
    Employee_Dimm e ON fs.SalesRepID = e.employee_key
WHERE 
    e.job_title = 'Sales Representative'  -- Filter for sales representatives
GROUP BY 
    p.product_name, 
    c.city, 
    fs.SalesRepName, 
    fs.SalesRepID
ORDER BY 
    Total_Sales_Amount DESC, 
    Total_Quantity_Sold DESC;


/* Determine top-selling products, seasonal sales trends, and regional performance.*/

-----------1. Top-Selling Products

	SELECT 
    DISTINCT p.product_name AS Product,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold

FROM FactSale fs

JOIN Product_Dimm p ON fs.product_key = p.product_key

GROUP BY p.product_name

ORDER BY Total_Sales_Amount DESC;


----------2. Seasonal Sales Trends

SELECT 
    YEAR(CONVERT(DATETIME, CAST(fs.order_date_key AS VARCHAR))) AS Year,
    MONTH(CONVERT(DATETIME, CAST(fs.order_date_key AS VARCHAR))) AS Month,
    DAY(CONVERT(DATETIME, CAST(fs.order_date_key AS VARCHAR))) AS Day,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold

FROM FactSale fs

GROUP BY 
    YEAR(CONVERT(DATETIME, CAST(fs.order_date_key AS VARCHAR))),
    MONTH(CONVERT(DATETIME, CAST(fs.order_date_key AS VARCHAR))),
    DAY(CONVERT(DATETIME, CAST(fs.order_date_key AS VARCHAR)))

ORDER BY Year, Month, Day DESC;


----------3. Regional Performance

SELECT 
    c.city AS Region,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold

FROM FactSale fs

JOIN Customer_Dimm c ON fs.customer_key = c.customer_key

GROUP BY c.city

ORDER BY  Total_Sales_Amount DESC;


/* B. Customer Insights:
   Identify the most valuable customers, common purchase patterns, and customer demographics.*/

--------1. Identify the Most Valuable Customers

SELECT TOP 10
    c.customer_name AS Customer_Name,
    c.city AS City,
    c.state AS State,
    c.country AS Country,
    SUM(fs.total_sales_amount) AS Total_Spent,
    COUNT(fs.fact_sales_id) AS Total_Orders

FROM  FactSale fs

JOIN Customer_Dimm c ON fs.customer_key = c.customer_key

GROUP BY c.customer_name, c.city, c.state, c.country

ORDER BY Total_Spent DESC;


---------------2. Analyzing Common Purchase Patterns

SELECT TOP 10
    p.product_name AS Product,
    COUNT(fs.fact_sales_id) AS Purchase_Count,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold,
    SUM(fs.total_sales_amount) AS Total_Revenue

FROM FactSale fs

JOIN  Product_Dimm p ON fs.product_key = p.product_key

GROUP BY p.product_name

ORDER BY  Total_Quantity_Sold DESC, Total_Revenue DESC;


/*3. Analyzing Customer Demographics
Basic Customer Demographic Overview*/

SELECT 
    c.city AS City,
    c.state AS State,
    c.country AS Country,
    COUNT(fs.fact_sales_id) AS TotalOrders,
    SUM(fs.total_sales_amount) AS TotalSales
FROM 
    FactSale fs
JOIN 
    Customer_Dimm c ON fs.customer_key = c.customer_key
GROUP BY 
    c.city, c.state, c.country
ORDER BY 
    TotalSales DESC;


/* Demographic Analysis
Grouping customers by location to see their purchasing behavior:*/

SELECT 
    c.city AS City,
	c.state AS State,
	c.country AS Country,
    COUNT(DISTINCT c.customer_key) AS NumberOfCustomers,
    SUM(fs.total_sales_amount) AS TotalSales,
    AVG(fs.total_sales_amount) AS AvgSalesPerCustomer

FROM FactSale fs

JOIN Customer_Dimm c ON fs.customer_key = c.customer_key

GROUP BY  c.city, c.state, c.country 
	
ORDER BY  TotalSales DESC;


/*C. PRODUCT INVENTORY & PERFORMANCE

1. Inventory Levels.
Showing current inventory levels for each product and identify low-stock products.*/

SELECT 
    p.product_name AS Product,
    pi.LocationID AS Location,
    pi.Quantity AS CurrentStock

FROM Production.ProductInventory pi

JOIN Product_Dimm p ON pi.ProductID = p.product_key

ORDER BY pi.Quantity ASC;



/*2. High-Turnover Products.
Analyzing products with the highest sales volume.*/

SELECT 
    p.product_name AS Product,
    SUM(fs.quantity_sold) AS TotalQuantitySold,
    SUM(fs.total_sales_amount) AS TotalSales

FROM FactSale fs

JOIN Product_Dimm p ON fs.product_key = p.product_key

GROUP BY p.product_name

ORDER BY TotalQuantitySold DESC;


/*3. Category Performance
Evaluating sales performance across product categories.*/

SELECT 
    p.[product_category] AS Category,
    SUM(fs.quantity_sold) AS TotalQuantitySold,
    SUM(fs.total_sales_amount) AS TotalSales

FROM FactSale fs

JOIN Product_Dimm p ON fs.product_key = p.product_key

GROUP BY p.product_category

ORDER BY TotalSales DESC;

/*4. Pricing Impact
Analyzing the relationship between product pricing and sales volume.*/

SELECT 
    p.product_name AS Product,
    p.price AS ProductPrice,
    SUM(fs.quantity_sold) AS TotalQuantitySold,
    SUM(fs.total_sales_amount) AS TotalSales
FROM 
    FactSale fs
JOIN 
    Product_Dimm p ON fs.product_key = p.product_key
GROUP BY 
    p.product_name, p.price
ORDER BY 
    TotalQuantitySold DESC;


/*5. Regional Inventory & Sales Analysis
Analyzing inventory and sales performance by region.*/

SELECT 
    c.country AS Region,
    p.product_name AS Product,
    pi.Quantity AS StockAvailable,
    SUM(fs.quantity_sold) AS TotalQuantitySold,
    SUM(fs.total_sales_amount) AS TotalSales

FROM FactSale fs

JOIN Product_Dimm p ON fs.product_key = p.product_key
JOIN  Production.ProductInventory pi ON p.product_key = pi.ProductID
JOIN  Customer_Dimm c ON fs.customer_key = c.customer_key

GROUP BY c.country, p.product_name, pi.Quantity

ORDER BY  c.country, TotalSales DESC;


/* 6. Product Sales vs. Inventory
Identify products that are performing well in sales but have low inventory.*/

SELECT 
    p.product_name AS Product,
    SUM(fs.quantity_sold) AS TotalQuantitySold,
    SUM(fs.total_sales_amount) AS TotalSales,
    pi.Quantity AS CurrentStock

FROM FactSale fs

JOIN Product_Dimm p ON fs.product_key = p.product_key
JOIN Production.ProductInventory pi ON p.product_key = pi.ProductID

GROUP BY p.product_name, pi.Quantity

HAVING SUM(fs.quantity_sold) > 300 AND pi.Quantity <= 10 

ORDER BY TotalSales DESC;




/* 7. Strategic Stocking and Pricing Adjustments
Integrate pricing, inventory, and sales data for actionable insights.*/


SELECT 
    p.product_name AS Product,
    p.price AS ProductPrice,
    pi.Quantity AS CurrentStock,
    SUM(fs.quantity_sold) AS TotalQuantitySold,
    SUM(fs.total_sales_amount) AS TotalSales

FROM  FactSale fs

JOIN Product_Dimm p ON fs.product_key = p.product_key
JOIN Production.ProductInventory pi ON p.product_key = pi.ProductID

GROUP BY  p.product_name, p.price, pi.Quantity

ORDER BY TotalSales DESC, CurrentStock ASC;

 


/*D. EMPLOYEE PERFORMANCE:
1. Sales Performance by Individual Employee
Track sales performance for each sales representative.*/

SELECT 
    e.employee_name AS Sales_Representative,
    e.job_title AS JobTitle,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold,
    AVG(fs.total_sales_amount) AS Average_Sales_Per_Transaction,
    COUNT(fs.fact_sales_id) AS Total_Orders

FROM FactSale fs

JOIN Employee_Dimm e ON fs.SalesRepID = e.employee_key

WHERE  e.job_title = 'Sales Representative'

GROUP BY e.employee_name, e.job_title

ORDER BY Total_Sales_Amount DESC;



/*2. Top Performers
Identify the top 5 sales representatives based on total sales.*/

SELECT TOP 5
    e.employee_name AS Sales_Representative,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold,
    COUNT(fs.fact_sales_id) AS Total_Orders

FROM FactSale fs

JOIN Employee_Dimm e ON fs.SalesRepID = e.employee_key

WHERE e.job_title = 'Sales Representative'

GROUP BY e.employee_name

ORDER BY Total_Sales_Amount DESC;


/*3. Department-Level Sales Performance
Aggregate sales performance by department. */

SELECT 
    e.department AS Department,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold,
    COUNT(fs.fact_sales_id) AS Total_Orders,
    AVG(fs.total_sales_amount) AS Average_Sales_Per_Transaction

FROM FactSale fs

JOIN Employee_Dimm e ON fs.SalesRepID = e.employee_key

GROUP BY e.department

ORDER BY Total_Sales_Amount DESC;



/*4. Sales Performance to evaluate Training Needs
Identify employees with low sales performance for targeted training. */

SELECT TOP 4
    e.employee_name AS Sales_Representative,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    COUNT(fs.fact_sales_id) AS Total_Orders
FROM 
    FactSale fs
JOIN 
    Employee_Dimm e ON fs.SalesRepID = e.employee_key
WHERE 
    e.job_title = 'Sales Representative'
GROUP BY 
    e.employee_name

ORDER BY 
    Total_Sales_Amount ASC;



/*5. Employee Productivity Metrics
Calculate productivity metrics such as average sales per employee.*/

SELECT 
    COUNT(DISTINCT fs.SalesRepID) AS Total_Sales_Representatives,
    SUM(fs.total_sales_amount) / COUNT(DISTINCT fs.SalesRepID) AS Average_Sales_Per_Employee,
    SUM(fs.quantity_sold) / COUNT(DISTINCT fs.SalesRepID) AS Average_Quantity_Sold_Per_Employee

FROM FactSale fs

JOIN  Employee_Dimm e ON fs.SalesRepID = e.employee_key

WHERE e.job_title = 'Sales Representative';



/* 6. Sales Performance by Region and Employee
Evaluate employee performance in different regions.*/

SELECT 
    c.country AS Region,
    e.employee_name AS Sales_Representative,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold

FROM FactSale fs

JOIN Employee_Dimm e ON fs.SalesRepID = e.employee_key
JOIN Customer_Dimm c ON fs.customer_key = c.customer_key

WHERE e.job_title = 'Sales Representative'

GROUP BY c.country, e.employee_name

ORDER BY  Total_Sales_Amount DESC;



/*7. Sales Trends Over Time by Employee
Track sales performance trends for individual employees.*/

SELECT 
    e.employee_name AS Sales_Representative,
    (d.year) AS Year,
    (d.month) AS Month,
    SUM(fs.total_sales_amount) AS Total_Sales_Amount,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold

FROM FactSale fs

JOIN Employee_Dimm e ON fs.SalesRepID = e.employee_key
JOIN Date_Dim d ON fs.order_date_key = d.date_key

WHERE e.job_title = 'Sales Representative'

GROUP BY e.employee_name, (d.year), (d.month)

ORDER BY  e.employee_name, Year, Month DESC;



/* E. Financial and Time-Based Analysis.
1. Yearly Revenue and Expenses Analysis */

SELECT 
    dd.year AS Year,
    SUM(fs.total_sales_amount) AS Total_Revenue

FROM FactSale fs

JOIN Date_Dim dd ON fs.order_date_key = dd.date_key

GROUP BY dd.year

ORDER BY dd.year;


---------2. Quarterly Sales Growth

SELECT 
    dd.year AS Year,
    dd.quarter AS Quarter,
    SUM(fs.total_sales_amount) AS Total_Revenue,
    SUM(fs.quantity_sold) AS Total_Quantity_Sold

FROM FactSale fs

JOIN Date_Dim dd ON fs.order_date_key = dd.date_key
GROUP BY dd.year, dd.quarter
ORDER BY dd.year,  dd.quarter ASC;


------------3. Monthly Sales Performance

SELECT 
    dd.year AS Year,
    dd.month AS Month,
    SUM(fs.total_sales_amount) AS Total_Revenue

FROM FactSale fs

JOIN Date_Dim dd ON fs.order_date_key = dd.date_key

GROUP BY dd.year, dd.month

ORDER BY  dd.year, dd.month ASC;



-------- Peak Sales Season

SELECT TOP 5 
    CONCAT(dd.month, '/', dd.year) AS Month_Year,
    SUM(fs.total_sales_amount) AS Total_Revenue

FROM FactSale fs

JOIN Date_Dim dd ON fs.order_date_key = dd.date_key

GROUP BY dd.year, dd.month

ORDER BY Total_Revenue DESC;

/*5. Project Future Revenue Based on Historical Data
Use a moving average or linear regression in tools like Power BI or Python to forecast revenue:*/

SELECT 
    dd.year AS Year,
    dd.month AS Month,
    SUM(fs.total_sales_amount) AS Total_Revenue
FROM 
    FactSale fs
JOIN 
    Date_Dim dd ON fs.order_date_key = dd.date_key
GROUP BY 
    dd.year, 
    dd.month
ORDER BY 
    dd.year, 
    dd.month;

	







