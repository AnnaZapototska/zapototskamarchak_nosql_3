// 1. Load Users
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
SET
    u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);

// 2. Load Movies
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
SET
    m.title = row.title;

// 3. Load Genres
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
WITH row, split(row.genres, '|') AS genres
UNWIND genres AS genre
MERGE (g:Genre {name: genre});

// INDEXES

CREATE INDEX user_userId IF NOT EXISTS
FOR (u:User) ON (u.userId);

CREATE INDEX movie_movieId IF NOT EXISTS
FOR (m:Movie) ON (m.movieId);

CREATE INDEX genre_name IF NOT EXISTS
FOR (g:Genre) ON (g.name);

// LOAD RATED RELATIONSHIPS

CALL apoc.periodic.iterate(
    "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row
     RETURN row",
    "MATCH (u:User {userId: toInteger(row.userId)})
     MATCH (m:Movie {movieId: toInteger(row.movieId)})
     MERGE (u)-[r:RATED]->(m)
     SET
         r.rating = toFloat(row.rating),
         r.timestamp = toInteger(row.timestamp)",
    {
        batchSize: 10000,
        parallel: false
    }
)
YIELD batches, total, errorMessages
RETURN batches, total, errorMessages;


// LOAD HAS_GENRE RELATIONSHIPS

LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
WITH row, split(row.genres, '|') AS genres
UNWIND genres AS genre
MATCH (m:Movie {movieId: toInteger(row.movieId)})
MATCH (g:Genre {name: genre})
MERGE (m)-[:HAS_GENRE]->(g);


MATCH (u:User)
RETURN count(u) AS users;

MATCH (m:Movie)
RETURN count(m) AS movies;

MATCH (g:Genre)
RETURN count(g) AS genres;

MATCH ()-[r:RATED]->()
RETURN count(r) AS ratings;

MATCH ()-[r:HAS_GENRE]->()
RETURN count(r) AS genreRelationships;

CALL {
    MATCH (u:User)
    RETURN count(u) AS users
}
CALL {
    MATCH (m:Movie)
    RETURN count(m) AS movies
}
CALL {
    MATCH (g:Genre)
    RETURN count(g) AS genres
}
CALL {
    MATCH ()-[r:RATED]->()
    RETURN count(r) AS ratings
}
CALL {
    MATCH ()-[r:HAS_GENRE]->()
    RETURN count(r) AS genreRelationships
}
RETURN users, movies, genres, ratings, genreRelationships;
