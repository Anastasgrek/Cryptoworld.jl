module Cryptoworld

# Write your package code here.

include("huobi.jl")
using .huobi

include("bithumb.jl")
using .bithumb
end
