import requests
import json

api_url = 'https://jot-mol-qualityapi.appspot.com/_ah/api/qualityapi/v1/geospatial'

def geospatial_flags(latitude, longitude, country, binomial):
    url = '/'.join([api_url, str(latitude), str(longitude), str(country), str(binomial)])
    r = requests.get(url)
    if r.status_code == 200:
        content = json.loads(r.content)
        flags = {}
        keys = [x for x in content if x != 'kind' and x != 'etag']
        for key in keys:
            flags[key] = content[key]
        return flags
    else:
        print 'Something went wrong. Status code: {0}'.format(r.status_code)
        print 'Content of the request: {0}'.format(r.content)
        return None

if __name__ == "__main__":
    
    latitude = -50.2667
    longitude = -72
    country = 'Argentina'
    binomial = 'Puma concolor'
    
    flags = geospatial_flags(latitude, longitude, country, binomial)
