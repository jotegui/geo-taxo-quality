-- Function: public.geospatial_rangemap_issue(integer)
-- 
-- 
-- First function to be called. It generates a set of quality flags for a given GBIF record
-- 
-- This function needs an occurrenceid, as stored in the gbif_import table.
-- It returns a set of 9 boolean (t/f) values and two double precision values. Details below
-- 
-- This function requires the following other functions to work:
-- a) rangemap_inside_distance
-- b) geospatial_issue
-- 
-- It also requires the following value type to work:
-- a) geospatialissue
-- 
-- And the following table:
-- a) the main GBIF occurrence points table
-- 
-- Author: Javier Otegui (javier.otegui@gmail.com)
-- 
-- 

drop function if exists public.geospatial_rangemap_issue(double precision, double precision, text, geometry(Point, 4326), text); -- Main function: Latitude, Longitude, Country, Point Geometry and Scientific Name
drop function if exists public.geospatial_rangemap_issue(double precision, double precision, text, text); -- First overload: Latitude, Longitude, Country and Scientific Name
-- todo
drop function if exists public.geospatial_rangemap_issue(geometry(Point, 4326), text, text); -- Second overload: Point Geometry, Country and Scientific Name

------------------------------------------------------------------------------------------
-- First overload

create or replace function public.geospatial_rangemap_issue
(
	in p_latitude double precision, -- the point's latitude value
	in p_longitude double precision, -- the point's longitude value
	in p_country text, -- the point's 2-character country_code
	in p_sciname text, -- the scientific name the occurrence belongs to
	out nocoordinates boolean, -- true if the record has no coordinates
	out nocountry boolean, -- true if the record has no country
	out iszero boolean, -- true if coordinates are 0,0
	out isoutofworld boolean, -- true if absolute value of latitude is greater than 90
	out islowprecision boolean, -- true if less than 3 decimal figures in coordinates
	out isoutofcountry boolean, -- true if out of specified country
	out istransposed boolean, -- true if transposed (latitude value in longitude field and vice versa)
	out isnegatedlatitude boolean, -- true if latitude value is negated (true when should be false or viceversa)
	out isnegatedlongitude boolean, -- same as isnegatedlatitude but with longitude value
	out distance2country double precision, -- distance from point to closest edge of country polygon
	out distance2rangemap double precision -- distance from point to closest edge of range map polygon
)

as

$BODY$

DECLARE
    p_geom geometry(Point, 4326);

BEGIN    

    select into p_geom pointval from (select ST_SetSRID(ST_Point(p_longitude, p_latitude), 4326) as pointval) as foo;
    select into nocoordinates, nocountry, iszero, isoutofworld, islowprecision, isoutofcountry, istransposed, isnegatedlatitude, isnegatedlongitude, distance2country, distance2rangemap foo.nocoordinates, foo.nocountry, foo.iszero, foo.isoutofworld, foo.islowprecision, foo.isoutofcountry, foo.istransposed, foo.isnegatedlatitude, foo.isnegatedlongitude, foo.distance2country, foo.distance2rangemap from (select (geospatial_rangemap_issue(p_latitude, p_longitude, p_country, p_geom, p_sciname)::text::geotaxoissue).*) as foo;

END;

$BODY$
	language plpgsql volatile
	cost 100;

------------------------------------------------------------------------------------------
-- Second overload



------------------------------------------------------------------------------------------
-- Main function

create or replace function public.geospatial_rangemap_issue
(
	in p_latitude double precision, -- the point's latitude value
	in p_longitude double precision, -- the point's longitude value
	in p_country text, -- the point's 2-character country_code
	in p_geom geometry(Point, 4326), -- the point's geometry value
	in p_sciname text, -- the scientific name the occurrence belongs to
	out nocoordinates boolean, -- true if the record has no coordinates
	out nocountry boolean, -- true if the record has no country
	out iszero boolean, -- true if coordinates are 0,0
	out isoutofworld boolean, -- true if absolute value of latitude is greater than 90
	out islowprecision boolean, -- true if less than 3 decimal figures in coordinates
	out isoutofcountry boolean, -- true if out of specified country
	out istransposed boolean, -- true if transposed (latitude value in longitude field and vice versa)
	out isnegatedlatitude boolean, -- true if latitude value is negated (true when should be false or viceversa)
	out isnegatedlongitude boolean, -- same as isnegatedlatitude but with longitude value
	out distance2country double precision, -- distance from point to closest edge of country polygon
	out distance2rangemap double precision -- distance from point to closest edge of range map polygon
)

as

$BODY$

BEGIN

	-- check if point has geom
	if p_geom is not null then

		-- run geospatial_issue
		-- check
		select into nocoordinates, nocountry, iszero, isoutofworld, islowprecision, isoutofcountry, istransposed, isnegatedlatitude, isnegatedlongitude, distance2country foo.nocoordinates, foo.nocountry, foo.iszero, foo.isoutofworld, foo.islowprecision, foo.isoutofcountry, foo.istransposed, foo.isnegatedlatitude, foo.isnegatedlongitude, foo.distance2country from (select (geospatial_issue(p_latitude, p_longitude, p_country, p_geom)::text::geospatialissue).*) as foo;
		
		-- run rangemap_inside_distance
		select into distance2rangemap dist from (select rangemap_inside_distance(p_sciname, p_geom) as dist) as foo;
		
	end if;

end;

$BODY$
	language plpgsql volatile
	cost 100;
