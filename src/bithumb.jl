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


#Sign requests

function private_request(
    request_path::String,
    query::OrderedDict,
    public::String,
    secret::String
)
    pairs =join(string.(keys(query),"=", HTTP.URIs.escapeuri.(values(query))), "&")
	tunix = datetime2unix(now(UTC))
	nonce = string(Int64(round(1000 * tunix)))

	data = query["endpoint"] * Char(0) * pairs * Char(0) * nonce
	hmac = HMACState("sha512", secret)
	Nettle.update!(hmac, data)

	url = BASE_URL * request_path

	params = [
		"Api-Key" => public,
		"Api-Sign" => Base64.base64encode(Nettle.hexdigest!(hmac)),
		"Api-Nonce" => nonce,
		"Content-Type" => "application/x-www-form-urlencoded"
	]
	response = HTTP.post(url, params, pairs, status_exception=false)

	json = JSON.parse(String(response.body))

    return json
end


function balance()
	path = "/info/balance"
	query = OrderedDict("endpoint" => path)

	result = private_request(path, query, publickey(), secretkey())
	return result["data"]
end





#Public requests
function public_request(
    method::String,
    request_path::String
)
    url = join([BASE_URL, request_path], "/")

    response = HTTP.request(method, url, query = query,
                            status_exception=false)

    json = JSON.parse(String(response.body))

    return json
end

function details(symbol = "ALL")
    method = "GET"
    path = "public/ticker/all"

    details = public_request(method, path)

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
        stats = public_request("GET", path * symbol)
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

    stats = public_request("GET", "public/ticker/all")["data"]
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
    result = public_request(method, path)["data"]

    return (
        base_currency = result["order_currency"],
        quote_currency = result["payment_currency"],
        bids = result["bids"],
        asks = result["asks"],
        time = unix2datetime(parse(Int64, result["timestamp"]) * 0.001),
    )
end

function symbols()

    method = "GET"
    path = "public/ticker/all"

    res = public_request(method, path)["data"]

    result = filter!(x -> x != "date", unique(keys(res)))
    result = map(x -> x * "_KRW", result)
    return result
end
