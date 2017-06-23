-- Read more about this program in the official Elm guide:
-- https://guide.elm-lang.org/architecture/effects/http.html


module Main exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Decode
import Json.Encode as Encode


main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }



-- MODEL


type alias Question =
    { user : User
    , week : Int
    , text : String
    }


type alias User =
    String


type SaveState
    = Saved
    | NotSaved


type Screen
    = Loading
    | Login
        { users : List User
        , user : User
        }
    | ShowError Http.Error
    | EditThisWeek (List Question) SaveState



--    | ViewAll List Question


type alias Model =
    { screen : Screen
    , user : User
    , week : Int
    }


init : ( Model, Cmd Msg )
init =
    ( { screen = Loading
      , user = "default"
      , week = 1
      }
    , usersCmd
    )



-- UPDATE
--    | GetAll
--    | PostThisWeek User Int List Question
--    | GetAll List Question
--    | GetThisWeek List Question
--    | Posted


type Msg
    = HazUsers (Result Http.Error (List User))
    | SwitchUser User
    | ChangeUser User
    | HazQuestions (Result Http.Error (List Question))
    | EditQuestion Int String
    | NewQuestion
    | DeleteQuestion
    | DoSave
    | SaveDone (Result Http.Error (List Question))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        SwitchUser user ->
            ( { model
                | screen = Loading
                , user = user
              }
            , getQuestionsCmd
            )

        HazUsers (Ok users) ->
            ( { model
                | screen =
                    Login
                        { users = users
                        , user = ""
                        }
              }
            , Cmd.none
            )

        HazUsers (Err e) ->
            ( { model
                | screen = ShowError e
              }
            , Cmd.none
            )

        ChangeUser user ->
            case model.screen of
                Login { users } ->
                    ( { model
                        | screen = Login { users = users, user = user }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        HazQuestions (Ok qs) ->
            ( { model
                | screen = EditThisWeek qs Saved
              }
            , Cmd.none
            )

        HazQuestions (Err e) ->
            ( { model
                | screen = ShowError e
              }
            , Cmd.none
            )

        NewQuestion ->
            case model.screen of
                EditThisWeek qs _ ->
                    ( { model
                        | screen = EditThisWeek (qs |> List.reverse |> (\l -> Question model.user model.week "" :: l) |> List.reverse) NotSaved
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        DeleteQuestion ->
            case model.screen of
                EditThisWeek qs _ ->
                    ( { model
                        | screen = EditThisWeek (qs |> List.reverse |> List.drop 1 |> List.reverse) NotSaved
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        EditQuestion i string ->
            case model.screen of
                EditThisWeek qs _ ->
                    ( { model
                        | screen =
                            EditThisWeek
                                (List.indexedMap
                                    (\qi ->
                                        \q ->
                                            if i == qi then
                                                { q | text = string }
                                            else
                                                q
                                    )
                                    qs
                                )
                                NotSaved
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        DoSave ->
            case model.screen of
                EditThisWeek qs _ ->
                    ( model
                    , saveQuestions model.user model.week qs
                    )

                _ ->
                    ( model, Cmd.none )

        SaveDone (Ok qs) ->
            case model.screen of
                EditThisWeek _ _ ->
                    ( { model
                        | screen = EditThisWeek qs Saved
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        SaveDone (Err e) ->
            ( { model
                | screen = ShowError e
              }
            , Cmd.none
            )



--        MorePlease ->
--            ( model, getRandomGif model.topic )
--
--        NewGif (Ok newUrl) ->
--            ( Model model.topic newUrl, Cmd.none )
--
--        NewGif (Err _) ->
--            ( model, Cmd.none )
-- VIEW


view : Model -> Html Msg
view model =
    case model.screen of
        Loading ->
            p [] [ text "Loading" ]

        Login { users, user } ->
            div []
                [ h2 [] [ text "Login" ]
                , h4 [] [ text "Existing Users" ]
                , ul [] (List.map (\u -> li [ value u ] [ text u ]) users)
                , label [ for "loginUser" ] [ text "Who are you? " ]
                , input [ name "loginUser", onInput ChangeUser ] []
                , button [ onClick (SwitchUser user) ] [ text "Login" ]
                ]

        ShowError e ->
            pre [] [ e |> toString |> text ]

        EditThisWeek qs saveState ->
            div []
                [ p [] [ text ("Hi " ++ model.user) ]
                , h2 [] [ text "Your questions for this week" ]
                , button [ onClick NewQuestion ] [ text "+" ]
                , button [ onClick DeleteQuestion ] [ text "-" ]
                , button [ onClick DoSave ] [ text "Save" ]
                , div []
                    (List.indexedMap
                        (\i ->
                            \q ->
                                let
                                    qname =
                                        "Q" ++ toString i
                                in
                                div []
                                    [ label [ for qname ] [ text (qname ++ " ") ]
                                    , textarea
                                        [ name qname
                                        , onInput (EditQuestion i)
                                        , rows 4
                                        , cols 50
                                        ]
                                        [ text q.text ]
                                    ]
                        )
                        qs
                    )
                , p []
                    [ text
                        (case saveState of
                            NotSaved ->
                                "These are not saved"

                            Saved ->
                                "These have been saved"
                        )
                    ]
                ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP


host : String
host =
    "134.173.42.255:9876"



--"www.cs.hmc.edu:9876"


usersCmd : Cmd Msg
usersCmd =
    let
        url =
            "http://" ++ host ++ "/users"
    in
    Http.send HazUsers (Http.get url (Decode.list Decode.string))


getQuestionsCmd : Cmd Msg
getQuestionsCmd =
    let
        url =
            "http://" ++ host ++ "/questions"
    in
    Http.send HazQuestions (Http.get url (Decode.list questionDecoder))


saveQuestions : User -> Int -> List Question -> Cmd Msg
saveQuestions user week qs =
    let
        url =
            "http://" ++ host ++ "/questions/" ++ user ++ "/" ++ toString week ++ "/"
    in
    Http.send SaveDone
        (Http.post url
            (qs |> List.map questionEncoder |> Encode.list |> Http.jsonBody)
            (Decode.list questionDecoder)
        )



-- Encoding & Decoding


questionEncoder : Question -> Encode.Value
questionEncoder question =
    Encode.object
        [ ( "user", Encode.string question.user )
        , ( "week", Encode.int question.week )
        , ( "text", Encode.string question.text )
        ]


questionDecoder : Decode.Decoder Question
questionDecoder =
    Decode.map3 Question
        (Decode.field "user" Decode.string)
        (Decode.field "week" Decode.int)
        (Decode.field "text" Decode.string)
