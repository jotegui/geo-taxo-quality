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

DROP FUNCTION public.geospatial_issue(double precision, double precision, text, geometry);

CREATE OR REPLACE FUNCTION geospatial_issue
(
	lat DOUBLE PRECISION,
	lon DOUBLE PRECISION,
	country text,
	p_geom geometry(Point,4326),
	OUT resa boolean, -- no geom (means no coordinates)
	out resb boolean, -- no country
	OUT res1 boolean, -- 0,0
	OUT res2 boolean, -- out of the map
	OUT res4 boolean, -- low precision
	OUT res8 boolean, -- out of coutry
	OUT res16 BOOLEAN, -- coordinates transposed
	out res32 boolean, -- latitude negated
	out res64 boolean, -- longitude negated
	out dist double precision -- further than 0.1 degrees
)

AS

$BODY$

DECLARE
	t integer; -- dummy variable to test the transformations
	i text; -- dummy variable to help translating between ISO2 and ISO3 country codes
	p_trans geometry(Point,4326); -- point with transposed coordinates
	p_neglat geometry(Point,4326); -- point with negated latitude
	p_neglon geometry(Point,4326); -- point with negated longitude
	p_neglatlon geometry(Point,4326); -- point with both latitude and longitude negated
	p_transneglat geometry(Point,4326); -- transposed point with negated latitude
	p_transneglon geometry(Point,4326); -- transposed point with negated longitude
	p_transneglatlon geometry(Point,4326); -- transposed point with both latitude and longitude negated
BEGIN

	resa := false;
	resb := false;
	res1 := false;
	res2 := false;
	res4 := false;
	res8 := false;
	res16 := false;
	res32 := false;
	res64 := false;
	dist := NULL;

	IF p_geom is null THEN
		resa := true;
	else
		if country is null then
			resb := true;
		end if;

--
-- INDIVIDUAL ISSUES
-- Issues that exclude the rest of the analyses if True
--

--
-- Latitude and longitude = 0
--
		IF lat = 0 AND lon = 0 THEN
			res1 := True;
		else
			res1 := false;
		END IF;

--
-- Coordinates outside of the world map
--
		IF lat > 90 OR lat < -90 THEN
			res2 := True;
		else
			res2 := false;
		END IF;

--
-- STACKABLE ISSUES
-- Issues that can appear together in records
--

		IF res1 = False AND res2 = False THEN

--
-- Coordinate precision below 2 decimal figures
--
			IF round(cast(lat as numeric),2)=lat AND round(cast(lon as numeric),2)=lon THEN
				res4 := True;
			else
				res4 := false;
			END IF;

--
-- Distance to country polygons, with coordinate transposition and negation
--
			IF country is not null then
				
				-- Patch to translate between iso2 and iso3 country codes
				select into i iso3 from (select iso3 from isocountrycodes where iso2=country) as foo; -- insert the iso3 in variable i

				-- check if point falls into given country. t: number of polygons with overlap
				select into t isWithin from (
					select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_geom, the_geom)=true) as foo
				) as bar;

				If t = 1 then -- point falls inside country
					res8 := false;
					dist := 0;
				else -- point falls outside country
					res8 := True;
					-- check if transposed point falls into given country. t: number of polygons with overlap
					select into p_trans newpoint from (select ST_FlipCoordinates(p_geom) as newpoint) as foo; -- insert transposed point in p_trans
					select into t isWithin from (
						select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_trans, the_geom)=true) as foo
					) as bar;
					IF t = 1 then -- transposed point falls inside country
						res16 := true;
					else -- point and transposed point fall outside country
						res16 := False;
						-- check if negated lat point falls into given country. t: number of polygons with overlap
						select into p_neglat newpoint from (select ST_SetSRID(ST_MakePoint(X(p_geom), -Y(p_geom)),4326) as newpoint) as foo; -- insert negated lat point in p_neglat
						select into t isWithin from (
							select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_neglat, the_geom)=true) as foo
						) as bar;
						IF t = 1 then -- negated lat point falls inside country
							res32 := true;
						else -- point, transposed and negated lat fall outside country
							res32 := false;
							-- check if negated lon point falls into given country. t: number of polygons with overlap
							select into p_neglon newpoint from (select ST_SetSRID(ST_MakePoint(-X(p_geom), Y(p_geom)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
							select into t isWithin from (
								select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_neglon, the_geom)=true) as foo
							) as bar;
							IF t = 1 then -- negated lon point falls inside country
								res64 := true;
							else -- point, transposed, negated lat and negated lon fall outside country
								res64 := false;
								-- check if negated latlon point falls into given country. t: number of polygons with overlap
								select into p_neglatlon newpoint from (select ST_SetSRID(ST_MakePoint(-X(p_geom), -Y(p_geom)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
								select into t isWithin from (
									select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_neglatlon, the_geom)=true) as foo
								) as bar;
								IF t = 1 then -- negated latlon point falls inside country
									res32 := true;
									res64 := true;
								else -- point, transposed, negated lat, negated lon and negated latlon fall outside country
									res32 := false;
									res64 := false;
									-- check if transposed and negated lat point falls into given country. t: number of polygons with overlap
									select into p_transneglat newpoint from (select ST_SetSRID(ST_MakePoint(X(p_trans), -Y(p_trans)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
									select into t isWithin from (
										select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_transneglat, the_geom)=true) as foo
									) as bar;
									IF t = 1 then -- negated latlon point falls inside country
										res16 := true;
										res32 := true;
									else -- point, transposed, negated lat, negated lon and negated latlon fall outside country
										res16 := false;
										res32 := false;
										-- check if transposed and negated lon point falls into given country. t: number of polygons with overlap
										select into p_transneglon newpoint from (select ST_SetSRID(ST_MakePoint(-X(p_trans), Y(p_trans)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
										select into t isWithin from (
											select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_transneglon, the_geom)=true) as foo
										) as bar;
										IF t = 1 then -- negated latlon point falls inside country
											res16 := true;
											res64 := true;
										else -- point, transposed, negated lat, negated lon and negated latlon fall outside country
											res16 := false;
											res64 := false;
											-- check if transposed and negated latlon point falls into given country. t: number of polygons with overlap
											select into p_transneglatlon newpoint from (select ST_SetSRID(ST_MakePoint(-X(p_trans), -Y(p_trans)),4326) as newpoint) as foo; -- insert negated lon point in p_neglon
											select into t isWithin from (
												select count(*) as isWithin from (select * from gadm2 where iso=i and ST_Within(p_transneglatlon, the_geom)=true) as foo
											) as bar;
											IF t = 1 then -- negated latlon point falls inside country
												res16 := true;
												res32 := true;
												res64 := true;
											else -- point, transposed, negated lat, negated lon and negated latlon fall outside country
												res16 := false;
												res32 := false;
												res64 := false;
												-- distance
												select into dist distance from (
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
ALTER FUNCTION public.geospatial_issue(double precision, double precision, text, geometry)
  OWNER TO javiero;
