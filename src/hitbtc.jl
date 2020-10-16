module hitbtc

using HTTP
using JSON
using Nettle
using Base64
using Dates
using Printf
using DataStructures

global const BASE_URL = "https://api.hitbtc.com"

publickey() = ENV["HITBTC-PUBLIC-KEY"]
secretkey() = ENV["HITBTC-SECRET-KEY"]

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

function details()
    method = "GET"
    path = "api/2/public/symbol"

    result = public_request(method, path, OrderedDict())
    form =
        x -> (
            symbol = x["id"],
            base_currency = x["baseCurrency"],
            quote_currency = x["quoteCurrency"],
   )

    return map(form, result)
end


function stats_24hr(symbol::String = "ALL")
    method = "GET"
    path = "api/2/public/ticker"

    format = "yyyy-mm-ddTHH:MM:SS.sss"
    form =
        x -> (
            symbol = x["symbol"],
            first_price = x["open"],
            last_price = x["last"],
            high_price = x["high"],
            low_price = x["low"],
            base_volume = x["volume"],
            quote_volume = x["volumeQuote"],
            time = DateTime(x["timestamp"][1:length(x["timestamp"])-1], format),
        )
    if !isequal(symbol, "ALL")
        path = "api/2/public/ticker/$symbol"

        x = public_request(method, path, OrderedDict())
        return (
            symbol = x["symbol"],
            first_price = x["open"],
            last_price = x["last"],
            high_price = x["high"],
            low_price = x["low"],
            base_volume = x["volume"],
            quote_volume = x["volumeQuote"],
            time = DateTime(x["timestamp"][1:length(x["timestamp"])-1], format),
        )
    end
    result = public_request(method, path, OrderedDict())
    return map(form, result)
end
stats_24hr()

function order_book(symbol::String)

end  # module hitbtc
