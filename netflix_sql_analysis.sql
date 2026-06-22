use netflix;
SELECT COUNT(*) FROM netflixx;

DESCRIBE netflixx;

SELECT DISTINCT type
FROM netflixx;

-- DATA CLEANING :
select 
count(*) - count(id) as missing_id ,
count(*) - count(title) as missing_title,
count(*) - count(type) as missing_type ,
count(*) - count(description) as missing_desc,
count(*) - count(release_year) as missing_release_year,
count(*) - count(age_certification) as missing_age_cert,
count(*) - count(runtime) as missing_runtime,
count(*) - count(imdb_id) as missing_imdb_id,
count(*) - count(imdb_score) as missing_imdb_score,
count(*) - count(imdb_votes) as missing_imdb_votes
from netflixx;

# in description there are 5 missing values,
# in age_certification there are 2285 missing values,
# in imdb_votes there are 16 missing values.

select id, title , type, count(*) 
from netflixx
group by id, title , type
having count(*) >1;

# no duplicates found

set sql_safe_updates = 0;

UPDATE netflixx
SET age_certification='Not Rated'
WHERE age_certification IS NULL; 

UPDATE netflixx
SET description='Not Available'
WHERE description IS NULL;

SELECT type, COUNT(*) total_titles
FROM netflixx
GROUP BY type;

SELECT age_certification, COUNT(*) total_titles
FROM netflixx
GROUP BY age_certification
ORDER BY total_titles DESC;

SELECT MIN(runtime) min_runtime, MAX(runtime) max_runtime, AVG(runtime) avg_runtime
FROM netflixx;

SELECT
    MIN(release_year) AS earliest_year,
    MAX(release_year) AS latest_year
FROM  netflixx;

SELECT 
    release_year,
    COUNT(CASE WHEN type = 'MOVIE' THEN 1 END) AS total_movies,
    COUNT(CASE WHEN type = 'SHOW' THEN 1 END) AS total_shows,
    COUNT(*) AS total_titles
FROM netflixx
GROUP BY release_year
ORDER BY release_year;

-- 1. Which was the best movie and TV show overall in the last 50 years?

CREATE VIEW popularity_data AS
SELECT
    title,
    type,
    imdb_score,
    imdb_votes,
    release_year,
    (imdb_score * imdb_votes) AS popularity_score
FROM netflixx
WHERE release_year >= (
    SELECT MAX(release_year) - 50
    FROM netflixx
)
AND imdb_votes IS NOT NULL;

-- TOP 5 MOVIES

SELECT *
FROM popularity_data
WHERE type = 'MOVIE'
ORDER BY popularity_score DESC
LIMIT 5;

-- TOP 5 SHOWS

SELECT *
FROM popularity_data
WHERE type = 'SHOW'
ORDER BY popularity_score DESC
LIMIT 5;


-- MOVIE SEGMENTATION AS HIT/AVERAGE/FLOP

WITH movie_scores AS (
    SELECT 
        id,
        title,
        type,
        imdb_score,
        imdb_votes,
        imdb_score * imdb_votes AS popularity_score,
        NTILE(3) OVER (
            ORDER BY imdb_score * imdb_votes DESC
        ) AS quartile
    FROM netflixx
    WHERE imdb_votes IS NOT NULL
)

SELECT *,
    CASE 
        WHEN quartile = 1 THEN 'Hit'
        WHEN quartile = 2 THEN 'Average'
        ELSE 'Flop'
    END AS quality_flag
FROM movie_scores;

/* 2.How many movies do we have in our dataset across the last few years? Do we have more representation of movies from the last 20 years or is the dataset free from any
such skewness? */

-- YEAR-WISE MOVIE COUNT TREND

SELECT 
    release_year,
    COUNT(DISTINCT id) AS total_movies
FROM netflixx
WHERE type='MOVIE'
GROUP BY release_year
ORDER BY release_year;

-- DECADE-LEVEL ANALYSIS

SELECT 
    CONCAT(FLOOR(release_year / 10) * 10, 's') AS decade,
    COUNT(DISTINCT id) AS total_movies
FROM netflixx
WHERE type = 'MOVIE'
GROUP BY decade
ORDER BY decade;

-- SKEWNESS VALIDATION

SELECT 
    CASE 
        WHEN release_year >= 2010 
        THEN '2010 and After'
        ELSE 'Before 2010'
    END AS period,
    COUNT(DISTINCT id) AS total_movies,
    ROUND( 
        COUNT(DISTINCT id) * 100.0 /
        (SELECT COUNT(DISTINCT id)
         FROM netflixx
         WHERE type = 'MOVIE'),
        2
    ) AS percentage_share
FROM netflixx
WHERE type = 'MOVIE'
GROUP BY period;

-- The movie dataset shows a significant temporal skewness, with 86.50% of movies released after 2010 and only 13.50% released before 2010. 
-- This indicates a strong bias toward recent content, and analyses across different time periods should consider this imbalance.

 /* 3. On average, how has the IMDb score been trending over the last 50 years? Has it been deteriorating or improving? */

SELECT 
    release_year,
    ROUND(AVG(imdb_score), 2) AS average_imdb_score
FROM netflixx
WHERE release_year >= (
    SELECT MAX(release_year) - 50
    FROM netflixx
)
AND imdb_score IS NOT NULL
GROUP BY release_year
ORDER BY release_year;

-- The average IMDb score has remained largely stable over the last 50 years, with minor fluctuations. 
-- There is no strong evidence of continuous improvement or deterioration; however, recent years show a slight downward trend in average ratings.

/* 4. Have more people started voting for movies/shows on IMDb over the last 50 years? */

SELECT 
    release_year,
    SUM(imdb_votes) AS total_imdb_votes
FROM netflixx
WHERE release_year >= (
        SELECT MAX(release_year) - 50
        FROM netflixx
)
AND imdb_votes IS NOT NULL
GROUP BY release_year
ORDER BY release_year;

SELECT 
    release_year,
    ROUND(AVG(imdb_votes), 0) AS avg_votes_per_title
FROM netflixx
WHERE release_year >= (
        SELECT MAX(release_year) - 50
        FROM netflixx
)
AND imdb_votes IS NOT NULL
GROUP BY release_year
ORDER BY release_year;

-- The total number of IMDb votes increases significantly after 2010. However, this trend is strongly affected by 
-- the larger number of movies and shows available in recent years.
-- When normalized by the number of titles, the average IMDb votes per title do not show a consistent increasing trend. 
-- Therefore, the rise in total votes is mainly due to the growth in content volume rather than increased audience participation.

/* 5. On average, how has the runtime changed over the last 50 years? */

SELECT 
    release_year,
    ROUND(AVG(runtime), 2) AS average_runtime
FROM netflixx
WHERE release_year >= (
        SELECT MAX(release_year) - 50
        FROM netflixx
)
AND runtime IS NOT NULL
GROUP BY release_year
ORDER BY release_year;

-- The average runtime has gradually decreased over the last 50 years and has become more consistent in recent years. 
-- Early-year fluctuations are likely caused by fewer available titles, while recent years show a clear trend toward shorter content durations.

/* 6. How does age certification of a movie affect its rating? */

-- OVERALL

SELECT 
    age_certification,
    ROUND(AVG(imdb_score), 2) AS average_imdb_score,
    COUNT(DISTINCT id) AS total_titles
FROM netflixx
WHERE age_certification IS NOT NULL
AND imdb_score IS NOT NULL
GROUP BY age_certification
ORDER BY average_imdb_score DESC;

-- FOR SHOWS

SELECT 
    age_certification,
    ROUND(AVG(imdb_score), 2) AS average_imdb_score,
    COUNT(DISTINCT id) AS total_shows
FROM netflixx
WHERE type = 'SHOW'
AND age_certification IS NOT NULL
AND imdb_score IS NOT NULL
GROUP BY age_certification
ORDER BY average_imdb_score DESC;

-- FOR MOVIES

SELECT 
    age_certification,
    ROUND(AVG(imdb_score), 2) AS average_imdb_score,
    COUNT(DISTINCT id) AS total_movies
FROM netflixx
WHERE type = 'MOVIE'
AND age_certification IS NOT NULL
AND imdb_score IS NOT NULL
GROUP BY age_certification
ORDER BY average_imdb_score DESC;

-- We have three insights from this: 
-- ● On average, TV shows have higher ratings as compared to movies. 
-- ● On average, within TV shows, TV-14 gets the highest rating. 
-- ● On average, within Movies, PG-13 movies have the highest rating.

