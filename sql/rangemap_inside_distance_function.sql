-- Function: public.rangemap_inside_distance(integer)
-- 
-- 
-- This function is called from geospatial_rangemap_issue. It returns a double precision
-- value that represents the closest distance between an occurrence point and the range map
-- for the species it belongs to. To improve performance, an inside/outside calculation is
-- done first, and if result is 'outside', then the actual distance is calculated.
-- 
-- This function needs an occurrenceid, as stored in the gbif_import table.
-- It returns a double precision value representing the distance
-- 
-- This function requires the following other functions to work:
-- a) rangemap_inside
-- b) rangemap_distance
-- 
-- And the following table:
-- a) the main GBIF occurrence points table
-- 
-- Author: Javier Otegui (javier.otegui@gmail.com)
-- 
-- 

DROP FUNCTION IF EXISTS public.rangemap_inside_distance(text, geometry); -- Main function: scientific name and point geometry
DROP FUNCTION IF EXISTS public.rangemap_inside_distance(geometry, text); -- First overload: point geometry and scientific name
DROP FUNCTION IF EXISTS public.rangemap_inside_distance(text, double precision, double precision); -- second overload: scientific name and coordinates
DROP FUNCTION IF EXISTS public.rangemap_inside_distance(double precision, double precision, text); -- third overload: coordinates and scientific name

-------------------------------------------------------------------
-- first overload

CREATE OR REPLACE FUNCTION public.rangemap_inside_distance
(
	IN p_geom geometry(Point, 4326),
	IN p_sciname text,
	OUT distance double precision
)

AS

$BODY$

BEGIN

    select into distance dist from (select rangemap_inside_distance(p_sciname, p_geom) as dist) as foo;

end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

-------------------------------------------------------------------
-- second overload

CREATE OR REPLACE FUNCTION public.rangemap_inside_distance
(
	IN p_sciname text,
	IN lat double precision,
	IN lon double precision,
	OUT distance double precision
)

AS

$BODY$

DECLARE
    p_geom geometry(Point, 4326);

BEGIN

    select into p_geom pointval from (select ST_SetSRID(ST_Point(lon, lat), 4326) as pointval) as foo;
    select into distance dist from (select rangemap_inside_distance(p_sciname, p_geom) as dist) as foo;

end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

-------------------------------------------------------------------
-- third overload

CREATE OR REPLACE FUNCTION public.rangemap_inside_distance
(
	IN lat double precision,
	IN lon double precision,
	IN p_sciname text,
	OUT distance double precision
)

AS

$BODY$

BEGIN

    select into distance dist from (select rangemap_inside_distance(p_sciname, lat, lon) as dist) as foo;

end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;

-------------------------------------------------------------------
-- Main function

create or replace function public.rangemap_inside_distance
(
	in p_sciname text,
	in p_geom geometry(Point, 4326),
	out dist double precision
)

as

$BODY$

DECLARE

	is_inside boolean := null;

BEGIN

	if p_geom is not null then
		-- check if point falls inside rangemap
		select into is_inside ins from (select rangemap_inside(p_sciname, p_geom) as ins) as foo;
		-- If rangemap_inside is null, we won't be able to calculate distance
		if is_inside is null then
			dist = null;
		-- If rangemap_inside is true, point falls inside rangemap, then dist is 0
		elsif is_inside is true then
			dist = 0;
		-- If rangemap_inside is false, we have to calculate distance
		else
			select into dist distance from (select rangemap_distance(p_sciname, p_geom) as distance) as foo;
		end if;
	end if;

end;

$BODY$
	language plpgsql stable
	cost 100;
