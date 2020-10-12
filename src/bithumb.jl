module bithumb

using HTTP
using JSON
using Nettle
using Base64
using Dates
using Printf
using DataStructures

global const BASE_URL = "https://api.bithumb.com"

publickey() = ENV["BITHUMB-PUBLIC-KEY"]
secretkey() = ENV["BITHUMB-SECRET-KEY"]

function signature(secret::String, query::AbstractDict)
    pairs = join(string.(keys(query), "=", values(query)), "&")

    sha256 = HMACState("sha256", secret)
    Nettle.update!(sha256, pairs)

    return Nettle.hexdigest!(sha256)
end

function request(
    method::String,
    request_path::String,
    query::AbstractDict,
    publickey::Union{Missing,String},
    secretkey::Union{Missing,String},
    private::Bool
)
    url = join([BASE_URL, request_path], "/")

    if private && !ismissing(publickey) && !ismissing(secretkey)
        tunix = datetime2unix(now(UTC))
        ts = OrderedDict("timestamp" => Int64(round(1000 * tunix)))

        sign = OrderedDict("signature" => signature(secretkey, query))
        query = merge(query, sign)
    end
    response = HTTP.request(method, url, query = query,
                            status_exception=false)

    json = JSON.parse(String(response.body))

    return json
end

request(
    method::String,
    request_path::String,
    query::AbstractDict = OrderedDict(),
    private::Bool = true
) = request(method, request_path, query, publickey(), secretkey(), private)


function details(symbol = "ALL")
    method = "GET"
    path = "public/ticker/all"

    details = request(method, path)

    result = map(content -> begin
                (symbol =content * "_KRW",
                base_currency = content,
                quote_currency = "KRW")
            end, keys(details["data"]) |> unique)

    !isequal(symbol, "ALL") &&
        return filter!(x -> isequal(x.symbol, symbol), result)[1]

    return result
end
map(x -> x.symbol, details())
info = request("GET", "public/ticker/BTC_KRW")
date = unix2datetime(parse(Int64, info["data"]["date"]) * 0.001)
function stats_24hr(symbol::String = "ALL")
    method = "GET"
    path = "public/ticker/"

    symbols = map(x -> x.symbol, details())
    for symbol in symbols
        details = request(method, path * symbol)

        time = unix2datetime(parse(Int64, details["data"]["date"]) * 0.001),
        open_price = details["data"]["opening_price"],
        close_price = details["data"]["closing_price"],
        low_price = details["data"]["min_price"],
        high_price = details["data"]["max_price"],
        base_volume = details["data"]["units_traded_24H"],
        quote_volume = details["data"]["acc_trade_value_24H"]


    con = x -> (
            time = unix2datetime(parse(Int64, x["date"]) * 0.001),
            open_price = x["opening_price"],
            close_price = x["closing_price"],
            low_price = x["min_price"],
            high_price = x["max_price"],
            base_volume = x["units_traded_24H"],
            quote_volume = x["acc_trade_value_24H"],
    )
