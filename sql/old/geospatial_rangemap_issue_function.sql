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
-- a) geoissue
-- 
-- And the following table:
-- a) the main GBIF occurrence points table
-- 
-- Author: Javier Otegui (javier.otegui@gmail.com)
-- 
-- 

drop function if exists public.geospatial_rangemap_issue(bigint);

create or replace function public.geospatial_rangemap_issue
(
	in p_id bigint, -- the point's occurrence id
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

	p_geom geometry(Point,4326) := null;
	p_latitude double precision := null;
	p_longitude double precision := null;
	p_country text := null;
	p_taxonid integer := null;

BEGIN

	-- check if point has geom and store
	select into p_geom geom from (select the_geom as geom from gbif_import where occurrenceid=p_id) as foo;
	if p_geom is not null then
		-- store oher values
		select into p_latitude latitude from (select latitudeinterpreted as latitude from gbif_import where occurrenceid=p_id) as foo;
		select into p_longitude longitude from (select longitudeinterpreted as longitude from gbif_import where occurrenceid=p_id) as foo;
		select into p_country country from (select countryisointerpreted as country from gbif_import where occurrenceid=p_id) as foo;
		select into p_taxonid taxonid from (select taxonid from gbif_import where occurrenceid=p_id) as foo;

		-- run geospatial_issue
		-- check
		select into nocoordinates, nocountry, iszero, isoutofworld, islowprecision, isoutofcountry, istransposed, isnegatedlatitude, isnegatedlongitude, distance2country foo.nocoordinates, foo.nocountry, foo.iszero, foo.isoutofworld, foo.islowprecision, foo.isoutofcountry, foo.istransposed, foo.isnegatedlatitude, foo.isnegatedlongitude, foo.dist from (select (geospatial_issue(p_latitude, p_longitude, p_country, p_geom)::text::geoissue).*) as foo;
		
		-- run rangemap_inside_distance
		select into distance2rangemap dist from (select rangemap_inside_distance(p_id) as dist) as foo;
		
	end if;

end;

$BODY$
	language plpgsql stable
	cost 100;
