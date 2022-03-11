module Ui.Typography exposing (h1, h2, h3, h4)

import Html exposing (Html)
import Html.Attributes as Attr


h1 : String -> Html msg
h1 str =
    Html.h1 [ Attr.class "h1" ] [ Html.text str ]


h2 : String -> Html msg
h2 str =
    Html.h2 [ Attr.class "h2" ] [ Html.text str ]


h3 : String -> Html msg
h3 str =
    Html.h3 [ Attr.class "h3" ] [ Html.text str ]


h4 : String -> Html msg
h4 str =
    Html.h4 [ Attr.class "h4" ] [ Html.text str ]
