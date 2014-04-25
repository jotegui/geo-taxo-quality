-- Function: public.jot_get_tile_beta(text, text)

-- DROP FUNCTION public.jot_get_tile_beta(text, text);

CREATE OR REPLACE FUNCTION public.jot_get_tile_beta(IN text, IN text)
  RETURNS TABLE(cartodb_id integer, seasonality integer, presence integer, the_geom_webmercator geometry, country_code text) AS
$BODY$

  DECLARE sql TEXT;
  DECLARE shard_sql TEXT; 
  DECLARE data RECORD; -- a data table record
  DECLARE taxon RECORD;
  BEGIN
      IF $1 = 'mol' THEN
	RETURN QUERY SELECT * FROM get_species_tile($3);
      ELSE
	      --assemble some sql to get the tables we want. a a table was passed as a paramater, use that 
	      sql = 'SELECT * from data_registry WHERE dataset_id = ''' || $1 || '''';
	      --RETURN QUERY SELECT sql as sql;
	      FOR data in EXECUTE sql LOOP
		 IF data.type = 'range' or data.type = 'points' THEN
			sql := 'SELECT ' ||
			  ' cartodb_id, ' ||
			  ' CAST(' || data.seasonality || ' as int) as seasonality, ' || 
			  ' CAST(' || data.presence || ' as int) as presence, ' || 
			  data.geometry_field || 
			  ' FROM ' || data.table_name || 
			  ' WHERE ' ||  
			  data.scientificname || ' = ''' || $2 || '''';
			  RETURN query EXECUTE sql;           
		 ELSIF data.type = 'taxogeochecklist' or data.type = 'taxogeooccchecklist' THEN 		
			sql := 'SELECT ' ||
			  ' d.cartodb_id as cartodb_id, ' || 
			  ' CAST(' || data.seasonality || ' as int) as seasonality, ' || 
			  ' CAST(' || data.presence || ' as int) as presence, ' || 
			  ' g.' || data.geometry_field || 
			  ' FROM ' || data.table_name || ' d ' ||
			  ' JOIN ' || data.geom_table || ' g ON ' ||
			  '   d.' || data.geom_id || ' = g.' || data.geom_link_id  ||
			  ' JOIN ' || data.taxo_table || ' t ON ' ||
			  '   d.' || data.species_id || ' = t.' || data.species_link_id ||
			  ' WHERE ' || data.scientificname || ' = ''' || $2 || '''';
			  RETURN query EXECUTE sql;
		  ELSIF data.type = 'geochecklist' THEN 
			sql := 'SELECT ' ||
			  ' d.cartodb_id as cartodb_id, ' || 
			  ' CAST(' || data.seasonality || ' as int) as seasonality, ' || 
			  ' CAST(' || data.presence || ' as int) as presence, ' || 
			  ' g.' || data.geometry_field || 
			  ' FROM ' || data.table_name || ' d ' ||
			  ' JOIN ' || data.geom_table || ' g ON ' ||
			  '   d.' || data.geom_id || ' = g.' || data.geom_link_id  ||
			  ' where ' || data.scientificname || ' = ''' ||  $2 || '''';
			  RETURN query EXECUTE sql;
		   ELSIF data.type = 'taxoshardedocc' THEN
			sql:= 'SELECT DISTINCT ' || 
				data.shard_id || ' as shard_id, ' || data.species_id || ' as species_id ' ||  
			      ' FROM '|| data.taxo_table || ' WHERE ' || data.scientificname || '=''' || $2 || '''' ;
			--RETURN query SELECT sql as sql;
			shard_sql := ' ';
			FOR taxon in EXECUTE sql  LOOP
				shard_sql := 'SELECT ' ||
				  ' d.cartodb_id as cartodb_id, ' ||  --hack!
				  ' CAST(' || data.seasonality || ' as int) as seasonality, ' || 
				  ' CAST(' || data.presence || ' as int) as presence, ' || 
				  ' ' || data.geometry_field || ' as the_geom_webmercator, ' ||
				  ' country_code as country_code '
				  ' FROM ' || data.shard_prefix || taxon.shard_id || ' d ' ||
				  ' WHERE ' || data.species_link_id || '=' || taxon.species_id || ';';
				 RETURN query EXECUTE shard_sql;
			END LOOP;
			sql := shard_sql;
		   Else
			-- We got nuttin'
		  END IF;
		  --RETURN query SELECT sql as sql;
	          
		 
	       END LOOP;
       END IF;
    END

$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100
  ROWS 1000;
ALTER FUNCTION public.jot_get_tile_beta(text, text)
  OWNER TO "cartodb_user_b4ba2644-9de0-43d0-86fb-baf3b484ccd3";

