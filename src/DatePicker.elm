module DatePicker exposing
    ( Msg, DateEvent(..), InputError(..), DatePicker
    , init, initFromDate, initFromDates, update, view, isOpen, focusedDate, getInitialDate
    , Settings, defaultSettings, pick, between, moreOrLess, from, to, off, open, close
    )

{-| A customizable date picker component.


# Tea ☕

@docs Msg, DateEvent, InputError, DatePicker
@docs init, initFromDate, initFromDates, update, view, isOpen, focusedDate, getInitialDate


# Settings

@docs Settings, defaultSettings, pick, between, moreOrLess, from, to, off, open, close

-}

import Date exposing (Date, Month, day, month, year)
import DatePicker.Date exposing (..)
import Html exposing (..)
import Html.Attributes as Attrs exposing (placeholder, selected, tabindex, type_, value)
import Html.Events exposing (on, onBlur, onClick, onFocus, onInput, targetValue)
import Html.Keyed
import Json.Decode as Json
import Task
import Time exposing (Month(..), Weekday(..))


{-| An opaque type representing messages that are passed inside the DatePicker.
-}
type Msg
    = CurrentDate Date
    | ChangeFocus Date
    | Pick Date
    | Text String
    | SubmitText
    | Focus
    | Blur
    | MouseDown
    | MouseUp
    | ChangePicking Pickable
    | ChangeFocusAndPicking Date Pickable
    | KeyDown Int


{-| The type of date picker settings.
-}
type alias Settings =
    { placeholder : String
    , classNamespace : String
    , containerClassList : List ( String, Bool )
    , inputClassList : List ( String, Bool )
    , inputName : Maybe String
    , inputId : Maybe String
    , inputAttributes : List (Html.Attribute Msg)
    , isDisabled : Date -> Bool
    , parser : String -> Result String Date
    , dateFormatter : Date -> String
    , dayFormatter : Weekday -> String
    , monthFormatter : Month -> String
    , yearFormatter : Int -> String
    , cellFormatter : String -> Html Msg
    , firstDayOfWeek : Weekday
    , changeYear : YearRange
    }


type Pickable
    = Day
    | Month
    | Year


type alias Model =
    { open : Bool
    , forceOpen : Bool
    , focused : Maybe Date -- date currently center-focused by picker, but not necessarily chosen
    , inputText : Maybe String
    , today : Date -- actual, current day as far as we know
    , picking : Pickable
    }


{-| The DatePicker model. Opaque, hence no field docs.
-}
type DatePicker
    = DatePicker Model


{-| A record of default settings for the date picker. Extend this if
you want to customize your date picker.

    import DatePicker exposing (defaultSettings)

    DatePicker.init { defaultSettings | placeholder = "Pick a date" }

To disable certain dates:

    import Date exposing (Day(..), dayOfWeek)
    import DatePicker exposing (defaultSettings)

    DatePicker.init { defaultSettings | isDisabled = \d -> dayOfWeek d `List.member` [ Sat, Sun ] }

-}
defaultSettings : Settings
defaultSettings =
    { placeholder = "Please pick a date..."
    , classNamespace = "elm-datepicker--"
    , containerClassList = []
    , inputClassList = []
    , inputName = Nothing
    , inputId = Nothing
    , inputAttributes =
        [ Attrs.required False
        ]
    , isDisabled = always False
    , parser = Date.fromIsoString
    , dateFormatter = Date.format "yyyy-MM-dd"
    , dayFormatter = formatDay
    , monthFormatter = formatMonth
    , yearFormatter = String.fromInt
    , cellFormatter = formatCell
    , firstDayOfWeek = Sun
    , changeYear = off
    }


yearRangeActive : YearRange -> Bool
yearRangeActive yearRange =
    yearRange /= Off


{-| Select a range of date to display

    DatePicker.init { defaultSettings | changeYear = between 1555 2018 }

-}
between : Int -> Int -> YearRange
between start end =
    if start > end then
        Between end start

    else
        Between start end


{-| Select a symmetric range of date to display

    DatePicker.init { defaultSettings | changeYear = moreOrLess 10 }

-}
moreOrLess : Int -> YearRange
moreOrLess range =
    MoreOrLess range


{-| Select a range from a given year to this year

    DatePicker.init { defaultSettings | changeYear = from 1995 }

-}
from : Int -> YearRange
from year =
    From year


{-| Select a range from this year to a given year

    DatePicker.init { defaultSettings | changeYear = to 2020 }

-}
to : Int -> YearRange
to year =
    To year


{-| Turn off the date range

    DatePicker.init { defaultSettings | changeYear = off }

-}
off : YearRange
off =
    Off


formatCell : String -> Html Msg
formatCell day =
    text day


{-| The default initial state of the Datepicker. You must execute
the returned command (which, for the curious, sets the current date)
for the date picker to behave correctly.

    init =
        let
            ( datePicker, datePickerFx ) =
                DatePicker.init
        in
        ( { picker = datePicker }, Cmd.map ToDatePicker datePickerfx )

-}
init : ( DatePicker, Cmd Msg )
init =
    ( DatePicker <|
        { open = False
        , forceOpen = False
        , focused = Just initDate
        , inputText = Nothing
        , today = initDate
        , picking = Day
        }
    , Task.perform CurrentDate Date.today
    )


{-| Initialize a DatePicker with a given Date

    init date =
        ( { picker = DatePicker.initFromDate date }, Cmd.none )

-}
initFromDate : Date -> DatePicker
initFromDate date =
    DatePicker <|
        { open = False
        , forceOpen = False
        , focused = Just date
        , inputText = Nothing
        , today = date
        , picking = Day
        }


{-| Initialize a DatePicker with a date for today and Maybe a date picked

    init today date =
        ( { picker = DatePicker.initFromDates today date }, Cmd.none )

-}
initFromDates : Date -> Maybe Date -> DatePicker
initFromDates today date =
    DatePicker <|
        { open = False
        , forceOpen = False
        , focused = date
        , inputText = Nothing
        , today = today
        , picking = Day
        }


prepareDates : Date -> Weekday -> { currentMonth : Date, currentDates : List Date }
prepareDates date firstDayOfWeek =
    let
        weekdayAsInterval =
            weekdayToInterval firstDayOfWeek

        firstOfMonth =
            Date.fromCalendarDate (year date) (month date) 1

        -- First shown date
        -- If the first of a month is a sunday and firstDayOfWeek is sunday then its the first of the month
        -- Otherwise the daterange starts in the month before the current month
        start =
            Date.fromCalendarDate (year date) (month date) 1
                |> Date.floor weekdayAsInterval

        end =
            Date.add Date.Months 1 firstOfMonth
                |> Date.ceiling weekdayAsInterval
    in
    { currentMonth = date
    , currentDates = Date.range Date.Day 1 start end
    }


{-| Expose if the datepicker is open
-}
isOpen : DatePicker -> Bool
isOpen (DatePicker model) =
    model.open


{-| Expose the currently focused date
-}
focusedDate : DatePicker -> Maybe Date
focusedDate (DatePicker model) =
    model.focused


{-| Expose the initial date

When you initialize the DatePicker using function `init` the resulting `Cmd Msg` fetches todays date.
This date is then stored in the DatePicker's model as initial date.

In some scenarios, you want use todays date in combination with `DatePicker.Settings`.
This allows you to use todays date without storing it yourself.

Check the `simple-with-validate-date` example for an example usage.

-}
getInitialDate : DatePicker -> Date
getInitialDate (DatePicker model) =
    model.today


{-| The event resulting from a `DatePicker.update`.
Three things can happen:

  - Nothing
  - The user might pick a date through clicking or typing
  - Or the user typed a date that is either invalid or disabled

If you do not care about case error handling for invalid inputs, just matching on `Picked` should suffice.

Have a look at the `nightwash-simple` example for basic error handling with `InputError`.

-}
type DateEvent
    = None
    | FailedInput InputError
    | Picked Date


{-| When typing a date it can go wrong in two ways:

  - `Invalid String`: the typed string cannot be parsed into a date. The error string is given be the parser defined in the settings.
  - `Disabled Date`: a valid date was typed, but it is disabled as defined in the settings.

-}
type InputError
    = Invalid String
    | EmptyString
    | Disabled Date


{-| The date picker update function. The second tuple member represents a user action to change the
date.
-}
update : Settings -> Msg -> DatePicker -> ( DatePicker, DateEvent )
update settings msg (DatePicker ({ forceOpen } as model)) =
    case msg of
        CurrentDate date ->
            ( DatePicker { model | focused = Just date, today = date }, None )

        ChangeFocus date ->
            ( DatePicker { model | focused = Just date }, None )

        ChangeFocusAndPicking date pickable ->
            ( DatePicker { model | focused = Just date, picking = pickable }, None )

        ChangePicking pickable ->
            ( DatePicker { model | picking = pickable }, None )

        Pick date ->
            ( DatePicker <|
                { model
                    | open = False
                    , inputText = Nothing
                    , focused = Nothing
                }
            , Picked date
            )

        Text text ->
            case settings.parser text of
                Ok date ->
                    ( DatePicker { model | inputText = Just text, focused = Just date, open = True }
                    , Picked date
                    )

                Err _ ->
                    ( DatePicker { model | inputText = Just text, open = True }, None )

        SubmitText ->
            if forceOpen then
                ( DatePicker model, None )

            else
                let
                    dateEvent =
                        case model.inputText of
                            Nothing ->
                                FailedInput EmptyString

                            Just "" ->
                                FailedInput EmptyString

                            Just rawInput ->
                                case settings.parser rawInput of
                                    Ok date ->
                                        if settings.isDisabled date then
                                            FailedInput <| Disabled date

                                        else
                                            Picked date

                                    Err e ->
                                        FailedInput <| Invalid e
                in
                ( DatePicker
                    { model
                        | inputText =
                            case dateEvent of
                                Picked _ ->
                                    Nothing

                                _ ->
                                    model.inputText
                        , focused =
                            case dateEvent of
                                Picked date ->
                                    Just date

                                _ ->
                                    model.focused
                    }
                , dateEvent
                )

        Focus ->
            ( DatePicker { model | open = True, forceOpen = False }, None )

        Blur ->
            ( DatePicker { model | open = forceOpen }, None )

        MouseDown ->
            ( DatePicker { model | forceOpen = True }, None )

        MouseUp ->
            ( DatePicker { model | forceOpen = False }, None )

        KeyDown keyCode ->
            case keyCode of
                27 ->
                    ( DatePicker { model | open = False }, None )

                _ ->
                    ( DatePicker model, None )


{-| Generate a message that will act as if the user has chosen a certain date,
so you can call `update` on the model yourself.
Note that this is different from just changing the "current chosen" date,
since the picker doesn't actually have internal state for that.
Rather, it will:

  - change the calendar focus

  - replace the input text with the new value

  - close the picker

    update datepickerSettings (pick someDate) datepicker

-}
pick : Date -> Msg
pick =
    Pick


{-| Generate a message that will act as if the user has focused on the input element.
This will open the datePicker

    update datepickerSettings open datepicker

Example usage is demonstrated in the `simple-nightwash`-example.

-}
open : Msg
open =
    Focus


{-| Generate a message that will act as if the user has removed focus from the input element.
This will close the datePicker

    update datepickerSettings close datepicker

Example usage is demonstrated in `simple-nightwash`-example.

-}
close : Msg
close =
    Blur


{-| The date picker view. The Date passed is whatever date it should treat as selected.
-}
view : Maybe Date -> Settings -> DatePicker -> Html Msg
view pickedDate settings (DatePicker model) =
    let
        potentialInputId =
            settings.inputId
                |> Maybe.map Attrs.id
                |> (List.singleton >> List.filterMap identity)

        inputClasses =
            ( settings.classNamespace ++ "input", True )
                :: settings.inputClassList

        inputCommon xs =
            input
                ([ Attrs.classList inputClasses
                 , Attrs.name (settings.inputName |> Maybe.withDefault "")
                 , type_ "text"
                 , on "change" (Json.succeed SubmitText)
                 , onInput Text
                 , onBlur Blur
                 , onClick Focus
                 , onFocus Focus
                 , on "keydown" (Json.map KeyDown Html.Events.keyCode)
                 ]
                    ++ settings.inputAttributes
                    ++ potentialInputId
                    ++ xs
                )
                []

        dateInput =
            inputCommon
                [ placeholder settings.placeholder
                , model.inputText
                    |> Maybe.withDefault
                        (Maybe.map settings.dateFormatter pickedDate
                            |> Maybe.withDefault ""
                        )
                    |> value
                ]

        containerClassList =
            ( settings.classNamespace ++ "container", True ) :: settings.containerClassList
    in
    div
        [ Attrs.classList containerClassList ]
        [ dateInput
        , if model.open then
            datePicker pickedDate settings model

          else
            text ""
        ]


datePicker : Maybe Date -> Settings -> Model -> Html Msg
datePicker pickedDate settings { focused, today, picking } =
    let
        currentDate =
            focused |> maybeOr pickedDate |> Maybe.withDefault today

        { currentMonth, currentDates } =
            prepareDates currentDate settings.firstDayOfWeek

        dpClass =
            mkClass settings

        firstDayOffset =
            Date.weekdayToNumber settings.firstDayOfWeek - 1

        arrow className message =
            button
                [ dpClass className
                , onClick message
                , tabindex -1
                , type_ "button"
                ]
                []

        picked d =
            pickedDate
                |> Maybe.map (\pdate -> Date.toRataDie pdate == Date.toRataDie d)
                |> Maybe.withDefault False

        isToday d =
            Date.toRataDie d == Date.toRataDie today

        isOtherMonth d =
            month currentDate /= month d

        dayList =
            groupDates currentDates
                |> List.map
                    (\rowDays ->
                        tr [ dpClass "row" ]
                            (List.map (viewDay settings picked isOtherMonth isToday) rowDays)
                    )

        onChange handler =
            on "change" <| Json.map handler targetValue

        isCurrentYear selectedYear =
            year currentMonth == selectedYear

        yearOption index selectedYear =
            ( String.fromInt index
            , option [ value (String.fromInt selectedYear), selected (isCurrentYear selectedYear) ]
                [ text <| String.fromInt selectedYear ]
            )

        ( addedYearsFront, addedYearsBack ) =
            let
                front to_ =
                    List.range (year currentMonth) to_

                back from_ =
                    List.range from_ (year currentMonth)
            in
            case settings.changeYear of
                From from_ ->
                    ( front (from_ - 1), back (year today + 1) )

                To to_ ->
                    ( front (year today - 1), back (to_ + 1) )

                Between from_ to_ ->
                    ( front (from_ - 1), back (to_ + 1) )

                MoreOrLess _ ->
                    ( [], [] )

                Off ->
                    ( [], [] )

        dropdownYear =
            Html.Keyed.node "select"
                [ onChange (changeYear currentDate >> ChangeFocus), dpClass "year-menu" ]
                (List.indexedMap yearOption
                    (List.concat
                        [ addedYearsFront
                        , yearRange { currentMonth = currentMonth, today = today } settings.changeYear
                        , addedYearsBack
                        ]
                    )
                )
    in
    div
        [ dpClass "picker"
        , Html.Events.stopPropagationOn "mousedown" <| Json.succeed ( MouseDown, True )
        , Html.Events.stopPropagationOn "mouseup" <| Json.succeed ( MouseUp, True )
        ]
    <|
        case picking of
            Day ->
                [ div [ dpClass "picker-header" ]
                    [ div [ dpClass "prev-container" ]
                        [ arrow "prev" (ChangeFocus (Date.add Date.Months -1 currentDate)) ]
                    , div [ dpClass "month-container" ]
                        [ button [ dpClass "month", type_ "button", onClick <| ChangePicking Month ]
                            [ text <| settings.monthFormatter <| month currentMonth ]
                        , button [ dpClass "year", type_ "button", onClick <| ChangePicking Year ]
                            [ if not (yearRangeActive settings.changeYear) then
                                text <| settings.yearFormatter <| year currentMonth

                              else
                                Html.Keyed.node "span" [] [ ( String.fromInt (year currentMonth), dropdownYear ) ]
                            ]
                        ]
                    , div [ dpClass "next-container" ]
                        [ arrow "next" (ChangeFocus (Date.add Date.Months 1 currentDate)) ]
                    ]
                , table [ dpClass "table" ]
                    [ thead [ dpClass "weekdays" ]
                        [ tr []
                            ([ Mon, Tue, Wed, Thu, Fri, Sat, Sun ]
                                |> List.repeat 2
                                |> List.concat
                                |> List.drop firstDayOffset
                                |> List.take 7
                                |> List.map (\d -> td [ dpClass "dow" ] [ text <| settings.dayFormatter d ])
                            )
                        ]
                    , tbody [ dpClass "days" ] dayList
                    ]
                ]

            Month ->
                [ div [ dpClass "picker-header" ]
                    [ div [ dpClass "prev-container" ]
                        [ arrow "prev" (ChangeFocus (Date.add Date.Years -1 currentDate)) ]
                    , div [ dpClass "month-container" ]
                        [ button [ dpClass "year", type_ "button", onClick <| ChangePicking Year ]
                            [ if not (yearRangeActive settings.changeYear) then
                                text <| settings.yearFormatter <| year currentMonth

                              else
                                Html.Keyed.node "span" [] [ ( String.fromInt (year currentMonth), dropdownYear ) ]
                            ]
                        ]
                    , div [ dpClass "next-container" ]
                        [ arrow "next" (ChangeFocus (Date.add Date.Years 1 currentDate)) ]
                    ]
                , table [ dpClass "table" ]
                    [ tbody [ dpClass "months" ] <| monthList currentDate settings
                    ]
                ]

            Year ->
                [ div [ dpClass "picker-header" ]
                    [ div [ dpClass "prev-container" ]
                        [ arrow "prev" (ChangeFocus (Date.add Date.Years -12 currentDate)) ]
                    , div [ dpClass "month-container" ]
                        [ span [ dpClass "year" ]
                            [ if not (yearRangeActive settings.changeYear) then
                                text <| settings.yearFormatter <| year currentMonth

                              else
                                Html.Keyed.node "span" [] [ ( String.fromInt (year currentMonth), dropdownYear ) ]
                            ]
                        ]
                    , div [ dpClass "next-container" ]
                        [ arrow "next" (ChangeFocus (Date.add Date.Years 12 currentDate)) ]
                    ]
                , table [ dpClass "table" ]
                    [ tbody [ dpClass "years" ] <| yearList currentDate settings
                    ]
                ]


monthList : Date -> Settings -> List (Html Msg)
monthList focused settings =
    let
        months =
            [ Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec ]

        splitMonths =
            split 3 months
    in
    splitMonths
        |> List.map (\monthsRow -> tr [] <| List.map (viewMonth focused settings) monthsRow)


yearList : Date -> Settings -> List (Html Msg)
yearList focused settings =
    let
        focusedYear =
            Date.year focused

        years =
            List.range (focusedYear - 1) (focusedYear + 10)

        splitYears =
            split 3 years
    in
    splitYears |> List.map (\yearsRow -> tr [] <| List.map (viewYear focused settings) yearsRow)


viewMonth : Date -> Settings -> Month -> Html Msg
viewMonth focused settings month =
    let
        year =
            Date.year focused

        day =
            Date.day focused
    in
    td
        [ mkClassList settings
            [ ( "day", True ) ]
        , onClick <| ChangeFocusAndPicking (Date.fromCalendarDate year month day) Day
        ]
        [ settings.cellFormatter <| settings.monthFormatter month ]


viewYear : Date -> Settings -> Int -> Html Msg
viewYear focused settings year =
    let
        month =
            Date.month focused

        day =
            Date.day focused
    in
    td
        [ mkClassList settings
            [ ( "day", True ) ]
        , onClick <| ChangeFocusAndPicking (Date.fromCalendarDate year month day) Month
        ]
        [ settings.cellFormatter <| settings.yearFormatter year ]


viewDay : Settings -> (Date -> Bool) -> (Date -> Bool) -> (Date -> Bool) -> Date -> Html Msg
viewDay settings picked isOtherMonth isToday d =
    let
        disabled =
            settings.isDisabled d

        classList =
            mkClassList settings

        props =
            if not disabled then
                [ onClick <| Pick d ]

            else
                []
    in
    td
        (classList
            [ ( "day", True )
            , ( "disabled", disabled )
            , ( "picked", picked d )
            , ( "today", isToday d )
            , ( "other-month", isOtherMonth d )
            ]
            :: props
        )
        [ settings.cellFormatter <| String.fromInt <| Date.day d ]


{-| Turn a list of dates into a list of date rows with 7 columns per
row representing each day of the week.
-}
groupDates : List Date -> List (List Date)
groupDates dates =
    let
        go i xs racc acc =
            case xs of
                [] ->
                    List.reverse acc

                x :: xxs ->
                    if i == 6 then
                        go 0 xxs [] (List.reverse (x :: racc) :: acc)

                    else
                        go (i + 1) xxs (x :: racc) acc
    in
    go 0 dates [] []


mkClass : Settings -> String -> Html.Attribute msg
mkClass { classNamespace } c =
    Attrs.class (classNamespace ++ c)


mkClassList : Settings -> List ( String, Bool ) -> Html.Attribute msg
mkClassList { classNamespace } cs =
    List.map (\( c, b ) -> ( classNamespace ++ c, b )) cs
        |> Attrs.classList


maybeOr : Maybe a -> Maybe a -> Maybe a
maybeOr lhs rhs =
    case rhs of
        Just _ ->
            rhs

        Nothing ->
            lhs


split : Int -> List a -> List (List a)
split into list =
    case List.take into list of
        [] ->
            []

        head ->
            head :: split into (List.drop into list)
