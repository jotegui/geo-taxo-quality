﻿-- Function: public.rangemap_inside(integer, point, text)
-- 
--  
-- 
-- This function is called from rangemap_inside_distance. It calculates whether the given point
-- is inside the range map for the species t belongs to.
-- 
-- This function needs a taxon id to determine which IUCN range map to use,
-- and the geometry of the occurrence point.
-- 
-- It returns a boolean (t/f) value indicating whether the point falls inside the range map.
-- 
-- This function requires the following tables to work:
-- a) The IUCN expert range maps, divided into single class tables
-- b) The GBIF taxonomy table, to decode the taxon id
-- c) Meyer's synonymy tables, to add synonymy resolution capability
-- 
-- Author: Javier Otegui (javier.otegui@gmail.com)
-- 
-- 

DROP FUNCTION IF EXISTS public.rangemap_inside(integer, geometry);

CREATE OR REPLACE FUNCTION public.rangemap_inside
(
	IN p_taxonid integer,
	IN p_geom geometry(Point, 4326),
	OUT inside boolean
)

AS

$BODY$

DECLARE

	noTaxonid boolean := false;
	noGeom boolean := false;
	p_sciname text := Null; -- Scientific name of the record
	p_class text := Null; -- Class associated to the p_sciname
	v_sciname text := null; -- "Valid" scientific name, extracted from Meyer's synonymy table
	v_class text := null; -- Class associated to the v_sciname
	good_name text := null; -- Placeholder for the name that exists in IUCN table, either p_sciname or v_sciname
	p_iucntable text := null; -- Name of the IUCN table in which the function should search or p_sciname
	p_iucnfield text := null; -- Name of the field that contains the scientific name in the IUCN table
	num_geo integer := null; -- Number of polygons in the iucn table associated with p_sciname
	is_within integer := null; -- Value to check if the point falls within any polygon and distance calculation can, thus, be avoided

BEGIN

	-- Check if taxonid exists
	if p_taxonid is null then
		noTaxonid = True;
	end if;
	-- Check if the_geom exists
	if p_geom is null then
		noGeom = True;
	end if;
	-- Check if Coordinates are 0,0 to avoid the calculation
	if ST_X(p_geom) = 0 and ST_Y(p_geom) = 0 then
		noGeom = True;
	end if;

	-- Continue only if taxonid and the_geom exist and if point is not 0,0
	if noTaxonid is false and noGeom is false then

		-- extract scientific name and class
		select into p_sciname scientificname from (select scientificname from gbif_import_taxonomy where taxonid=p_taxonid) as foo;
		select into p_class class from (select class from gbif_import_taxonomy where taxonid=p_taxonid) as foo;

		-- check if scientific name exists
		if p_sciname is not null then

			-- extract valid scientific name and class from synonymy table
			select into v_sciname mol_scientificname from (select mol_scientificname from synonyms_carsten_n10 where upper(scientificname) = upper(p_sciname)) as foo;
			select into v_class class from (select class from gbif_import_taxonomy where upper(scientificname) = upper(v_sciname)) as foo;
			
			-- Build the p_iucntable and p_iucnfield variables based on p_class and v_class
			-- If class is not among IUCN tables, avoid calculation
			if p_class is not null then
				if p_class = 'Amphibia' then
					p_iucntable = 'iucn_amphibians';
					p_iucnfield = 'binomial';
				elsif p_class = 'Aves' then
					p_iucntable = 'iucn_species2011_birds';
					p_iucnfield = 'binomial';
				elsif p_class = 'Mammalia' then
					p_iucntable = 'iucn_mammals';
					p_iucnfield = 'binomial';
				elsif p_class = 'Reptilia' then
					p_iucntable = 'iucn_species2011_reptiles';
					p_iucnfield = 'binomial';
				elsif p_class = 'Holocephali' then
					p_iucntable = 'iucn_species2011_fish';
					p_iucnfield = 'binomial';
				elsif p_class = 'Elasmobranchii' then
					p_iucntable = 'iucn_species2011_fish';
					p_iucnfield = 'binomial';
				elsif p_class = 'Actinopterygii' then
					p_iucntable = 'iucn_species2011_fish';
					p_iucnfield = 'binomial';
				elsif p_class = 'Myxini' then
					p_iucntable = 'iucn_species2011_fish';
					p_iucnfield = 'binomial';
				elsif p_class = 'Magnoliopsida' then
					p_iucntable = 'iucn_species2011_plants';
					p_iucnfield = 'binomial';
				else
					inside = NULL;
				end if;
			elsif v_class is not null then
				if v_class = 'Amphibia' then
					p_iucntable = 'iucn_amphibians';
					p_iucnfield = 'binomial';
				elsif v_class = 'Aves' then
					p_iucntable = 'iucn_species2011_birds';
					p_iucnfield = 'binomial';
				elsif v_class = 'Mammalia' then
					p_iucntable = 'iucn_mammals';
					p_iucnfield = 'binomial';
				elsif v_class = 'Reptilia' then
					p_iucntable = 'iucn_species2011_reptiles';
					p_iucnfield = 'binomial';
				elsif v_class = 'Holocephali' then
					p_iucntable = 'iucn_species2011_fish';
					p_iucnfield = 'binomial';
				elsif v_class = 'Elasmobranchii' then
					p_iucntable = 'iucn_species2011_fish';
					p_iucnfield = 'binomial';
				elsif v_class = 'Actinopterygii' then
					p_iucntable = 'iucn_species2011_fish';
					p_iucnfield = 'binomial';
				elsif v_class = 'Myxini' then
					p_iucntable = 'iucn_species2011_fish';
					p_iucnfield = 'binomial';	
				elsif v_class = 'Magnoliopsida' then
					p_iucntable = 'iucn_species2011_plants';
					p_iucnfield = 'binomial';				
				else
					inside = NULL;
				end if;
			end if;

			-- check if p_sciname exists in corresponding iucn_table
			if p_iucntable is not null then
				execute 'select count(*) from (select '
				|| p_iucnfield
				|| ' from '
				|| p_iucntable
				|| ' where upper('
				|| p_iucnfield
				|| ') = upper('''
				|| p_sciname
				|| ''') limit 1 ) as base;'
				into num_geo using p_iucntable, p_iucnfield, p_sciname;

				if num_geo = 1 then
					good_name = p_sciname;
				elsif v_sciname is not null then
					-- if not, check v_sciname
					execute 'select count(*) from (select '
					|| p_iucnfield
					|| ' from '
					|| p_iucntable
					|| ' where upper('
					|| p_iucnfield
					|| ') = upper('''
					|| v_sciname
					|| ''') limit 1 ) as base;'
					into num_geo using p_iucntable, p_iucnfield, v_sciname;

					if num_geo = 1 then
						good_name = v_sciname;
					end if;
				end if;
				
				-- check if either p_sciname or v_sciname exist in the iucn_table
				if good_name is not null then
					-- check if point falls inside any polygon of good_name's range map
					EXECUTE 'select count(*) from (select ST_DWithin('''
					|| p_geom::TEXT
					|| ''', the_geom, 0) as intersects from '
					|| p_iucntable
					|| ' where upper('
					|| p_iucnfield
					|| ')=upper('''
					|| good_name
					|| ''')) as foo where intersects is True;'
					into is_within using p_geom, good_name, p_iucntable, p_iucnfield;

					-- if is_within is true, we are done
					if is_within > 0 then
						inside = true;
					else
						inside = false;
					end if;
				end if;
			end if;
		end if;
	end if;
end;
$BODY$
  LANGUAGE plpgsql STABLE
  COST 100;
