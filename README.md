# NewsPulse – News Aggregator (Oracle APEX)

NewsPulse automatically collects news from several RSS feeds (BBC, TechCrunch, Hacker News),
stores them in an Oracle database, and displays them in an Oracle APEX application,
organized by category (Tech, Science, Business, Sport, World, Health, Culture).

## Features
- Automatic news collection from RSS feeds every hour (APEX Automation)
- "Refresh" button to fetch the latest news on demand
- Interactive report with search, filters by category/source, and export
- Source management page (add, edit, disable feeds) with an Interactive Grid
- Dashboard with key figures and charts (articles by category and by source)

## Tech stack
Oracle APEX 26.2 · Oracle Database · SQL · PL/SQL

## Database
| Table | Content |
|---|---|
| `SOURCES` | RSS feeds: name, URL, category, active flag, last fetch time |
| `ARTICLES` | Collected articles: title, link, publication date, summary |
| `BOOKMARKS` | Saved articles with a note |

Data rules are enforced in the database with constraints
(primary keys, foreign keys, `UNIQUE` on the article link, `CHECK` on categories).

## How it works
1. The PL/SQL procedure `fetch_news` downloads a feed with `APEX_WEB_SERVICE`.
2. `XMLTABLE` turns the XML into rows.
3. `ROW_NUMBER` removes duplicates inside the feed, and `MERGE` inserts only new articles.
4. `fetch_all_news` loops over all active sources; one broken feed does not stop the others.
5. An APEX Automation runs `fetch_all_news` every hour, and the "Refresh" button runs it on demand.

## Installation
1. In SQL Workshop > SQL Scripts, run `database/database.sql`.
2. In App Builder > Import, import `apex/f64552.sql`.
3. Run `BEGIN fetch_all_news; END;` to load the first articles.
4. In Shared Components > Automations, set the automation status to **Active**
   (automations are disabled after an import).

## Screenshots
![Dashboard](screenshots/dashboard.png)
![Articles](screenshots/articles.png)
![Sources](screenshots/sources.png)

## Author
Khadija Sassioui – Personal project (2026)
