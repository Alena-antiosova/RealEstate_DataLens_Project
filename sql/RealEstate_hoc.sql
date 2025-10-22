with limits as (
    select  
        percentile_disc(0.99) within group (order by total_area) as total_area_limit,
        percentile_disc(0.99) within group (order by rooms) as rooms_limit,
        percentile_disc(0.99) within group (order by balcony) as balcony_limit,
        percentile_disc(0.99) within group (order by ceiling_height) as ceiling_height_limit_h,
        percentile_disc(0.01) within group (order by ceiling_height) as ceiling_height_limit_l
    from real_estate.flats     
),
filtered_id as (
    select 
        f.rooms,
        f.total_area,
        f.ceiling_height,
        f.floor,
        f.balcony,
        f.kitchen_area,
        a.last_price,
        a.days_exposition,
        c.city,
        t.type
    from real_estate.flats f
    join real_estate.advertisement a using(id)
    join real_estate.city c using(city_id)
    join real_estate.type t using(type_id)
    join limits l on true 
    where 
        f.total_area < l.total_area_limit
        and (f.rooms < l.rooms_limit or f.rooms is null)
        and (f.balcony < l.balcony_limit or f.balcony is null)
        and (
            (f.ceiling_height < l.ceiling_height_limit_h and f.ceiling_height > l.ceiling_height_limit_l)
            or f.ceiling_height is null
        )
)
select
    case 
        when city = 'Санкт-Петербург' then 'Санкт-Петербург'
        else 'ленобл'
    end as exposition_group_city,
    case
        when days_exposition > 1 and days_exposition < 30 then 'до месяца'
        when days_exposition >= 30 and days_exposition <= 90 then 'до трех месяцев'
        when days_exposition > 90 and days_exposition <= 180 then 'до полугода'
        when days_exposition is null or days_exposition > 180 then 'более полугода'
    end as exposition_group_time,
    round(avg(last_price::numeric / total_area::numeric), 2) as price_for_metr,
    round(avg(total_area)::numeric, 2) as avg_total_area,
    percentile_cont(0.5) within group (order by rooms) as mediana_rooms,
    percentile_cont(0.5) within group (order by balcony) as mediana_balcony,
    round(percentile_cont(0.5) within group (order by floor)::numeric, 3) as mediana_floor,
    round(percentile_cont(0.5) within group (order by kitchen_area)::numeric, 2) as mediana_kitchen_area,
    count(*) as ad_count
from filtered_id
where type = 'город'
group by exposition_group_time, exposition_group_city
order by exposition_group_city desc;
-- ке1с номер 2---------
-------------------------
with limits as (
    select  
        percentile_disc(0.99) within group (order by total_area) as total_area_limit
    from real_estate.flats     
),
filtered_id as (
    select 
        a.id,
        f.total_area,
        a.last_price,
        a.days_exposition,
        a.first_day_exposition,
        t.type
    from real_estate.flats f
    join real_estate.advertisement a using(id)
    join real_estate.type t using(type_id)
    join limits l on true 
    where f.total_area < l.total_area_limit and t.type = 'город'
),
ads_published as (
    select 
        to_char(date_trunc('month', first_day_exposition), 'fmmonth') as month,
        count(*) as ads_published_start,
        rank() over (order by count(*) desc) as rank_start
    from filtered_id
    where extract(year from first_day_exposition) not in ('2014', '2019')
    group by to_char(date_trunc('month', first_day_exposition), 'fmmonth')
),
ads_finish as (
    select 
        coalesce(
            to_char(date_trunc('month', first_day_exposition + days_exposition * interval '1 day'), 'fmmonth'),
            'не продано'
        ) as month,
        count(*) as ads_published_finish,
        rank() over (order by count(*) desc) as rank_finish
    from filtered_id
    where extract(year from first_day_exposition) not in ('2014', '2019')
    group by coalesce(
        to_char(date_trunc('month', first_day_exposition + days_exposition * interval '1 day'), 'fmmonth'),
        'не продано'
    )
),
seasonal_stats as (
    select 
        to_char(date_trunc('month', first_day_exposition), 'fmmonth') as month,
        round(avg(last_price::numeric / total_area::numeric), 2) as avg_price_per_m2,
        round(avg(total_area)::numeric, 2) as avg_total_area,
        count(id) as total_ads
    from filtered_id
    group by to_char(date_trunc('month', first_day_exposition), 'fmmonth')
)
select 
    coalesce(ap.month, af.month, ss.month) as month,
    ap.ads_published_start,
    ap.rank_start,
    af.ads_published_finish,
    round(af.ads_published_finish::numeric /ss.total_ads::numeric, 2) as finish_share,
    af.rank_finish,
    ss.avg_price_per_m2,
    ss.avg_total_area
from ads_published ap
full join ads_finish af using (month)
full join seasonal_stats ss using (month)
order by ap.rank_start nulls last, af.rank_finish nulls last;
--ке3-------------------------------------------------------
------------------------------------------------------------
with limits as (
    select  
        percentile_disc(0.99) within group (order by total_area) as total_area_limit,
        percentile_disc(0.99) within group (order by rooms) as rooms_limit,
        percentile_disc(0.99) within group (order by balcony) as balcony_limit,
        percentile_disc(0.99) within group (order by ceiling_height) as ceiling_height_limit_h,
        percentile_disc(0.01) within group (order by ceiling_height) as ceiling_height_limit_l
    from real_estate.flats     
),
filtered_id as (
    select 
        f.rooms,
        f.total_area,
        f.ceiling_height,
        f.floor,
        f.balcony,
        f.kitchen_area,
        a.last_price,
        a.days_exposition,
        c.city,
        a.id
    from real_estate.flats f
    join real_estate.advertisement a using(id)
    join real_estate.city c using(city_id)
    join limits l on true 
    where 
        f.total_area < l.total_area_limit
        and (f.rooms < l.rooms_limit or f.rooms is null)
        and (f.balcony < l.balcony_limit or f.balcony is null)
        and (
            (f.ceiling_height < l.ceiling_height_limit_h and f.ceiling_height > l.ceiling_height_limit_l)
            or f.ceiling_height is null
        )
),
total_ads as (
    select 
        city,
        count(id) as count_ads,
        round(avg(days_exposition)::numeric, 2) as avg_days_exposition
    from filtered_id
    group by city
),
finish_ads as (
    select 
        city,
        count(id) as count_finish_ads
    from filtered_id
    where days_exposition is not null
    group by city
),
statistics_flat as (
    select
        round(avg(last_price::numeric / total_area::numeric), 2) as price_for_metr,
        round(avg(total_area)::numeric, 2) as avg_total_area,
        percentile_cont(0.5) within group (order by rooms) as mediana_rooms,
        percentile_cont(0.5) within group (order by balcony) as mediana_balcony,
        percentile_cont(0.5) within group (order by floor) as mediana_floor,
        round(percentile_cont(0.5) within group (order by kitchen_area)::numeric, 2) as mediana_kitchen_area,
        city
    from filtered_id
    group by city
)
select 
    city,
    count_ads,
    count_finish_ads,
    round(count_finish_ads::numeric / count_ads::numeric, 2) as ads_finish_share,
    avg_days_exposition,
    price_for_metr,
    avg_total_area,
    mediana_rooms,
    mediana_balcony,
    mediana_floor,
    mediana_kitchen_area
from total_ads ta
join finish_ads fa using (city)
join statistics_flat sf using(city)
where city is not null and city != 'Санкт-Петербург' and count_ads > 50
order by count_ads desc;