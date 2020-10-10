module huobi

using HTTP
using JSON
using Nettle
using Base64
using Dates
using Printf
using DataStructures
using StringEncodings

global const BASE_URL = "https://api.huobi.pro"

publickey() = ENV["HUOBI-PUBLIC-KEY"]
secretkey() = ENV["HUOBI-SECRET-KEY"]


function signature(secret::String, query::String)

    sha256 = HMACState("sha256", secret)
    Nettle.update!(sha256, query)

    return base64encode(Nettle.hexdigest!(sha256))
end





#Public requests

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

function order_book(symbol::String, type::String="step0")
    _path = "market/depth"
    url = join([BASE_URL, _path], "/")
    params = "?symbol=$(lowercase(symbol))&type=$type"
    response = HTTP.request("GET", url * params)
    json = JSON.parse(String(response.body))
    return json["tick"]
end

function klines(symbol::String, period::String, size::Int)
    _path = "market/history/kline"
    point = join([BASE_URL, _path], "/")
    params = "period=$period&size=$size&symbol=$(lowercase(symbol))"
    curl = join([point, params], "?")
    response = HTTP.request("GET", curl)
    json = JSON.parse(String(response.body))
    return json["data"]
end

function historical_trades(symbol::String, size::Int)
    _path = "market/history/trade"
    point = join([BASE_URL, _path], "/")
    params = "symbol=$(lowercase(symbol))&size=$size"
    curl = join([point, params], "?")
    response = HTTP.request("GET", curl)
    json = JSON.parse(String(response.body))
    return json["data"]
end

#Signed requests

# function accounts()
_path = "v1/account/accounts"

query = OrderedDict("AccessKeyId" => publickey(),
                    "SignatureMethod" => "HmacSHA256",
                    "SignatureVersion" => "2",
                    "Timestamp" => HTTP.escapeuri(string(round(DateTime(now(UTC)), Dates.Second(1)))))

pre_sigened = "GET\napi.huobi.pro\n/v1/account/accounts\n"
query = join(string.(keys(query), "=" , values(query)), "&")
params = string(pre_sigened, join(string.(keys(query), "=" , values(query)), "&"))

res = HTTP.request("GET", string(BASE_URL, "/", _path, "?", query, "&Signature=", signature(secretkey(), params)))
json = JSON.parse(String(res.body))
# end
end
round(DateTime(now(UTC)), Dates.Second(1))
