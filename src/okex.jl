module okex

using HTTP
using JSON
using Nettle
using Base64
using Dates
using Printf
using DataStructures

global const BASE_URL = "https://www.okex.com"

publickey() = ENV["OKEX-PUBLIC-KEY"]
secretkey() = ENV["OKEX-SECRET-KEY"]
passshare() = ENV["OKEX-PASSPHRASE"]

function public_request(
    method::String,
    request_path::String,
    query::OrderedDict
    )
    url = join([BASE_URL, request_path], "/")
    pairs = join(string.(keys(query),"=", values(query)), "&")
    curl = url * "?" * pairs

    response = HTTP.request(method, curl, query)
    json = JSON.parse(String(response.body))
    return json
end

public_request("GET", "api/spot/v3/instruments/BTC-USDT/book", OrderedDict("size"=> "50", "depth" => "0.1"))

function details()
    method = "GET"
    path = "api/spot/v3/instruments"

    result = public_request(method, path, OrderedDict())
    form =
        x -> (
            symbol = x["instrument_id"],
            base_currency = x["base_currency"],
            quote_currency = x["quote_currency"],
        )

    return map(form, result)
end

function stats_24hr(symbol::String = "ALL")
    method = "GET"

    if !isequal(symbol, "ALL")

        path = "api/spot/v3/instruments/$symbol/ticker"
        x = public_request(method, path, OrderedDict())

        return (
            symbol = x["instrument_id"],
            first_price = parse(Float64, x["open_24h"]),
            last_price = parse(Float64, x["last"]),
            high_price = parse(Float64, x["high_24h"]),
            low_price = parse(Float64, x["low_24h"]),
            base_volume = parse(Float64, x["base_volume_24h"]),
            quote_volume = parse(Float64, x["quote_volume_24h"]),
            time = x["timestamp"],
        )
    end

    path = "api/spot/v3/instruments/ticker"
    result = public_request(method, path, OrderedDict())

    form =
        x -> (
            symbol = x["instrument_id"],
            first_price = parse(Float64, x["open_24h"]),
            last_price = parse(Float64, x["last"]),
            high_price = parse(Float64, x["high_24h"]),
            low_price = parse(Float64, x["low_24h"]),
            base_volume = parse(Float64, x["base_volume_24h"]),
            quote_volume = parse(Float64, x["quote_volume_24h"]),
            time = x["timestamp"],
        )
    return map(form, result)
end

function order_book(symbol::String, size::Int = 200, depth::Float64 = 0.1)

    method = "GET"
    path = "api/spot/v3/instruments/$symbol/book"
    query = OrderedDict("size" => size, "depth" => depth)

    result = public_request(method, path, query)
    return result
end

function symbols()
    method = "GET"
    path = "api/spot/v3/instruments"

    result = public_request(method, path, OrderedDict())

    return  map(x -> x["instrument_id"], result)
end

function historical_trades(symbol::String, limit::Int = 100)
    method = "GET"
    path = "api/spot/v3/instruments/$symbol/trades"
    query = OrderedDict("limit" => limit)

    result = public_request(method, path, query)
    form =
        x -> (
            price = parse(Float64, x["price"]),
            size = parse(Float64, x["size"]),
            side = x["side"],
            time = x["time"],
            trade_id = parse(Int64, x["trade_id"]),
        )
    return map(form, result)
end


#period = [60/180/300/900/1800/3600/7200/14400/21600/43200/86400/604800] =>
#[1 minute, 3 minutes, 5 minutes, 15 minutes, 30 minutes, 1 hour, 2 hours, 4 hours, 6 hours, 12 hours, 1 day, 1 week,1 month ,3 months, 6 months and 1 year]
#max = 200

function klines(
    symbol::String,
    period::Int64 = 60, #1minute candle,
    start::Union{TimeType,Missing} = missing,
    finish::Union{TimeType,Missing} = missing,
)

    method = "GET"
    path = "api/spot/v3/instruments/$symbol/candles"
    format = "yyyy-mm-ddTHH:MM:SS.sss"

    form =
        x -> (
            open = parse(Float64, x[2]),
            high = parse(Float64, x[3]),
            low = parse(Float64, x[4]),
            close = parse(Float64, x[5]),
            candle_volume = parse(Float64, x[6]),
            time = DateTime(x[1][1:length(x[1])-1], format),
        )

    if isequal(start, missing) && isequal(finish, missing)
        query = OrderedDict("granularity" => period)
        result = public_request(method, path, query)
        return map(form, result)
    end

    query = OrderedDict(
        "granularity" => period,
        "start" => string(start) * "Z",
        "end" => string(finish) * "Z",
    )

    result = public_request(method, path, query)

    return map(form, result)
end
