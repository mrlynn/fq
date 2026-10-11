# Fiscal Quarter

A macOS menu bar app for a fiscal calendar. FY27 began 1 February 2026 and ends 31 December. The current quarter, Q4, is 1 October through 31 December. From January 2027 the year starts on 1 January.

On 2026-10-09 the quarter is **FY27-Q4**. The menu bar reads `FY27-Q4 · 84d`: day 9 of 92, week 2, 84 days left, counting today. Click it for the start and end, a progress bar, the next quarter, and copy. While the year is still FY27, the panel also says that FY28 starts on January 1 and follows the calendar year.

Copy quarter id puts `FY27-Q4` on the pasteboard. Copy status line puts `FY27-Q4 · Day 9 of 92 · week 2 · 84 days left`. In the last two weeks the days-remaining figure turns amber, and the last week and last day get a line of their own. Open at login, Calendar, About, and Quit are in the same panel. About links to mlynn.org, GitHub, and LinkedIn.

Calendar keeps the built-in year unless you choose a custom start. A custom year is four quarters of three months. The FY number is the calendar year that fiscal year ends in. A year that starts on 1 February 2025 ends on 31 January 2026, so it is FY26. A 1 January start ends in the same calendar year, so 2026 is FY26. The built-in calendar is the one with the short FY27. A custom February start does not repeat that exception. `fq` reads the same choice. The app has no Dock icon, no network access, and no account.

Line, Year, and Ring are three pictures of that year, in one slot. Line is the picture that opens. Each month is a bar as long as its days, and a wider gap separates the quarters, so FY27 Q3 is visibly the short one. A ring sits on today. Year turns those months into calendars, two quarters to a row: days already passed are filled, today is a hollow ring, and the current quarter is green. Ring draws the same year as a circle. In FY27 it starts at the top with February and runs clockwise, and the day of the month sits in the middle. The choice is remembered.

`fq` prints the same facts for a shell or a script. The packaged app carries that binary at `Contents/MacOS/fq`.

## Countdowns

The panel counts down to the end of the quarter, the half, and the fiscal year. When they end on the same day they share a line, so on 2026-10-11 the panel shows one line, `FY27-Q4 · H2 · FY27`, with 82 days. The menu next to Countdown switches between days, workdays, weeks, and weekends. Workdays are Monday through Friday. Holidays are not known, so they count as workdays. Weekends counts the one in progress.

Click a countdown line to put it in the menu bar. The menu bar keeps the unit you chose, so it can read `FY27 · 59wd` or `FY27-Q4 · 11w 5d`. The default is still `FY27-Q4 · 82d`.

```sh
fq --countdown
```

```
FY27-Q4 · H2 · FY27 ends 2026-12-31
  82 days · 59 workdays · 12 weekends
```

`fq --json` carries the same figures under `countdowns`, one object each for the quarter, the half, and the year.

A half is the first two quarters or the last two. A calendar file with a year of other than four quarters puts the extra quarter in the first half.

## Widgets

The Mac app carries a Fiscal countdown widget for the desktop and Notification Center, in small and medium sizes. After the app has opened once, right-click the desktop, choose Edit Widgets, and find Fiscal Quarter. Small shows one countdown. Medium adds the quarter, the half, and the year side by side, each with its own bar, because they start on different days even when they end together.

Each widget has its own settings under Edit Widget: what to count to, the unit, the calendar, and a label. The calendar is the built-in one or a start month and day, so a widget labelled SpaceX with a 1 January start reads FY26 while yours reads FY27. Widgets do not read the app's calendar setting or its other calendars. Sharing those needs an App Group, and an App Group needs a signing team.

The countdown turns amber in the last two weeks, as in the panel.

## iPhone and iPad

`FiscalQuarteriOS` is the same calendar on a phone: the quarter, the three pictures, the countdowns, the other calendars, and your calendar setting. Tap a calendar to copy its status line, or share the status line from the toolbar.

Its widget comes in the same small and medium sizes, plus three Lock Screen sizes: a ring with the number, a line with a bar, and a single line of text.

To run it in the simulator, choose the `FiscalQuarteriOS` scheme and an iPhone simulator, then press Run. A device needs a signing team: set `DEVELOPMENT_TEAM` in `project.yml`, run `xcodegen`, and choose your iPhone.

The web prototype stores `CURRENT_QUARTER` as the string `FY27-Q3` and does not follow the wall clock. This app reads the local calendar date instead. Opened in October 2026, it shows Q4.

## Calendar

Quarters are not equal length. FY27 is an 11-month transition year that ends in December 2026.

| Id | Start | End |
| --- | --- | --- |
| FY27-Q1 | 2026-02-01 | 2026-04-30 |
| FY27-Q2 | 2026-05-01 | 2026-07-31 |
| FY27-Q3 | 2026-08-01 | 2026-09-30 |
| FY27-Q4 | 2026-10-01 | 2026-12-31 |

FY26-Q4 is 2025-11-01 through 2026-01-31. FY26-Q1 through FY26-Q3 fill February through October 2025, using the same February, May, August, and November starts:

| Id | Start | End |
| --- | --- | --- |
| FY26-Q1 | 2025-02-01 | 2025-04-30 |
| FY26-Q2 | 2025-05-01 | 2025-07-31 |
| FY26-Q3 | 2025-08-01 | 2025-10-31 |
| FY26-Q4 | 2025-11-01 | 2026-01-31 |

Years before FY26 use that February start as well. February of calendar year Y is FY(Y - 1999). January still belongs to Q4 of the fiscal year that started the previous February.

From 2027-01-01, fiscal years follow the calendar year. 2027 is FY28, split into Jan-Mar, Apr-Jun, Jul-Sep, and Oct-Dec. That part is inferred from the transition year ending in December. If a later calendar is published, change `FiscalCalendarDefinition.builtIn` in `FiscalQuarterCore/FiscalCalendarDefinition.swift` and `calendars/built-in.json` together. A test fails if they disagree.

Days remaining counts today through the last day of the quarter. On the last day the value is 1.

Week 1 is the first seven days of the quarter, counting the start date. Day 8 is week 2. A 92-day quarter runs to week 14.

The percent is the day index divided by the length of the quarter, rounded to the nearest integer. 2026-10-09 is day 9 of 92, which is 10%.

The pure function is `FiscalCalendar.quarter(containing:)`.

```swift
let quarter = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 10, day: 5))
quarter.id // "FY27-Q4"
```

`FiscalCalendar.quarter(on:calendar:)` reads a `Date` in a chosen calendar. The app passes `Calendar.current`, so the machine's local time zone decides the civil day.

## Calendar files

A calendar is data: a list of eras. Each era starts on its `from` date and runs until the next one starts. An era either repeats a `months` rule (four three-month quarters from `startMonth`/`startDay`) or lists its quarters outright with `explicit`, which is how FY27 is written. The first era has no `from`, and the first and last eras must use `months`, so every date has a quarter.

`yearOffset` shifts the FY number. The built-in calendar needs it because 2027 is FY28, not FY27.

`calendars/built-in.json` is the built-in calendar. `calendars/calendar-year.json` is a plain January start, where 2026-10-11 is FY26-Q4. `fq` reads either one:

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
Yours   FY27-Q4 · Day 11 of 92 · week 2 · 82 days left
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

- `dist/FiscalQuarter-1.3.zip`
- `dist/FiscalQuarter-1.3.dmg`

The disk image has the app, a shortcut to Applications, and `How to install.txt`. Drag the app to Applications and open it. The first open may need a Control-click, then Open, then Open again. The app is ad-hoc signed, so a paid Apple Developer account is not required.

`fq` is inside the app. After it is in Applications:

```sh
mkdir -p "$HOME/.local/bin"
ln -sfn "/Applications/FiscalQuarter.app/Contents/MacOS/fq" "$HOME/.local/bin/fq"
```

Add `~/.local/bin` to `PATH` if it is not already there.

```sh
fq
fq --id
fq --status
fq --json
fq --copy
fq --date 2026-10-05
```

`--id` prints `FY27-Q4`. `--status` prints the one line the panel copies. `--json` prints one object. `--copy` copies the id. `--date` takes `YYYY-MM-DD` and is for checking a boundary without changing the clock.

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

The project ad-hoc signs the app, so a paid Apple Developer account is not required. If macOS says the app cannot be opened, Control-click `FiscalQuarter.app`, choose Open, then choose Open again.

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
- `calendars/` holds example calendar files
- `FiscalQuarterCore/Countdown.swift` counts down to the end of the quarter, half, and year
- `FiscalQuarterApp/` is the menu bar UI, including the line, year, and ring pictures. The iOS app shares `CalendarModel.swift`, `QuarterClock.swift`, and `YearPicture.swift`
- `FiscalQuarterWidget/` is the countdown widget, built once for the Mac and once for iOS
- `FiscalQuarteriOS/` is the iPhone and iPad app
- `project.yml` generates `FiscalQuarter.xcodeproj`
- `FiscalQuarterCLI/fq.swift` is the `fq` command
- `FiscalQuarterTests/` is the XCTest suite
- `FiscalQuarter.xcodeproj` builds the apps and widgets
- `scripts/package.sh` writes the zip and the disk image
- `Package.swift` runs the calendar tests with `swift test` and builds `fq`
