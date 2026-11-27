# Robotalia frontend guidelines

The living rules for frontend work, followed by the `frontend-builder` subagent and the main
session, and checked in review. `CLAUDE.md` wins where the two differ.

They apply to the code you add or change. Some older code does not follow them yet: leave it alone
unless the task is about it.

A rule is added or changed only after the owner approves its exact wording (see `CLAUDE.md`).

## 1. Structure
- Every view and partial lives under `app/views`, in the folder of its resource. Partials for one
  page go in a subfolder, such as `accounts/dashboard/_summary.html.erb`.
- Controllers, models and services do not build HTML.
- A new partial receives its data as locals, not instance variables.
- Views do not add database queries: the controller or a service provides the data.
- Logic longer than a short conditional moves to a helper or a presenter.

## 2. Figures
- Format figures with the `DashboardHelper` methods, such as `money`, `percent` and `ratio`.
- An undefined figure (`nil`) shows `DashboardHelper::DASH`, never zero, "NaN" or "Infinity".
- Views show figures as the metrics services compute them and do not calculate new metrics.

## 3. Tailwind and design
- Style with Tailwind classes, not `style` attributes.
- Write each class name in full, without string interpolation, so Tailwind can find it.
- Use `profit_class` and `heat_class` for gain and loss colours. Do not add new hex colours.
- Match the existing cards (`rounded-lg border border-gray-200 bg-white p-4`).
- Pages work from phone width up to the widest layout.

## 4. Hotwire
- Use Turbo Frames and Streams before writing JavaScript.
- A Stimulus controller is small, has one behaviour and lives in `app/javascript/controllers`.
- Filter state lives in the URL, so a page can be bookmarked and reloaded.

## 5. Accessibility
- Use semantic elements: `section` with an `aria-label`, `dl`/`dt`/`dd` for figures, and
  `th` with `scope` and `aria-sort` in tables.
- Colour is never the only signal: keep the minus sign, or add a text label.
- A chart has a table view of the same data.

## 6. Security
- No `html_safe`, `raw` or `<%==` on data. Trusted library markup, such as Pagy's navigation, is
  the exception.
- Pass data to JavaScript through `data-*` attributes, not inline scripts.

## 7. Testing
- Each change to what a page shows has a spec that renders it, such as a request spec.
- Add a `data-testid` when a spec has no stable text or semantic element to select.
- A page still renders with no trades, and with filters that match nothing.
