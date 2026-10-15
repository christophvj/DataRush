/*=============================================================================
GROUP MEMBERS
-----------------------------------------------------------------------------
50143956      Christoph van Jaarsveld
46251960      Luan du Plessis
49019767      Pieta Hattingh
45926808      Sune Muller
46036482      Zoe du Plessis
 
CONTENTS
-----------------------------------------------------------------------------
6.1    RQ1   Average spend per trip by province
6.2    RQ2   Trip distances by province and ride category
6.3    RQ3   Distance, duration and fare by ride category
6.4    RQ4   Tipping frequency and average tip
6.5    RQ5   Payment method adoption by province
6.6    RQ6   Preferred vs. actual payment method
        6.6.1   Preferred vs. actual (breakdown)
        6.6.2   Overall match / mismatch rate
        6.6.3   Match percentage (subquery version)
6.7    RQ7   Payment method and trip cancellations
6.8    RQ8   Surge pricing and rider spending
        6.8.1   By ride category
        6.8.2   By payment method
6.9    RQ9   Rider satisfaction by payment method
6.10   RQ10  High-value riders
============================================================================= */
 

/*=============================================================================
6.1  RQ1 | Average spend per completed trip, by province
-----------------------------------------------------------------------------
Question : What is the average spend per completed trip in each province?
============================================================================= */
SELECT
    r.province,
    COUNT(*)                                        AS completed_trips,
    ROUND(AVG(f.total_fare_zar), 2)                 AS avg_fare_per_trip_zar,
    ROUND(AVG(f.total_fare_zar)
          - SUM(SUM(f.total_fare_zar)) OVER ()
            / SUM(COUNT(*)) OVER (), 2)             AS diff_vs_national_avg_zar,
    ROUND(SUM(f.total_fare_zar), 2)                 AS total_spend_zar,
    RANK() OVER (ORDER BY AVG(f.total_fare_zar) DESC) AS spend_rank
FROM trip_headers t
    INNER JOIN sa_riders r           ON r.rider_id = t.rider_id
    INNER JOIN trip_fare_breakdown f ON f.trip_id  = t.trip_id
WHERE t.trip_status = 'COMPLETED'
GROUP BY r.province
HAVING COUNT(*) >= 30          
ORDER BY spend_rank;


/*=============================================================================
6.2  RQ2 | Trip distances by province and ride category
-----------------------------------------------------------------------------
Question: How do trip distances differ between provinces and ride categories?
============================================================================= */
SELECT
    r.province,
    t.ride_category,
    COUNT(*)                            AS completed_trips,
    ROUND(AVG(f.distance_km), 2)        AS avg_distance_km,
    ROUND(MIN(f.distance_km), 2)        AS min_distance_km,
    ROUND(MAX(f.distance_km), 2)        AS max_distance_km,
    ROUND(STDDEV_POP(f.distance_km), 2) AS sd_distance_km
FROM trip_headers t
    INNER JOIN sa_riders r           ON r.rider_id = t.rider_id
    INNER JOIN trip_fare_breakdown f ON f.trip_id  = t.trip_id
WHERE t.trip_status = 'COMPLETED'
GROUP BY r.province, t.ride_category
ORDER BY r.province, t.ride_category;


/*=============================================================================
6.3  RQ3 | Distance, duration and fare by ride category
-----------------------------------------------------------------------------
Question: How do distance, duration and fare relate for each ride category?
============================================================================= */
WITH completed AS (
    SELECT t.ride_category,
           f.distance_km,
           f.duration_minutes,
           f.total_fare_zar
    FROM trip_headers t
        INNER JOIN trip_fare_breakdown f ON f.trip_id = t.trip_id
    WHERE t.trip_status = 'COMPLETED'
)
SELECT
    ride_category,
    COUNT(*)                              AS completed_trips,
    ROUND(AVG(distance_km), 2)            AS avg_distance_km,
    ROUND(AVG(duration_minutes), 1)       AS avg_duration_min,
    ROUND(AVG(total_fare_zar), 2)         AS avg_total_fare_zar,
    ROUND( (AVG(distance_km * total_fare_zar)
            - AVG(distance_km) * AVG(total_fare_zar))
           / (STDDEV_POP(distance_km) * STDDEV_POP(total_fare_zar)), 3)
                                          AS r_distance_fare
FROM completed
GROUP BY ride_category
ORDER BY avg_total_fare_zar DESC;


/*=============================================================================
6.4  RQ4 | Tipping frequency and average tip
-----------------------------------------------------------------------------
Question: How often do riders tip, and what is the average tip amount?
============================================================================= */
SELECT
    IF(GROUPING(r.province) = 1, 'ALL PROVINCES', r.province)
                                                   AS province,
    IF(GROUPING(t.ride_category) = 1, 'ALL CATEGORIES', t.ride_category)
                                                   AS ride_category,
    COUNT(*)                                       AS completed_trips,
    SUM(CASE WHEN f.tip_zar > 0 THEN 1 ELSE 0 END) AS tipped_trips,
    ROUND(100.0 * SUM(CASE WHEN f.tip_zar > 0 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                           AS tip_frequency_pct,
    ROUND(AVG(CASE WHEN f.tip_zar > 0 THEN f.tip_zar END), 2)
                                                   AS avg_tip_when_tipped_zar,
    ROUND(AVG(f.tip_zar), 2)                       AS avg_tip_all_trips_zar
FROM trip_headers t
    INNER JOIN sa_riders r           ON r.rider_id = t.rider_id
    INNER JOIN trip_fare_breakdown f ON f.trip_id  = t.trip_id
WHERE t.trip_status = 'COMPLETED'
GROUP BY r.province, t.ride_category WITH ROLLUP
ORDER BY GROUPING(r.province), r.province,
         GROUPING(t.ride_category), tip_frequency_pct DESC;
		 

/*=============================================================================
6.5  RQ5 | Payment method adoption by province
-----------------------------------------------------------------------------
Question: What are the most frequently used payment methods among riders,
          and how does uptake of each method vary between the provinces
          of South Africa?
============================================================================= */
WITH payment_counts AS (
    SELECT
        r.province,
        f.payment_method,
        COUNT(*) AS trip_count
    FROM trip_headers AS t

    INNER JOIN sa_riders AS r
        ON t.rider_id = r.rider_id

    INNER JOIN trip_fare_breakdown AS f
        ON t.trip_id = f.trip_id

    WHERE t.trip_status = 'COMPLETED'

    GROUP BY
        r.province,
        f.payment_method
)
SELECT
    province,
    payment_method,
    trip_count,

    ROUND(
        100.0 * trip_count /
        SUM(trip_count) OVER (PARTITION BY province),
        2
    ) AS pct_within_province

FROM payment_counts

ORDER BY
    province,
    pct_within_province DESC;


/*=============================================================================
6.6  RQ6 Preferred vs actual payment method
-----------------------------------------------------------------------------
Question: Do riders actually pay with the payment method they say they prefer?
============================================================================= */

-- -----------------------------------------------------------------------------
-- 6.6.1 Number of completed trips for every preferred/actual combination.
-- -----------------------------------------------------------------------------
SELECT
    r.preferred_payment,
    f.payment_method AS actual_payment_method,
    COUNT(*) AS trip_count

FROM trip_headers AS t

INNER JOIN sa_riders AS r
    ON t.rider_id = r.rider_id

INNER JOIN trip_fare_breakdown AS f
    ON t.trip_id = f.trip_id

WHERE t.trip_status = 'COMPLETED'

GROUP BY
    r.preferred_payment,
    f.payment_method

ORDER BY
    r.preferred_payment,
    trip_count DESC;


-- -----------------------------------------------------------------------------
-- 6.6.2 Overall match and mismatch rate
-- -----------------------------------------------------------------------------
SELECT
    COUNT(*) AS completed_trips,

    SUM(
        CASE
            WHEN r.preferred_payment = f.payment_method
            THEN 1
            ELSE 0
        END
    ) AS matching_trips,

    SUM(
        CASE
            WHEN r.preferred_payment <> f.payment_method
            THEN 1
            ELSE 0
        END
    ) AS non_matching_trips,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN r.preferred_payment = f.payment_method
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS match_percentage,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN r.preferred_payment <> f.payment_method
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS mismatch_percentage

FROM trip_headers AS t

INNER JOIN sa_riders AS r
    ON t.rider_id = r.rider_id

INNER JOIN trip_fare_breakdown AS f
    ON t.trip_id = f.trip_id

WHERE t.trip_status = 'COMPLETED';


-- -----------------------------------------------------------------------------
-- 6.6.3 Match percentage (subquery)
-- -----------------------------------------------------------------------------
SELECT
    ROUND(
        100.0 *
        (
            SELECT COUNT(*)
            FROM trip_headers AS t2

            INNER JOIN sa_riders AS r2
                ON t2.rider_id = r2.rider_id

            INNER JOIN trip_fare_breakdown AS f2
                ON t2.trip_id = f2.trip_id

            WHERE t2.trip_status = 'COMPLETED'
              AND r2.preferred_payment = f2.payment_method
        )
        /
        (
            SELECT COUNT(*)
            FROM trip_headers AS t3
            WHERE t3.trip_status = 'COMPLETED'
        ),
        2
    ) AS preferred_actual_match_percentage;


/*=============================================================================
6.7  RQ7 | Payment method and trip cancellations
-----------------------------------------------------------------------------
Question : Is the payment method related to how often trips are cancelled?   
============================================================================= */    
SELECT f.payment_method,
    COUNT(*) AS total_trips,

    SUM(
        CASE
            WHEN t.trip_status = 'COMPLETED'
            THEN 1
            ELSE 0
        END
    ) AS completed_trips,

    SUM(
        CASE
            WHEN t.trip_status = 'CANCELLED_BY_RIDER'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_by_rider,

    SUM(
        CASE
            WHEN t.trip_status = 'CANCELLED_BY_DRIVER'
            THEN 1
            ELSE 0
        END
    ) AS cancelled_by_driver,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN t.trip_status = 'CANCELLED_BY_RIDER'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS rider_cancellation_pct,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN t.trip_status = 'CANCELLED_BY_DRIVER'
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS driver_cancellation_pct,

    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN t.trip_status IN (
                    'CANCELLED_BY_RIDER',
                    'CANCELLED_BY_DRIVER'
                )
                THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS total_cancellation_pct

FROM trip_headers AS t

INNER JOIN trip_fare_breakdown AS f
    ON t.trip_id = f.trip_id

GROUP BY
    f.payment_method

HAVING COUNT(*) >= 100

ORDER BY
    total_cancellation_pct DESC;


/*=============================================================================
6.8  RQ8 | Surge pricing and rider spending
-----------------------------------------------------------------------------
Question : How does surge pricing affect what riders spend?
============================================================================= */

-- -----------------------------------------------------------------------------
-- 6.8.1  RQ8 | Surge pricing by ride category
-- -----------------------------------------------------------------------------
WITH surge_data AS (
    SELECT
        CASE
            WHEN f.surge_multiplier = 1.00
                THEN '1. No Surge'

            WHEN f.surge_multiplier > 1.00
                 AND f.surge_multiplier <= 1.50
                THEN '2. Low Surge'

            WHEN f.surge_multiplier > 1.50
                 AND f.surge_multiplier <= 2.00
                THEN '3. Medium Surge'

            ELSE '4. High Surge'
        END AS surge_band,

        t.ride_category,
        f.total_fare_zar

    FROM trip_headers AS t

    INNER JOIN trip_fare_breakdown AS f
        ON t.trip_id = f.trip_id

    WHERE t.trip_status = 'COMPLETED'
)
SELECT
    surge_band,
    ride_category,
    COUNT(*) AS trip_count,
    ROUND(AVG(total_fare_zar), 2) AS avg_fare_zar,
    ROUND(SUM(total_fare_zar), 2) AS total_spend_zar

FROM surge_data

GROUP BY
    surge_band,
    ride_category

ORDER BY
    ride_category,
    surge_band;


-- -----------------------------------------------------------------------------
-- 6.8.2  RQ8 | Surge pricing by payment method
-- -----------------------------------------------------------------------------
WITH surge_data AS (
    SELECT
        CASE
            WHEN f.surge_multiplier = 1.00
                THEN '1. No Surge'

            WHEN f.surge_multiplier > 1.00
                 AND f.surge_multiplier <= 1.50
                THEN '2. Low Surge'

            WHEN f.surge_multiplier > 1.50
                 AND f.surge_multiplier <= 2.00
                THEN '3. Medium Surge'

            ELSE '4. High Surge'
        END AS surge_band,

        f.payment_method,
        f.total_fare_zar

    FROM trip_headers AS t

    INNER JOIN trip_fare_breakdown AS f
        ON t.trip_id = f.trip_id

    WHERE t.trip_status = 'COMPLETED'
)
SELECT
    surge_band,
    payment_method,
    COUNT(*) AS trip_count,
    ROUND(AVG(total_fare_zar), 2) AS avg_fare_zar,
    ROUND(SUM(total_fare_zar), 2) AS total_spend_zar

FROM surge_data

GROUP BY
    surge_band,
    payment_method

ORDER BY
    payment_method,
    surge_band;

/*=============================================================================
 6.9  RQ9 | Rider satisfaction by payment method
-----------------------------------------------------------------------------
Question : Does rider satisfaction differ by payment method?
============================================================================= */
SELECT 
    f.payment_method,
    COUNT(t.trip_id) AS completed_trips,
    COUNT(rv.review_id) AS reviewed_trips,
    ROUND(AVG(rv.rider_rating_of_driver), 2) AS avg_rider_rating_of_driver
FROM trip_headers t
JOIN trip_fare_breakdown f
    ON t.trip_id = f.trip_id
LEFT OUTER JOIN trip_reviews rv
    ON t.trip_id = rv.trip_id
WHERE t.trip_status = 'COMPLETED'
GROUP BY f.payment_method
ORDER BY avg_rider_rating_of_driver DESC;


/* =============================================================================
6.10  RQ10 | High-value riders
-----------------------------------------------------------------------------
   Question : Which riders are "high value"?
============================================================================= */
SELECT  r.rider_id, r.province,
        COUNT(*)                        AS completed_trips,
        ROUND(AVG(f.total_fare_zar), 2) AS avg_fare_zar
FROM    trip_headers t
JOIN    sa_riders r ON t.rider_id = r.rider_id
JOIN    trip_fare_breakdown f ON t.trip_id = f.trip_id
WHERE   t.trip_status = 'COMPLETED'
GROUP BY r.rider_id, r.province
HAVING  AVG(f.total_fare_zar) > (
            SELECT AVG(f2.total_fare_zar)
            FROM   trip_headers t2
            JOIN   trip_fare_breakdown f2 ON t2.trip_id = f2.trip_id
            WHERE  t2.trip_status = 'COMPLETED'
        )
ORDER BY avg_fare_zar DESC;


/* =============================================================================
6.11 Supporting Query: Transaction Example
============================================================================= */
SET @trip_to_correct = (
    SELECT trip_id
    FROM trip_fare_breakdown
    WHERE tolls_zar > 0
      AND total_fare_zar >= tolls_zar
    ORDER BY trip_id
    LIMIT 1
);

SET @original_toll = (
    SELECT tolls_zar
    FROM trip_fare_breakdown
    WHERE trip_id = @trip_to_correct
);

START TRANSACTION;

SELECT
    trip_id,
    tolls_zar,
    total_fare_zar
FROM trip_fare_breakdown
WHERE trip_id = @trip_to_correct;

UPDATE trip_fare_breakdown
SET
    tolls_zar = 0.00,
    total_fare_zar = total_fare_zar - @original_toll
WHERE trip_id = @trip_to_correct;

SELECT
    trip_id,
    tolls_zar,
    total_fare_zar
FROM trip_fare_breakdown
WHERE trip_id = @trip_to_correct;

ROLLBACK;

SELECT
    trip_id,
    tolls_zar,
    total_fare_zar
FROM trip_fare_breakdown
WHERE trip_id = @trip_to_correct;
