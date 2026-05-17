
# Given 4 csv files with the following schema

# customers - (cid, cname, age, gender)
# restaurants - (res_id, res_name, city, location)
# menu - (menu_id, res_id, item_name, veg/non-veg, res_price, app_price)
# orders - (order_id, menu_id, cust_id, qty, order_date, order_time, eta, delivery_time)

create database project;
use project;

select * from customers;
select * from menu;
select * from orders;
select * from restaurants;

# Basic Questions

# Q1) Find Res with more than 50 orders
select m.res_id, r.res_name, count(o.order_id) total_orders 
from menu m join orders o on m.menu_id=o.menu_id 
join restaurants r on m.res_id = r.res_id
group by m.res_id, r.res_name
having count(o.order_id)>50;

# Q2) Find the top 5 customers by total quantity ordered.
select c.cid, c.cname, sum(o.qty) total_qty from customers c 
join orders o on o.cust_id = c.cid 
group by c.cid,c.cname 
order by total_qty 
desc limit 5;

# Q3) Find each customer's first order date and last order date
# only for those customers who have placed multiple orders
select c.cid, c.cname, min(o.order_date) first_order_date, 
max(o.order_date) last_order_date from orders o 
join customers c on o.cust_id = c.cid
group by c.cid, c.cname 
having count(o.order_id)>1;

# Q4) Find customers who ordered from more than 3 distinct restaurants.
select c.cid, c.cname, count(distinct m.res_id) restraunt_count
from orders o join menu m on o.menu_id = m.menu_id 
join customers c on o.cust_id = c.cid
group by c.cid, c.cname 
having count(distinct m.res_id)>3;

# Q5) Find month wise total revenue 
select monthname(o.order_date) order_month, 
sum(o.qty*m.app_price) total_revenue
from orders o join menu m on m.menu_id = o.menu_id
group by monthname(o.order_date);

# Q6) Find each restaurant's average delivery delay
# Display res_id,order_time, delivery_time, diff, eta
select m.res_id, o.order_time, o.delivery_time, 
minute(timediff(o.delivery_time,o.order_time)) as diff, o.eta,
avg(minute(timediff(o.delivery_time,o.order_time))) 
over (partition by m.res_id) as avg_delay
from orders o join menu m on m.menu_id = o.menu_id;

# Q7) Find menu items where app price is higher than restaurant price
# Display item_name, res_price, app_price
select item_name, res_price, app_price from menu 
where app_price>res_price;


# Questions on Subqueries, Window Functions, Self-join, Joins

# Q1) Find most expensive menu item in each restaurant ?
select r.res_id, r.res_name, m.item_name, m.app_price
from restaurants r join menu m on m.res_id = r.res_id
where m.app_price = (select max(app_price) from menu where res_id = r.res_id);

# Q2) Find customers whose total orders exceed the average orders 
# placed by all customers.
select c.cid, c.cname, count(o.order_id) total_orders
from customers c join orders o on c.cid = o.cust_id
group by c.cid, c.cname 
having total_orders > (select avg(order_count) from
(select count(order_id) as order_count from orders group by cust_id) as dt);

# Q3) Rank customers based on total spending. 
# Display cust_id,total_spend and rank. Display top 15 Ranks
select * from
(select o.cust_id, sum(o.qty*m.app_price) total_spend, 
rank() over (order by sum(o.qty*m.app_price) desc) rnk
from orders o join menu m on m.menu_id=o.menu_id
group by o.cust_id) dt
where dt.rnk<=15;

# Q4) Find the top 3 highest priced item in the menu for each city
select * from
(select r.city, r.res_id, m.item_name, m.app_price, 
dense_rank() over(partition by r.city order by m.app_price desc) DRank 
from restaurants r join menu m on m.res_id = r.res_id) dt
where dt.DRank<=3;

# Q5) Find running revenue by order month for 2024
select *, sum(monthly_revenue) over (order by month_num) running_revenue from
(select month(o.order_date) month_num, monthname(o.order_date) order_month,
sum(o.qty*m.app_price)  monthly_revenue 
from orders o join menu m on o.menu_id = m.menu_id 
where year(o.order_date)=2024 
group by month(o.order_date), monthname(o.order_date)) dt
group by month_num, order_month order by month_num asc;

# Q6) Find menu items never ordered.
select m.menu_id, m.item_name 
from menu m left join orders o on m.menu_id=o.menu_id
where o.menu_id is null;

# Q7) Find top 4 ordered item per restaurant
# Display res_name, item_name, total_qty, rank
select * from
(select r.res_name, m.item_name, sum(o.qty) total_qty, 
rank() over (partition by r.res_name order by sum(o.qty) desc) rank1
from restaurants r join menu m on r.res_id=m.res_id
join orders o on m.menu_id=o.menu_id 
group by r.res_name,m.item_name) dt
where dt.rank1<=4;

# Q8) Find customers whose spending is above their own gender 
# average spending. Display cust_id, gender, spend, avg_spend by gender
select dt1.* from
(select dt.*, avg(spend) over(partition by gender) avg_spend_by_gender from 
(select c.cid, c.gender, sum(o.qty*m.app_price) spend 
from customers c join orders o on o.cust_id=c.cid
join menu m on m.menu_id=o.menu_id group by c.cid, c.gender) dt
group by cid,gender) dt1
where spend>avg_spend_by_gender;

# Q9) Find the latest order placed by each customer.
# Display all columns from orders
select * from 
(select *, row_number() 
over(partition by cust_id 
order by order_date desc,order_time desc) as rnum
from orders) dt
where dt.rnum=1;

# Q10) Find customers with consecutive-day orders.
select distinct cust_id from
(select cust_id, order_date, 
lag(order_date) over(partition by cust_id 
order by order_date) prev_date
from orders) dt
where datediff(order_date, prev_date) = 1;

# Q11) Find percentage contribution of each restaurant to total revenue. 
select *, round(dt.revenue*100/sum(dt.revenue) over(),2) percentage_contribution from
(select r.res_id, r.res_name, sum(o.qty*m.app_price) revenue
from restaurants r join menu m on m.res_id=r.res_id
join orders o on o.menu_id=m.menu_id 
group by r.res_id, r.res_name) dt
group by dt.res_id,dt.res_name;

# Q12) Find the bottom 3 least ordered items overall(least ordered in terms of qty)
select o.menu_id, m.item_name ,sum(o.qty) total_qty 
from orders o join menu m on m.menu_id=o.menu_id
group by o.menu_id, m.item_name 
order by total_qty asc limit 3;

# Q13) Find restaurants whose revenue is above average restaurant revenue.
# Dispaly res_id and revenue
select dt.res_id, dt.revenue from
(select m.res_id, sum(o.qty*m.app_price) revenue,
avg(sum(o.qty*m.app_price)) over() avg_revenue
from menu m join orders o on m.menu_id = o.menu_id
group by m.res_id) dt
where dt.revenue>dt.avg_revenue;

# Q14) Find each customer's preferred restaurant (most ordered from).
select cust_id, res_id, res_name, total_orders from
(select o.cust_id, r.res_id, r.res_name, count(*) total_orders, 
row_number() over (partition by o.cust_id order by count(*) desc) rn
from restaurants r join menu m on m.res_id = r.res_id
join orders o on m.menu_id = o.menu_id
group by o.cust_id, r.res_id, r.res_name) dt
where dt.rn=1;


# Q15) Find customers whose spending is above the average spending 
# of customers from the same age group (18–25, 26–35, 36–45).
# Display cid, age_group, spend, avg_group_spend
select dt1.cid, dt1.age_group, dt1.spend, dt1.avg_group_spend from
(select dt.*, 
avg(dt.spend) over(partition by dt.age_group) avg_group_spend from
(select c.cid, c.age,
case when c.age between 18 and 25 then '18-25'
when c.age between 26 and 35 then '26-35'
when c.age between 36 and 45 then '36-45'
end as age_group, sum(o.qty*m.app_price) spend
from customers c join orders o on c.cid=o.cust_id
join menu m on m.menu_id=o.menu_id
group by c.cid, c.age ) dt)dt1
where dt1.spend>dt1.avg_group_spend;

# Q16) Find the top 2 restaurants by revenue in each city.
# Dispaly city, restaurant_name, revenue,rank
select * from 
(select r.city, r.res_name, sum(o.qty*m.app_price) revenue,
rank() over(partition by r.city order by sum(o.qty*m.app_price) desc) rnk
from restaurants r join menu m on m.res_id=r.res_id
join orders o on o.menu_id=m.menu_id
group by r.city,r.res_name order by r.city) dt
where dt.rrank<=2;

# Q17) Find customers whose latest order value is greater than their average historical order value.
# Display cust_id, order_id, order_value, avg_order_value, rank
select * from
(select dt.*, avg(dt.order_value) 
over(partition by dt.cust_id) avg_order_value from
(select o.cust_id, o.order_id, (o.qty*m.app_price) order_value,
rank() over(partition by o.cust_id order by o.order_date desc, o.order_time desc) rnk
from orders o join menu m on o.menu_id = m.menu_id)dt) dt1
where dt1.rnk=1 and dt1.order_value>dt1.avg_order_value;

# Q18) Find restaurants whose most expensive item is above the overall average max item price.
# Display res_id, max_price
select res_id, item_name, max_price from
(select res_id, item_name, max(app_price) max_price, 
avg(max(app_price)) over() avg_max_price from menu 
group by res_id, item_name) dt
where max_price>avg_max_price;

# Q19) Find menu items whose revenue is above the average revenue of items in the same restaurant.
#  Display res_id, item_name, revenue, avg_res_item_rev
select * from 
(select dt.*, avg(dt.revenue) over(partition by dt.res_id) avg_res_item_rev from
(select m.res_id, m.item_name, sum(o.qty*m.app_price) revenue
from menu m join orders o on m.menu_id=o.menu_id
group by m.res_id, m.item_name) dt) dt1
where dt1.revenue>dt1.avg_res_item_rev;

# Q20) Find customers who have ordered every restaurant available in their city.
# Display cid
select dt.cid, dt.cname, dt.city from
(select c.cid, c.cname, r.city, count(distinct r.res_id) res_count
from customers c join orders o on o.cust_id=c.cid
join menu m on m.menu_id = o.menu_id
join restaurants r on r.res_id=m.res_id
group by c.cid, c.cname, r.city) dt
where dt.res_count in (select res_city_count from
(select city, count(res_id) res_city_count from restaurants
group by city) r);

# Q21) Find revenue growth/decline for each restaurant compared to previous order date.
#  Display res_id, order_date, revenue, revenue_change
select dt.res_id, dt.order_date, dt.revenue, 
dt.revenue-lag(revenue) over(partition by dt.res_id 
order by dt.order_date) revenue_change from
(select m.res_id, o.order_date, sum(m.app_price*o.qty) revenue
from menu m join orders o on o.menu_id=m.menu_id
group by m.res_id, o.order_date)dt;

# Q22) Find customers whose total spend ranks in top 10%.
# Display cust_id,spend and spend_decile (Hint use ntile window function)
select * from
(select dt.cust_id, dt.spend, ntile(10) 
over(order by dt.spend desc) spend_decile from
(select o.cust_id, sum(m.app_price*o.qty) spend
from orders o join menu m on m.menu_id=o.menu_id
group by o.cust_id) dt)dt1
where dt1.spend_decile=1;


# Q23) Find the most frequently ordered pair of menu items by same customer.
select * from
(select c.cid, c.cname, m1.item_name as item1, 
m2.item_name as item2, count(*) order_frequency,
rank() over(partition by c.cid order by count(*) desc) rnk
from customers c join orders o1 on o1.cust_id=c.cid
join orders o2 on o1.cust_id=o2.cust_id 
and o1.menu_id<o2.menu_id
join menu m1 on o1.menu_id=m1.menu_id
join menu m2 on o2.menu_id=m2.menu_id
where m1.item_name!=m2.item_name
group by c.cid, c.cname, item1, item2) dt
where dt.rnk=1;

# Q24) Find pairs of customers who placed orders on the same date.
# Solve using self-join. Display cust1_name, cust2_name, order_date
select c1.cname as customer1, c2.cname as customer2, o1.order_date 
from orders o1 join orders o2 on o1.order_date=o2.order_date
and o1.cust_id<o2.cust_id
join customers c1 on o1.cust_id=c1.cid
join customers c2 on o2.cust_id=c2.cid
order by customer1 asc;

# Q25) Find duplicate-aged customer pairs
# Dispaly Cust1_name, cust2_name and age
select c1.cname as Cust1_name, c2.cname as cust2_name,
c1.age from customers c1 join customers c2 on c1.age=c2.age
and c1.cid!=c2.cid;

# Q26) Find customers who never ordered from the same restaurant twice
select * from
(select c.cid, c.cname, m.res_id, count(*) total_orders
from customers c join orders o on o.cust_id=c.cid
join menu m on m.menu_id=o.menu_id
group by c.cid, c.cname, m.res_id order by c.cid asc) dt
where dt.total_orders=1; 

# Q27) Find restaurants where veg items qty solds outnumber non-veg items
# qty sold
select * from
(select m.res_id, 
sum(case when `veg/non-veg`='veg' then o.qty else 0 end) as veg_qty, 
sum(case when `veg/non-veg`='non-veg' then o.qty else 0 end) as non_veg_qty
from menu m join orders o on o.menu_id=m.menu_id
group by m.res_id) dt
where dt.veg_qty>dt.non_veg_qty;

# Q28) Find top 3 menu items with maximum markup percentage
# markup_percentage = % diff between app_price and res_price
select * from
(select dt.*, rank() over(order by markup_percentage desc) rnk from
(select menu_id, item_name, 
round((app_price-res_price)*100/res_price,2) markup_percentage
from menu) dt)dt1
where dt1.rnk<=3;

# Q29) Find restaurants whose average markup exceeds overall average markup
# markup = app_price - res_price
# Dispaly res_name
select dt1.res_name from
(select dt.*, avg(avg_markup) over() overall_avg_markup from
(select r.res_name, avg(m.app_price-m.res_price) avg_markup
from restaurants r join menu m on m.res_id=r.res_id
group by r.res_name) dt) dt1
where dt1.avg_markup>dt1.overall_avg_markup;

# Q30) Rank restaurants by total commission earned
# Display res_name, total_commission, commission_rank
select *, rank() 
over(order by dt.total_commission desc) commission_rank from
(select r.res_name, sum(m.app_price-m.res_price) total_commission
from restaurants r join menu m on m.res_id=r.res_id
group by r.res_name) dt;

# Q31) Find menu items priced above restaurant's own average app price
# Display item_name, res_name, app_price
select dt.res_name, dt.item_name, dt.app_price from
(select r.res_name, m.item_name, m.app_price, 
avg(m.app_price) over(partition by r.res_name) res_avg_app_price
from restaurants r join menu m on m.res_id=r.res_id
group by r.res_name, m.item_name, m.app_price) dt
where dt.app_price>dt.res_avg_app_price;

# Q32) Find orders where total commission exceeded order average commission
# Commission = app_price - res_price
# Display ordeR_id, commission
select dt.order_id, dt.commission from
(select o.order_id, (m.app_price-m.res_price) as commission,
avg(m.app_price-m.res_price) over() avg_order_commission
from orders o join menu m on m.menu_id=o.menu_id)dt
where dt.commission>dt.avg_order_commission;

# Q33) Find restaurant with highest average commission per item sold
# Display res_name avg_commission, rank
select * from
(select dt.*, rank() over(order by avg_commission desc) rnk from
(select r.res_name, avg(m.app_price-m.res_price) avg_commission
from restaurants r join menu m on m.res_id=r.res_id
group by r.res_name) dt)dt1
where dt1.rnk=1;











