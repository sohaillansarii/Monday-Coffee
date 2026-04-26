--MONDAY COFFEE-- 
-- DATA ANALYSIS--

SELECT * from city;
SELECT * from customers;
SELECT * from products;
SELECT * from sales;

-- Q.1 Coffee Consumers Count
-- How many people in each city are estimated to consume coffee, given that 25% of the population does?
select 
 city_name,
 (population * 0.25)/1000000 as coffee_consumer_in_millions,
 city_rank
from city
order by 2 desc;


-- -- Q.2 Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all cities in the last quarter of 2023?
SELECT 
       cy.city_name,
      SUM(s.total) as revenue
from sales as s
join customers as c
on s.customer_id = c.customer_id
join city as cy
on cy.city_id = c.city_id

where 
   EXTRACT (YEAR FROM s.sale_date) = 2023
   AND
   EXTRACT (QUARTER FROM s.sale_date) = 4
group by 1
order by 2 desc;

-- Q.3 Sales Count for Each Product
-- How many units of each coffee product have been sold?

SELECT 
	p.product_name,
	COUNT(s.sale_id) as total_orders
FROM products as p
LEFT JOIN
sales as s
ON s.product_id = p.product_id
GROUP BY 1
ORDER BY 2 DESC;

-- Q.4 Average Sales Amount per City
-- What is the average sales amount per customer in each city?

SELECT 
	cy.city_name,
	SUM(s.total) as total_revenue,
	COUNT(DISTINCT s.customer_id) as total_cstmr,
	ROUND(SUM(s.total)/
				COUNT(DISTINCT s.customer_id)) as avg_sale_per_cstmr
	
FROM sales as s
JOIN customers as c
ON s.customer_id = c.customer_id
JOIN city as cy
ON cy.city_id = c.city_id
GROUP BY 1
ORDER BY 2 DESC;

-- -- Q.5 City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their populations and estimated coffee consumers.
-- return city_name, total current cx, estimated coffee consumers (25%)

WITH city_table as 
(
	SELECT 
		city_name,
		ROUND((population * 0.25)/1000000, 2) as coffee_consumers
	FROM city
),
customers_table
AS
(
	SELECT 
		cy.city_name,
		COUNT(DISTINCT c.customer_id) as unique_cx
	FROM sales as s
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as cy
	ON cy.city_id = c.city_id
	GROUP BY 1
)
SELECT 
	customers_table.city_name,
	city_table.coffee_consumers as coffee_consumer_in_millions,
	customers_table.unique_cx
FROM city_table
JOIN 
customers_table
ON city_table.city_name = customers_table.city_name;

-- -- Q6 Top Selling Products by City
-- What are the top 3 selling products in each city based on sales volume?

SELECT * 
FROM -- table
(
	SELECT 
		cy.city_name,
		p.product_name,
		COUNT(s.sale_id) as total_orders,
		DENSE_RANK() OVER(PARTITION BY cy.city_name ORDER BY COUNT(s.sale_id) DESC) as rank
	FROM sales as s
	JOIN products as p
	ON s.product_id = p.product_id
	JOIN customers as c
	ON c.customer_id = s.customer_id
	JOIN city as cy
	ON cy.city_id = c.city_id
	GROUP BY  1,2
	ORDER BY 2,3 DESC
) as t1
WHERE rank <= 3;

-- Q7  AVG Rating of Products in each city
-- How do different products perform across cities in terms of customer ratings, revenue generated, and sales volume, 
-- and which products rank highest within each city across these dimensions?


SELECT 
    cy.city_name,
    p.product_name,
    ROUND(AVG(s.rating)::numeric, 2) AS avg_rating,
    SUM(s.total) AS total_revenue,
    COUNT(s.sale_id) AS total_orders,

    DENSE_RANK() OVER(
        PARTITION BY cy.city_name 
        ORDER BY AVG(s.rating) DESC
    ) AS rating_rank,

    DENSE_RANK() OVER(
        ORDER BY SUM(s.total) DESC
    ) AS revenue_rank,

    DENSE_RANK() OVER(
        ORDER BY COUNT(s.sale_id) DESC
    ) AS volume_rank

FROM sales AS s
JOIN products AS p
    ON s.product_id = p.product_id
JOIN customers AS c
    ON c.customer_id = s.customer_id
JOIN city AS cy
    ON cy.city_id = c.city_id

GROUP BY cy.city_name, p.product_name
ORDER BY cy.city_name, avg_rating DESC
 ;


-- -- Q.8 Revenue Efficiency by Price Tier
-- Which price tier (₹0-500, ₹500-1000, ₹1000+) delivers the highest revenue per rating point — 
-- balancing customer satisfaction with profitability?


WITH price_tiers AS (
    SELECT 
        s.product_id,
        s.sale_id,
        s.total,
        s.rating,
        CASE 
            WHEN p.price <= 500 THEN '0-500'
            WHEN p.price <= 1000 THEN '500-1000'
            ELSE '1000+'
        END AS price_tier
    FROM sales s
    JOIN products p 
        ON s.product_id = p.product_id
)
SELECT 
    price_tier,
    COUNT(*) AS total_orders,
    SUM(total) AS total_revenue,
    ROUND(AVG(rating)::numeric, 2) AS avg_rating,

    ROUND(
        (SUM(total) / NULLIF(SUM(rating), 0))::numeric,
        2
    ) AS revenue_per_rating_pt,

    DENSE_RANK() OVER (
        ORDER BY (SUM(total) / NULLIF(SUM(rating), 0)) DESC
    ) AS efficiency_rank

FROM price_tiers
GROUP BY price_tier
ORDER BY efficiency_rank;

-- Q.9 Customer Segmentation by City
-- How many unique customers are there in each city who have purchased coffee products?

SELECT 
	cy.city_name,
	COUNT(DISTINCT c.customer_id) as unique_cx
FROM city as cy
JOIN customers as c
ON cy.city_id = c.city_id
JOIN sales as s
ON s.customer_id = c.customer_id
WHERE s.product_id BETWEEN 1 AND 14
GROUP BY 1;

-- -- Q.10 Average Sale vs Rent
-- Find each city and their average sale per customer and avg rent per customer


SELECT 
		cy.city_name,
		SUM(s.total) as total_revenue,
		COUNT(DISTINCT s.customer_id) as total_cx,
		ROUND(
				SUM(s.total)/
					COUNT(DISTINCT s.customer_id)) as avg_sale_pr_cx,
           cy.estimated_rent,
		   ROUND(
		cy.estimated_rent/COUNT(DISTINCT s.customer_id)
		) as avg_rent_per_cstmr
		
	FROM sales as s
	JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as cy
	ON cy.city_id = c.city_id
	GROUP BY 1,5
	ORDER BY 2 DESC;

-- Q.11 Monthly Sales Growth
-- Sales growth rate: Calculate the percentage growth (or decline) in sales over different time periods (monthly)
-- by each city

WITH
monthly_sales
as
(
SELECT 
        cy.city_name,
		extract(month from sale_date) as month, 
		extract(year  from sale_date) as year,
		sum(s.total) as total_revenue
    FROM sales as s
	JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as cy
	ON cy.city_id = c.city_id
GROUP BY 1,2,3
ORDER BY 1,3,2
) ,
Growth_Ratio
as
(
		SELECT
			  city_name,
			month,
			year,
			total_revenue as cr_month_sale,
			LAG(total_revenue, 1) OVER(PARTITION BY city_name ORDER BY year, month) 
			as last_month_sale
		FROM monthly_sales
)
 SELECT
        city_name,
			month,
			year,
			cr_month_sale,
			last_month_sale,
  ROUND(
  ((cr_month_sale - last_month_sale) / last_month_sale) * 100)::text || '%'
	
		AS growth_ratio_in_prcnt  
FROM Growth_Ratio

WHERE 
	last_month_sale IS NOT NULL	;

-- Q.12 Market Potential Analysis
-- Identify top 3 city based on highest sales, return city name, total sale, total rent, total customers, estimated coffee consumer

SELECT 
		cy.city_name,
		(population * 0.25)/1000000 as estimatd_coffee_consumers_in_mil,
		SUM(s.total) as total_revenue,
		COUNT(DISTINCT s.customer_id) as total_cx,
		ROUND(
				SUM(s.total)/
					COUNT(DISTINCT s.customer_id)) as avg_sale_pr_cx,
           cy.estimated_rent,
		   ROUND(
		cy.estimated_rent/COUNT(DISTINCT s.customer_id)
		) as avg_rent_per_cstmr
		
	FROM sales as s
	JOIN customers as c
	ON s.customer_id = c.customer_id
	JOIN city as cy
	ON cy.city_id = c.city_id
	GROUP BY 1,2,6
	ORDER BY 3 DESC
	LIMIT 3;
