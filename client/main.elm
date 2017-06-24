-- Read more about this program in the official Elm guide:
-- https://guide.elm-lang.org/architecture/effects/http.html


module Main exposing (..)

import Bootstrap.Alert as Alert
import Bootstrap.Button as Button
import Bootstrap.ButtonGroup as ButtonGroup
import Bootstrap.CDN as CDN
import Bootstrap.Form as Form
import Bootstrap.Form.Input as Input
import Bootstrap.Form.InputGroup as InputGroup
import Bootstrap.Form.Textarea as Textarea
import Bootstrap.Grid as Grid
import Bootstrap.Grid.Col as Col
import Bootstrap.ListGroup as ListGroup
import Bootstrap.Table as Table
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
    , votes : List User
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
    | Interface
        { yourQuestions : List Question
        , allQuestions : List Question
        , saved : SaveState
        }


type alias Model =
    { screen : Screen
    , user : User
    , week : Int
    }


init : ( Model, Cmd Msg )
init =
    ( { screen = Loading
      , user = "default"
      , week = 2
      }
    , usersCmd
    )


type Msg
    = HazUsers (Result Http.Error (List User))
    | SwitchUser User
    | ChangeUser User
    | GetQuestions
    | HazQuestions (Result Http.Error (List Question))
    | NewQuestion
    | DeleteQuestion
    | EditQuestion Int String
    | DoSave


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

        GetQuestions ->
            ( model, getQuestionsCmd )

        HazQuestions (Ok qs) ->
            ( { model
                | screen =
                    Interface
                        { yourQuestions = List.filter (\q -> q.week == model.week && q.user == model.user) qs
                        , allQuestions = List.sortBy (\q -> q.week) qs
                        , saved = Saved
                        }
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
                Interface screen ->
                    ( { model
                        | screen =
                            Interface
                                { screen
                                    | yourQuestions =
                                        screen.yourQuestions
                                            |> List.reverse
                                            |> (\l -> Question model.user model.week "" [] :: l)
                                            |> List.reverse
                                    , saved = NotSaved
                                }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        DeleteQuestion ->
            case model.screen of
                Interface screen ->
                    ( { model
                        | screen =
                            Interface
                                { screen
                                    | yourQuestions =
                                        screen.yourQuestions
                                            |> List.reverse
                                            |> List.drop 1
                                            |> List.reverse
                                    , saved = NotSaved
                                }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        EditQuestion i string ->
            case model.screen of
                Interface screen ->
                    ( { model
                        | screen =
                            Interface
                                { screen
                                    | yourQuestions =
                                        List.indexedMap
                                            (\qi ->
                                                \q ->
                                                    if i == qi then
                                                        { q | text = string }
                                                    else
                                                        q
                                            )
                                            screen.yourQuestions
                                    , saved = NotSaved
                                }
                      }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        DoSave ->
            case model.screen of
                Interface { yourQuestions } ->
                    ( model
                    , saveQuestions model.user model.week yourQuestions
                    )

                _ ->
                    ( model, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    case model.screen of
        Loading ->
            Alert.info [ text "Loading" ]

        Login { users, user } ->
            Grid.container []
                [ h2 [] [ text "Login" ]
                , h4 [] [ text "Existing Users" ]
                , ButtonGroup.buttonGroup [ ButtonGroup.vertical ]
                    (List.map
                        (\u ->
                            ButtonGroup.button
                                [ Button.outlinePrimary, Button.onClick (SwitchUser u) ]
                                [ text u ]
                        )
                        users
                    )
                , br [] []
                , br [] []
                , h4 [] [ text "New Users" ]
                , Form.formInline
                    []
                    [ Input.text [ Input.placeholder "username", Input.onInput ChangeUser ]
                    , Button.button
                        [ Button.outlinePrimary
                        , Button.onClick (SwitchUser user)
                        ]
                        [ text "Create" ]
                    ]
                ]

        ShowError e ->
            Alert.danger [ code [] [ e |> toString |> text ] ]

        Interface data ->
            Grid.container []
                [ Grid.row []
                    --                    [ Grid.col [ Col.md6 ] [ text "hi" ]
                    --                    , Grid.col [ Col.md6 ] [ text "bye" ]
                    --                    ]
                    [ Grid.col [ Col.xl8 ] [ viewAllQuestions data.allQuestions ]
                    , Grid.col [ Col.xl4 ] [ viewEditor data.yourQuestions data.saved ]
                    ]
                ]


viewAllQuestions : List Question -> Html Msg
viewAllQuestions qs =
    div []
        [ h2 [] [ text "All Questions" ]
        , Table.simpleTable
            ( Table.simpleThead
                [ Table.th [] [ text "Week" ]
                , Table.th [] [ text "User" ]
                , Table.th [] [ text "Question" ]
                ]
            , Table.tbody []
                (List.map
                    (\q ->
                        Table.tr []
                            [ Table.td [] [ q.week |> toString |> text ]
                            , Table.td [] [ q.user |> text ]
                            , Table.td [] [ q.text |> text ]
                            ]
                    )
                    qs
                )
            )
        ]


viewEditor : List Question -> SaveState -> Html Msg
viewEditor qs saved =
    div []
        [ h2 [] [ text "Your questions" ]
        , ButtonGroup.toolbar []
            [ ButtonGroup.buttonGroupItem []
                [ ButtonGroup.button
                    [ Button.outlineSecondary
                    , Button.onClick NewQuestion
                    ]
                    [ text "+" ]
                , ButtonGroup.button
                    [ Button.outlineSecondary
                    , Button.onClick DeleteQuestion
                    ]
                    [ text "-" ]
                , ButtonGroup.button
                    [ Button.outlineSuccess
                    , Button.onClick DoSave
                    , Button.disabled (saved == Saved)
                    ]
                    [ text "Save" ]
                ]
            , ButtonGroup.buttonGroupItem []
                [ ButtonGroup.button [ Button.outlineWarning, Button.onClick GetQuestions ]
                    [ text "Reload Saved Questions" ]
                ]
            ]
        , div []
            (List.indexedMap
                (\i ->
                    \q ->
                        let
                            qname =
                                "Question " ++ toString i
                        in
                        Form.form []
                            [ Form.group []
                                [ Form.label [ for qname ] [ text (qname ++ " ") ]
                                , Textarea.textarea
                                    [ Textarea.id qname
                                    , Textarea.onInput (EditQuestion i)
                                    , Textarea.rows 5
                                    , Textarea.defaultValue q.text
                                    ]
                                ]
                            ]
                )
                qs
            )
        , br [] []
        , br [] []
        , case saved of
            Saved ->
                Alert.success [ text "These have been saved" ]

            NotSaved ->
                Alert.warning [ text "These are not saved" ]
        ]



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none



-- HTTP


host : String
host =
    "ec2-54-183-112-131.us-west-1.compute.amazonaws.com:9876"



-- "134.173.42.255:9876"
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



--getQuestionsCmd : User -> Int -> Cmd Msg
--getQuestionsCmd user week =
--    let
--        url =
--            "http://" ++ host ++ "/questions/" ++ user ++ "/" ++ toString week ++ "/"
--    in
--    Http.send HazQuestions (Http.get url (Decode.list questionDecoder))


saveQuestions : User -> Int -> List Question -> Cmd Msg
saveQuestions user week qs =
    let
        url =
            "http://" ++ host ++ "/questions/" ++ user ++ "/" ++ toString week ++ "/"
    in
    Http.send HazQuestions
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
    Decode.map4 Question
        (Decode.field "user" Decode.string)
        (Decode.field "week" Decode.int)
        (Decode.field "text" Decode.string)
        (Decode.field "votes" (Decode.list Decode.string))
