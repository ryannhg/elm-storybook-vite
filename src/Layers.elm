module Layers exposing
    ( Model
    , Msg
    , closeMenu
    , idForItem
    , init
    , toggleMenu
    , update
    , view
    )

import AssocList as Dict exposing (Dict)
import Browser.Dom
import Html.Styled as Html exposing (Html)
import Html.Styled.Attributes as Attr
import Html.Styled.Events as Events
import Task
import Time
import Ui


type Model item
    = Model { open : Dict item Data }


type alias Data =
    { id : String
    , parent : Maybe Browser.Dom.Element
    }


init : Model item
init =
    Model { open = Dict.empty }



-- UPDATE


type Msg item
    = Open item
    | Close item
    | CloseAll
    | GotTime item Time.Posix
    | GotElement item Id (Result Browser.Dom.Error Browser.Dom.Element)


update :
    { model : Model item
    , msg : Msg item
    , toAppMsg : Msg item -> msg
    , toAppModel : Model item -> model
    }
    -> ( model, Cmd msg )
update options =
    Tuple.mapBoth
        options.toAppModel
        (Cmd.map options.toAppMsg)
        (update_ options.msg options.model)


toggleMenu :
    { item : item
    , model : Model item
    , toAppMsg : Msg item -> msg
    , toAppModel : Model item -> model
    }
    -> ( model, Cmd msg )
toggleMenu options =
    let
        (Model model) =
            options.model
    in
    update
        { msg =
            if Dict.member options.item model.open then
                Close options.item

            else
                Open options.item
        , model = options.model
        , toAppModel = options.toAppModel
        , toAppMsg = options.toAppMsg
        }


closeMenu :
    { item : item
    , model : Model item
    , toAppMsg : Msg item -> msg
    , toAppModel : Model item -> model
    }
    -> ( model, Cmd msg )
closeMenu options =
    update
        { msg = Close options.item
        , model = options.model
        , toAppModel = options.toAppModel
        , toAppMsg = options.toAppMsg
        }


update_ : Msg item -> Model item -> ( Model item, Cmd (Msg item) )
update_ msg (Model model) =
    case msg of
        Open item ->
            ( Model model
            , Time.now
                |> Task.perform (GotTime item)
            )

        GotTime item posix ->
            let
                id : Id
                id =
                    fromPosixToId posix
            in
            ( Model
                { open =
                    Dict.insert item
                        { id = id
                        , parent = Nothing
                        }
                        model.open
                }
            , Browser.Dom.getElement id
                |> Task.attempt (GotElement item id)
            )

        GotElement item id (Ok parent) ->
            ( Model
                { model
                    | open =
                        Dict.insert item
                            { id = id
                            , parent = Just parent
                            }
                            model.open
                }
            , Cmd.none
            )

        GotElement _ _ (Err (Browser.Dom.NotFound _)) ->
            -- Ignore ID not found errors
            ( Model model, Cmd.none )

        Close item ->
            ( Model { model | open = Dict.remove item model.open }, Cmd.none )

        CloseAll ->
            ( Model { model | open = Dict.empty }, Cmd.none )



-- VIEW


view :
    { model : Model item
    , toAppMsg : Msg item -> msg
    , viewAppLayer : Ui.Html msg
    , viewLayerItem : String -> item -> Browser.Dom.Element -> Ui.Html msg
    }
    -> Ui.Html msg
view options =
    let
        (Model model) =
            options.model

        viewTopLayer : List (Html msg)
        viewTopLayer =
            if Dict.isEmpty model.open then
                []

            else
                viewDismissLayer :: viewLayerItems

        viewLayerItems : List (Html msg)
        viewLayerItems =
            List.foldl
                (\( index, ( item, data ) ) list ->
                    case data.parent of
                        Just parent ->
                            options.viewLayerItem (toMenuId index) item parent :: list

                        Nothing ->
                            list
                )
                []
                (List.indexedMap Tuple.pair (Dict.toList model.open))

        viewDismissLayer : Html msg
        viewDismissLayer =
            Html.div
                [ Attr.class "elm-layers__dismiss"
                , Events.onClick (CloseAll |> options.toAppMsg)
                ]
                []
    in
    Html.div [ Attr.class "elm-layers" ]
        [ Html.node "style"
            []
            [ Html.text (String.trim """
.elm-layers__z1 { position: relative; z-index: 1; }
.elm-layers__z2 { position: relative; z-index: 2; }
.elm-layers__z3 { position: relative; z-index: 3; }
.elm-layers__z4 { position: relative; z-index: 4; }
.elm-layers__dismiss { position: fixed; top: 0; left: 0; right: 0; bottom: 0; }

.elm-layers__modal { position: fixed; }
.elm-layers__modal--center { top: 50%; left: 50%; transform: translate(-50%, -50%); }

.elm-layers__parent { position: fixed; }

.elm-layers__dropdown { position: absolute; top: 100%;  }
.elm-layers__dropdown--left { left: 0; }
.elm-layers__dropdown--right { right: 0; }
        """)
            ]
        , Html.div [ Attr.class "elm-layers__z1" ] [ options.viewAppLayer ]
        , Html.div [ Attr.class "elm-layers__z2" ] viewTopLayer
        ]


viewButton :
    { item : item
    , model : Model item
    , toAppMsg : Msg item -> msg
    }
    -> List (Html.Attribute msg)
    -> List (Html msg)
    -> Html msg
viewButton options attributes children =
    Html.button (attributes ++ attributesFor options) children



-- INTERNALS


toMenuId : Int -> String
toMenuId index =
    "elm-layers-menu-" ++ String.fromInt (index + 1)


attributesFor :
    { item : item
    , model : Model item
    , toAppMsg : Msg item -> msg
    }
    -> List (Html.Attribute msg)
attributesFor options =
    let
        (Model model) =
            options.model

        attributes : List (Html.Attribute msg)
        attributes =
            [ Events.onClick (Open options.item |> options.toAppMsg)
            , Attr.class "elm-layers__button"
            ]
    in
    case Dict.get options.item model.open of
        Just data ->
            Attr.id data.id :: attributes

        Nothing ->
            attributes


idForItem : item -> Model item -> Maybe String
idForItem item (Model model) =
    Dict.get item model.open
        |> Maybe.map .id



-- ID


type alias Id =
    String


fromPosixToId : Time.Posix -> Id
fromPosixToId posix =
    posix
        |> Time.posixToMillis
        |> String.fromInt
        |> String.append "elm-layer__"