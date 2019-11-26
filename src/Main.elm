module Main exposing (Model, Msg, init, subscriptions, update, view)

import Browser
import Config exposing (Config)
import Element exposing (Element)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import FeatherIcons
import Html exposing (Html)
import Ports
import QuadDivision as QuadDivision exposing (Viewport)
import Random
import Time


type alias Model =
    { config : Config
    , settings : Settings
    , settingsOpen : Bool
    , fullScreen : Bool
    , running : Bool
    , internal : QuadDivision.Model
    , elmUIEmbedded : Bool
    }


type alias Settings =
    { updateEvery : Float
    }


type Msg
    = Tick
    | InitSeed Int
    | UpdateEveryChanged Float
    | InternalSettingChanged QuadDivision.SettingChange
    | Pause
    | Resume
    | Restart
    | OpenSettings
    | CloseSettings
    | EnterFullScreen
    | ExitFullScreen
    | DownloadSvg
    | ViewPortResized Viewport


init : { elmUIEmbedded : Bool, viewport : Viewport } -> ( Model, Cmd Msg )
init { elmUIEmbedded, viewport } =
    ( { config = Config.fromViewport viewport
      , settings =
            { updateEvery = 100
            }
      , settingsOpen = False
      , fullScreen = False

      -- this should be false but set to True due to a bug with subscriptions not triggering
      , running = True
      , internal =
            QuadDivision.initialize
                { initialSeed = 1
                , viewport = viewport
                , settings =
                    { separation = 5
                    , quantity = QuadDivision.About 50
                    }
                }
      , elmUIEmbedded = elmUIEmbedded
      }
    , Random.generate InitSeed anyInt
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick ->
            if QuadDivision.done model.internal then
                ( { model | running = False }
                , Cmd.none
                )

            else
                ( { model | internal = QuadDivision.subdivideStep model.internal }
                , Cmd.none
                )

        InitSeed seed ->
            ( { model | internal = QuadDivision.setSeed seed model.internal, running = True }
            , Cmd.none
            )

        UpdateEveryChanged newVal ->
            let
                oldSettings =
                    model.settings

                newSettings =
                    { oldSettings | updateEvery = newVal }
            in
            ( { model | settings = newSettings }
            , Cmd.none
            )

        InternalSettingChanged settingChange ->
            ( { model | internal = QuadDivision.changeSetting settingChange model.internal }
            , Cmd.none
            )

        Pause ->
            ( { model | running = False }
            , Cmd.none
            )

        Resume ->
            ( { model | running = True }
            , Cmd.none
            )

        Restart ->
            ( { model | internal = QuadDivision.restart model.internal, running = True }
            , Cmd.none
            )

        OpenSettings ->
            ( { model | settingsOpen = True }
            , Cmd.none
            )

        CloseSettings ->
            ( { model | settingsOpen = False }
            , Cmd.none
            )

        EnterFullScreen ->
            ( { model | fullScreen = True }
            , Cmd.none
            )

        ExitFullScreen ->
            ( { model | fullScreen = False }
            , Cmd.none
            )

        DownloadSvg ->
            ( model
            , Ports.downloadSvg "quad-division"
            )

        ViewPortResized newViewport ->
            ( resize newViewport model, Cmd.none )


resize : Viewport -> Model -> Model
resize viewport model =
    { model
        | config = Config.fromViewport viewport
        , internal = QuadDivision.resize viewport model.internal
        , running = True
    }


view : Model -> Html Msg
view model =
    Element.layoutWith
        { options =
            if model.elmUIEmbedded then
                [ Element.noStaticStyleSheet ]

            else
                []
        }
        [ Element.width Element.fill
        , Element.height Element.fill
        , Element.inFront (foregroundView model.config model)
        , Font.family [ Font.typeface "Roboto" ]
        ]
    <|
        Element.map never <|
            Element.html (QuadDivision.view model.internal)


foregroundView : Config -> Model -> Element Msg
foregroundView config model =
    let
        settings =
            alignedRight <| settingsView config model

        controls =
            alignedRight <| controlsView config model

        alignedRight el =
            Element.el
                [ Element.alignRight
                ]
                el
    in
    Element.el
        [ Element.width Element.fill
        , Element.height Element.fill
        ]
        (Element.column
            [ Element.spacing config.spacing.tiny
            , Element.alignRight
            , Element.alignBottom
            ]
         <|
            if model.fullScreen then
                [ controls ]

            else
                [ settings
                , controls
                ]
        )


controlsView : Config -> Model -> Element Msg
controlsView config model =
    let
        button msg iconType =
            Input.button [ Element.padding config.spacing.tiny ]
                { onPress = Just msg
                , label = icon iconType
                }

        restartButton =
            button Restart FeatherIcons.refreshCw

        downloadButton =
            button DownloadSvg FeatherIcons.download

        pauseButton =
            button Pause FeatherIcons.pause

        resumeButton =
            button Resume FeatherIcons.play

        settingsButton =
            button
                (if model.settingsOpen then
                    CloseSettings

                 else
                    OpenSettings
                )
                FeatherIcons.settings

        enterFullScreenButton =
            button EnterFullScreen FeatherIcons.maximize

        exitFullScreenButton =
            button ExitFullScreen FeatherIcons.minimize

        githubLink =
            Element.newTabLink [ Element.padding config.spacing.tiny ]
                { url = "https://github.com/danmarcab/quad-division"
                , label = icon FeatherIcons.github
                }

        buttons =
            [ restartButton
            , if QuadDivision.done model.internal then
                downloadButton

              else if model.running then
                pauseButton

              else
                resumeButton
            , settingsButton
            , githubLink
            , enterFullScreenButton
            ]
    in
    Element.column
        [ Element.padding config.spacing.tiny
        , Background.color (Element.rgba255 0 0 0 0.75)
        , Font.color (Element.rgba255 255 255 255 1)
        , Border.roundEach
            { topLeft = config.spacing.small
            , topRight = 0
            , bottomLeft = 0
            , bottomRight = 0
            }
        , Font.size config.fontSize.large
        , Font.bold
        , Element.spacing config.spacing.tiny
        ]
    <|
        if model.fullScreen then
            [ exitFullScreenButton ]

        else
            [ Element.el
                [ Element.padding config.spacing.tiny
                , Element.centerX
                ]
              <|
                Element.text "Quad Division"
            , Element.row
                [ Element.spacing config.spacing.tiny
                , Element.centerX
                ]
                buttons
            ]


settingsView : Config -> Model -> Element Msg
settingsView config model =
    Element.el
        [ Element.alignLeft
        , Element.centerY
        , Element.width Element.shrink
        , Background.color (Element.rgba255 0 0 0 0.8)
        , Font.color (Element.rgba255 255 255 255 1)
        , Border.roundEach
            { topLeft = config.spacing.small
            , topRight = 0
            , bottomLeft = config.spacing.small
            , bottomRight = 0
            }
        , Font.size config.fontSize.medium
        ]
    <|
        if model.settingsOpen then
            openSettingsView config model

        else
            Element.none


openSettingsView : Config -> Model -> Element Msg
openSettingsView config model =
    Element.column
        [ Element.spacing config.spacing.medium
        , Element.padding config.spacing.medium
        , Element.width Element.shrink
        ]
    <|
        [ Element.el
            [ Element.width Element.fill
            , Border.widthEach { top = 0, right = 0, left = 0, bottom = 1 }
            , Element.paddingEach { top = 0, right = 0, left = 0, bottom = config.spacing.small }
            ]
          <|
            Element.row [ Element.width Element.fill ]
                [ Element.el [ Font.size config.fontSize.large ] <|
                    Element.text "Settings"
                , Input.button (buttonStyle ++ [ Element.alignRight, Element.alignTop ])
                    { onPress = Just CloseSettings, label = Element.text "Close" }
                ]
        , Input.radioRow [ Element.spacing config.spacing.medium ]
            { onChange = UpdateEveryChanged
            , options =
                List.map
                    (\( num, lab ) -> radioOption config num <| Element.text lab)
                    [ ( 25, "Fast" ), ( 100, "Medium" ), ( 500, "Slow" ) ]
            , selected = Just model.settings.updateEvery
            , label =
                Input.labelAbove
                    [ Font.size config.fontSize.medium
                    , Element.paddingEach { top = 0, left = 0, right = 0, bottom = config.spacing.tiny }
                    ]
                <|
                    Element.text "Subdivision speed"
            }
        ]
            ++ internalSettingsView config model.internal
            ++ [ Input.button (buttonStyle ++ [ Element.alignRight, Element.alignTop ])
                    { onPress = Just Restart, label = Element.text "Restart" }
               ]


internalSettingsView : Config -> QuadDivision.Model -> List (Element Msg)
internalSettingsView config model =
    let
        internalSettings =
            QuadDivision.settings model
    in
    [ Input.radioRow [ Element.spacing config.spacing.medium ]
        { onChange = InternalSettingChanged << QuadDivision.ChangeSeparation
        , options =
            List.map
                (\num -> radioOption config num <| Element.text (String.fromFloat num))
                [ 1, 2, 5, 10 ]
        , selected = Just internalSettings.separation
        , label =
            Input.labelAbove
                [ Font.size config.fontSize.medium
                , Element.paddingEach { top = 0, left = 0, right = 0, bottom = config.spacing.tiny }
                ]
            <|
                Element.text "Border width in pixels"
        }
    , Input.radioRow [ Element.spacing config.spacing.medium ]
        { onChange = InternalSettingChanged << QuadDivision.ChangeQuantity
        , options =
            List.map
                (\num -> radioOption config (QuadDivision.About num) <| Element.text (String.fromInt num))
                [ 20, 50, 100, 200 ]
        , selected = Just internalSettings.quantity
        , label =
            Input.labelAbove
                [ Font.size config.fontSize.medium
                , Element.paddingEach { top = 0, left = 0, right = 0, bottom = config.spacing.tiny }
                ]
            <|
                Element.text "Approximate number of quads"
        }
    ]


radioOption : Config -> val -> Element msg -> Input.Option val msg
radioOption config val optView =
    let
        baseWith bgColor iconType =
            Element.row
                [ Background.color bgColor
                , Border.rounded config.spacing.small
                , Element.paddingXY config.spacing.small config.spacing.tiny
                , Element.spacing config.spacing.tiny
                , Element.mouseOver [ Background.color (Element.rgba255 255 255 255 0.15) ]
                ]
                [ icon iconType
                , optView
                ]
    in
    Input.optionWith val
        (\optionState ->
            case optionState of
                Input.Idle ->
                    baseWith (Element.rgba255 255 255 255 0.1) FeatherIcons.circle

                Input.Focused ->
                    baseWith (Element.rgba255 255 255 255 0.1) FeatherIcons.stopCircle

                Input.Selected ->
                    baseWith (Element.rgba255 255 255 255 0.3) FeatherIcons.checkCircle
        )


buttonStyle : List (Element.Attribute msg)
buttonStyle =
    [ Border.width 1
    , Border.color (Element.rgba255 255 255 255 0.5)
    , Background.color (Element.rgba255 255 255 255 0.05)
    , Element.padding 5
    , Element.alignRight
    ]


icon : FeatherIcons.Icon -> Element msg
icon i =
    i
        |> FeatherIcons.withSize 26
        |> FeatherIcons.withViewBox "0 0 26 26"
        |> FeatherIcons.toHtml []
        |> Element.html
        |> Element.el []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Ports.windowResizes ViewPortResized
        , if model.running then
            Time.every model.settings.updateEvery (always Tick)

          else
            Sub.none
        ]



-- RANDOM GENERATORS


anyInt : Random.Generator Int
anyInt =
    Random.int Random.minInt Random.maxInt


main =
    Browser.element
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }
