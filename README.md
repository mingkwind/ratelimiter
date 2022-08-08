基于openresty的限速器

# 使用

使用ratelimiter

ratelimiter_test.lua

```lua
local limit_req = require "mw_ratelimiter"

-- 速率为1req/s，松弛量为10req，表示可抵消的次数为10
local lim, err = limit_req.new("my_limit_req_store", 1, 10)


if not lim then
    ngx.log(ngx.ERR,
        "failed to instantiate a my_rate object: ", err)
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
```

nginx.conf在access_by_lua阶段设置限速限流器

```nginx
http {
    include mime.types;
    # 配置lua模块路径
    lua_package_path "lua/?.lua;;";
    # 用于调试时用off
    lua_code_cache on;
    # 配置ratelimiter
    lua_shared_dict my_limit_req_store 100m;
    access_by_lua_file  lua/ratelimiter_test.lua;

    server {
        listen 80;
        server_name localhost;

        location /check {
            default_type text/html;
            content_by_lua_block {
                ngx.say("timestamp: "..ngx.now()*1000)
            }
        }
    }
}
```

# 测试

sh test.sh

```shell
a=0
while [ $a -le 100 ]
do
curl http://localhost/check
a=$[a+1]
done
```

