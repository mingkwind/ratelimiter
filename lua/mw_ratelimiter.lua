local ffi = require "ffi"
local math = require "math"


local ngx_shared = ngx.shared
local ngx_now = ngx.now
local setmetatable = setmetatable
local ffi_cast = ffi.cast
local ffi_str = ffi.string
local abs = math.abs
local tonumber = tonumber
local type = type
local assert = assert
local max = math.max


ffi.cdef [[
    struct mw_limit_req_rec {
        uint64_t            last;
        int64_t             sleepfor;
        uint8_t             lock;
    };
]]

local const_rec_ptr_type = ffi.typeof("struct mw_limit_req_rec*")
local rec_size = ffi.sizeof("struct mw_limit_req_rec")

local _M = {
    _VERSION = '0.01'
}


local mt = {
    __index = _M
}


function _M.new(dict_name, rate, burst)
    local dict = ngx_shared[dict_name]
    if not dict then
        return nil, "shared dict not found"
    end

    assert(rate > 0 and burst >= 0)

    local self = {
        dict = dict,
        perrequest = 1000 / rate, -- 表示每个请求之间的间隔，单位为ms
        burst = burst, -- 表示松弛量允许抵消的请求次数
    }

    return setmetatable(self, mt)
end

function _M.incoming(self, key)
    local dict = self.dict
    local perrequest = self.perrequest
    local burst = self.burst
    local now = ngx_now() * 1000 -- 时间戳，单位为ms
    local v = dict:get(key)
    if not v then
        local rec_cdata = ffi.new("struct mw_limit_req_rec")
        rec_cdata.last = now
        rec_cdata.sleepfor = 0
        rec_cdata.lock = 0
        dict:set(key, ffi_str(rec_cdata, rec_size))
        return now, nil
    else
        if type(v) ~= "string" or #v ~= rec_size then
            return nil, "shdict abused by other users"
        end
        local rec_ptr = ffi_cast(const_rec_ptr_type, v)
        -- 自旋锁，防止多个请求同时访问同一个key
        while rec_ptr.lock ~= 0 do
            ngx.sleep(0.001)
            v = dict:get(key)
            rec_ptr = ffi_cast(const_rec_ptr_type, v)
        end
        rec_ptr.lock = 1
        dict:set(key, ffi_str(rec_ptr, rec_size))
        local last = tonumber(rec_ptr.last)
        local sleepfor = tonumber(rec_ptr.sleepfor)
        -- 如果上次请求还没有结束，则等待

        sleepfor = sleepfor + perrequest - abs(now - last)
        if sleepfor > 0 then
            ngx.sleep(sleepfor / 1000)
            rec_ptr.last = now + sleepfor
            rec_ptr.sleepfor = 0
        else
            rec_ptr.last = now
            rec_ptr.sleepfor = max(sleepfor, -burst * perrequest)
        end

        rec_ptr.lock = 0
        dict:set(key, ffi_str(rec_ptr, rec_size))

        return tonumber(rec_ptr.last), nil
    end
end

-- lim:set_rate(rate)
function _M.set_rate(self, rate)
    assert(rate > 0)
    self.perrequest = 1000 / rate
end

-- lim:set_burst(burst)
function _M.set_burst(self, burst)
    assert(burst >= 0)
    self.burst = burst * 1000
end

return _M
