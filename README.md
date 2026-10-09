# Fiscal Quarter

A macOS menu bar app for a fiscal calendar. The built-in calendar starts in February. FY27 is an 11-month transition year. From January 2027 the quarters follow the calendar year.

On 2026-10-09 the quarter is **FY27-Q4**. The menu bar reads `FY27-Q4 · 84d`: day 9 of 92, week 2, 84 days left, counting today. Click it for the start and end, a progress bar, the next quarter, and copy. While the year is still FY27, the panel also says that FY28 starts on January 1 and follows the calendar year.

Copy quarter id puts `FY27-Q4` on the pasteboard. Copy status line puts `FY27-Q4 · Day 9 of 92 · week 2 · 84 days left`. In the last two weeks the days-remaining figure turns amber, and the last week and last day get a line of their own. Open at login, Calendar, About, and Quit are in the same panel. About links to mlynn.org, GitHub, and LinkedIn.

Calendar keeps the built-in year unless you choose a custom start. A custom year is four quarters of three months. The FY number is the calendar year that fiscal year ends in. A year that starts on 1 February 2025 ends on 31 January 2026, so it is FY26. A 1 January start ends in the same calendar year, so 2026 is FY26. The built-in calendar is the one with the short FY27. A custom February start does not repeat that exception. `fq` reads the same choice. The app has no Dock icon, no network access, and no account.

Line, Year, and Ring are three pictures of that year, in one slot. Line is the picture that opens. Each month is a bar as long as its days, and a wider gap separates the quarters, so FY27 Q3 is visibly the short one. A ring sits on today. Year turns those months into calendars, two quarters to a row: days already passed are filled, today is a hollow ring, and the current quarter is green. Ring draws the same year as a circle. In FY27 it starts at the top with February and runs clockwise, and the day of the month sits in the middle. The choice is remembered.

`fq` prints the same facts for a shell or a script. The packaged app carries that binary at `Contents/MacOS/fq`.

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

From 2027-01-01, fiscal years follow the calendar year. 2027 is FY28, split into Jan-Mar, Apr-Jun, Jul-Sep, and Oct-Dec. That part is inferred from the transition year ending in December. If a later calendar is published, change `calendarYearQuarter` in `FiscalQuarterCore/FiscalCalendar.swift`.

Days remaining counts today through the last day of the quarter. On the last day the value is 1.

Week 1 is the first seven days of the quarter, counting the start date. Day 8 is week 2. A 92-day quarter runs to week 14.

The percent is the day index divided by the length of the quarter, rounded to the nearest integer. 2026-10-09 is day 9 of 92, which is 10%.

The pure function is `FiscalCalendar.quarter(containing:)`.

```swift
let quarter = FiscalCalendar.quarter(containing: CalendarDate(year: 2026, month: 10, day: 5))
quarter.id // "FY27-Q4"
```

`FiscalCalendar.quarter(on:calendar:)` reads a `Date` in a chosen calendar. The app passes `Calendar.current`, so the machine's local time zone decides the civil day.

## Requirements

- A Mac on macOS 13 or later
- Xcode 14 or later, to build the app
- Swift 5.9 or later, if you only want `swift test`

Open `FiscalQuarter.xcodeproj` directly. Opening the folder can load the Swift package instead of the app target.

## Handing it to someone

From this directory:

```sh
scripts/package.sh
```

That runs the tests, builds a universal app, and writes two files:

- `dist/FiscalQuarter-1.2.zip`
- `dist/FiscalQuarter-1.2.dmg`

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
swift run fq -- --date 2026-10-09
```

The `--` belongs to Swift Package Manager. The installed `fq` does not need it.

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
- `FiscalQuarterApp/` is the menu bar UI, including the line, year, and ring pictures
- `FiscalQuarterCLI/fq.swift` is the `fq` command
- `FiscalQuarterTests/` is the XCTest suite
- `FiscalQuarter.xcodeproj` builds the app
- `scripts/package.sh` writes the zip and the disk image
- `Package.swift` runs the calendar tests with `swift test` and builds `fq`
