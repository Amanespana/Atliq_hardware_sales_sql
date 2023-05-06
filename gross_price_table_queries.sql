select * from fact_gross_price;
select count(*) from fact_gross_price;
select count(distinct product_code) from fact_gross_price;
select distinct fiscal_year from fact_gross_price order by fiscal_year desc;
describe fact_gross_price;
