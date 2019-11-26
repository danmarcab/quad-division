port module Ports exposing (downloadSvg, windowResizes)


port downloadSvg : String -> Cmd msg


port windowResizes : ({ width : Int, height : Int } -> msg) -> Sub msg
