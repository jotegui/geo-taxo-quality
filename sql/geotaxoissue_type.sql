-- Custom data type to store the results
-- from the geospatial_issue function
-- 
-- author: Javier Otegui (javier.otegui@gmail.com)

drop type if exists geotaxoissue;

create type geotaxoissue as (
	noCoordinates boolean,
	noCountry boolean,
	isZero boolean,
	isOutofWorld boolean,
	isLowPrecision boolean,
	isOutOfCountry boolean,
	isTransposed boolean,
	isNegatedLatitude boolean,
	isNegatedLongitude boolean,
	distance2country double precision,
	distance2rangemap double precision
);
