SET GLOBAL local_infile = 1;
 
 
-- ---------------------------------------------------------
-- 1. sa_riders
-- ---------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/chris/OneDrive/Desktop/uber_bolt_sa_dataset/sa_riders.csv'
INTO TABLE sa_riders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(rider_id, first_name, last_name, mobile_number, home_city, province,
 preferred_payment, @created)
SET account_created_date = STR_TO_DATE(@created, '%Y/%m/%d');
 
 
-- ---------------------------------------------------------
-- 2. sa_drivers
-- ---------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/chris/OneDrive/Desktop/uber_bolt_sa_dataset/sa_drivers.csv'
INTO TABLE sa_drivers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(driver_id, first_name, last_name, operating_city, platform_affiliation,
 platform_commission_pct, driver_rating, total_lifetime_trips, @onboard)
SET onboarding_date = STR_TO_DATE(@onboard, '%Y/%m/%d');
 
 
-- ---------------------------------------------------------
-- 3. pricing_surge_zones
-- ---------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/chris/OneDrive/Desktop/uber_bolt_sa_dataset/pricing_surge_zones.csv'
INTO TABLE pricing_surge_zones
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(zone_id, zone_name, city, base_fare_zar, per_km_rate_zar, per_min_rate_zar);
 
 
-- ---------------------------------------------------------
-- 4. vehicles  (depends on sa_drivers)
-- ---------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/chris/OneDrive/Desktop/uber_bolt_sa_dataset/vehicles.csv'
INTO TABLE vehicles
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(vehicle_id, driver_id, make, model, year, license_plate, category_type);
 
 
-- ---------------------------------------------------------
-- 5. trip_headers  (depends on sa_riders, sa_drivers, pricing_surge_zones)
--    cancellation_reason is the text 'N/A' on completed trips -> convert to NULL
-- ---------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/chris/OneDrive/Desktop/uber_bolt_sa_dataset/trip_headers.csv'
INTO TABLE trip_headers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(trip_id, rider_id, driver_id, zone_id, ride_category,
 request_timestamp, trip_status, @cancel)
SET cancellation_reason = NULLIF(@cancel, 'N/A');
 
 
-- ---------------------------------------------------------
-- 6. trip_fare_breakdown  (depends on trip_headers)
-- ---------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/chris/OneDrive/Desktop/uber_bolt_sa_dataset/trip_fare_breakdown.csv'
INTO TABLE trip_fare_breakdown
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(trip_id, distance_km, duration_minutes, surge_multiplier, base_fare_zar,
 tolls_zar, tip_zar, total_fare_zar, platform_commission_zar,
 driver_payout_zar, payment_method);
 
 
-- ---------------------------------------------------------
-- 7. trip_reviews  (depends on trip_headers)
-- ---------------------------------------------------------
LOAD DATA LOCAL INFILE 'C:/Users/chris/OneDrive/Desktop/uber_bolt_sa_dataset/trip_reviews.csv'
INTO TABLE trip_reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(review_id, trip_id, rider_rating_of_driver, driver_rating_of_rider, feedback_comment);
 
 
-- ---------------------------------------------------------
-- Sanity check: row counts should be 1200 / 800 / 9 / 800 / 50000 / 50000 / 25055
-- ---------------------------------------------------------
SELECT 'sa_riders' t, COUNT(*) row_count FROM sa_riders
UNION ALL SELECT 'sa_drivers', COUNT(*) FROM sa_drivers
UNION ALL SELECT 'pricing_surge_zones', COUNT(*) FROM pricing_surge_zones
UNION ALL SELECT 'vehicles', COUNT(*) FROM vehicles
UNION ALL SELECT 'trip_headers', COUNT(*) FROM trip_headers
UNION ALL SELECT 'trip_fare_breakdown', COUNT(*) FROM trip_fare_breakdown
UNION ALL SELECT 'trip_reviews', COUNT(*) FROM trip_reviews;
 