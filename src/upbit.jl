module upbit

using HTTP
using JSON
using Nettle
using Base64
using Dates
using Printf
using DataStructures

global const BASE_URL = "https://api.upbit.com"

publickey() = ENV["UPBIT-PUBLIC-KEY"]
secretkey() = ENV["UPBIT-SECRET-KEY"]

function balances()
    path = "/v1/accounts"
    tunix = datetime2unix(now(UTC))
    nonce = string(Int64(round(1000 * tunix)))

    payload = OrderedDict(
        "access_key" => publickey(),
        "nonce" => nonce
    )
    hmac = HMACState("sha256", secretkey())
    Nettle.update!(hmac, payload)

    authorize_token = Dict("Bearer" => Nettle.hexdigest!(hmac))
    headers = ["Authorization": authorize_token]
    res = HTTP.request("GET", BASE_URL * path, headers=headers)
    json = JSON.parse(String(res.body))
end

function public_request(
    method::String,
    request_path::String,
    query::OrderedDict
)
    url = join([BASE_URL, request_path], "/")

    pairs  = join(string.(keys(query),"=", values(query)), "&")
    curl = url * "?" * pairs
    response = HTTP.request(method, curl , status_exception=false)

    json = JSON.parse(String(response.body))

    return json
end

function public_request(
    method::String,
    request_path::String
)
    url = join([BASE_URL, request_path], "/")

    curl = url
    response = HTTP.request(method, curl , status_exception=false)

    json = JSON.parse(String(response.body))

    return json
end


function details()
    method = "GET"
    path = "v1/market/all"

    result = public_request(method, path)
    res = Vector()
    for data in result
        symbol = data["market"]
        base_currency = split(symbol, "-")[2]
        quote_currency = split(symbol, "-")[1]

        push!(res, (symbol=symbol, base_currency=base_currency, quote_currency=quote_currency))
    end
    return res
end

function stats_24hr(symbol::String)

    method = "GET"
    _path = "v1/ticker"

    query = ["markets" => symbol] |> OrderedDict
    result = public_request(method, _path, query)[1]

    return (
        symbol = result["market"],
        open_price = result["opening_price"],
        close_price = result["prev_closing_price"],
        low_price = result["low_price"],
        high_price = result["high_price"],
        base_volume = result["acc_trade_volume_24h"],
        quote_volume = result["trade_volume"],
        time = unix2datetime(result["timestamp"] * 0.001),
    )
end

function order_book(symbol::String)
    method = "GET"
    path = "v1/orderbook"
    query = ["markets" => symbol] |> OrderedDict
    result = public_request(method, path, query)[1]
    return result
end

function symbols()
    method = "GET"
    path = "v1/market/all"

    result = public_request(method, path)
    symbol = map(x -> x["market"], result)
    return symbol
end


function historical_trades(symbol::String, count::Union{Missing,Int}, daysAgo::Union{Missing,String})
    method = "GET"
    path = "v1/trades/ticks"

    query = OrderedDict("market" => symbol,
                        "count"  => count,
                        "daysAgo"=> daysAgo)
    result = public_request(method, path, query)
    return result
end

function klines(symbol::String, period::String, count::Int)
    method = "GET"
    path = "v1/candles/$period"

    query = OrderedDict("market" => symbol, "count" => count)
    result = public_request(method, path, query)
end


end  # module upbit
