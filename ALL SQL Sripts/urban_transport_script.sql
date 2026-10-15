-- ============================================================
-- MySQL Database & Table Creation for urban_transport Script
-- ============================================================

-- 50143956 - Christoph van Jaarsveld
-- 46251960 - Luan du Plessis
-- 49019767 - Pieta Hattingh
-- 45926808 - Sune Muller
-- 46036482 - Zoe du Plessis

-- =========================================================
-- Creates urban_transport Database
-- =========================================================
CREATE DATABASE IF NOT EXISTS urban_transport
	DEFAULT CHARACTER SET utf8mb4;

USE urban_transport;


-- =========================================================
-- Drops tables to avoid errors with existing tables
-- =========================================================
DROP TABLE IF EXISTS trip_reviews;
DROP TABLE IF EXISTS trip_fare_breakdown;
DROP TABLE IF EXISTS trip_headers;
DROP TABLE IF EXISTS vehicles;
DROP TABLE IF EXISTS pricing_surge_zones;
DROP TABLE IF EXISTS sa_drivers;
DROP TABLE IF EXISTS sa_riders;


-- =========================================================
-- Create sa_riders Table
-- =========================================================
CREATE TABLE sa_riders (
    rider_id				VARCHAR(12)	PRIMARY KEY,
    first_name				VARCHAR(50)	NOT NULL,
    last_name				VARCHAR(50)	NOT NULL,
    mobile_number			VARCHAR(15)	NOT NULL UNIQUE,
    home_city				VARCHAR(30)	NOT NULL,
    province				VARCHAR(30)	NOT NULL,
    preferred_payment		VARCHAR(20)	NOT NULL,
    account_created_date	DATE		NOT NULL,
	
    CONSTRAINT chk_riders_preferred_payment CHECK (
        preferred_payment IN ('CASH','CREDIT_CARD','DEBIT_CARD','EFT_OZOW','IN_APP_WALLET')
    )
);


 -- =========================================================
-- Create sa_drivers Table
-- =========================================================
CREATE TABLE sa_drivers (
    driver_id					VARCHAR(10)		PRIMARY KEY,
    first_name					VARCHAR(50)		NOT NULL,
    last_name					VARCHAR(50)		NOT NULL,
    operating_city				VARCHAR(30)		NOT NULL,
    platform_affiliation		VARCHAR(25)		NOT NULL,
    platform_commission_pct		DECIMAL(4,2)	NOT NULL,
    driver_rating				DECIMAL(3,2)	NOT NULL,
    total_lifetime_trips		INT				NOT NULL,
    onboarding_date				DATE			NOT NULL,
	
    CONSTRAINT chk_drivers_platform CHECK (
        platform_affiliation IN ('Uber','Bolt','Dual-Platform (Both)')
    ),
    CONSTRAINT chk_drivers_commission CHECK (
        platform_commission_pct BETWEEN 0 AND 1
    ),
    CONSTRAINT chk_drivers_rating CHECK (
        driver_rating BETWEEN 1 AND 5
    ),
    CONSTRAINT chk_drivers_lifetime_trips CHECK (
        total_lifetime_trips >= 0
    )
);


-- =========================================================
-- Create vehicles Table
-- =========================================================
CREATE TABLE vehicles (
    vehicle_id		VARCHAR(10)	PRIMARY KEY,
    driver_id		VARCHAR(10)	NOT NULL UNIQUE,
    make			VARCHAR(30)	NOT NULL,
    model			VARCHAR(30)	NOT NULL,
    year			SMALLINT	NOT NULL,
    license_plate	VARCHAR(15)	NOT NULL UNIQUE,
    category_type	VARCHAR(40)	NOT NULL,
	
    CONSTRAINT fk_vehicles_driver FOREIGN KEY (driver_id)
        REFERENCES sa_drivers(driver_id),
    CONSTRAINT chk_vehicles_year CHECK (
        year BETWEEN 2000 AND 2026
    )
);


-- =========================================================
-- Create pricing_surge_zones Table
-- =========================================================
CREATE TABLE pricing_surge_zones (
    zone_id				VARCHAR(25)		PRIMARY KEY,
    zone_name			VARCHAR(60)		NOT NULL,
    city				VARCHAR(30)		NOT NULL,
    base_fare_zar		DECIMAL(6,2)	NOT NULL,
    per_km_rate_zar		DECIMAL(6,2)	NOT NULL,
    per_min_rate_zar	DECIMAL(6,2)	NOT NULL,
	
    CONSTRAINT chk_zones_base_fare CHECK (base_fare_zar >= 0),
    CONSTRAINT chk_zones_per_km CHECK (per_km_rate_zar >= 0),
    CONSTRAINT chk_zones_per_min CHECK (per_min_rate_zar >= 0)
);


-- =========================================================
-- Create trip_headers Table
-- =========================================================
CREATE TABLE trip_headers (
    trip_id					VARCHAR(20)	PRIMARY KEY,
    rider_id				VARCHAR(12)	NOT NULL,
    driver_id				VARCHAR(10)	NOT NULL,
    zone_id					VARCHAR(25)	NOT NULL,
    ride_category			VARCHAR(40)	NOT NULL,
    request_timestamp		DATETIME	NOT NULL,
    trip_status				VARCHAR(25)	NOT NULL,
    cancellation_reason		VARCHAR(25),
	
    CONSTRAINT fk_trips_rider FOREIGN KEY (rider_id)
        REFERENCES sa_riders(rider_id),
    CONSTRAINT fk_trips_driver FOREIGN KEY (driver_id)
        REFERENCES sa_drivers(driver_id),
    CONSTRAINT fk_trips_zone FOREIGN KEY (zone_id)
        REFERENCES pricing_surge_zones(zone_id),
    CONSTRAINT chk_trips_ride_category CHECK (
        ride_category IN (
            'Budget (Uber Go/Bolt Go)','Standard (UberX/Bolt)',
            'Comfort (Uber Comfort)','Large Capacity (UberXL/Bolt XL)'
        )
    ),
    CONSTRAINT chk_trips_status CHECK (
        trip_status IN ('COMPLETED','CANCELLED_BY_RIDER','CANCELLED_BY_DRIVER')
    ),
    CONSTRAINT chk_trips_cancel_reason CHECK (
        cancellation_reason IN (
            'CHANGED_MIND','DRIVER_TOO_FAR','PRICING_SURGE',
            'RIDER_NO_SHOW','SAFETY_CONCERN','TRAFFIC_DELAY'
        ) OR cancellation_reason IS NULL
    )
);


-- =========================================================
-- Create trip_fare_breakdown Table
-- =========================================================
CREATE TABLE trip_fare_breakdown (
    trip_id						VARCHAR(20)		PRIMARY KEY,
    distance_km					DECIMAL(5,2)	NOT NULL,
    duration_minutes			INT				NOT NULL,
    surge_multiplier			DECIMAL(3,2)	NOT NULL,
    base_fare_zar				DECIMAL(6,2)	NOT NULL,
    tolls_zar					DECIMAL(6,2)	NOT NULL DEFAULT 0,
    tip_zar						DECIMAL(6,2)	NOT NULL DEFAULT 0,
    total_fare_zar				DECIMAL(9,2)	NOT NULL,
    platform_commission_zar		DECIMAL(8,2)	NOT NULL,
    driver_payout_zar			DECIMAL(9,2)	NOT NULL,
    payment_method				VARCHAR(20)		NOT NULL,
	
    CONSTRAINT fk_fares_trip FOREIGN KEY (trip_id)
        REFERENCES trip_headers(trip_id),
    CONSTRAINT chk_fares_distance CHECK (distance_km >= 0),
    CONSTRAINT chk_fares_duration CHECK (duration_minutes >= 0),
    CONSTRAINT chk_fares_surge CHECK (surge_multiplier >= 1),
    CONSTRAINT chk_fares_base_fare CHECK (base_fare_zar >= 0),
    CONSTRAINT chk_fares_tolls CHECK (tolls_zar >= 0),
    CONSTRAINT chk_fares_tip CHECK (tip_zar >= 0),
    CONSTRAINT chk_fares_total CHECK (total_fare_zar >= 0),
    CONSTRAINT chk_fares_commission CHECK (platform_commission_zar >= 0),
    CONSTRAINT chk_fares_payout CHECK (driver_payout_zar >= 0),
    CONSTRAINT chk_fares_payment_method CHECK (
        payment_method IN ('CASH','CREDIT_CARD','DEBIT_CARD','EFT_OZOW','IN_APP_WALLET')
    )
);
 

-- =========================================================
-- Create trip_reviews Table
-- =========================================================
CREATE TABLE trip_reviews (
    review_id					VARCHAR(15)	PRIMARY KEY,
    trip_id						VARCHAR(20)	NOT NULL UNIQUE,
    rider_rating_of_driver		SMALLINT	NOT NULL,
    driver_rating_of_rider		SMALLINT	NOT NULL,
    feedback_comment			VARCHAR(150),
	
    CONSTRAINT fk_reviews_trip FOREIGN KEY (trip_id)
        REFERENCES trip_headers(trip_id),
    CONSTRAINT chk_reviews_rider_rating CHECK (
        rider_rating_of_driver BETWEEN 1 AND 5
    ),
    CONSTRAINT chk_reviews_driver_rating CHECK (
        driver_rating_of_rider BETWEEN 1 AND 5
    )
);