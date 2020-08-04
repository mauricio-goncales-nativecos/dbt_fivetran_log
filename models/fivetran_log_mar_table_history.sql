with active_volume as (

    select 
        *,
        DATE_TRUNC(date(measured_at), month) as measured_month

    from {{ ref('stg_fivetran_log_active_volume') }} 
    where schema_name != 'fivetran_log' -- TODO: can we reference the source schema with jinja?
),

ordered_mar as (
    select
        connector_name,
        schema_name,
        table_name,
        destination_id,
        measured_at,
        measured_month,
        monthly_active_rows,
        row_number() over(partition by table_name, connector_name, destination_id, measured_month order by measured_at desc) as n

    from active_volume

),

latest_mar as (
    select 
        schema_name,
        table_name,
        connector_name,
        destination_id,
        measured_month,
        date(measured_at) as last_measured_at,
        sum(monthly_active_rows) as monthly_active_rows
      
    from ordered_mar
    where n = 1
    group by 1,2,3,4,5,6

),

connector as (

    select * 
    from {{ ref('stg_fivetran_log_connector') }}
),

destination as (

    select *
    from {{ ref('stg_fivetran_log_destination') }}
),

mar_join as (

    select 
        latest_mar.*,
        connector.connector_type,
        destination.destination_name

    from latest_mar
    join connector on latest_mar.connector_name = connector.connector_name -- data is messed up, TODO: fix connector_id in staging after sharing w bjorn? 
    join destination on latest_mar.destination_id = destination.destination_id
)

select * from mar_join
order by measured_month desc, destination_id, connector_name