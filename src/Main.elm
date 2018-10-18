port module Main exposing (..)

import Browser
import Browser.Dom as Dom
import Task
import Array
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Keyboard.Key as Key
import Material
import Material.Button as Button
import Material.Options as Options
import Material.Textfield as Textfield
import Material.Snackbar as Snackbar
import Material.Icon as Icon
import Json.Encode as E
import Http
import Json.Decode as D
import Json.Decode.Extra as DE
import Url.Builder as Url


---- HTTP ----


type alias PlaceModel =
    { lon : Float
    , lat : Float
    , displayName : String
    }


placeDecoder : D.Decoder PlaceModel
placeDecoder =
    D.map3 PlaceModel
        (D.field "lon" DE.parseFloat)
        (D.field "lat" DE.parseFloat)
        (D.field "display_name" D.string)


geocodeUrl : String -> String
geocodeUrl q = 
    Url.crossOrigin "https://nominatim.openstreetmap.org" ["search"]
        [ Url.string "q" q
        , Url.string "format" "json"
        ]


geocode : String -> Cmd Msg
geocode q =
    Http.send Geocode (Http.get (geocodeUrl q) (D.list placeDecoder)) 


reverseUrl : Float -> Float -> String
reverseUrl lon lat = 
    Url.crossOrigin "https://nominatim.openstreetmap.org" ["reverse"]
        [ Url.string "lon" (String.fromFloat lon)
        , Url.string "lat" (String.fromFloat lat)
        , Url.string "format" "json"
        ]


reverseGeocode : Maybe Float -> Maybe Float -> Cmd Msg
reverseGeocode maybeLon maybeLat =
    case maybeLon of
        Nothing ->
            Cmd.none
    
        Just lon ->
            case maybeLat of
                Nothing ->
                    Cmd.none
            
                Just lat ->
                    Http.send ReverseGeocode (Http.get (reverseUrl lon lat) placeDecoder) 


---- MODEL ----


floatFormat : String -> String
floatFormat input =
    case (String.toFloat input) of
        Nothing ->
            ""
            
        Just float ->
            let
                parts =
                    Array.fromList (String.split "." input)
            in
            if Array.length parts == 2
            && String.length (Maybe.withDefault "" (Array.get 1 parts)) > 5 then
                let
                    absFloat =
                        abs float

                    fraction =
                        absFloat - toFloat (floor absFloat)

                    decimals =
                        String.fromInt (round (fraction * 100000))
                in
                (Maybe.withDefault "" (Array.get 0 parts)) ++ "." ++ decimals
            
            else
                input


type alias Model =
    { mdc : Material.Model Msg
    , lon : String
    , lon_old : String
    , lat : String
    , lat_old : String
    , place : String
    , place_old : String
    }


defaultModel : Model
defaultModel =
    { mdc = Material.defaultModel
    , lon = ""
    , lon_old = ""
    , lat = ""
    , lat_old = ""
    , place = ""
    , place_old = ""
    }


init : ( Model, Cmd Msg )
init =
    ( defaultModel, Cmd.batch
        [ Material.init Mdc
        , geocode "onze lieve vrouwetoren, amersfoort"
        ]
    )


---- UPDATE ----


type alias Coordinate =
    { lon : Float
    , lat : Float
    }


toast : Model -> String -> ( Model, Cmd Msg )
toast model message =
    let
        contents =
            Snackbar.toast Nothing message
        ( mdc, effects ) =
            Snackbar.add Mdc "my-snackbar" contents model.mdc
    in
        ( { model | mdc = mdc }, effects )


httpErrorMessage : Http.Error -> String -> String
httpErrorMessage err base =
    case err of
        Http.BadUrl url ->
            "Ongeldige url bij " ++ base ++ " " ++ url

        Http.Timeout ->
            "Timeout bij " ++ base

        Http.NetworkError ->
            "Netwerkfout bij " ++ base

        Http.BadStatus response ->
            "Foutcode " ++ (String.fromInt response.status.code) ++ " bij " ++ base ++ ": " ++ response.status.message

        Http.BadPayload message _ ->
            "Datafout bij " ++ base ++ ": " ++ message


blur : String -> Cmd Msg
blur id =
    Task.attempt (\_ -> NoOp) (Dom.blur id)


latLon : Model -> Cmd Msg
latLon model =
    Cmd.batch
        [ mapFly (String.toFloat model.lon) (String.toFloat model.lat)
        , reverseGeocode (String.toFloat model.lon) (String.toFloat model.lat)
        ]


type Msg
    = Mdc (Material.Msg Msg)
    | NoOp
    | Lon String
    | LonKey Int
    | LonBlur
    | Lat String
    | LatKey Int
    | LatBlur
    | Place String
    | PlaceKey Int
    | PlaceBlur
    | MapCenter Coordinate
    | Geocode (Result Http.Error (List PlaceModel))
    | ReverseGeocode (Result Http.Error PlaceModel)
    | SelectText String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Mdc msg_ ->
            Material.update Mdc msg_ model
        
        NoOp ->
            ( model, Cmd.none )

        Lon input ->
            ( { model | lon = input }, Cmd.none )

        Lat input ->
            ( { model | lat = input }, Cmd.none )

        Place input ->
            ( { model | place = input }, Cmd.none )
        
        LonKey code ->
            case (Key.fromCode code) of
                Key.Enter ->
                    ( model, (blur "textfield-lon-native" ) )
                
                Key.Escape ->
                    ( { model | lon = model.lon_old }, (blur "textfield-lon-native" ) )
                
                _ ->
                    ( model, Cmd.none )
        
        LatKey code ->
            case (Key.fromCode code) of
                Key.Enter ->
                    ( model, (blur "textfield-lat-native" ) )
                
                Key.Escape ->
                    ( { model | lat = model.lat_old }, (blur "textfield-lat-native" ) )
                
                _ ->
                    ( model, Cmd.none )
        
        PlaceKey code ->
            case (Key.fromCode code) of
                Key.Enter ->
                    ( model, (blur "textfield-place-native" ) )
                
                Key.Escape ->
                    ( { model | place = model.place_old }, (blur "textfield-place-native" ) )
                
                _ ->
                    ( model, Cmd.none )

        LonBlur ->
            let
                lon =
                    floatFormat model.lon
            in
            if lon == model.lon_old then
                ( { model | lon = lon }, Cmd.none )
            
            else
                ( { model | lon_old = lon, lon = lon }, latLon model )

        LatBlur ->
            let
                lat =
                    floatFormat model.lat
            in
            if lat == model.lat_old then
                ( { model | lat = lat }, Cmd.none )
            
            else
                ( { model | lat_old = lat, lat = lat }, latLon model )

        PlaceBlur ->
            if model.place == model.place_old then
                ( model, Cmd.none )
            
            else
                ( { model | place_old = model.place }, geocode model.place )

        MapCenter coordinate ->
            let
                lon =
                    floatFormat (String.fromFloat coordinate.lon)

                lat =
                    floatFormat (String.fromFloat coordinate.lat)
            in
            if lon == model.lon
            && lat == model.lat then
                (  model, Cmd.none)
            
            else
                ( { model
                    | lon_old = lon, lon = lon
                    , lat_old = lat, lat = lat
                }, reverseGeocode (Just coordinate.lon) (Just coordinate.lat) )
                                
        Geocode result ->
            case result of
                Ok places ->
                    case (List.head places) of
                        Nothing ->
                            ( model, Cmd.none )
                            
                        Just place ->
                            let
                                lon =
                                    floatFormat (String.fromFloat place.lon)

                                lat =
                                    floatFormat (String.fromFloat place.lat)
                            in
                            ( { model
                                | lon_old = lon, lon = lon
                                , lat_old = lat, lat = lat
                                , place = place.displayName
                                , place_old = place.displayName
                            }, mapFly (Just place.lon) (Just place.lat) )

                Err err ->
                    toast model (httpErrorMessage err "geocoderen")
                    
        
        ReverseGeocode result ->
            case result of
                Ok place ->
                    ( { model | place = place.displayName }, Cmd.none )

                Err err ->
                    toast model (httpErrorMessage err "omgekeerd geocoderen")

        SelectText field  ->
            ( model, selectText ("textfield-" ++ field ++ "-native") )


---- VIEW ----


ordinateTextField :  Model -> String -> String -> String -> (String -> Msg) -> (Int -> Msg) -> Msg -> Html Msg
ordinateTextField model field label value inputMsg keyMsg blurMsg =
    let
        index =
            "textfield-" ++ field
    in
    Textfield.view Mdc index model.mdc
        [ Textfield.label label
        , Textfield.value value
        , Textfield.box
        , Textfield.pattern "-?\\d\\d?\\d?\\.?\\d*"
        , Options.css "background-color" "rgba(255, 255, 255, 0.77)"
        , Options.css "margin-left" ".5em"
        , Options.onInput inputMsg
        , Textfield.nativeControl
            [ Options.id (index ++ "-native")
            , Options.onFocus (SelectText field)
            , Options.onBlur blurMsg
            , Options.on "keydown" (D.map keyMsg keyCode)
            ]
        ]
        []


view : Model -> Html Msg
view model =
    div []
        [ div [ id "place"
            , style "position" "absolute"
            , style "top" ".5em", style "left" "3em"
            , style "width" "calc(100% - 4em)"
            ]
            [ Textfield.view Mdc "textfield-place" model.mdc
                [ Textfield.label "Plek"
                , Textfield.value model.place
                , Textfield.fullwidth
                -- , Textfield.trailingIcon "cancel"
                , Options.css "background-color" "rgba(255, 255, 255, 0.77)"
                , Options.css "padding" "0 1em"
                , Options.onInput Place
                , Textfield.nativeControl
                    [ Options.id "textfield-place-native"
                    , Options.onFocus (SelectText "place")
                    , Options.on "keydown" (D.map PlaceKey keyCode)
                    , Options.onBlur PlaceBlur
                    ]
                ] []
            ]
        , div [ id "lonlat"
            , style "position" "absolute", style "bottom" "0"
            ]
            [ ordinateTextField model "lon" "Lengtegraad" model.lon Lon LonKey LonBlur
            , ordinateTextField model "lat" "Breedtegraad" model.lat Lat LatKey LatBlur
            ]
        , div [ id "map"
            , style "position" "absolute", style "top" "0"
            , style "width" "100%", style "height" "100%"
            , style "z-index" "-1"
            ] []
        , Icon.view [ Options.id "icon-visor"
            , Options.css "position" "absolute"
            , Options.css "top" "50%", Options.css "left" "50%"
            , Options.css "transform" "translate(-50%, -50%)"
            ] "gps_not_fixed"
        , Snackbar.view Mdc "my-snackbar" model.mdc [] []
        ]


---- SUBSCRIPTIONS ----


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Material.subscriptions Mdc model
        , mapCenter MapCenter
        ]


---- PORTS ----


port mapCenter : (Coordinate -> msg) -> Sub msg


port map : E.Value -> Cmd msg


mapFly : (Maybe Float) -> (Maybe Float) -> Cmd msg
mapFly maybeLon maybeLat =
    case maybeLon of
        Nothing ->
            Cmd.none
        
        Just lon ->
            case maybeLat of
                Nothing ->
                    Cmd.none
                
                Just lat ->
                    map (E.object
                        [ ("Cmd", E.string "Fly")
                        , ("lon", E.float lon)
                        , ("lat", E.float lat)
                        ]
                    )


port dom : E.Value -> Cmd msg


selectText : String -> Cmd msg
selectText id =
    dom (E.object
        [ ("Cmd", E.string "SelectText")
        , ("id", E.string id)
        ]
    )


---- PROGRAM ----


main : Program () Model Msg
main =
    Browser.element
        { view = view
        , init = \_ -> init
        , update = update
        , subscriptions = subscriptions
        }