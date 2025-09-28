-- SQL ANALYSIS


-- 1 . number of stores in each country

select country , count(store_id) as stores_count 
     from stores
	 group by country
	 order by count(store_id) desc;

-- 2. total number of units sold by each store

select sales.store_id ,stores.store_name , stores.city, stores.country, sum(sales.quantity) 
     from sales
	 left join stores on sales.store_id = stores.store_id 
	 group by  sales.store_id , stores.store_name ,stores.city, stores.country;


-- 3. how many sales occurred in December 2023

select count(sale_id) as total_sales_in_Dec from sales
where extract( month from sale_date) = 12 and extract( year from sale_date)=2023;



-- 4. Determine how many stores have never had a warranty claim filed.


SELECT *
FROM stores st
WHERE st.store_id NOT IN (
    SELECT DISTINCT s.store_id
    FROM warranty w
    JOIN sales s ON w.sale_id = s.sale_id
);


-- Calculate the percentage of warranty claims marked as ""Rejected""

select  distinct repair_status from warranty;

select round(count( distinct claim_id) / (select count(*) from warranty)::numeric * 100 , 2)
      from  warranty where repair_status='Rejected';

	  
-- Identify which store had the highest total units sold in the last year.
select ( extract(year from sale_date)) as year from sales; 

-- select ( extract(year from sale_date)) as year, store_id,  sum(quantity) 
-- from sales group by store_id , extract(year from sale_date)  order by extract(year from sale_date) desc;

select store_id,  sum(quantity)  from  sales 
where sale_date >= current_date - interval '1 year'
group by store_id order by  sum(quantity) limit 1;

-- Count the number of unique products sold in the last year
select count (distinct( product_id) )
 from sales where sale_date >= current_date - interval '1 year';

-- Find the average price of products in each category.
select  products.category_id, category.category_name ,avg(price)
           from products join category on category.category_id = products.category_id
		   group by products.category_id , category.category_name; 


		   
-- How many warranty claims were filed in 2024?
select count(*) from warranty where extract(year from claim_date)=2024;


-- For each store,  the best-selling day based on highest quantity sold.

select * from

 (select store_id , to_char( sale_date , 'Day'),sum(quantity),
 rank() over(partition by store_id order by  sum(quantity) desc ) as rank
 from sales 
 group by 1 , 2 ) as t where rank=1;
 -- order by store_id,sum(quantity) desc;



--  the least selling product in each country for each year based on total units sold

select * from (select st.country , s.product_id , p.product_name, sum(s.quantity) as total_quan_sold, 
rank() over( partition by country order by  sum(s.quantity) ) as rank
from sales s
join stores st 
on st.store_id = s.store_id
join products p
on s.product_id = p.product_id
group by  st.country , s.product_id ,  p.product_name)  as t
where rank=1;
-- order by st.country, sum(s.quantity)  asc;


--  how many warranty claims were filed within 180 days of a product sale
select count(w.claim_id)
from warranty w left join sales s on s.sale_id = w.sale_id
where s.sale_date - w.claim_date <= 180;

--  how many warranty claims were filed for products launched in the last two years

select p.product_name , count(w.claim_id) as num_claims , count( s.sale_id) as sales_count
from warranty w right join sales s on s.sale_id = w.sale_id 
join products p on p.product_id = s.product_id 
where p.launch_date >= current_date - interval '2 years'
 group by  p.product_name ;


-- months in the last three years where sales exceeded 5,000 units in the USA
select extract(month from sale_date) as month , 
       extract(year from sale_date) as year ,
	   sum(s.quantity)
	   from sales s join stores st on st.store_id=s.store_id
       where st.country='United States'
       and sale_date >= current_date - interval '3 year' 
       group by extract(month from sale_date),extract(year from sale_date)
	   having sum(s.quantity) > 5000;


--  the product category with the most warranty claims filed in the last two years

select c.category_id , c.category_name,count(w.claim_id)from warranty w
left join sales s on s.sale_id = w.sale_id 
join products p on p.product_id = s.product_id
join category c on c.category_id = p.category_id
where w.claim_date >= current_date - interval '2 year'
group by c.category_id , c.category_name;




-- Determine the percentage chance of receiving warranty claims
-- after each purchase for each country

SELECT 
    st.country,
    SUM(s.quantity) AS total_unit_sold,
    COUNT(w.claim_id) AS claim_count,
    (COUNT(w.claim_id)::numeric / NULLIF(SUM(s.quantity), 0)::numeric) * 100 AS claim_percentage
FROM sales s
JOIN stores st ON st.store_id = s.store_id
LEFT JOIN warranty w ON w.sale_id = s.sale_id
GROUP BY st.country;



-- Analyze the year-by-year growth ratio for each store.
WITH yearly_sales AS (
    SELECT 
        s.store_id AS store_id,
        st.store_name AS store_name,
        EXTRACT(YEAR FROM s.sale_date) AS year,
        SUM(s.quantity * p.price) AS curr_total_sale
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    JOIN stores st ON st.store_id = s.store_id
    GROUP BY s.store_id, st.store_name, EXTRACT(YEAR FROM s.sale_date)
),
growth_table AS (
    SELECT
        store_name,
        year,
        curr_total_sale,
        LAG(curr_total_sale, 1) OVER (PARTITION BY store_name ORDER BY year) AS prev_year_sales
    FROM yearly_sales
)
SELECT
    store_name,
    year,
    curr_total_sale,
    prev_year_sales,
    CASE 
        WHEN prev_year_sales IS NULL OR prev_year_sales = 0 THEN NULL
        ELSE ((curr_total_sale - prev_year_sales)::numeric / prev_year_sales::numeric) * 100
    END AS growth_percentage
FROM growth_table where prev_year_sales is not null 
ORDER BY store_name, year ;

       
-- Calculate the correlation between product price and warranty claims
-- for products sold in the last five years, segmented by price range






WITH recent_sales AS (
    SELECT 
        s.sale_id,
        s.product_id,
        p.price,
        CASE 
            WHEN w.claim_id IS NOT NULL THEN 1
            ELSE 0
        END AS has_claim,
        CASE 
            WHEN p.price < 500 THEN 'Under 500'
            WHEN p.price BETWEEN 500 AND 1000 THEN '500-1000'
            WHEN p.price BETWEEN 1001 AND 2000 THEN '1001-2000'
            ELSE '2000+'
        END AS price_range
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    LEFT JOIN warranty w ON w.sale_id = s.sale_id
    WHERE s.sale_date >= (CURRENT_DATE - INTERVAL '5 years')
)
SELECT 
    price_range,
    COUNT(*) AS total_sales,
    SUM(has_claim) AS total_claims,
    CORR(price, has_claim) AS price_claim_correlation
FROM recent_sales
GROUP BY price_range
ORDER BY price_range;

select * from warranty
-- Identify the store with the highest percentage of "Paid Repaired" claims relative to total claims filed.


WITH store_claims AS (
    SELECT 
        st.store_id,
        st.store_name,
        COUNT(w.claim_id) AS total_claims,
        SUM(CASE WHEN w.repair_status = 'Completed' THEN 1 ELSE 0 END) AS completed_claims
    FROM warranty w
    JOIN sales s ON w.sale_id = s.sale_id
    JOIN stores st ON s.store_id = st.store_id
    GROUP BY st.store_id, st.store_name
)
SELECT 
    store_id,
    store_name,
    completed_claims,
    total_claims,
    (completed_claims::numeric / total_claims::numeric) * 100 AS completed_percentage
FROM store_claims
ORDER BY completed_percentage DESC
LIMIT 1;

-- Write a query to calculate the monthly running total of sales for each store over the past four years and compare trends during this period.


WITH monthly_sales AS (
    SELECT 
        st.store_id,
        st.store_name,
        DATE_TRUNC('month', s.sale_date) AS month,
        SUM(s.quantity * p.price) AS monthly_total
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    JOIN stores st ON s.store_id = st.store_id
    WHERE s.sale_date >= (CURRENT_DATE - INTERVAL '4 years')
    GROUP BY st.store_id, st.store_name, DATE_TRUNC('month', s.sale_date)
)
SELECT 
    store_id,
    store_name,
    month,
    monthly_total,
    SUM(monthly_total) OVER (
        PARTITION BY store_id
        ORDER BY month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total
FROM monthly_sales
ORDER BY store_name, month;


-- Analyze product sales trends over time, segmented into key periods: from launch to 6 months, 6-12 months, 12-18 months, and beyond 18 months.






WITH product_age_sales AS (
    SELECT
        p.product_id,
        p.product_name,
        s.sale_date,
        s.quantity * p.price AS sale_amount,
        -- Calculate months since launch
        EXTRACT(MONTH FROM AGE(s.sale_date, p.launch_date)) + 
        EXTRACT(YEAR FROM AGE(s.sale_date, p.launch_date)) * 12 AS months_since_launch
    FROM sales s
    JOIN products p ON s.product_id = p.product_id
    WHERE s.sale_date >= p.launch_date
)
SELECT
    CASE
        WHEN months_since_launch <= 6 THEN '0-6 months'
        WHEN months_since_launch <= 12 THEN '6-12 months'
        WHEN months_since_launch <= 18 THEN '12-18 months'
        ELSE '18+ months'
    END AS period,
    SUM(sale_amount) AS total_sales,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT product_id) AS num_products
FROM product_age_sales
GROUP BY period
ORDER BY 
    CASE 
        WHEN period = '0-6 months' THEN 1
        WHEN period = '6-12 months' THEN 2
        WHEN per




select distinct extract(year from sale_date)  from sales;

























