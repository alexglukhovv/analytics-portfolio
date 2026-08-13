/* Проект Исследование внутриигровых покупок
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты, а также оценить 
 * активность игроков при совершении внутриигровых покупок
*/
-- Исследовательский анализ данных
-- 1. Исследование доли платящих игроков
select count(payer), 
       sum(payer), 
       round(avg(payer), 2)
from fantasy.users; 
--  Доля платящих пользователей в разрезе расы персонажа:
select race,
       sum(payer) as total_plaing,
       count(payer) as total_users,
       round(avg(payer), 3) as proportion
from fantasy.race as r
join fantasy.users as u on r.race_id = u.race_id
group by race
order by proportion desc;
-- 2. Исследование внутриигровых покупок
-- Статистические показатели по полю amount:
select 'Все данные' as tabel, 
       count(amount) as total_count,
       sum(amount) as total_sum,
       min(amount) as total_min,
       max(amount) as total_max,
       avg(amount) as total_avg,
       percentile_cont(0.50) within group (order by amount) as median,
       stddev(amount) as total_st_deviation
from fantasy.events
union
select 'Только > 0' as tabel,
       count(amount) as total_count,
       sum(amount) as total_sum,
       min(amount) as total_min,
       max(amount) as total_max,
       avg(amount) as total_avg,
       percentile_cont(0.50) within group (order by amount) as median,
       stddev(amount) as total_st_deviation
from fantasy.events
where amount > 0 and amount is not null;
-- Аномальные нулевые покупки:
select count(*) filter (where amount = 0) as zero_count,
       count(*) as total_count,
       round(count(*) filter (where amount = 0)::numeric/count(*), 3)as proportion 
from fantasy.events 
-- Популярные эпические предметы:
select i.game_items,
       t.item_code,
       count(*) as group_count,
       count(*)/t.total_count::real*100 as proportion_count, 
       count(distinct id)/t.total_users::real*100 as proportion_users 
from (select *,
             count (*) over () as total_count, 
             (select count(distinct id) from fantasy.events where amount > 0) as total_users 
      from fantasy.events
      where amount > 0 )as t
join fantasy.items as i on t.item_code = i.item_code
group by i.game_items, t.item_code, t.total_count, t.total_users
order by group_count desc; 

-- Зависимость активности игроков от расы персонажа:
-- 1.Таблица с общими данными 
with table_active_users as (
select r.race_id, r.race,
       count(distinct u.id)as total_quantity_users, 
       count(distinct e.id) as activ_users, 
       count(e.transaction_id) as total_transactions, 
       sum(e.amount) as total_amount, 
       count(distinct case when u.payer = 1 then e.id end)as paying_users 
from fantasy.race as r
join fantasy.users as u on r.race_id = u.race_id
left join fantasy.events as e on u.id = e.id AND e.amount > 0
group by r.race_id, r.race
order by total_quantity_users desc),
-- 2.Таблица с расчетом долей: 
table_coversions as (
select *,
       round(activ_users/total_quantity_users::numeric, 3) as conv_users, 
       round(paying_users/activ_users::numeric, 3) as conv_paying 
from table_active_users),
-- 3.Таблица с средними значениями:
table_avg_quantity as (
select *,
       round(total_transactions / activ_users::numeric, 2) as avg_orders, 
       round(total_amount::numeric/total_transactions ::numeric, 2) as avg_transaction_amount, 
       round(total_amount::numeric/activ_users::numeric, 2) as avg_revenue_users 
from table_coversions)
-- Итоговая таблица 
select race_id,
       race,
       total_quantity_users,
       activ_users,
       conv_users,
       conv_paying,
       avg_orders,
       avg_transaction_amount,
       avg_revenue_users 
from table_avg_quantity;