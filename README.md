# Fiscal Quarter

A macOS menu bar app for a fiscal calendar. The built-in fiscal year is the calendar year, numbered by that year: 2026 is FY26, with quarters starting on 1 January, 1 April, 1 July, and 1 October.

Screenshots, features, and the download are at [fq.mlynn.dev](https://fq.mlynn.dev).

On 2026-10-09 the quarter is **FY26-Q4**. The menu bar reads `FY26-Q4 · 84d`: day 9 of 92, week 2, 84 days left, counting today. Click it for the start and end, a progress bar, the next quarter, and copy.

Copy quarter id puts `FY26-Q4` on the pasteboard. Copy status line puts `FY26-Q4 · Day 9 of 92 · week 2 · 84 days left`. In the last two weeks the days-remaining figure turns amber, and the last week and last day get a line of their own. Open at login, Calendar, About, and Quit are in the same panel. About links to mlynn.org, GitHub, and LinkedIn.

Calendar keeps the built-in year unless you choose a custom start. A custom year is four quarters of three months. The FY number is the calendar year that fiscal year ends in. A year that starts on 1 February 2025 ends on 31 January 2026, so it is FY26. A 1 January start ends in the same calendar year, so 2026 is FY26, the same as the built-in calendar. `fq` reads the same choice. The app has no Dock icon, no network access, and no account.

Line, Year, and Ring are three pictures of that year, in one slot. Line is the picture that opens. Each month is a bar as long as its days, and a wider gap separates the quarters, so a short quarter is visibly short. A ring sits on today. Year turns those months into calendars, two quarters to a row: days already passed are filled, today is a hollow ring, and the current quarter is green. Ring draws the same year as a circle. It starts at the top with the first month of the year and runs clockwise, and the day of the month sits in the middle. The choice is remembered.

`fq` prints the same facts for a shell or a script. The packaged app carries that binary at `Contents/MacOS/fq`.

## Countdowns

The panel counts down to the end of the quarter, the half, and the fiscal year. When they end on the same day they share a line, so on 2026-10-11 the panel shows one line, `FY26-Q4 · H2 · FY26`, with 82 days. The menu next to Countdown switches between days, workdays, weeks, and weekends. Workdays are Monday through Friday. Holidays are not known, so they count as workdays. Weekends counts the one in progress.

Click a countdown line to put it in the menu bar. The menu bar keeps the unit you chose, so it can read `FY26 · 59wd` or `FY26-Q4 · 11w 5d`. The default is `FY26-Q4 · 82d`.

```sh
fq --countdown
```

```
FY26-Q4 · H2 · FY26 ends 2026-12-31
  82 days · 59 workdays · 12 weekends
```

`fq --json` carries the same figures under `countdowns`, one object each for the quarter, the half, and the year.

A half is the first two quarters or the last two. A calendar file with a year of other than four quarters puts the extra quarter in the first half.

## Milestones

A milestone is a date that comes around every quarter, such as "Forecast due, 5 workdays before quarter end." It is a rule, not a date: a distance in days, workdays, or weeks, before or after the quarter's start or end, in every quarter or only some. Each quarter it lands on that quarter's own dates, so a short quarter gets its own day. One that lands on a weekend moves to the Friday before, unless it is set to stay. Milestones belong to your calendar.

`fq` lists them, soonest first:

```sh
fq --milestones
```

```
Pipeline review  Thu 2026-10-15  3 days · 3 workdays
                 2 weeks after quarter start, every quarter
Forecast due     Thu 2026-12-24  73 days · 53 workdays
                 5 workdays before quarter end, every quarter
```

Once a milestone's day has passed, it shows the next quarter's. `fq --countdown` adds them after the quarter, half, and year, and `fq --json` lists them under `milestones`.

In the app, Milestones lists them with their next dates. Add one with a name and a rule, and the form shows when it next falls before you save it. Click one to change it. The panel counts each one down under Countdown, in amber in its last week, and clicking one puts it in the menu bar, such as `Forecast due · 3wd`.

### Notifications

Under Notifications on the Milestones page, the app can send four kinds. All start off.

- **Milestones**, on the day, or 1, 2, or 5 workdays before. Each milestone picks its own, under Remind.
- **Last two weeks of the quarter**, the day 14 days are left, when the countdown turns amber.
- **First day of a quarter.**
- **30 days before the year ends.**

They go out at 9:00, or the time set under Send at. The first one turned on asks macOS for permission. The app plans 30 days ahead and plans again when a milestone, the calendar, a setting, or the date changes. It runs at login, so the plan stays current. macOS only allows notifications from a signed copy in Applications, which the disk image provides.

The iPhone and iPad app has the same Milestones screen, under the list's last section, and shows each milestone under Countdown. It plans notifications a month ahead each time it opens, since iOS gives it no other chance to run, so it needs opening now and then to keep them coming.

## Widgets

The Mac app carries a Fiscal countdown widget for the desktop and Notification Center, in small and medium sizes. After the app has opened once, right-click the desktop, choose Edit Widgets, and find Fiscal Quarter. Small shows one countdown. Medium adds the quarter, the half, and the year side by side, each with its own bar, because they start on different days even when they end together. To count down to a milestone instead, choose it under Milestone in Edit Widget. The widget then shows the milestone's name, its count, and "Due" with its date, in amber in its last week. A milestone always runs on your calendar, and a widget whose milestone has been removed goes back to its period.

Each widget has its own settings under Edit Widget: what to count to, the unit, the calendar, and a label. The calendar starts as Yours, the one chosen in the app, and follows it when you change it. A saved calendar is picked from the list of other calendars, and its name becomes the label unless you type one. The built-in calendar and a start month and day are there too. So one widget can follow your calendar while another follows a customer whose year starts in July.

The app and its widgets share settings through an App Group: `YZ36Z8GSEN.local.fiscalquarter` on the Mac and `group.local.fiscalquarter` on iOS. The first time the new app opens, it copies the calendar settings across from where earlier versions kept them. `fq` reads the group's settings file directly, because a command-line tool cannot hold the App Group entitlement.

The countdown turns amber in the last two weeks, as in the panel.

## Appearance

Appearance, in the Mac panel and in the iOS app, changes how the app and every widget look. One look is shared through the App Group, so a change reaches the widgets at once. The screen opens with a live preview of both widget sizes.

- **Background**: the system's own, a solid color, a gradient, or a photo or image file. Gradients come in six presets, with your own start and end colors and four directions. A photo is copied into the app's shared container and scaled so its longer side is 1000 pixels, because widgets cannot read the photo library and refuse large images. Darken lays black over a photo so text stays readable.
- **Text**: ten typefaces: System, Rounded, Serif, and Monospaced, plus Avenir Next, Futura, Georgia, Gill Sans, Didot, and American Typewriter, which exist on both macOS and iOS. The weight of the big number, an overall size, and light, dark, or automatic text, which follows the background's brightness.
- **Accent**: the color of bars, today's ring, and the current quarter. Without one, the standard green is used, unless it would be hard to see on the background, and then the text color is used.
- **Show**: progress bars, the end date, the quarter under a label, the half and year rows in medium widgets, and a centered number.

On the Mac the background sits behind the whole panel, and the typeface's design applies to the panel's text. A named typeface such as Futura applies to the quarter id and the widgets. On iOS the top card takes the look. Reset to the standard look puts everything back.

## iPhone and iPad

`FiscalQuarteriOS` is the same calendar on a phone: the quarter, the three pictures, the countdowns, the other calendars, and your calendar setting. Tap a calendar to copy its status line, or share the status line from the toolbar.

Its widget comes in the same small and medium sizes, plus three Lock Screen sizes: a ring with the number, a line with a bar, and a single line of text.

To run it in the simulator, choose the `FiscalQuarteriOS` scheme and an iPhone simulator, then press Run. A device build registers the app, the widget, and the App Group with the signing team the first time, which Xcode does when you choose your iPhone and press Run.

## Calendar

The built-in fiscal year is the calendar year. The FY number is the year, so 2026 is FY26 and 2027 is FY27.

| Id | Start | End |
| --- | --- | --- |
| FY26-Q1 | 2026-01-01 | 2026-03-31 |
| FY26-Q2 | 2026-04-01 | 2026-06-30 |
| FY26-Q3 | 2026-07-01 | 2026-09-30 |
| FY26-Q4 | 2026-10-01 | 2026-12-31 |

Every year follows the same pattern, so FY27-Q1 starts on 2027-01-01. If your fiscal year starts on another date, choose a custom start in Calendar.

Earlier versions built in a February year with an 11-month FY27, February through December 2026. That calendar is now `calendars/february-transition.json`, for anyone whose year really did work that way. Import it under Calendar, Others, or pass it to `fq --calendar`.

Days remaining counts today through the last day of the quarter. On the last day the value is 1.

Week 1 is the first seven days of the quarter, counting the start date. Day 8 is week 2. A 92-day quarter runs to week 14.

The percent is the day index divided by the length of the quarter, rounded to the nearest integer. 2026-10-09 is day 9 of 92, which is 10%.

The pure function is `FiscalCalendar.quarter(containing:)`.

```swift
let quarter = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 10, day: 5))
quarter.id // "FY26-Q4"
```

`FiscalCalendar.quarter(on:calendar:)` reads a `Date` in a chosen calendar. The app passes `Calendar.current`, so the machine's local time zone decides the civil day.

## Calendar files

A calendar is data: a list of eras. Each era starts on its `from` date and runs until the next one starts. An era either repeats a `months` rule (four three-month quarters from `startMonth`/`startDay`) or lists its quarters outright with `explicit`, which is how the short FY27 in `calendars/february-transition.json` is written. The first era has no `from`, and the first and last eras must use `months`, so every date has a quarter.

`yearOffset` shifts the FY number. The February example needs it, because after its short FY27 the calendar year 2027 is FY28.

`calendars/built-in.json` is the built-in calendar, and a test fails if it and `FiscalCalendarDefinition.builtIn` disagree. `calendars/calendar-year.json` is the same plain January start under another name. `calendars/february-transition.json` is the old February calendar with the short FY27. `fq` reads any of them:

```sh
fq --calendar calendars/calendar-year.json
```

A file with a gap, an overlap, or an open-ended explicit era is rejected with the reason.

## Other calendars

Your calendar drives the menu bar. Other calendars sit beside it, for a customer or a partner whose year is not yours. Add one in Calendar, under Others: give it a name and a start month and day, or import a calendar file. The panel lists each one with its quarter and days left, amber in its last two weeks. Click a line to copy its status line with the name in front.

`fq` reads the same list. `--calendar` takes a saved name as well as a file, and `--all` prints every calendar:

```sh
fq --calendar SpaceX
fq --all
```

```
Yours   FY26-Q4 · Day 11 of 92 · week 2 · 82 days left
SpaceX  FY26-Q4 · Day 11 of 92 · week 2 · 82 days left
```

Names are unique, ignoring case, so a name always finds one calendar.

## Requirements

- A Mac on macOS 13 or later
- Xcode 14 or later, to build the app
- Swift 5.9 or later, if you only want `swift test`

Open `FiscalQuarter.xcodeproj` directly. Opening the folder can load the Swift package instead of the app target.

`project.yml` describes the Xcode project, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) writes `FiscalQuarter.xcodeproj` from it. The generated project is committed, so you only need XcodeGen to change targets or settings. Edit `project.yml`, then run `xcodegen` in this directory. New Swift files in an existing folder are picked up the next time it runs.

## Handing it to someone

From this directory:

```sh
scripts/package.sh
```

That runs the tests, builds a universal app, and writes two files:

- `dist/FiscalQuarter-1.6.zip`
- `dist/FiscalQuarter-1.6.dmg`

The disk image has the app, a shortcut to Applications, and `How to install.txt`. Drag the app to Applications and open it. The script signs the app, the widget, `fq`, and the disk image with the Developer ID certificate in your keychain, with the hardened runtime and a secure timestamp. Set `SIGN_IDENTITY` to use another certificate.

It also notarizes the app and the disk image and staples the tickets, so they open like any other app, even offline. That needs a notarytool profile in your keychain, made once:

```sh
xcrun notarytool store-credentials fiscalquarter --apple-id YOU@EXAMPLE.COM --team-id YZ36Z8GSEN
```

It asks for an app-specific password, which you make at account.apple.com under Sign-In and Security. Without the profile the script warns and builds an unnotarized copy, and the first open needs a Control-click, then Open, then Open again. `NOTARIZE=1` stops instead of warning, `NOTARIZE=0` skips notarizing, and `NOTARY_PROFILE` names another profile.

`fq` is inside the app. Each time the app opens from Applications, it links `~/.local/bin/fq` to that copy, so the command follows the app through updates. It leaves an `fq` that is not its own alone. About says where `fq` is, and asks you to add `~/.local/bin` to `PATH` if your shell does not have it. To make the link by hand:

```sh
mkdir -p "$HOME/.local/bin"
ln -sfn "/Applications/FiscalQuarter.app/Contents/MacOS/fq" "$HOME/.local/bin/fq"
```

```sh
fq
fq --id
fq --status
fq --json
fq --copy
fq --date 2026-10-05
```

`--id` prints `FY26-Q4`. `--status` prints the one line the panel copies. `--json` prints one object. `--copy` copies the id. `--date` takes `YYYY-MM-DD` and is for checking a boundary without changing the clock.

Open at login uses the macOS login-item API. It applies after the app is in Applications. If macOS is waiting on approval, the panel says so.

## Build and run

From this directory:

```sh
xcodebuild -project FiscalQuarter.xcodeproj -scheme FiscalQuarter -configuration Release -destination 'platform=macOS' -derivedDataPath build build
open build/Build/Products/Release/FiscalQuarter.app
```

Or open the project and press Run:

```sh
open FiscalQuarter.xcodeproj
```

The project signs with team `YZ36Z8GSEN`, which the App Group needs. To build under another team, change `DEVELOPMENT_TEAM` in `project.yml` and `SharedSettings.appGroup` in `FiscalQuarterCore/SharedSettings.swift`, then run `xcodegen`. iOS also needs a different `group.` ID, because App Group IDs are unique across all teams. If macOS says the app cannot be opened, Control-click `FiscalQuarter.app`, choose Open, then choose Open again.

To keep it installed:

```sh
cp -R build/Build/Products/Release/FiscalQuarter.app /Applications/
open /Applications/FiscalQuarter.app
```

To show it after every login, add Fiscal Quarter in System Settings, General, Login Items.

## Command line, without packaging

```sh
swift run fq --date 2026-10-09
```

## Tests

Calendar tests, without launching the app:

```sh
swift test
```

The same tests through Xcode:

```sh
xcodebuild -project FiscalQuarter.xcodeproj -scheme FiscalQuarter -destination 'platform=macOS' -derivedDataPath build test
```

## Project layout

- `FiscalQuarterCore/FiscalCalendar.swift` maps a date to a quarter and builds the snapshot the panel and `fq` share
- `FiscalQuarterCore/FiscalCalendarDefinition.swift` describes a calendar as eras, including the built-in one
- `FiscalQuarterCore/SavedCalendars.swift` stores the other calendars
- `FiscalQuarterCore/SharedSettings.swift` is the App Group the apps, widgets, and `fq` share
- `calendars/` holds example calendar files
- `FiscalQuarterCore/Countdown.swift` counts down to the end of the quarter, half, and year
- `FiscalQuarterCore/Milestone.swift` works out when each milestone falls and stores the list
- `FiscalQuarterApp/MilestonesView.swift` lists, adds, and changes milestones, and sets notifications
- `FiscalQuarterCore/Reminders.swift` plans which notifications fall in the next 30 days
- `FiscalQuarterApp/ReminderScheduler.swift` schedules that plan with macOS or iOS
- `FiscalQuarteriOS/MilestonesScreen.swift` lists, adds, and changes milestones on iPhone and iPad, and sets notifications
- `FiscalQuarterApp/` is the menu bar UI, including the line, year, and ring pictures. The iOS app shares `CalendarModel.swift`, `QuarterClock.swift`, and `YearPicture.swift`
- `FiscalQuarterCore/Appearance.swift` is the shared look: background, type, colors, and what is shown
- `FiscalQuarterUI/` is SwiftUI shared by both apps and both widgets: the theme, the background pictures, and the countdown views
- `FiscalQuarterWidget/` is the countdown widget, built once for the Mac and once for iOS
- `FiscalQuarteriOS/` is the iPhone and iPad app
- `project.yml` generates `FiscalQuarter.xcodeproj`
- `FiscalQuarterCLI/fq.swift` is the `fq` command
- `FiscalQuarterApp/CommandLineTool.swift` links `~/.local/bin/fq` to the copy inside the app
- `FiscalQuarterTests/` is the XCTest suite
- `FiscalQuarter.xcodeproj` builds the apps and widgets
- `scripts/package.sh` writes the zip and the disk image
- `Package.swift` runs the calendar tests with `swift test` and builds `fq`
