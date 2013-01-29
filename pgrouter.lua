-- 
-- A simple API adapter for using postgresql internal subreq in a reusable manner
--
-- Copyright Tor Hveem <thveem> 2013
--

--local cjson = require "cjson"


-- The function sending subreq to nginx postgresql location with rds_json on
-- returns json body to the caller
local function dbreq(sql)
    ngx.log(ngx.ERR, 'SQL: ' .. sql)
    local dbreq = ngx.location.capture("/pg", { args = { sql = sql } })
    local json = dbreq.body
    return json
end

local function max(match)
    local key = ngx.req.get_uri_args()['key']
    if not key then ngx.exit(403) end
    -- Make sure valid request, only accept plain lowercase ascii string for key name
    keytest = ngx.re.match(key, '[a-z]+', 'oj')
    if not keytest then ngx.exit(403) end

    local sql = "SELECT date_trunc('day', timestamp) AS timestamp, MAX("..key..") AS "..key.." FROM wd WHERE date_part('year', timestamp) < 2013 GROUP BY 1"
    
    ngx.print(dbreq(sql))
    return ngx.HTTP_OK
end

local function index()
    ngx.print(dbreq("SELECT * FROM wd WHERE date_part('year', timestamp) >= 2013 ORDER BY timestamp"))
    return ngx.HTTP_OK
end

local function year(match)
    local year = match[1]
    ngx.print(dbreq([[
        SELECT 
            date_trunc('day', timestamp) AS timestamp,
            AVG(temp) as temp,
            MAX(daily_rain) as daily_rain,
            AVG(avg_speed) as avg_speed,
            AVG(winddir) as winddir,
            AVG(barometer) as barometer
        FROM wd 
        WHERE date_part('year', timestamp) = ]]..year..[[
        GROUP BY 1
        ORDER BY 1
        ]]))
    return ngx.HTTP_OK
end

-- mapping patterns to queries
local routes = {
    ['max']  = max,
    ['year/([0-9]{4})'] = year,
    ['$']    = index,
}
-- Set the content type
ngx.header.content_type = 'application/json';
-- Our URL base, must match location in nginx config
local BASE = '/api/'
-- iterate route patterns and find view
for pattern, view in pairs(routes) do
    local uri = '^' .. BASE .. pattern
    local match = ngx.re.match(ngx.var.uri, uri, "oj") -- regex mather in compile mode
    if match then
        exit = view(match) or ngx.HTTP_OK
        ngx.exit( exit )
    end
end
-- no match, return 404
ngx.exit( ngx.HTTP_NOT_FOUND )
