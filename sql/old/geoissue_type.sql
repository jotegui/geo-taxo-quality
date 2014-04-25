-- Custom data type to store the results
-- from the geospatial_issue function
-- 
-- author: Javier Otegui (javier.otegui@gmail.com)

create type geoissue as (
	noCoordinates boolean,
	noCountry boolean,
	isZero boolean,
	isOutofWorld boolean,
	isLowPrecision boolean,
	isOutOfCountry boolean,
	isTransposed boolean,
	isNegatedLatitude boolean,
	isNegatedLongitude boolean,
	dist double precision 
);
