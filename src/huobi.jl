module huobi

using HTTP
using JSON
using Nettle
using Base64
using Dates
using Printf
using DataStructures

global const BASE_URL = "https://api.huobi.pro"


function details()
    endpoint = "/v1/common/symbols"
    response = HTTP.request("GET", string(BASE_URL, endpoint))
    json = JSON.parse(String(response.body))
    symbols = map(
        x -> x["symbol"],
        filter(
            x -> x["state"] == "online" && x["api-trading"] == "enabled",
            json["data"],
        ),
    )
    base_currency = map(
        x -> x["base-currency"],
        filter(
            x -> x["state"] == "online" && x["api-trading"] == "enabled",
            json["data"],
        ),
    )
    quote_currency = map(
        x -> x["quote-currency"],
        filter(
            x -> x["state"] == "online" && x["api-trading"] == "enabled",
            json["data"],
        ),
    )
    return (
        symbols = symbols,
        base_currency = base_currency,
        quote_currency = quote_currency,
    )
end

function stats_24hr(symbol::String)
    path = "market/detail/merged"
    url = join([BASE_URL, path], "/")
    params = "symbol=$(lowercase(symbol))"
    curl = join([url, params], "?")
    response = HTTP.request("GET", curl)
    jsn = JSON.parse(String(response.body))
    return jsn["tick"]["vol"]
end

function order_book(symbol::String, depth::Int64)
    path = "/market/depth"
    url = join([BASE_URL, path], "/")
    
end
