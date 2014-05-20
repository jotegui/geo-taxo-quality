-- Function: public.geospatial_issue(double precision, double precision, text, geometry)
-- 
-- 
-- This function is called from geospatial_rangemap_issue. It returns a record-type
-- set of flags that represent the possible geospatial issues in the occurrence point.
-- See below for details.
-- 
-- This function needs the geospatial values from he occurrence point, namely coordinates,
-- the specified country and the PostGIS representation of the point.
-- 
-- It returns a record-type set of variables representing the geospatial issues.
-- 
-- This function requires the following tables to work:
-- a) the GADM table with the first level administrative boundaries
-- b) the ISO country codes table, to translate between ISO codes, here called isocountrycodes.
--    (In our setup, the GADM table uses ISO3 and GBIF uses ISO2)
-- 
-- Author: Javier Otegui (javier.otegui@gmail.com)
-- 
-- 

DROP FUNCTION IF EXISTS public.geospatial_issue(double precision, double precision, text, geometry); -- Main function: Latitude, Longitude, Country and Point Geometry
DROP FUNCTION IF EXISTS public.geospatial_issue(geometry, text); -- 1st overload, supply only the_geom and country
DROP FUNCTION IF EXISTS public.geospatial_issue(double precision, double precision, text); -- 2st overload, supply only coordinates and country

-------------------------------------------------------------------
-- First overload

CREATE OR REPLACE FUNCTION geospatial_issue
(
	p_geom geometry(Point,4326),
	country text,
	out nocoordinates boolean, -- true if the record has no coordinates
	out nocountry boolean, -- true if the record has no country
	out iszero boolean, -- true if coordinates are 0,0
	out isoutofworld boolean, -- true if absolute value of latitude is greater than 90
	out islowprecision boolean, -- true if less than 3 decimal figures in coordinates
	out isoutofcountry boolean, -- true if out of specified country
	out istransposed boolean, -- true if transposed (latitude value in longitude field and vice versa)
	out isnegatedlatitude boolean, -- true if latitude value is negated (true when should be false or viceversa)
	out isnegatedlongitude boolean, -- same as isnegatedlatitude but with longitude value
	out distance2country double precision -- distance from point to closest edge of country polygon
)

AS

$BODY$

DECLARE
    lon double precision;
    lat double precision;

BEGIN

    select into lon xval from (select ST_X(p_geom) as xval) as foo;
    select into lat yval from (select ST_Y(p_geom) as yval) as foo;
    select into nocoordinates, nocountry, iszero, isoutofworld, islowprecision, isoutofcountry, istransposed, isnegatedlatitude, isnegatedlongitude, distance2country foo.nocoordinates, foo.nocountry, foo.iszero, foo.isoutofworld, foo.islowprecision, foo.isoutofcountry, foo.istransposed, foo.isnegatedlatitude, foo.isnegatedlongitude, foo.distance2country from (select (geospatial_issue(lat, lon, country, p_geom)).*) as foo;

END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ;

-------------------------------------------------------------------
-- Second overload

CREATE OR REPLACE FUNCTION geospatial_issue
(
	lat double precision,
	lon double precision,
	country text,
	out nocoordinates boolean, -- true if the record has no coordinates
	out nocountry boolean, -- true if the record has no country
	out iszero boolean, -- true if coordinates are 0,0
	out isoutofworld boolean, -- true if absolute value of latitude is greater than 90
	out islowprecision boolean, -- true if less than 3 decimal figures in coordinates
	out isoutofcountry boolean, -- true if out of specified country
	out istransposed boolean, -- true if transposed (latitude value in longitude field and vice versa)
	out isnegatedlatitude boolean, -- true if latitude value is negated (true when should be false or viceversa)
	out isnegatedlongitude boolean, -- same as isnegatedlatitude but with longitude value
	out distance2country double precision -- distance from point to closest edge of country polygon
)

AS

$BODY$

DECLARE
    p_geom geometry(Point, 4326);

BEGIN

    select into p_geom pointval from (select ST_SetSRID(ST_Point(lon, lat), 4326) as pointval) as foo;
    select into nocoordinates, nocountry, iszero, isoutofworld, islowprecision, isoutofcountry, istransposed, isnegatedlatitude, isnegatedlongitude, distance2country foo.nocoordinates, foo.nocountry, foo.iszero, foo.isoutofworld, foo.islowprecision, foo.isoutofcountry, foo.istransposed, foo.isnegatedlatitude, foo.isnegatedlongitude, foo.distance2country from (select (geospatial_issue(lat, lon, country, p_geom)).*) as foo;

END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ;

-------------------------------------------------------------------
-- Main function

CREATE OR REPLACE FUNCTION geospatial_issue
(
	lat DOUBLE PRECISION,
	lon DOUBLE PRECISION,
	country text,
	p_geom geometry(Point,4326),
	out nocoordinates boolean, -- true if the record has no coordinates
	out nocountry boolean, -- true if the record has no country
	out iszero boolean, -- true if coordinates are 0,0
	out isoutofworld boolean, -- true if absolute value of latitude is greater than 90
	out islowprecision boolean, -- true if less than 3 decimal figures in coordinates
	out isoutofcountry boolean, -- true if out of specified country
	out istransposed boolean, -- true if transposed (latitude value in longitude field and vice versa)
	out isnegatedlatitude boolean, -- true if latitude value is negated (true when should be false or viceversa)
	out isnegatedlongitude boolean, -- same as isnegatedlatitude but with longitude value
	out distance2country double precision -- distance from point to closest edge of country polygon
)

AS

$BODY$

DECLARE
	t integer; -- dummy variable to test the transformations
	i text; -- dummy variable to help translating between ISO2 and ISO3 country codes
	c_length integer; -- dummy variable to help translating between ISO2 and ISO3 country codes
	p_trans geometry(Point,4326); -- point with transposed coordinates
	p_neglat geometry(Point,4326); -- point with negated latitude
	p_neglon geometry(Point,4326); -- point with negated longitude
	p_neglatlon geometry(Point,4326); -- point with both latitude and longitude negated
	p_transneglat geometry(Point,4326); -- transposed point with negated latitude
	p_transneglon geometry(Point,4326); -- transposed point with negated longitude
	p_transneglatlon geometry(Point,4326); -- transposed point with both latitude and longitude negated
	
BEGIN

	nocoordinates := NULL;
	nocountry := NULL;
	iszero := NULL;
	isoutofworld := NULL;
	islowprecision := NULL;
	isoutofcountry := NULL;
	istransposed := NULL;
	isnegatedlatitude := NULL;
	isnegatedlongitude := NULL;
	distance2country := NULL;

	IF p_geom is null THEN
		nocoordinates := true;
	else
		nocoordinates := false;
		if country is null or country = '' then
			nocountry := true;
	    else
	        nocountry := false;
		end if;

--
-- INDIVIDUAL ISSUES
-- Issues that exclude the rest of the analyses if True
--

--
-- Latitude and longitude = 0
--
		IF lat = 0 AND lon = 0 THEN
			iszero := True;
		else
			iszero := false;
		END IF;

--
-- Coordinates outside of the world map
--
		IF lat > 90 OR lat < -90 THEN
			isoutofworld := True;
		else
			isoutofworld := false;
		END IF;

--
-- STACKABLE ISSUES
-- Issues that can appear together in records
--

		IF iszero = False AND isoutofworld = False THEN

--
-- Coordinate precision below 2 decimal figures
--
			IF round(cast(lat as numeric),2)=lat AND round(cast(lon as numeric),2)=lon THEN
				islowprecision := True;
			else
				islowprecision := false;
			END IF;

--
-- Distance to country polygons, with coordinate transposition and negation
--
			IF country is not null then
				
				-- Patch to translate between country name and iso3 country code
				select into c_length length from (select length(country)) as foo;
				IF c_length > 3 THEN
				    select into i iso from (select iso from gadm2 where name_0=country limit 1) as foo;
				else
				-- Patch to translate between iso2 and iso3 country codes
				    select into i iso3 from (select iso3 from isocountrycodes where iso2=country) as foo; -- insert the iso3 in variable i
                END IF;
				-- check if point falls into given country. t: number of polygons with overlap
				select into t isWithin from (
					select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_geom, the_geom)=true) as foo
				) as bar;

				If t = 1 then -- point falls inside country
					isoutofcountry := false;
					istransposed := false;
					isnegatedlatitude := false;
					isnegatedlongitude := false;
					distance2country := 0;
				else -- point falls outside country
					isoutofcountry := True;
					-- check if transposed point falls into given country. t: number of polygons with overlap
					select into p_trans newpoint from (select ST_FlipCoordinates(p_geom) as newpoint) as foo; -- insert transposed point in p_trans
					select into t isWithin from (
						select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_trans, the_geom)=true) as foo
					) as bar;
					IF t = 1 then -- transposed point falls inside country
						istransposed := true;
	    				isnegatedlatitude := false;
    					isnegatedlongitude := false;
					else -- point and transposed point fall outside country
						istransposed := False;
						-- check if negated lat point falls into given country. t: number of polygons with overlap
						select into p_neglat newpoint from (select ST_SetSRID(ST_MakePoint(X(p_geom), -Y(p_geom)),4326) as newpoint) as foo; -- insert negated lat point in p_neglat
						select into t isWithin from (
							select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_neglat, the_geom)=true) as foo
						) as bar;
						IF t = 1 then -- negated lat point falls inside country
							isnegatedlatitude := true;
							isnegatedlongitude := false;
						else -- point, transposed and negated lat fall outside country
							isnegatedlatitude := false;
							-- check if negated lon point falls into given country. t: number of polygons with overlap
							select into p_neglon newpoint from (select ST_SetSRID(ST_MakePoint(-X(p_geom), Y(p_geom)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
							select into t isWithin from (
								select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_neglon, the_geom)=true) as foo
							) as bar;
							IF t = 1 then -- negated lon point falls inside country
								isnegatedlongitude := true;
							else -- point, transposed, negated lat and negated lon fall outside country
								isnegatedlongitude := false;
								-- check if negated latlon point falls into given country. t: number of polygons with overlap
								select into p_neglatlon newpoint from (select ST_SetSRID(ST_MakePoint(-X(p_geom), -Y(p_geom)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
								select into t isWithin from (
									select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_neglatlon, the_geom)=true) as foo
								) as bar;
								IF t = 1 then -- negated latlon point falls inside country
									isnegatedlatitude := true;
									isnegatedlongitude := true;
								else -- point, transposed, negated lat, negated lon and negated latlon fall outside country
									isnegatedlatitude := false;
									isnegatedlongitude := false;
									-- check if transposed and negated lat point falls into given country. t: number of polygons with overlap
									select into p_transneglat newpoint from (select ST_SetSRID(ST_MakePoint(X(p_trans), -Y(p_trans)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
									select into t isWithin from (
										select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_transneglat, the_geom)=true) as foo
									) as bar;
									IF t = 1 then -- negated latlon point falls inside country
										istransposed := true;
										isnegatedlatitude := true;
									else -- point, transposed, negated lat, negated lon and negated latlon fall outside country
										istransposed := false;
										isnegatedlatitude := false;
										-- check if transposed and negated lon point falls into given country. t: number of polygons with overlap
										select into p_transneglon newpoint from (select ST_SetSRID(ST_MakePoint(-X(p_trans), Y(p_trans)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
										select into t isWithin from (
											select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_transneglon, the_geom)=true) as foo
										) as bar;
										IF t = 1 then -- negated latlon point falls inside country
											istransposed := true;
											isnegatedlongitude := true;
										else -- point, transposed, negated lat, negated lon and negated latlon fall outside country
											istransposed := false;
											isnegatedlongitude := false;
											-- check if transposed and negated latlon point falls into given country. t: number of polygons with overlap
											select into p_transneglatlon newpoint from (select ST_SetSRID(ST_MakePoint(-X(p_trans), -Y(p_trans)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
											select into t isWithin from (
												select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_transneglatlon, the_geom)=true) as foo
											) as bar;
											IF t = 1 then -- negated latlon point falls inside country
												istransposed := true;
												isnegatedlatitude := true;
												isnegatedlongitude := true;
											else -- point, transposed, negated lat, negated lon and negated latlon fall outside country
												istransposed := false;
												isnegatedlatitude := false;
												isnegatedlongitude := false;
												-- distance
												select into distance2country distance from (
													select min(distance)::double precision as distance from (select ST_Distance(p_geom, the_geom) as distance from gadm2 where iso=i) as foo -- works, though slow
												) as bar;
											end if;
										end if;
									end if;
								end if;
							end if;
						end if;
					end if;
				END IF;
			END IF;
		END IF;
	END IF;

END;

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ;
