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

drop function if exists public.rangemap_inside_distance(bigint);

create or replace function public.rangemap_inside_distance
(
	in p_id bigint,
	out dist double precision
)

as

$BODY$

DECLARE

	p_geom geometry(Point,4326) := null;
	p_taxonid integer := null;
	is_inside boolean := null;

BEGIN

	-- check if point has geom and store
	select into p_geom geom from (select the_geom as geom from gbif_import where occurrenceid=p_id) as foo;
	if p_geom is not null then
		-- store taxonid
		select into p_taxonid taxonid from (select taxonid from gbif_import where occurrenceid=p_id) as foo;
		-- check if point falls inside rangemap
		select into is_inside ins from (select rangemap_inside(p_taxonid, p_geom) as ins) as foo;
		-- If rangemap_inside is null, we won't be able to calculate distance
		if is_inside is null then
			dist = null;
		-- If rangemap_inside is true, point falls inside rangemap, then dist is 0
		elsif is_inside is true then
			dist = 0;
		-- If rangemap_inside is false, we have to calculate distance
		else
			select into dist distance from (select rangemap_distance(p_taxonid, p_geom) as distance) as foo;
		end if;
	end if;

end;

$BODY$
	language plpgsql stable
	cost 100;
alter function public.rangemap_inside_distance(bigint)
	owner to javiero;
comment on function public.rangemap_inside_distance(bigint) is '';
