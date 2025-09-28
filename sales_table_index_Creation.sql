select * from category;

select * from products ;


select * from stores;

select * from sales ;


select * from warranty;



--EDA


select distinct repair_status from warranty;
--4 repiar status we have :-
                        -- "Rejected"
                        -- "Completed"
                        -- "In Progress"
                        -- "Pending"
select * from category;

select count(*) from sales;
-- 1040200


--Improving the query performance


-- pt 0.529ms
-- et 210.480ms
explain analyze 
select * from sales where product_id='P-44';


-- CREATE INDEX sales_product_id ON sales(product_id);

-- et after sales_product_id index  - 14ms

-- "Planning Time: 0.082 ms"
-- "Execution Time: 176.236 ms"
explain analyze 
select * from sales
where store_id='ST-31';


-- CREATE INDEX sales_store_id ON sales(store_id);

-- "Execution Time: 11.067 ms" after index 
explain analyze 
select * from sales
where store_id='ST-31';




CREATE INDEX sales_sale_date ON sales(sale_date);

































