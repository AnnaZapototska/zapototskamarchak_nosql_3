// QUERY 1
// Thriller movies with average rating > 4

MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre {name: 'Thriller'})
MATCH (u:User)-[r:RATED]->(m)
WITH m, avg(r.rating) AS averageRating, count(r) AS ratingsCount
WHERE averageRating > 4
RETURN
    m.title AS movie,
    round(averageRating, 2) AS averageRating,
    ratingsCount
ORDER BY averageRating DESC;

// QUERY 2
// Users who gave 5-star ratings to more than 50 movies

MATCH (u:User)-[r:RATED]->()
WHERE r.rating = 5
WITH u, count(r) AS fiveStarRatings
WHERE fiveStarRatings > 50
RETURN
    u.userId AS userId,
    fiveStarRatings
ORDER BY fiveStarRatings DESC;

// QUERY 3
// Movies rated 4 or higher by both User 1 and User 2

MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)
MATCH (u2:User {userId: 2})-[r2:RATED]->(m)
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN
    m.title AS movie,
    r1.rating AS user1Rating,
    r2.rating AS user2Rating
ORDER BY movie;

// QUERY 4
// Average ratings by genre

MATCH (m:Movie)-[:HAS_GENRE]->(g:Genre)
MATCH (u:User)-[r:RATED]->(m)
WITH
    g.name AS genre,
    avg(r.rating) AS averageRating,
    count(r) AS ratingsCount
RETURN
    genre,
    round(averageRating, 2) AS averageRating,
    ratingsCount
ORDER BY averageRating DESC;


// QUERY 5
// Recommendations based on similar users

MATCH (target:User {userId: 1})-[targetRating:RATED]->(common:Movie)
MATCH (other:User)-[otherRating:RATED]->(common)
WHERE other <> target
  AND abs(targetRating.rating - otherRating.rating) <= 1

WITH target, other, count(common) AS commonMovies
WHERE commonMovies >= 3

MATCH (other)-[r:RATED]->(recommended:Movie)
WHERE r.rating >= 4
  AND NOT EXISTS {
      MATCH (target)-[:RATED]->(recommended)
  }

RETURN
    recommended.title AS movie,
    count(DISTINCT other) AS recommendedByUsers,
    round(avg(r.rating), 2) AS averageRating
ORDER BY recommendedByUsers DESC, averageRating DESC
LIMIT 10;


// QUERY 6
// Shortest path between User 1 and User 2
// through shared movies

MATCH (u1:User {userId: 1}),
      (u2:User {userId: 2})

MATCH p = shortestPath(
    (u1)-[:RATED*..6]-(u2)
)

RETURN
    p AS connectionPath,
    length(p) AS pathLength;
