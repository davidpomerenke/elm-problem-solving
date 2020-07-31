module Search.Problems.NPuzzle exposing (NPuzzleError(..), empty, fromList, nPuzzle, random, simpleEightPuzzle)

import List exposing (all, concat, length, map, member, range)
import List.Extra exposing (elemIndex, getAt, swapAt)
import Maybe.Extra exposing (values)
import Random exposing (initialSeed, step)
import Search exposing (Problem, Solution(..))


type alias State =
    List Int


vertical : Int -> State -> Maybe State
vertical d state =
    elemIndex 0 state |> Maybe.map (\a -> swapAt a (a + d) state)


up : Int -> State -> Maybe State
up s =
    vertical -s


down : Int -> State -> Maybe State
down s =
    vertical s


horizontal : Int -> State -> Maybe State
horizontal d state =
    elemIndex 0 state |> Maybe.map (\a -> swapAt a (a + d) state)


left : State -> Maybe State
left =
    horizontal -1


right : State -> Maybe State
right =
    horizontal 1


type NPuzzleError
    = NotQuadratic
    | NoPermutationOfRange


sideLength : State -> Float
sideLength state =
    sqrt (toFloat (length state))


goal : State -> List Int
goal state =
    range 0 (length state - 1)


checkState : State -> Result NPuzzleError State
checkState s =
    if sideLength s /= toFloat (round (sideLength s)) then
        Err NotQuadratic

    else if not (all (\a -> member a s) (goal s)) then
        Err NoPermutationOfRange

    else
        Ok s


nPuzzle : State -> Problem State
nPuzzle validState =
    let
        s =
            round (sideLength validState)
    in
    { initialState = validState
    , actions =
        \state ->
            [ up s, down s, left, right ]
                |> map (\f -> f state)
                |> values
                |> map (\a -> ( 1, a ))
    , goalTest = \state -> state == goal validState
    }


empty : Problem State
empty =
    { initialState = []
    , actions = \_ -> []
    , goalTest = \_ -> False
    }


fromList : List Int -> Result NPuzzleError (Problem State)
fromList l =
    Result.map nPuzzle (checkState l)


simpleEightPuzzle : Problem State
simpleEightPuzzle =
    nPuzzle <|
        concat
            [ [ 1, 4, 2 ]
            , [ 3, 0, 5 ]
            , [ 6, 7, 8 ]
            ]



-- RANDOM GENERATION


randomLoop : Int -> Random.Seed -> Int -> State -> State
randomLoop size seed n a =
    if n > 0 then
        let
            ( r, newSeed ) =
                step (Random.int 0 3) seed
        in
        case Maybe.map (\f -> f a) (getAt r [ up size, down size, left, right ]) of
            Just (Just aa) ->
                randomLoop size newSeed (n - 1) aa

            _ ->
                randomLoop size newSeed n a

    else
        a


random : Int -> Int -> Int -> Problem State
random length steps seed =
    List.Extra.initialize length identity
        |> randomLoop (round (sqrt (toFloat length))) (initialSeed seed) steps
        |> nPuzzle
