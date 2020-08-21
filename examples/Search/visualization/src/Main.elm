module Main exposing (..)

import Browser
import Browser.Events
import Html exposing (p, text)
import Json.Decode
import Process
import Search
import Search.Problem.Graph exposing (routeFinding)
import Search.Problem.NPuzzle as NPuzzle exposing (complexEightPuzzle, mediumEightPuzzle, simpleEightPuzzle, visualize)
import Search.Problem.Romania as Romania
import Search.Result exposing (Result(..))
import Search.Visualization.TreeMap as TreeMap
import Task


type alias State =
    List Int


type Msg
    = NewModel (Search.Model State State)
    | Show (Maybe ( Float, State ))
    | Move { x : Float, y : Float }


type alias Model =
    { searchModel : Search.Model State State
    , tooltip : TreeMap.Tooltip State
    }


main =
    Browser.document
        { view =
            \{ tooltip, searchModel } ->
                { title = "Breadth-first search of 8-Puzzle"
                , body = [ TreeMap.html Show NPuzzle.visualize (Just tooltip) searchModel ]
                }
        , init = init
        , update = update
        , subscriptions =
            \_ -> Browser.Events.onMouseMove (Json.Decode.map Move decodeMove)
        }


init : () -> ( Model, Cmd Msg )
init =
    \_ ->
        let
            initialModel =
                Search.bestFirst complexEightPuzzle
        in
        ( { searchModel = initialModel
          , tooltip = { node = Nothing, position = { x = 0, y = 0 } }
          }
        , searchTask initialModel
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg ({ tooltip } as model) =
    case msg of
        NewModel m ->
            ( { model | searchModel = m }
            , searchTask m
            )

        Show s ->
            ( { model | tooltip = { tooltip | node = s } }, Cmd.none )

        Move p ->
            ( { model | tooltip = { tooltip | position = p } }, Cmd.none )


decodeMove : Json.Decode.Decoder { x : Float, y : Float }
decodeMove =
    Json.Decode.map2 (\a b -> { x = a, y = b })
        (Json.Decode.field "pageX" Json.Decode.float)
        (Json.Decode.field "pageY" Json.Decode.float)


searchTask : Search.Model State State -> Cmd Msg
searchTask model =
    case model.solution of
        Pending ->
            Task.perform
                NewModel
                (Process.sleep 0
                    |> Task.andThen
                        (\_ -> Task.succeed (Search.nextN 50 model))
                )

        _ ->
            Cmd.none
