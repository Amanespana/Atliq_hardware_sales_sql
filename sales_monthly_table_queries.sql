describe fact_sales_monthly;
select * from fact_sales_monthly limit 10;
alter table fact_sales_monthly modify date DATE;
update fact_sales_monthly SET date = STR_TO_DATE(date, '%Y-%m-%d');
select distinct day(date) from fact_sales_monthly;
