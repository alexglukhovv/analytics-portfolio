/* Проект. Анализ данных для агентства недвижимости
 * Цель - Провести исследование рынка жилой недвижимости Санкт-Петербурга и Ленинградской области, 
 * выявить наиболее привлекательные сегменты рынка, определить влияние сезонности на активность объявлений.
*/

-- 1. Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT *
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Итоговая таблица
total_table as (
    select 
       case 
      	  WHEN f.city_id = '6X8I' AND f.type_id = 'F8EM' THEN 'Санкт-Петербург'
       else 'Ленинградская область'
       end as region,
       case 
	       when a.days_exposition between 1 and 30 then 'до 1 месяца'
           when a.days_exposition between 31 and 90 then 'до 3 месяцев'
           when a.days_exposition between 91 and 180 then 'до 6 месяцев'
           when a.days_exposition > 180 then 'свыше 6 месяцев'
       else 'non category'
       end as categories,
       count (f.id) as quantity_fals,
       round(avg(a.last_price/f.total_area)::numeric, 2) as avg_price_per_m2,
       round(avg(f.total_area)::numeric, 2) as total_area,
       round(avg(f.rooms)::numeric) as quantity_rooms,
       round(avg(f.balcony)::numeric) as quantity_balcony       
from filtered_id as f
join real_estate.advertisement as a on f.id = a.id
where first_day_exposition between '2015-01-01' and '2018-12-31'
  and f.type_id = 'F8EM'
group by  region,categories
order by region desc, categories)
-- Итоговая таблица с долей объявлений Санкт Петербурга и Ленинградской области
select region,
       categories,
       quantity_fals,
       round(quantity_fals/total::numeric * 100 , 2) as percent_fals,
       avg_price_per_m2,
       total_area,
       quantity_rooms,
       quantity_balcony
from (select *,
             sum(quantity_fals) over(partition by region) as total
      from total_table) as t
order by region desc, categories;


-- 2. Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT *
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
    -- Таблица с добавлением периодов
    table_periods as (
    select date_trunc('month', a.first_day_exposition)::date as date_first_day,
           date_trunc('month', a.first_day_exposition + a.days_exposition * interval '1 day')::date as date_last_day, 
           a.id,
           round((a.last_price/f.total_area)::numeric, 2) as price_1_square_meter,
           f.total_area      
    from filtered_id as f
    join real_estate.advertisement as a on f.id = a.id
    join real_estate.type as t on f.type_id = t.type_id
    where first_day_exposition >= '2015-01-01' 
      and first_day_exposition < '2019-01-01'
      and type = 'город'),
    -- Таблица с периодом публикаций и агригациями
    published as (
    select date_first_day,
           count(id) as pub_ads,
           round(avg(price_1_square_meter)::numeric ,2) as avg_price_per_m2_pub,
           round(avg(total_area)::numeric, 2) as avg_area_pub       
    from table_periods
    group by date_first_day),
    -- Таблица с периодом снятия публикаций и агригациями
    removed as (
    select date_last_day,
           count(id) as rem_ads,
           round(avg(price_1_square_meter)::numeric ,2) as avg_price_per_m2_rem,
           round(avg(total_area)::numeric, 2) as avg_area_rem
    from table_periods
    group by date_last_day)
    -- Итоговая таблица
    select to_char(coalesce(date_first_day,date_last_day), 'TMMonth') as month_name,
           sum(pub_ads) as pub_ads,
           sum(rem_ads) as rem_ads,
           round(avg(avg_price_per_m2_pub)::numeric, 2) as avg_price_per_m2_pub,
           round(avg(avg_price_per_m2_rem)::numeric, 2) as avg_price_per_m2_rem,
           round(avg(avg_area_pub)::numeric, 2) as avg_area_pub,
           round(avg(avg_area_rem)::numeric, 2) as avg_area_rem
    from published as p
    full join removed as r on p.date_first_day = r.date_last_day
    where coalesce(date_first_day,date_last_day) is not null
    group by extract(month from coalesce(date_first_day,date_last_day)),month_name
    order by extract(month from coalesce(date_first_day,date_last_day));

    
    
    