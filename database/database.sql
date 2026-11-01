-- =====================================================================
-- NewsPulse - Oracle APEX news aggregator
-- Database script: tables, constraints, function, procedures, sources
-- Run in: SQL Workshop > SQL Scripts (Create > paste > Run)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) Tables
-- ---------------------------------------------------------------------

-- RSS feeds followed by the application (one feed = one category)
CREATE TABLE sources (
  source_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            VARCHAR2(100)  NOT NULL,
  feed_url        VARCHAR2(500)  NOT NULL UNIQUE,
  category        VARCHAR2(20)   NOT NULL,
  is_active       CHAR(1) DEFAULT 'Y' NOT NULL,
  last_fetched_at DATE,
  CONSTRAINT chk_category CHECK (category IN ('TECH', 'SCIENCE', 'ECONOMIE', 'SPORT',
                                              'MONDE', 'SANTE', 'CULTURE')),
  CONSTRAINT chk_is_active CHECK (is_active IN ('Y', 'N'))
);

-- Articles collected from the feeds (the UNIQUE link prevents duplicates)
CREATE TABLE articles (
  article_id   NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  source_id    NUMBER NOT NULL REFERENCES sources(source_id),
  title        VARCHAR2(500)  NOT NULL,
  link         VARCHAR2(1000) NOT NULL UNIQUE,
  published_at DATE,
  summary      VARCHAR2(4000),
  fetched_at   DATE DEFAULT SYSDATE NOT NULL
);

-- Articles saved by the user
CREATE TABLE bookmarks (
  bookmark_id  NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  article_id   NUMBER NOT NULL UNIQUE REFERENCES articles(article_id),
  note         VARCHAR2(400),
  created_at   DATE DEFAULT SYSDATE NOT NULL
);

-- ---------------------------------------------------------------------
-- 2) Function: convert the RSS date text into an Oracle DATE
--    e.g. 'Fri, 30 Oct 2026 10:15:00 GMT' -> DATE (NULL if unreadable)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION parse_rss_date (p_text IN VARCHAR2) RETURN DATE AS
BEGIN
  RETURN TO_DATE(REGEXP_SUBSTR(p_text, '\d{1,2} \w{3} \d{4} \d{2}:\d{2}:\d{2}'),
                 'DD Mon YYYY HH24:MI:SS',
                 'NLS_DATE_LANGUAGE = ENGLISH');
EXCEPTION
  WHEN OTHERS THEN
    RETURN NULL;
END parse_rss_date;
/

-- ---------------------------------------------------------------------
-- 3) Procedure: fetch the articles of ONE source
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE fetch_news (p_source_id IN NUMBER) AS
  l_url  sources.feed_url%TYPE;
  l_xml  CLOB;
BEGIN
  -- A) Find the feed URL
  SELECT feed_url INTO l_url
  FROM   sources
  WHERE  source_id = p_source_id;

  -- B) Download the RSS feed
  l_xml := apex_web_service.make_rest_request(
             p_url => l_url, p_http_method => 'GET');

  IF apex_web_service.g_status_code <> 200 THEN
    raise_application_error(-20001,
      'Feed not reachable, HTTP code ' || apex_web_service.g_status_code);
  END IF;

  -- C) Parse the XML, remove duplicates inside the feed, insert only new articles
  MERGE INTO articles a
  USING (
    SELECT title, link, published_at, summary
    FROM (
      SELECT SUBSTRB(x.title, 1, 500)            AS title,
             SUBSTRB(x.link, 1, 1000)            AS link,
             parse_rss_date(x.pub_date)          AS published_at,
             DBMS_LOB.SUBSTR(x.summary, 1000, 1) AS summary,
             ROW_NUMBER() OVER (PARTITION BY SUBSTRB(x.link, 1, 1000)
                                ORDER BY NULL)   AS rn
      FROM XMLTABLE('/rss/channel/item'
             PASSING XMLTYPE(l_xml)
             COLUMNS title    VARCHAR2(4000) PATH 'title',
                     link     VARCHAR2(4000) PATH 'link',
                     pub_date VARCHAR2(100)  PATH 'pubDate',
                     summary  CLOB           PATH 'description') x
      WHERE x.link IS NOT NULL
        AND x.title IS NOT NULL
    )
    WHERE rn = 1
  ) s
  ON (a.link = s.link)
  WHEN NOT MATCHED THEN
    INSERT (source_id, title, link, published_at, summary)
    VALUES (p_source_id, s.title, s.link, s.published_at, s.summary);

  -- D) Record the last fetch time
  UPDATE sources
  SET    last_fetched_at = SYSDATE
  WHERE  source_id = p_source_id;
END fetch_news;
/

-- ---------------------------------------------------------------------
-- 4) Procedure: fetch the articles of ALL active sources
--    One broken feed does not stop the others.
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE fetch_all_news AS
BEGIN
  FOR src IN (SELECT source_id, name FROM sources WHERE is_active = 'Y') LOOP
    BEGIN
      fetch_news(src.source_id);
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line('Error for ' || src.name || ' : ' || SQLERRM);
    END;
  END LOOP;
  COMMIT;
END fetch_all_news;
/

-- ---------------------------------------------------------------------
-- 5) Initial sources
-- ---------------------------------------------------------------------
INSERT INTO sources (name, feed_url, category)
VALUES ('BBC Technology', 'https://feeds.bbci.co.uk/news/technology/rss.xml', 'TECH');
INSERT INTO sources (name, feed_url, category)
VALUES ('TechCrunch', 'https://techcrunch.com/feed/', 'TECH');
INSERT INTO sources (name, feed_url, category)
VALUES ('Hacker News', 'https://news.ycombinator.com/rss', 'TECH');
INSERT INTO sources (name, feed_url, category)
VALUES ('BBC Science', 'https://feeds.bbci.co.uk/news/science_and_environment/rss.xml', 'SCIENCE');
INSERT INTO sources (name, feed_url, category)
VALUES ('BBC Business', 'https://feeds.bbci.co.uk/news/business/rss.xml', 'ECONOMIE');
INSERT INTO sources (name, feed_url, category)
VALUES ('BBC Sport', 'https://feeds.bbci.co.uk/sport/rss.xml', 'SPORT');
INSERT INTO sources (name, feed_url, category)
VALUES ('BBC World', 'https://feeds.bbci.co.uk/news/world/rss.xml', 'MONDE');
INSERT INTO sources (name, feed_url, category)
VALUES ('BBC Health', 'https://feeds.bbci.co.uk/news/health/rss.xml', 'SANTE');
INSERT INTO sources (name, feed_url, category)
VALUES ('BBC Culture', 'https://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml', 'CULTURE');

COMMIT;

-- ---------------------------------------------------------------------
-- 6) First load (optional)
-- ---------------------------------------------------------------------
-- BEGIN
--   fetch_all_news;
-- END;
-- /
