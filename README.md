# History

This is a fork of the `elm-community/elm-datepicker` package ported to support elm 0.19.
`elm-datepicker` is a reusable date picker component in Elm.

## Dependencies

This package depends on [justinmimbs/date](https://github.com/justinmimbs/date).
It uses its date representation: Dates without time and timezones.

## Breaking Changes

During the port to 0.19 two breaking changes were made:


- parseDate now defaults to Date.fromIsoString. Before it was elm-lang/Date.fromString which was much more flexible

- The --today-css class is now only added to cells that represent todays or the initialized date. Not the picked date. (Bugfix or Breaking change. You may decide)


### Upgrading to 3.0.0

3.0.0 introduces a change in emitted html and the packaged css.

The next and previous month buttons previously were `a`-tags. These interfered with `Browser.application` apps.
Thus, they were changed to `button`-tags. (see [issue #12](https://github.com/CurrySoftware/elm-datepicker/issues/12) for details).

As this change in emitted html needs a change in css, we recommend you to add the following rule to your css when upgrading to 3.0.0:

```css
.elm-datepicker--prev,
.elm-datepicker--next { background-color: inherit; }
```

## Install

``` shell
elm install CurrySoftware/elm-datepicker
```

## Usage

The `DatePicker.init` function initialises the DatePicker. It returns the initialised DatePicker and associated `Cmds` so it must be done in your program's `init` or `update` functions:

**Note** Make sure you don't throw away the initial `Cmd`!

```elm

init : (Model, Cmd Msg)
...
    let
        ( datePicker, datePickerCmd ) =
            DatePicker.init
    in
        (
            { model | datePicker = datePicker },
            Cmd.map SetDatePicker datePickerCmd
)        )
```

The `DatePicker` can be displayed in a view using the `DatePicker.view` function. It returns its own
message type so you should wrap it in one of your own messages using `Html.map`:


```elm
type Msg
    = ...
    | SetDatePicker DatePicker.Msg
    | ...


view : Model -> Html Msg
view model =
    ...
    div [] [
        DatePicker.view
            model.date
            someSettings
            model.startDatePicker
         |> Html.map SetDatePicker
        ]

```

To handle `Msg` in your update function, you should unwrap the `DatePicker.Msg` and pass it down to the `DatePicker.update` function. The `DatePicker.update` function returns:

* the new model
* a `DateEvent` that represents three things that can possibly happen during an update:
  - `None`: Nothing
  - `Picked Date`: The user might pick a date through clicking or typing
  - `FailedInput InputError`: Or the user typed a date that is either invalid or disabled

In most usecases it should suffice to match on `Picked Date`.
Have a look at the `nightwash-simple` example for basic error handling with `InputError`.

To create the settings to pass to `update`, `DatePicker.defaultSettings` is provided to make it easier to use. You only have to override the settings that you are interested in.

**Note** The datepicker does _not_ retain an internal idea of a picked date in its model. That is, it depends completely on you for an idea of what date is chosen, so that third tuple member is important! Evan Czaplicki has a compelling argument for why components should not necessarily have an their own state for the primary data they manage [here](https://github.com/evancz/elm-sortable-table#single-source-of-truth).

```elm
someSettings : DatePicker.Settings
someSettings =
    { defaultSettings
        | inputClassList = [ ( "form-control", True ) ]
        , inputId = Just "datepicker"
    }

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        ...

         SetDatePicker subMsg ->
            let
                ( newDatePicker, dateEvent ) =
                    DatePicker.update someSettings subMsg model.startDatePicker

                date =
                    case dateEvent of
                        Picked newDate ->
                            Just newDate

                        _ ->
                            model.date

            in
                ({ model
                    | date = date
                    , datePicker = newDatePicker
                }
                , Cmd.none)

```

## Examples

See the [examples][examples] folder or try it on ellie-app: [simple] example and [bootstrap] example.

[examples]: https://github.com/CurrySoftware/elm-datepicker/tree/master/examples
[simple]: https://ellie-app.com/3WbsRpXXzJ5a1
[bootstrap]: https://ellie-app.com/3WbrzQPqx3ma1


## CSS

The CSS for the date picker is distributed separately.  You can grab
the compiled CSS from [here][compiled] or you can grab the SCSS source
from [here][scss].

[compiled]: https://github.com/CurrySoftware/elm-datepicker/blob/master/css/elm-datepicker.css
[scss]: https://github.com/CurrySoftware/elm-datepicker/blob/master/css/elm-datepicker.scss


## Running the acceptance tests
### Prerequisites

- elm reactor - this is most likely already installed if you're using Elm!
- chromedriver (https://sites.google.com/a/chromium.org/chromedriver/).
  Try `brew install chromedriver` if you're on OSX.


### Install the testing tools
run `npm install`

### build the examples
cd examples && make && cd ..

### Run the tests
`./run-acceptance-tests`

Please file an issue if you have any difficulty running the tests.
