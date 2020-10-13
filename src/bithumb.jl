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



function stats_24hr(symbol::String = "ALL")
    method = "GET"
    path = "public/ticker/"

    if symbol != "ALL"
        stats = request("GET", path * symbol)
        return (
            symbol = symbol,
            open_price = stats["data"]["opening_price"],
            close_price = stats["data"]["closing_price"],
            low_price = stats["data"]["min_price"],
            high_price = stats["data"]["max_price"],
            base_volume = stats["data"]["units_traded_24H"],
            quote_volume = stats["data"]["acc_trade_value"],
            time = unix2datetime(parse(Int64, stats["data"]["date"]) * 0.001),
        )
    end

    stats = request("GET", "public/ticker/all")["data"]
    result = Vector()

    for pair in stats
        if pair.first != "date"
            push!(
                result,
                (
                    symbol = pair.first * "_KRW",
                    open_price = parse(Float64, pair.second["opening_price"]),
                    close_price = parse(Float64, pair.second["closing_price"]),
                    low_price = parse(Float64, pair.second["min_price"]),
                    high_price = parse(Float64, pair.second["max_price"]),
                    base_volume = parse(Float64, pair.second["units_traded_24H"]),
                    quote_volume = parse(Float64, pair.second["acc_trade_value"]),
                    time = unix2datetime(parse(Int64, stats["date"]) * 0.001),
                ),
            )
        end
    end
    return result
end

function order_book(symbol::String)

    method = "GET"
    path = "public/orderbook/$(symbol)"
    result = request(method, path)["data"]

    return (
        base_currency = result["order_currency"],
        quote_currency = result["payment_currency"],
        bids = result["bids"],
        asks = result["asks"],
        time = unix2datetime(parse(Int64, result["timestamp"]) * 0.001),
    )
end


request("GET", "public/ticker/all")

function symbols()

    method = "GET"
    path = "public/ticker/all"

    res = request(method, path)["data"]

    result = filter!(x -> x != "date", unique(keys(res)))
    result = map(x -> x * "_KRW", result)
    return result
end

function balanses()
    method = "POST"
    path = "info/account"

    result = request(method, path, publickey(), secretkey(), true)
    return result
end

balanses()
