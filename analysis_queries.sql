-- Data Analysis queries

-- drop table merged_data;
-- 1. merging gross_price, manufacturing_cost, pre_discount, product, sales tables into one------------------------------------------------------------------
create table merged_data as
with collected_data as (
select s.date, s.product_code,p.variant, s.customer_code, s.sold_quantity, s.fiscal_year, g.gross_price, d.pre_invoice_discount_pct,
round((g.gross_price*(1-d.pre_invoice_discount_pct)), 2) as final_price, m.manufacturing_cost
from fact_sales_monthly s 
inner join fact_gross_price g on s.product_code=g.product_code 
and s.fiscal_year=g.fiscal_year
inner join fact_pre_discount d on s.customer_code=d.customer_code 
and s.fiscal_year=d.fiscal_year
inner join fact_manufacturing_cost m on s.product_code=m.product_code 
and s.fiscal_year=m.cost_year
inner join dim_product p on s.product_code=p.product_code
)
select *, round(sold_quantity*(final_price), 2) as revenue, round(sold_quantity*(final_price - manufacturing_cost), 2) as profit from collected_data;

select * from merged_data;


-- 2. Quantity sold grouped by Year and annual percent change -------------------------------------------------------------------------------
CREATE TABLE quantity_sold_agg AS
with quantity_sold_data as (
select fiscal_year, sum(sold_quantity) as total_quantity
from fact_sales_monthly 
group by fiscal_year
), total_quantity_data as(
select *, ((total_quantity - LAG(total_quantity) OVER (ORDER BY fiscal_year)) / LAG(total_quantity) OVER (ORDER BY fiscal_year)) * 100 AS Annual_quantity_sold_pct_change from quantity_sold_data
)
SELECT * FROM total_quantity_data;

select * from quantity_sold_agg;

-- 3. sales/revenue data and annual percent change -------------------------------------------------------------------------------------
create table revenue_agg as
with sales_data as (
select s.date, s.product_code, s.customer_code, s.sold_quantity, s.fiscal_year, g.gross_price, d.pre_invoice_discount_pct,
round((g.gross_price*(1-d.pre_invoice_discount_pct)), 2) as final_price
from fact_sales_monthly s inner join fact_gross_price g on s.product_code=g.product_code 
and s.fiscal_year=g.fiscal_year
inner join fact_pre_discount d on s.customer_code=d.customer_code 
and s.fiscal_year=d.fiscal_year
), revenue_data as (
select fiscal_year, round(sum((sold_quantity*final_price)), 2) as revenue from sales_data group by fiscal_year
)
select *, round(((revenue - Lag(revenue) over (order by fiscal_year))/Lag(revenue) over (order by fiscal_year))*100, 2) as Annual_revenue_pct_change from revenue_data;

select * from revenue_agg;

-- 4. profit data -------------------------------------------------------------------------------------------------------------------------
create table profit_agg as
with sales_data as (
select s.date, s.product_code, s.customer_code, s.sold_quantity, s.fiscal_year, g.gross_price, d.pre_invoice_discount_pct,
round((g.gross_price*(1-d.pre_invoice_discount_pct)), 2) as final_price, m.manufacturing_cost
from fact_sales_monthly s 
inner join fact_gross_price g on s.product_code=g.product_code 
and s.fiscal_year=g.fiscal_year
inner join fact_pre_discount d on s.customer_code=d.customer_code 
and s.fiscal_year=d.fiscal_year
inner join fact_manufacturing_cost m on s.product_code=m.product_code 
and s.fiscal_year=m.cost_year
), profit_data as(
select fiscal_year, round(sum(sold_quantity*(final_price - manufacturing_cost)), 2) as profit from sales_data group by fiscal_year
)
select *, round(((profit - lag(profit) over (order by fiscal_year))/(lag(profit) over (order by fiscal_year)))*100, 2) as Annual_Profit_pct_change from profit_data;

select * from profit_agg;

select p.fiscal_year, p.Annual_Profit_pct_change, r.Annual_revenue_pct_change from profit_agg p 
inner join revenue_agg r on p.fiscal_year=r.fiscal_year;

-- 5. showing newly created tables together ----------------------------------------------------------------------------------------------------
select q.fiscal_year, q.total_quantity, r.revenue, p.profit,
q.Annual_quantity_sold_pct_change, r.Annual_revenue_pct_change,  p.Annual_profit_pct_change 
from quantity_sold_agg q 
inner join revenue_agg r on q.fiscal_year=r.fiscal_year
inner join profit_agg p on q.fiscal_year=p.fiscal_year;

/* Questions
Q. Why is there a dramatic spike in quantities sold from 2018 to 2019?
Q. Why is there a diff in pct chnange in col 4, 5, 6 from years 2020-22? It it because change in manufacturing or gross sales price pr discounts?
   or is it because the products sold in those years had higher sales price and profit margin?
*/

-- change in manufacturing cost? ------------------------------------------------------------------------------------------------------------------
-- I want to check if there is any change in cost of top 10 products sold over the years

-- 6. Top 10 most sold products yearly --------------------------------------------
select product_code, sum(sold_quantity) as total_quantity, fiscal_year from fact_sales_monthly where fiscal_year=2022 group by product_code order by sum(sold_quantity) desc limit 10;
select product_code, sum(sold_quantity) as total_quantity, fiscal_year from fact_sales_monthly where fiscal_year=2021 group by product_code order by sum(sold_quantity) desc limit 10;
select product_code, sum(sold_quantity) as total_quantity, fiscal_year from fact_sales_monthly where fiscal_year=2020 group by product_code order by sum(sold_quantity) desc limit 10;
select product_code, sum(sold_quantity) as total_quantity, fiscal_year from fact_sales_monthly where fiscal_year=2019 group by product_code order by sum(sold_quantity) desc limit 10;
select product_code, sum(sold_quantity) as total_quantity, fiscal_year from fact_sales_monthly where fiscal_year=2018 group by product_code order by sum(sold_quantity) desc limit 10;

-- 7. Every year from 2018-22, product code "A0118150104" was in top 10 products, we will do cost and price analysis for this product to find any insights
with product_cost as (
select * from fact_manufacturing_cost where product_code="A0118150104" order by cost_year
), product_price as (
select * from fact_gross_price where product_code="A0118150104" order by fiscal_year
), product_cost_price as (
select c.product_code, p.fiscal_year, c.manufacturing_cost, p.gross_price, round((p.gross_price-c.manufacturing_cost), 2) as profit_margin from product_cost c
inner join product_price p on c.cost_year = p.fiscal_year
)
select * from product_cost_price;

-- 8. no. of customers increase every year ----------------------------------------------------------------------------------------------------------------------------------------
select fiscal_year, count(distinct customer_code) as total_customers from fact_sales_monthly group by fiscal_year;

-- 9. Top 10 customers every year by quantity sold ---------------------------------------------------------------------------------------------
select customer_code, sum(sold_quantity) as quantity_sold, fiscal_year from fact_sales_monthly where fiscal_year=2018 group by customer_code order by quantity_sold desc limit 10;
select customer_code, sum(sold_quantity) as quantity_sold, fiscal_year from fact_sales_monthly where fiscal_year=2019 group by customer_code order by quantity_sold desc limit 10;
select customer_code, sum(sold_quantity) as quantity_sold, fiscal_year from fact_sales_monthly where fiscal_year=2020 group by customer_code order by quantity_sold desc limit 10;
select customer_code, sum(sold_quantity) as quantity_sold, fiscal_year from fact_sales_monthly where fiscal_year=2021 group by customer_code order by quantity_sold desc limit 10;
select customer_code, sum(sold_quantity) as quantity_sold, fiscal_year from fact_sales_monthly where fiscal_year=2022 group by customer_code order by quantity_sold desc limit 10;
--  customer_code= 80007195 has been one of the top customers every year by quantity sold --------------------------------------------------

-- 10. Top 10 customers every year by profit -----------------------------------------------------------------------------------------------
select customer_code, round(sum(profit), 2) as total_profit from merged_data where fiscal_year=2018 group by customer_code order by total_profit desc limit 10;
select customer_code, round(sum(profit), 2) as total_profit from merged_data where fiscal_year=2019 group by customer_code order by total_profit desc limit 10;
select customer_code, round(sum(profit), 2) as total_profit from merged_data where fiscal_year=2020 group by customer_code order by total_profit desc limit 10;
select customer_code, round(sum(profit), 2) as total_profit from merged_data where fiscal_year=2021 group by customer_code order by total_profit desc limit 10;
select customer_code, round(sum(profit), 2) as total_profit from merged_data where fiscal_year=2022 group by customer_code order by total_profit desc limit 10;

-- 11. product variant analysis ---------------------------------------------------------------
SELECT variant, SUM(sold_quantity) AS quantity_sold, round(SUM(profit), 2) AS total_profit
FROM merged_data where fiscal_year = 2022
GROUP BY variant
ORDER BY total_profit DESC;


