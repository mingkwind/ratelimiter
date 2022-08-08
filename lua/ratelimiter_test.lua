local limit_req = require "mw_ratelimiter"

-- 速率为1req/s，松弛量为10req，表示可抵消的次数为10
local lim, err = limit_req.new("my_limit_req_store", 1, 10)


if not lim then
    ngx.log(ngx.ERR,
        "failed to instantiate a mw_ratelimiter object: ", err)
    return ngx.exit(500)
end

local key = "ratelimiter"


local token, err = lim:incoming(key)

if err ~= nil then
    ngx.log(ngx.ERR, "err: ", err)
    return ngx.exit(500)
else
    ngx.log(ngx.INFO, "token: ", token)
end
