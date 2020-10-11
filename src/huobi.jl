module huobi

using HTTP
using JSON
using Nettle
using Base64
using Dates
using Printf
using DataStructures

global const BASE_URL = "https://api.huobi.pro"

publickey() = ENV["HUOBI-PUBLIC-KEY"]
secretkey() = ENV["HUOBI-SECRET-KEY"]


function signature(
    method::AbstractString,
    host::AbstractString,
    path::AbstractString,
    query::AbstractDict,
    secret::AbstractString
)
    pairs = join(string.(keys(query),"=", HTTP.URIs.escapeuri.(values(query))), "&")
    str_query = join([method, host, path, pairs], "\n")

    hmac = HMACState("sha256", secret)
    Nettle.update!(hmac, str_query)

    Base64.base64encode(Nettle.digest!(hmac))
end



function request(
    method::String,
    path::String,
    query::AbstractDict,
    public::Union{Missing,String},
    secret::Union{Missing,String},
)

    @debug "request" method path (;zip(keys(query) .|> Symbol, values(query))...)...

    !(method ∈ ["GET", "POST"]) &&
        error("unknown method $method")

    timestamp = Dates.format(now(UTC), "yyyy-mm-ddTHH:MM:SS")

    params = [
        "AccessKeyId" => public,
        "SignatureMethod" => "HmacSHA256",
        "SignatureVersion" => 2,
        "Timestamp" => timestamp
    ] |> OrderedDict

    path = "/" * path
    host = HTTP.URI(BASE_URL).host
    url = string(BASE_URL, path)

    isequal(method, "GET") &&
        merge!(params, query)

    params["Signature"] =
        signature(method, host, path, params, secret)

    response = if method == "GET"
        HTTP.request(method, url, query=params, status_exception=false)
    else
        jsn = isempty(query) ? "" : JSON.json(query)
        HTTP.request(method, url, query=params, jsn, status_exception=false)
    end

    json = JSON.parse(String(response.body))

    if haskey(json, "status")
        if json["status"] == "error"
            error(string(
                json["err-msg"], " ",
                JSON.json(query)
            ))
        end
    end

    if haskey(json, "code")
        if json["code"] != 200
            error(string(
                JSON.json(query)
            ))
        end
    end

    @debug "response" method path (;zip(keys(json) .|> Symbol, values(json))...)...

    return json
end

request(
    method::String,
    path::String,
    query::AbstractDict = OrderedDict()
) = request(method, path, query, publickey(), secretkey())

#Signed requests

accounts() =
    request("GET", "v1/account/accounts", OrderedDict())

function balances(type::String)
    response = accounts()
    filter!(x-> x["type"] == "$type", response["data"])
    account_id = map(x -> x["id"], response["data"])[1]
    request("GET", "v1/account/accounts/$account_id/balance", OrderedDict())
end

function balance(currency::String, type::String)
    response = balances("$type")
    for cur in response["data"]["list"]
        if currency == cur["currency"]
            return cur["balance"]
        else
            nothing
        end
    end
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

end
