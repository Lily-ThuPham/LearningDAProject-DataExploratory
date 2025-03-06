USE retailsales;

-- 1.1 Latest and earliest date updated in the sales table

SELECT MAX(date_) as latest_date,
		MIN(date_) as earliest_date
FROM retailsales.sales

-- 1.2 How many products and stores are there?
SELECT COUNT(DISTINCT product_id) as product,
	   COUNT(DISTINCT store_id) as store,
       (SELECT COUNT(DISTINCT city_id) FROM retailsales.stores) as city 
FROM retailsales.sales;

-- 2. Store2 and cities 
-- 2.1 Top cities with most stores nationalwide, the average store size, their store contribution
SELECT city_id, 
	   COUNT(store_id) as Store,
       AVG(store_size) as avg_storesize,
       ROUND(COUNT(store_id)/(
						SELECT COUNT(*) FROM retailsales.stores)*100,2) AS contribution 
FROM retailsales.stores 
GROUP BY city_id
ORDER BY 2 DESC
LIMIT 5;

-- 2.2 Which cities have the best revenue, their revenue contributions, their number of stores in 2019? Their revenue in 2018, 2017?
WITH s as (
	SELECT YEAR(date_) as year, sale.store_id, stores.city_id,
		   ROUND(SUM(revenue),0) as revenue_by_year
	FROM retailsales.sales sale
    JOIN retailsales.stores stores 
    ON sale.store_id = stores.store_id
    WHERE YEAR(date_) = '2019'
    GROUP BY 1,2,3)
    
SELECT city_id, 
	   SUM(s.revenue_by_year) as revenue,
       ROUND(SUM(s.revenue_by_year)/(SELECT SUM(revenue_by_year) FROM s)*100,0) as contribution,
       COUNT(store_id) as nb_of_store
FROM s 
GROUP BY 1
ORDER BY SUM(s.revenue_by_year) DESC

-- 2.2.1 Which cities have lowest revenue, their contributions and their number of stores in 2019?
WITH s as (
	SELECT YEAR(date_) as year, sale.store_id, stores.city_id,
		   ROUND(SUM(revenue),0) as revenue_by_year
	FROM retailsales.sales sale
    JOIN retailsales.stores stores 
    ON sale.store_id = stores.store_id
    WHERE YEAR(date_) = '2019'
    GROUP BY 1,2,3)
    
SELECT city_id, 
	   SUM(s.revenue_by_year) as revenue,
       ROUND(SUM(s.revenue_by_year)/(SELECT SUM(revenue_by_year) FROM s)*100,2) as contribution,
       COUNT(store_id) as nb_of_store
FROM s 
GROUP BY 1
ORDER BY SUM(s.revenue_by_year) 
LIMIT 5;

-- 2.3 Stores with highest revenue in 2019 along with their location and size
SELECT sale.store_id, store_size, city_id,
	   ROUND(SUM(revenue),2) as revenue_2019,
       ROUND(SUM(revenue)/(SELECT SUM(revenue) FROM sales WHERE YEAR(date_) = 2019)*100,2) as contribution 
FROM retailsales.sales sale
JOIN retailsales.stores s
ON s.store_id = sale.store_id 
WHERE YEAR(sale.date_) = '2019' 
GROUP BY 1,2,3
ORDER BY 4 DESC
LIMIT 5

-- 2.3.1 Stores with lowest revenue in 2019 
SELECT sale.store_id, store_size, city_id,
	   ROUND(SUM(revenue),2) as revenue_2019,
       ROUND(SUM(revenue)/(SELECT SUM(revenue) FROM sales WHERE YEAR(date_)='2019')*100,2) as contribution 
FROM retailsales.sales sale
JOIN retailsales.stores s
ON s.store_id = sale.store_id 
WHERE YEAR(sale.date_) = '2019' 
GROUP BY 1,2,3
ORDER BY 4
LIMIT 5

-- 2.4 Average, minimum and maximum store sizes, standard deviation of store sizes 
SELECT ROUND(AVG(store_size),0) as mean,
	   MAX(store_size) as max,
       MIN(store_size) as min, 
       round(STDDEV(store_size),0) as std_deviation,
       ROUND((AVG(store_size) + 1*STDDEV(store_size)),0) as higher_limit,
       ROUND((AVG(store_size) - STDDEV(store_size)),0) as lower_limit
FROM retailsales.stores 

-- 2.5 Categorize and summarize the number of stores by sizes, each categories' revenue and contributions 
WITH c as (
	SELECT store_id, 
			CASE WHEN store_size > 37 THEN "Large"
				 WHEN store_size BETWEEN 11 AND 37 THEN "Medium"
                 ELSE "Small" END AS category
	FROM retailsales.stores 	   
), 
cat as (
	SELECT sale.store_id, revenue, category
    FROM retailsales.sales sale 
    JOIN c ON c.store_id = sale.store_id 
    WHERE YEAR(date_) = 2019
)
SELECT category, 
	   COUNT(DISTINCT store_id) as nb_store, 
       ROUND(SUM(revenue),2) as revenue_2019, 
       ROUND(SUM(revenue)/(SELECT SUM(revenue) FROM cat)*100,2) as contribution
FROM cat 
GROUP BY 1

-- 2.5.1 Stores size in top performing cities 
WITH top as (
	SELECT city_id,
		   RANK() OVER (ORDER BY SUM(revenue) DESC) as ranking 
	FROM retailsales.sales sale
    JOIN retailsales.stores s 
    ON s.store_id = sale.store_id
    WHERE YEAR(date_)=2019 
    GROUP BY 1 
)

SELECT city_id, category, 
	   COUNT(DISTINCT sale.store_id) as nb_store,
       ROUND(SUM(sale.revenue),2) as revenue
FROM retailsales.sales sale 
JOIN 
	(SELECT store_id, city_id, 
		    CASE WHEN store_size > 37 THEN "Large"
				 WHEN store_size BETWEEN 11 AND 37 THEN "Medium"
                 ELSE "Small" END AS category
	 FROM retailsales.stores) as s
ON s.store_id = sale.store_id
WHERE city_id IN (SELECT city_id FROM top WHERE ranking <6) 
AND YEAR(date_) = 2019 
GROUP BY 1,2 
ORDER BY 1

-- 2.6 Top 10 best performance stores of 2019, their contributions, sizes and locations 
SELECT s.store_id, city_id, category, ROUND(SUM(revenue),0) as revenue,
       ROUND(SUM(revenue)/(SELECT SUM(revenue) FROM retailsales.sales WHERE YEAR(date_)=2019)*100,2) as contribution
FROM retailsales.sales s
JOIN 
	(SELECT store_id, city_id, 
		    CASE WHEN store_size > 37 THEN "Large"
				 WHEN store_size BETWEEN 11 AND 37 THEN "Medium"
                 ELSE "Small" END AS category
	 FROM retailsales.stores) as cat
ON cat.store_id = s.store_id 
WHERE YEAR(date_)=2019 
GROUP BY 1,2,3
ORDER BY 4 desc
LIMIT 10

-- 2.6.1 The top performance stores in 2019 and theri ranking over time 
WITH r as (
SELECT YEAR(date_) as sale_year, store_id, 
	   RANK() OVER (PARTITION BY YEAR(date_) ORDER BY SUM(revenue) DESC) as ranking 
FROM retailsales.sales
GROUP BY 1,2 
ORDER BY 1,3
),
rank_19 as (
	SELECT store_id, 
		   RANK() OVER (ORDER BY SUM(revenue) DESC) as ranking 
	FROM retailsales.sales 
    WHERE YEAR(date_) = 2019 
    GROUP BY 1
) 

SELECT rank_19.store_id, rank_19.ranking as 2019_rank, 
	   GROUP_CONCAT(CASE WHEN sale_year = 2018 THEN r.ranking ELSE NULL END) AS "2018_rank",
       GROUP_CONCAT(CASE WHEN sale_year = 2017 THEN r.ranking ELSE NULL END) AS "2017_rank"
FROM rank_19
JOIN r 
ON r.store_id = rank_19.store_id 
WHERE rank_19.ranking < 6
GROUP BY 1,2
ORDER BY 2


-- 3. Products performance analysis 
SELECT * FROM retailsales.product

-- 3.1 Product category exploration 
SELECT COUNT(DISTINCT cluster_id) as nb_cluster,
	   COUNT(DISTINCT hierarchy1_id) as nb_hierarchy1,
	   COUNT(DISTINCT hierarchy2_id) as nb_hierarchy2,
       COUNT(DISTINCT hierarchy3_id) as nb_hierarchy3,
       COUNT(DISTINCT hierarchy4_id) as nb_hierarchy4,
       COUNT(DISTINCT hierarchy5_id) as nb_hierarchy5
FROM retailsales.product

-- 3.1.1 Products revenue by category-cluster over years 
SELECT p.cluster_id as cluster_id, 
	   COUNT(DISTINCT p.product_id) as nb_product,
	   ROUND(SUM(CASE WHEN YEAR(date_) = '2019' THEN revenue ELSE 0 END),0) AS 2019_revenue,
       ROUND(SUM(CASE WHEN YEAR(date_) = '2019' THEN revenue ELSE 0 END)/(SELECT sum(revenue) FROM retailsales.sales WHERE YEAR(date_)=2019)*100,2) AS 2019_contribution,
       ROUND(SUM(CASE WHEN YEAR(date_) = '2018' THEN revenue ELSE 0 END),0) AS 2018_revenue,
       ROUND(SUM(CASE WHEN YEAR(date_) = '2017' THEN revenue ELSE 0 END),0) AS 2017_revenue
FROM retailsales.sales s 
JOIN retailsales.product p 
ON s.product_id = p.product_id 
GROUP BY 1
ORDER BY 3 DESC 

-- 3.1.2 Products revenue by category-product hierarchy 1 over the years 
SELECT p.hierarchy1_id as hierarchy1_id, 
	   COUNT(DISTINCT p.product_id) as nb_product, 
	   ROUND(SUM(CASE WHEN YEAR(date_) = '2019' THEN revenue ELSE 0 END),0) AS 2019_revenue,
       ROUND(SUM(CASE WHEN YEAR(date_) = '2019' THEN revenue ELSE 0 END)/(SELECT sum(revenue) FROM retailsales.sales WHERE YEAR(date_)=2019)*100,2) AS 2019_contribution,
       ROUND(SUM(CASE WHEN YEAR(date_) = '2018' THEN revenue ELSE 0 END),0) AS 2018_revenue,
       ROUND(SUM(CASE WHEN YEAR(date_) = '2017' THEN revenue ELSE 0 END),0) AS 2017_revenue
FROM retailsales.sales s 
JOIN retailsales.product p 
ON s.product_id = p.product_id 
GROUP BY 1
ORDER BY 3 DESC 

-- 3.2 Top best sellings products of 2019, their average price and total quantites
SELECT s.product_id, ROUND(AVG(price),2) as avg_price, p.hierarchy1_id, p.cluster_id,
	   ROUND(SUM(revenue),0) revenue_2019,
       ROUND(SUM(revenue)/303,2) as daily_revenue,
       ROUND(SUM(revenue)/(SELECT SUM(revenue) FROM retailsales.sales WHERE YEAR(date_) = '2019')*100,2) as contribution,
       SUM(sales) as quantity,
       ROUND(SUM(sales)/303,0) as daily_quantity
FROM retailsales.sales s
JOIN retailsales.product p 
ON p.product_id = s.product_id
WHERE YEAR(date_) = '2019'
GROUP BY 1
ORDER BY 5 desc
LIMIT 5

-- 3.3 Top sellers ranking over the years
SELECT product_id, 
       RANK() OVER (ORDER BY SUM(CASE WHEN YEAR(date_) = '2019' THEN revenue ELSE 0 END) DESC) as 2019_rank,
       RANK() OVER (ORDER BY SUM(CASE WHEN YEAR(date_) = '2018' THEN revenue ELSE 0 END) DESC) as 2018_rank,
       RANK() OVER (ORDER BY SUM(CASE WHEN YEAR(date_) = '2017' THEN revenue ELSE 0 END) DESC) as 2017_rank
FROM retailsales.sales 
GROUP BY 1 
ORDER BY 2 
LIMIT 10


-- 3.4 Explore the stock from the best selling store S0085 and the stocks of one specific products in the store for the lastest month of 2019 (October) 
WITH new_date as
(SELECT MAX(date_) as latest_date,
		MIN(date_) as earliest_date
FROM retailsales.sales)

SELECT store_id, product_id, sales, revenue, date_, stock
FROM retailsales.sales
WHERE store_id = 'S0085' 
AND MONTH(date_) IN (SELECT MONTH(latest_date) FROM new_date) 
AND YEAR(date_) = '2019'

SELECT store_id, product_id, sales, revenue, date_, stock
FROM retailsales.sales
WHERE store_id = 'S0085' AND product_id = "P0103" 
AND MONTH(date_) IN (SELECT MONTH(latest_date) FROM new_date) 
AND YEAR(date_) = '2019'

-- 3.5 What are the daily average stock for top selling products in 2019 
SELECT product_id,
	   ROUND(SUM(revenue),2) as revenue_2019,
	   SUM(sales) as total_qty_2019,
       ROUND(SUM(sales)/304,0) as avg_daily_sales,
       ROUND(SUM(stock)/304,0) as avg_daily_stock,
       ROUND(SUM(stock)/SUM(sales),0) as DOH
FROM retailsales.sales 
WHERE YEAR(date_) = '2019'
GROUP BY 1
ORDER BY 2 DESC 
LIMIT 10 

-- 3.5.1 average daily stock and days on hands of best selling products from the top stores 
SELECT store_id,product_id,
	   SUM(sales) as total_qty_2019,
       ROUND(AVG(sales),0) as avg_daily_sales,
       ROUND(AVG(stock),0) as avg_daily_stock,
       ROUND(SUM(stock)/SUM(sales),0) as DOH
FROM retailsales.sales 
WHERE YEAR(date_) = '2019' AND product_id = "P0103"
GROUP BY 1,2
ORDER BY 3 DESC 
LIMIT 10 
	   
-- 3.6. Products with lowest days on hands stocks nationwide 
SELECT product_id, 
	   SUM(sales) as total_qty_2019,
       ROUND(avg(sales),0) as avg_dailysale,
       ROUND(avg(stock),0) as avg_daily_stock,
       ROUND(SUM(stock)/SUM(sales),0) as DOH
FROM retailsales.sales 
WHERE YEAR(date_) = '2019'
GROUP BY 1 ORDER BY 5
LIMIT 10

-- 3.7.	Products with highest days on hands stocks nationwide 
SELECT product_id, 
	   SUM(sales) as total_qty_2019,
       ROUND(avg(sales),0) as avg_dailysale,
       ROUND(AVG(stock),0) as avg_daily_stock,
       ROUND(SUM(stock)/SUM(sales),0) as DOH
FROM retailsales.sales 
WHERE YEAR(date_) = '2019'
GROUP BY 1 ORDER BY 5 DESC
LIMIT 10

-- 3.8. Average daily stock, days on hands of according product categories (cluster and hierarchy)
SELECT p.cluster_id, p.hierarchy1_id, 
	   SUM(sales) as total_qty_2019, 
	   ROUND(AVG(sales),0) as avg_dailysales,
       ROUND(AVG(stock),0) as avg_dailystock,
       ROUND(SUM(stock)/SUM(sales),0) as DOH
FROM retailsales.sales s 
JOIN retailsales.product p 
ON p.product_id = s.product_id 
WHERE YEAR(date_) = 2019
GROUP BY 1,2 
ORDER BY 3 DESC

-- 3.9 Daily stock of total product from each store 
SELECT store_id,
	   SUM(sales) as total_qty, 
       RANK() OVER (ORDER BY sum(sales) DESC) as ranking, 
       ROUND(SUM(sales)/(SELECT COUNT(DISTINCT IF(YEAR(date_)=2019,date_,NULL)) FROM retailsales.sales),0) as avg_dailyqty, 
       ROUND(SUM(stock)/(SELECT COUNT(DISTINCT IF(YEAR(date_)=2019,date_,NULL)) FROM retailsales.sales),0) as avg_dailystock,
	   ROUND(SUM(stock)/SUM(sales),0) as DOH
FROM retailsales.sales 
WHERE YEAR(date_)=2019
GROUP BY 1
ORDER BY ranking 
LIMIT 10
	
-- 3.9.1 Stores with lowest daily stock for all products 
SELECT store_id,
	   RANK() OVER (ORDER BY sum(sales) DESC) as ranking, 
	   SUM(sales) as total_qty, 
       ROUND(SUM(sales)/(SELECT COUNT(DISTINCT IF(YEAR(date_)=2019,date_,NULL)) FROM retailsales.sales),0) as avg_dailyqty, 
       ROUND(SUM(stock)/(SELECT COUNT(DISTINCT IF(YEAR(date_)=2019,date_,NULL)) FROM retailsales.sales),0) as avg_dailystock,
	   ROUND(SUM(stock)/SUM(sales),0) as DOH
FROM retailsales.sales 
WHERE YEAR(date_)=2019
GROUP BY 1
ORDER BY 6
LIMIT 10

-- 3.9.2 Stores with highest daily stock for all products 
SELECT store_id,
	   RANK() OVER (ORDER BY sum(sales) DESC) as ranking, 
	   SUM(sales) as total_qty, 
       ROUND(SUM(sales)/(SELECT COUNT(DISTINCT IF(YEAR(date_)=2019,date_,NULL)) FROM retailsales.sales),0) as avg_dailyqty, 
       ROUND(SUM(stock)/(SELECT COUNT(DISTINCT IF(YEAR(date_)=2019,date_,NULL)) FROM retailsales.sales),0) as avg_dailystock,
	   ROUND(SUM(stock)/SUM(sales),0) as DOH
FROM retailsales.sales 
WHERE YEAR(date_)=2019
GROUP BY 1
ORDER BY 6 DESC 
LIMIT 10

-- 3.10.1 Stock turn of best sellers in 2019 
WITH be as (	
    SELECT product_id, SUM(stock) as begin_stock
	FROM retailsales.sales 
	WHERE date_ IN (SELECT min(date_) FROM retailsales.sales WHERE YEAR(date_) = 2019) 
    GROUP BY 1
),
en as (
	SELECT product_id, SUM(stock) as end_stock, date_
    FROM retailsales.sales 
    WHERE date_ IN (SELECT max(date_) FROM retailsales.sales WHERE YEAR(daTE_)=2019) 
	GROUP BY 1,3
)

SELECT s.product_id, 
	   RANK() OVER (ORDER BY SUM(revenue) DESC) AS ranking, 
	   ROUND(SUM(revenue),2) as revenue_2019,
       SUM(sales) as qty_2019, begin_stock, end_stock,
       ROUND((begin_stock+ end_stock)/2,0) as avg_stock, 
       ROUND(SUM(sales)/((begin_stock+end_stock)/2),0) as stock_turn 
FROM retailsales.sales s
JOIN be ON be.product_id = s.product_id
JOIN en ON en.product_id = s.product_id 
WHERE YEAR(s.date_) = 2019 
GROUP BY 1, begin_stock, end_stock
ORDER BY ranking 
LIMIT 10 

-- 3.10.2 Product with Highest stock turn     
WITH be as (	
    SELECT product_id, SUM(stock) as begin_stock
	FROM retailsales.sales 
	WHERE date_ IN (SELECT min(date_) FROM retailsales.sales WHERE YEAR(date_) = 2019) 
    GROUP BY 1
),
en as (
	SELECT product_id, SUM(stock) as end_stock, date_
    FROM retailsales.sales 
    WHERE date_ IN (SELECT max(date_) FROM retailsales.sales WHERE YEAR(daTE_)=2019) 
	GROUP BY 1,3
)

SELECT s.product_id, 
	   RANK() OVER (ORDER BY SUM(revenue) DESC) AS ranking, 
	   ROUND(SUM(revenue),2) as revenue_2019,
       SUM(sales) as qty_2019, begin_stock, end_stock,
       ROUND((begin_stock+ end_stock)/2,0) as avg_stock, 
       ROUND(SUM(sales)/((begin_stock+end_stock)/2),0) as stock_turn 
FROM retailsales.sales s
JOIN be ON be.product_id = s.product_id
JOIN en ON en.product_id = s.product_id 
WHERE YEAR(s.date_) = 2019 
GROUP BY 1, begin_stock, end_stock
ORDER BY 8 DESC
LIMIT 10

-- 3.10.3 Product with lowest stock turn
WITH be as (	
    SELECT product_id, SUM(stock) as begin_stock
	FROM retailsales.sales 
	WHERE date_ IN (SELECT min(date_) FROM retailsales.sales WHERE YEAR(date_) = 2019) 
    GROUP BY 1
),
en as (
	SELECT product_id, SUM(stock) as end_stock, date_
    FROM retailsales.sales 
    WHERE date_ IN (SELECT max(date_) FROM retailsales.sales WHERE YEAR(daTE_)=2019) 
	GROUP BY 1,3
)

SELECT s.product_id, 
	   RANK() OVER (ORDER BY SUM(revenue) DESC) AS ranking, 
	   ROUND(SUM(revenue),2) as revenue_2019,
       SUM(sales) as qty_2019, begin_stock, end_stock,
       ROUND((begin_stock+ end_stock)/2,0) as avg_stock, 
       ROUND(SUM(sales)/((begin_stock+end_stock)/2),0) as stock_turn 
FROM retailsales.sales s
JOIN be ON be.product_id = s.product_id
JOIN en ON en.product_id = s.product_id 
WHERE YEAR(s.date_) = 2019 
GROUP BY 1, begin_stock, end_stock
ORDER BY 8 
LIMIT 10
        
-- 3.12.2 Sell through ratio of regular products chain-wide
SELECT product_id, unit_sold, unit_receive, sale_month,
	   ROUND(unit_sold/(unit_sold+unit_receive)*100,2) as sell_through 
FROM 
	(SELECT s.product_id AS product_id, MONTH(date_) as sale_month, 
		   SUM(s.sales) as unit_sold,
           SUM(stock) as endof_month_stock,
            LAG(SUM(stock)) OVER (PARTITION BY s.product_id ORDER BY MONTH(date_) ASC) as unit_receive
    FROM retailsales.sales s 
    JOIN retailsales.regular2019 r
    ON s.product_id = r.product_id 
    WHERE YEAR(date_) = '2019' 
    GROUP BY 1,2) as monthly 



-- Average sale from each stores and each city over the years 

SELECT YEAR(date_) as year,
	   ROUND(SUM(revenue)/(SELECT COUNT(DISTINCT store_id) FROM retailsales.stores),0) as avg_store_sale,
       ROUND(SUM(revenue)/(SELECT COUNT(DISTINCT city_id) FROM retailsales.stores),0) as avg_city_sale
FROM retailsales.sales sale
GROUP BY 1
       
-- Best selling product from each year

WITH cte1 as
(
SELECT YEAR(date_) as year, 
       product_id, ROUND(SUM(revenue),0) as revenue_by_year
FROM retailsales.sales
GROUP BY 1, 2
),
cte2 as
(
SELECT year,
	   MAX(revenue_by_year) as bestsale
FROM cte1 
GROUP BY 1
)

SELECT * FROM cte1
WHERE (year,revenue_by_year) IN (SELECT * FROM cte2);

-- Best store performance of each year and their city

WITH cte as
( 
SELECT year(date_) as year,
	   store_id,
       ROUND(SUM(revenue),0) as revenue_by_year 
FROM retailsales.sales
GROUP BY 1,2) 
,
temp3 as 
(SELECT * FROM cte
WHERE (year,revenue_by_year) IN (
	SELECT year, MAX(revenue_by_year) as revenue_by_year
    FROM cte GROUP BY 1)
)

SELECT temp3.*, 
	   s.city_id
FROM temp3 
JOIN retailsales.stores s 
ON temp3.store_id = s.store_id 

-- Which city has highest sale over the year? 
WITH temp as (
SELECT year(date_) as year,
	   city_id as city,
       Round(SUM(revenue),0) as revenue_by_year 
FROM retailsales.sales s
JOIN retailsales.stores c
ON s.store_id = c.store_id 
GROUP BY 1,2
),
s as (
SELECT YEAR(date_)as year, SUM(revenue) as sum_of_year
FROM retailsales.sales 
GROUP BY 1
),
temp2 as (
SELECT *
FROM temp
WHERE (year, revenue_by_year) IN (
									SELECT year, MAX(revenue_by_year)
                                    FROM temp GROUP BY 1)
)

SELECT temp2.*,
	   ROUND(revenue_by_year/sum_of_year*100,2) as contribution
FROM temp2
JOIN s ON s.year = temp2.year 

-- 4.1 Sales by year in the period of 2017 - 2018:
SELECT YEAR(date_) as sale_year,
	   ROUND(SUM(revenue),2) as total_revenue,
       CASE WHEN LAG(SUM(revenue)) OVER (ORDER BY YEAR(date_)) IS NULL 
			THEN "NA" ELSE 
            ROUND((1- SUM(revenue)/(SUM(revenue) OVER (ORDER BY YEAR(date_))))*100,2) 
	   END AS growth 
FROM retailsales.sales 
WHERE YEAR(date_) < 2019
GROUP BY 1

-- 4.2.	Sales changes by month and quarter in the period of 2017-2019 
SELECT YEAR(date_) as sale_year, 
	   MONTH(date_) as sale_month, 
       ROUND(SUM(revenue),2) as total_revenue
FROM retailsales.sales 
GROUP BY 1,2 
ORDER BY 1,2

SELECT YEAR(date_) as sale_year,
	   CONCAT("Q",QUARTER(date_)) as sale_quarter,
       ROUND(SUM(revenue),2) as total_revenue
FROM retailsales.sales 
GROUP BY 1,2 
ORDER BY 1,2

-- 4.2.1 Identified the top 5 months when sales are highest.
SELECT *,
	  CASE 
		  WHEN sale_month IN (1,2,3) THEN "Q1" 
          WHEN sale_month IN (4,5,6) THEN "Q2"
          WHEN sale_month IN (7,8,9) THEN "Q3"
          ELSE "Q4"
	  END AS sale_quarter
FROM (
SELECT year(date_) as sale_year,
	   month(date_) as sale_month, 
       ROUND(SUM(revenue),2) as total_revenue,
       RANK() OVER (PARTITION BY YEAR(date_) ORDER BY sum(revenue) DESC) as ranking 
FROM retailsales.sales 
GROUP BY 1,2) AS ranking 
WHERE ranking < 6

-- 4.3.	2019 performance and same period last years  
SELECT 2019_revenue, PY_2018,
	   ROUND(-(1-  2019_revenue/PY_2018)*100,2) as Growth_vs_2018,
       PY_2017,
       ROUND(-(1- 2019_revenue/PY_2017)*100,2) as Growth_vs_2017
FROM (
SELECT
	   round(SUM(IF (YEAR(date_) = '2019',revenue,0)),2) as 2019_revenue,
	   ROUND(SUM(IF (YEAR(date_) = '2018',revenue,0)),2) as PY_2018,
       ROUND(SUM(IF (YEAR(date_) = '2017',revenue,0)),2) as PY_2017
FROM retailsales.sales ) as PY

-- 4.4. How does sale change over years in term of products? 
SELECT product_id,
	   ROUND(SUM(CASE WHEN YEAR(date_)=2019 THEN revenue ELSE 0 END),0) AS 2019_revenue, 
       ROUND(SUM(CASE WHEN YEAR(date_)=2018 THEN revenue ELSE 0 END),0) AS 2018_revenue, 
       ROUND(SUM(CASE WHEN YEAR(date_)=2017 THEN revenue ELSE 0 END),0) AS 2017_revenue
FROM retailsales.sales 
WHERE 
	DAY(date_) BETWEEN 1 AND (SELECT DAY(MAX(date_)) FROM retailsales.sales) 
    AND MONTH(date_) BETWEEN 1 AND (SELECT MONTH(MAX(date_)) FROM retailsales.sales)
GROUP BY 1 
ORDER BY 2 DESC 
LIMIT 10 
-- with growth
WITH top as (
	SELECT product_id, 
    RANK() OVER (ORDER BY SUM(revenue) DESC) AS ranking 
	FROM retailsales.sales 
	WHERE YEAR(date_) = 2019 
    GROUP BY 1
)

SELECT YEAR(date_) as sale_year, 
	   product_id,
       ROUND(SUM(revenue),2) as revenue,
       SUM(sales) as qty,
       COALESCE(ROUND((SUM(revenue)-(LAG(SUM(revenue)) OVER (PARTITION BY product_id ORDER BY YEAR(date_))))/(LAG(SUM(revenue)) OVER (PARTITION BY product_id ORDER BY YEAR(date_)))*100,2),"0") as revenue_growth,
       COALESCE(ROUND((SUM(sales)-(LAG(SUM(sales)) OVER (PARTITION BY product_id ORDER BY YEAR(date_))))/(LAG(SUM(sales)) OVER (PARTITION BY product_id ORDER BY YEAR(date_)))*100,2),"0") as revenue_growth
FROM retailsales.sales 
WHERE 
	DAY(date_) BETWEEN 1 AND (SELECT DAY(MAX(date_)) FROM retailsales.sales) 
    AND MONTH(date_) BETWEEN 1 AND (SELECT MONTH(MAX(date_)) FROM retailsales.sales)
    AND product_id IN 
					( SELECT product_id FROM top WHERE ranking < 8)
GROUP BY 1,2
ORDER BY 2,1

-- 4.4.1 Does the best seller change over the year? 
WITH r as (
SELECT product_id,
	   year(date_) as sale_year,
       SUM(revenue) as total_sale,
       RANK() OVER (PARTITION BY YEAR(date_) ORDER BY SUM(revenue) DESC) ranking 
FROM retailsales.sales 
WHERE DAY(date_) BETWEEN 1 AND (SELECT DAY(MAX(date_)) FROM retailsales.sales) 
    AND MONTH(date_) BETWEEN 1 AND (SELECT MONTH(MAX(date_)) FROM retailsales.sales)
GROUP BY 1,2
ORDER BY 2,4)

SELECT ranking, 
	   GROUP_CONCAT(CASE WHEN sale_year = '2019' THEN product_id ELSE NULL END) AS 2019_top5,
       GROUP_CONCAT(CASE WHEN sale_year = '2018' THEN product_id ELSE NULL END) AS 2018_top5,
       GROUP_CONCAT(CASE WHEN sale_year = '2017' THEN product_id ELSE NULL END) AS 2017_top5
FROM r 
WHERE ranking < 6
GROUP BY ranking
ORDER BY ranking

-- 4.4.2.	Does the price of the top 5 best sellers 2019 change over the year? 
WITH r as (
SELECT product_id,
       RANK() OVER (ORDER BY SUM(revenue) DESC) ranking 
FROM retailsales.sales 
WHERE YEAR(date_) = 2019
GROUP BY 1
ORDER BY 2),
tab as (
SELECT 
	   product_id as 2019_top5, 
       YEAR(date_) as sale_year, 
       ROUND(SUM(revenue),2) as total_revenue, 
       ROUND(AVG(price),2) as avg_price
FROM retailsales.sales s
WHERE product_id IN (SELECT product_id FROM r WHERE ranking < 11) 
      AND DAY(date_) BETWEEN 1 AND (SELECT DAY(MAX(date_)) FROM retailsales.sales) 
	  AND MONTH(date_) BETWEEN 1 AND (SELECT MONTH(MAX(date_)) FROM retailsales.sales)
GROUP BY product_id, YEAR(date_))
       
SELECT 2019_top5, 
	   ranking,
	  GROUP_CONCAT(CASE WHEN sale_year = '2019' THEN avg_price ELSE NULL END) AS 2019_avg_price,
	  GROUP_CONCAT(CASE WHEN sale_year = '2018' THEN avg_price  ELSE NULL END) AS 2018_avg_price,
	  GROUP_CONCAT(CASE WHEN sale_year = '2017' THEN avg_price  ELSE NULL END) AS 2017_avg_price
FROM tab 
JOIN r 
ON tab.2019_top5 = r.product_id 
GROUP BY ranking, 2019_top5

-- 4.4.3 How does sale changes from year to year in term of product category? 
WITH cte as (
SELECT YEAR(date_) as sale_year, hierarchy1_id,
	   ROUND(SUM(revenue),0) as total_revenue,
       SUM(sales) as total_qty
FROM retailsales.sales s 
JOIN retailsales.product p 
ON p.product_id = s.product_id 
WHERE DAY(date_) BETWEEN 1 AND (SELECT DAY(MAX(date_)) FROM retailsales.sales) AND
	  MONTH(date_) BETWEEN 1 AND (SELECT MONTH(MAX(date_)) FROM retailsales.sales)
GROUP BY 1,2
ORDER BY 2,1
)

SELECT *,
	   COALESCE(ROUND((total_revenue - (LAG(total_revenue) OVER (PARTITION BY hierarchy1_id ORDER BY sale_year)))/(LAG(total_revenue) OVER (PARTITION BY hierarchy1_id ORDER BY sale_year))*100,2),"0") as revenue_growth,
	   COALESCE(ROUND((total_qty - (LAG(total_qty) OVER (PARTITION BY hierarchy1_id ORDER BY sale_year)))/(LAG(total_qty) OVER (PARTITION BY hierarchy1_id ORDER BY sale_year))*100,2),"0") as qty_growth
FROM cte 
   
	   

	   
-- 4.5.	Does the best performer change over the year? 
WITH r as (
	SELECT store_id,
	YEAR(date_) as sale_year,
	SUM(revenue) as total_sale,
	RANK() OVER (PARTITION BY YEAR(date_) ORDER BY SUM(revenue) DESC) ranking 
FROM retailsales.sales 
WHERE DAY(date_) BETWEEN 1 AND (SELECT DAY(MAX(date_)) FROM retailsales.sales) AND
	  MONTH(date_) BETWEEN 1 AND (SELECT MONTH(MAX(date_)) FROM retailsales.sales)
GROUP BY 1,2
ORDER BY 2,4)

SELECT ranking, 
	   GROUP_CONCAT(CASE WHEN sale_year = '2019' THEN store_id ELSE NULL END) AS 2019_store,
       GROUP_CONCAT(CASE WHEN sale_year = '2018' THEN store_id ELSE NULL END) AS 2018_store,
       GROUP_CONCAT(CASE WHEN sale_year = '2017' THEN store_id ELSE NULL END) AS 2017_store
FROM r 
WHERE ranking < 11
GROUP BY ranking
ORDER BY ranking



-- 5.1 Promotions types

SELECT DISTINCT promo_type_1 as promotion_1, 
				promo_type_2 as promotion_2
FROM retailsales.sales 
	   
-- 5.1.1 Promotion type 1 
SELECT DISTINCT promo_type_1 as promotion_1
FROM retailsales.sales 

-- 5.1.2 Promotion type 2 and their discount types 
SELECT DISTINCT promo_type_2 as promotion_2,
				promo_discount_2 
FROM retailsales.sales 
ORDER BY 1 

-- 5.2. Exploring how promotions are applied 
-- 5.2.1 How many types of promotions combinations are applied from one store in one days?
SELECT store_id, 
	   product_id,
       date_ as sale_date, 
       promo_type_1, promo_type_2, promo_discount_2
FROM retailsales.sales 
WHERE store_id = 'S0085' and date_ = '2019-10-31'

-- 5.2.2 What kind of promotions are applied to one product from one store for consecutive days in a month? (For example best seller product ID "P0103" for store "S0085" for the month of 09.2019)
SELECT 
	  product_id, store_id, date_,
      promo_type_1, promo_type_2, promo_discount_2
FROM retailsales.sales 
WHERE product_id = "P0103" AND
	  store_id = "S0085" AND
      date_ BETWEEN "2019-09-01" AND "2019-09-30"
ORDER BY 3 

SELECT 
	  product_id, store_id, date_,
      promo_type_1, promo_type_2, promo_discount_2
FROM retailsales.sales 
WHERE product_id = "P0182" AND
	  store_id = "S0085" AND
      date_ BETWEEN "2019-09-01" AND "2019-09-30"
ORDER BY 3 

-- 5.2.3 How many promotion combinations applied and to each product from one store in 2019 and for how many days? For example choose store "S0085"
WITH cte as (
	SELECT store_id, product_id, date_,
		   promo_type_1, promo_type_2, promo_discount_2, 
           CONCAT(promo_type_1,"-", promo_type_2,"-", promo_discount_2) as combinations
	FROM retailsales.sales 
	WHERE YEAR(date_) = 2019 and
	       store_id = "S0062" 
    ORDER BY product_id, date_
),
consecutive as (
		SELECT product_id, combinations, 
               date_,
               ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY date_)- ROW_NUMBER() OVER (PARTITION BY combinations,product_id order by date_) as grp 
		FROM cte
        ORDER BY product_id, date_      
),
con_grp as (
	SELECT product_id, combinations, 
		   count(*) as duration 
	FROM consecutive 
    GROUP BY 1,2,grp
    ORDER BY 1,2
)
SELECT product_id, combinations, 
	   ROUND(AVG(duration),0) as avg_duration
FROM con_grp 
GROUP BY 1,2 
ORDER BY 1,2 AND 3 DESC

-- 5.3 Which is the most common prmotion combinations in 2019 
SELECT promo_type_1, promo_type_2, promo_discount_2,
       COUNT(*) as occurrence
FROM retailsales.sales 
WHERE YEAR(date_) = 2019 
GROUP BY 1,2,3
ORDER BY 4 DESC 

-- 5.4.	Which is the longest promotion combinations across all products and stores in 2019?
WITH cte as (
	SELECT combinations, date_,
		   ROUND(ROW_NUMBER() OVER (ORDER BY date_) - ROW_NUMBER() OVER (PARTITION BY combinations ORDER BY date_),0) as grp 
    FROM (
		  SELECT date_, 
			     CONCAT(promo_type_1,"-", promo_type_2,"-", promo_discount_2) as combinations
		  FROM retailsales.sales 
          WHERE YEAR(date_) = '2019'
          ) as concat 
	ORDER BY 1,2
)
SELECT combinations, COUNT(*) as duration
FROM cte 
GROUP BY 1,grp
ORDER BY 2 DESC 
    
-- 5.5.	Investigate the impact of promotions on pricing and revenues, choosing the top 5 selling items 
-- 5.5.1 
WITH top as (
 	SELECT ranking, product_id 
    FROM (
		  SELECT product_id,
			     RANK() OVER (ORDER BY SUM(revenue) DESC) as ranking 
		  FROM retailsales.sales s
          WHERE YEAR(date_) = 2019 
          GROUP BY 1 
          ) as r
	WHERE ranking <= 5    
) 

		  SELECT product_id, month(date_) as month_sale, 
				 ROUND(AVG(price),2) as avg_price,
				 ROUND(SUM(revenue),2) as total_revenue,  
                 ROUND(AVG(revenue),2) as avg_revenue,
			     CONCAT(promo_type_1,"-", promo_type_2,"-", promo_discount_2) as combinations
		  FROM retailsales.sales 
          WHERE YEAR(date_) = '2019'AND
          product_id IN (SELECT product_id FROM top)
          GROUP BY 1,2,6
          ORDER BY 1,2,6


    
),
duration as (
	SELECT combinations, COUNT(*) as duration
	FROM grp 
	GROUP BY 1,grp
	ORDER BY 2 DESC 
)            
       
       
	   






