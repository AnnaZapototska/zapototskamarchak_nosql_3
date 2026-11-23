# MovieLens Knowledge Graph Recommendation System

**Homework 3 -Knowledge Graph for a Recommendation System**\
**Database:** Neo4j 5.18 Community Edition\
**Deployment:** Local Docker container\
**Dataset:** MovieLens 1M

## Project overview

This project models MovieLens 1M as a knowledge graph in Neo4j. Users,
movies, and genres are nodes; user ratings and movie-genre membership
are relationships.

The project covers graph schema design, CSV preparation, batch loading,
Cypher queries, supernode analysis, and comparison of graph and
relational database approaches.

## Repository structure

``` text
zapototskamarchak_nosql_3/
├── docker-compose.yml
├── convert.py
├── movies.dat
├── users.dat
├── ratings.dat
├── import/
│   ├── movies.csv
│   ├── users.csv
│   └── ratings.csv
├── queries/
│   ├── part2_load.cypher
│   ├── part3.cypher
│   └── part4_supernodes.cypher
├── screenshots/
│   ├── part2_counts.png
│   ├── part3_query1.png
│   ├── part3_query2.png
│   ├── part3_query3.png
│   ├── part3_query4.png
│   ├── part3_query5.png
│   ├── part3_query6.png
│   ├── part4_movies.png
│   ├── part4_genres.png
│   └── part4_users.png
└── README.md
```

# Part 1 -Graph schema design

## 1.1. Nodes and relationships

The graph uses three node labels:

-   **User** -`userId`, `gender`, `age`, `occupation`.
-   **Movie** -`movieId`, `title`. The release year remains embedded
    in the title in this implementation; it is not a separate property.
-   **Genre** -`name`.

It uses two relationship types:

-   **`(User)-[:RATED {rating, timestamp}]->(Movie)`** -records a
    user's rating and its timestamp.
-   **`(Movie)-[:HAS_GENRE]->(Genre)`** -connects a movie to each of
    its genres.

## 1.2. Why these entities are nodes and relationships

Users, movies, and genres are distinct entities that participate in many
relationships. A user can rate many movies, a movie can be rated by many
users, and a genre can be assigned to many movies.

A rating is modeled as a relationship because it describes an
interaction between a particular user and a particular movie. Its
`rating` and `timestamp` properties belong naturally to that
interaction. This makes user-to-movie traversals direct.

An alternative is to create a separate `Rating` node connected to both a
User and a Movie. That design is more flexible if a rating needs its own
lifecycle, moderation, comments, multiple events, or additional
relationships. However, it introduces an extra node and two
relationships for every rating, making common user-to-movie traversals
more verbose and increasing graph size. Since MovieLens ratings are
simple user-to-movie events with two properties, a relationship is the
more compact choice here.

## 1.3. Why Genre is a separate node

A separate `Genre` node gives each genre a shared identity and makes
genre-based traversal and analysis straightforward. For example, the
graph can find all movies connected to `Thriller` or calculate rating
statistics for each genre.

A list property on Movie would be simpler for some filters and could
avoid traversing a highly connected Genre node. However, it would not
represent Genre as a shared entity and would make graph queries
involving genre relationships less natural. Separate Genre nodes are
useful for the relationship-analysis goals of this assignment.

## 1.4. ASCII graph schema

``` text
(User {
    userId,
    gender,
    age,
    occupation
})
       |
       | RATED {
       |   rating,
       |   timestamp
       | }
       v
(Movie {
    movieId,
    title
})
       |
       | HAS_GENRE
       v
(Genre {
    name
})
```

A user can rate many movies; a movie can be rated by many users and can
belong to multiple genres.

------------------------------------------------------------------------

# Part 2 -Data preparation and loading

## 2.1. Dataset and CSV conversion

MovieLens 1M source `.dat` files use `::` as a delimiter and Latin-1
encoding. They were converted to UTF-8 CSV files with a comma delimiter
using `convert.py` and Python's standard `csv` module.

The conversion produces:

-   `movies.csv`: `movieId`, `title`, `genres`
-   `users.csv`: `userId`, `gender`, `age`, `occupation`
-   `ratings.csv`: `userId`, `movieId`, `rating`, `timestamp`

The ZIP code from `users.dat` is omitted because it is not needed for
the graph queries. The year remains embedded in the movie title.

Verified CSV line counts (including one header row per file):

  CSV file          Lines including header   Data rows
  ------------------------------------- -----------
  `movies.csv`                       3,884       3,883
  `users.csv`                        6,041       6,040
  `ratings.csv`                  1,000,210   1,000,209

## 2.2. Neo4j deployment

Neo4j Community Edition 5.18 was deployed locally using Docker Compose.
The container exposes port `7474` for Neo4j Browser and port `7687` for
Bolt connections. The project `import/` directory is mounted into the
container so Neo4j can read CSV files using `file:///...` paths.

Neo4j Browser is available at `http://localhost:7474`.

## 2.3. Loading nodes

The node-loading statements are saved in `queries/part2_load.cypher`.

-   **Users:** `LOAD CSV WITH HEADERS` reads `users.csv`. `toInteger()`
    converts numeric fields, and `MERGE` creates a User node if the
    `userId` does not already exist.
-   **Movies:** `LOAD CSV WITH HEADERS` reads `movies.csv`. `MERGE`
    identifies a Movie by `movieId`, and `SET` assigns its title.
-   **Genres:** the `genres` field is split on `|`. `UNWIND` turns the
    list into individual rows, and `MERGE` creates one shared Genre node
    per distinct genre name.

`MERGE` is used instead of `CREATE` so that rerunning node imports does
not create duplicate nodes for the same key.

## 2.4. Indexes

Indexes are created on `User.userId`, `Movie.movieId`, and `Genre.name`.
They help Neo4j locate nodes when matching relationship endpoints and
when executing queries that filter by these properties. The indexes are
created after loading nodes and before loading relationships, as
required.

## 2.5. Loading relationships in batches

The `RATED` relationships are loaded with `apoc.periodic.iterate()`
using a batch size of 10,000 and `parallel: false`.

The first query reads rows from `ratings.csv`. The action query matches
the already-created User and Movie nodes by their indexed IDs, then uses
`MERGE` to create the `RATED` relationship. The rating is converted to a
floating-point value and the timestamp to an integer.

Batching avoids processing all 1,000,209 ratings in one large
transaction. `parallel: false` follows the assignment's recommendation
and avoids concurrent write operations competing to create or update the
same graph elements.

The `HAS_GENRE` relationships are loaded by reading `movies.csv`,
splitting each movie's genre list, matching the Movie and Genre nodes,
and merging a relationship between them.

## 2.6. Import verification

The following counts were returned by Neo4j:

  Graph element                 Verified count
  --------------------------- ----------------
  `User` nodes                           6,040
  `Movie` nodes                          3,883
  `Genre` nodes                             18
  `RATED` relationships              1,000,209
  `HAS_GENRE` relationships              6,408

The User, Movie, and RATED counts match the expected MovieLens 1M
totals.

------------------------------------------------------------------------

# Part 3 -Cypher queries

All six queries are saved in `queries/part3.cypher`. Screenshots should
show the first ten or fewer visible result rows.

## Query 1 -Thriller movies with average rating above 4.0

The query traverses from Movie nodes to the `Thriller` Genre node and
then matches users who rated each movie. It groups ratings by movie,
calculates `avg(r.rating)` and the number of ratings, filters for an
average above 4.0, and sorts by average rating in descending order.

Observed examples:

  Movie                         Average rating   Ratings count
  --------------------------- ---------------- ---------------
  The Usual Suspects (1995)               4.52           1,783
  A Close Shave (1995)                    4.52             657
  Rear Window (1954)                      4.48           1,050
  The Third Man (1949)                    4.45             480
  The Sixth Sense (1999)                  4.41           2,459

Screenshot: `screenshots/part3_query1.png`

## Query 2 -Users who gave more than 50 five-star ratings

The query matches users and their outgoing `RATED` relationships,
filters relationships to rating 5, groups by user, and counts the
five-star ratings. It then filters the aggregated count to values
greater than 50 and sorts in descending order.

Observed examples:

    User ID   Five-star ratings
  --------- -------------------
       4277                 571
       4169                 476
       3032                 466
       4448                 434
       5100                 424
       1680                 406

Screenshot: `screenshots/part3_query2.png`

## Query 3 -Movies rated highly by both User 1 and User 2

The query matches User 1 and User 2 to the same Movie node through
separate `RATED` relationships. It filters both ratings to values
greater than or equal to 4 and returns the movie title and both ratings.

Observed examples:

  Movie                                      User 1 rating   User 2 rating
  ---------------------------------------- --------------- ---------------
  Awakenings (1990)                                      5               4
  Dead Poets Society (1989)                              4               5
  Driving Miss Daisy (1989)                              4               5
  One Flew Over the Cuckoo's Nest (1975)                 5               5
  Saving Private Ryan (1998)                             5               4
  To Kill a Mockingbird (1962)                           4               4

Screenshot: `screenshots/part3_query3.png`

## Query 4 -Average rating and rating count by genre

The query traverses from each Genre to its Movies and then to the Users
who rated those movies. It groups rating data by genre, calculates the
average rating and number of ratings, and sorts by average rating in
descending order.

A movie can belong to multiple genres. Therefore, its ratings contribute
to the aggregate for each genre assigned to that movie.

Observed examples:

  Genre           Average rating   Ratings count
  ------------- ---------------- ---------------
  Film-Noir                 4.08          18,261
  Documentary               3.93           7,910
  War                       3.89          68,527
  Drama                     3.77         354,529
  Crime                     3.71          79,541
  Animation                 3.68          43,293

Film-Noir has the highest average among the displayed results, while
Drama has a much larger number of ratings. Rating volume is useful
context when interpreting averages.

Screenshot: `screenshots/part3_query4.png`

## Query 5 - Recommendations based on users with similar tastes

The recommendation query uses User 1 as the target. It finds other users
who rated the same movies and retains users whose ratings differ from
the target user's ratings by no more than one point on each shared
movie. It requires at least three shared movies.

It then finds movies those users rated at least 4, excludes movies
already rated by the target user, and returns up to ten recommendations.
Results are ranked by the number of similar users who recommended each
movie and then by average rating.

This is a simplified collaborative-filtering approach. It uses shared
rated movies and a rating-difference condition as a basic similarity
rule; it does not calculate a formal statistical similarity score.

Observed examples:

  Recommended movie                                          Recommending users   Average rating
  -------------------------------------------------------- -------------------- ----------------
  American Beauty (1999)                                                  2,454             4.69
  Star Wars: Episode V -- The Empire Strikes Back (1980)                  2,325             4.60
  Raiders of the Lost Ark (1981)                                          2,096             4.67
  The Silence of the Lambs (1991)                                         2,094             4.60
  The Matrix (1999)                                                       1,975             4.66
  The Shawshank Redemption (1994)                                         1,969             4.71

Screenshot: `screenshots/part3_query5.png`

## Query 6 -Shortest path between two users through movies

The query finds User 1 and User 2 and uses `shortestPath()` over
variable-length `RATED` relationships, traversable in either direction.
The maximum path length is six relationships.

The returned path had length **2** and consisted of User 1, *Dead Poets
Society*, and User 2. Both users rated the same movie.

### Interpreting path length

One hop is one traversal of a `RATED` relationship. The path alternates
between User and Movie nodes:

-   **Length 2:** two users rated the same movie: User A → Movie 1 →
    User B.
-   **Length 4:** two users are connected through one intermediate user
    and two movies: User A → Movie 1 → User B → Movie 2 → User C.
-   **Length 6:** two users are connected through two intermediate users
    and three movies: User A → Movie 1 → User B → Movie 2 → User C →
    Movie 3 → User D.

Longer paths represent indirect connections through other users and
their rated movies.

Screenshot: `screenshots/part3_query6.png`

------------------------------------------------------------------------

# Part 4 -Supernode detection

The queries are saved in `queries/part4_supernodes.cypher`.

## 4.1. Detection method

The first query matches every node, optionally matches relationships
connected to each node in either direction, counts those relationships
as the node's degree, and sorts nodes by degree in descending order. It
returns the 30 highest-degree nodes.

Two additional queries inspect Genre and User nodes separately. This
allows comparison of degree by node type.

Degree is the number of relationships incident to a node. For a Movie,
this includes both `RATED` and `HAS_GENRE`. For a User, it counts
`RATED`. For a Genre, it counts `HAS_GENRE`.

## 4.2. Highly connected examples

  ------------------------------------------------------------------------
  Node type             Node                                        Degree
  --------------------- --------------------- ----------------------------
  Movie                 American Beauty                              3,430
                        (1999)                

  Movie                 Star Wars: Episode IV                        2,995
                        -- A New Hope (1977)  

  Movie                 Star Wars: Episode V                         2,995
                        -- The Empire Strikes 
                        Back (1980)           

  User                  4169                                         2,314

  User                  1680                                         1,850

  User                  4277                                         1,743

  Genre                 Drama                                        1,603

  Genre                 Comedy                                       1,200

  Genre                 Action                                         503

  Genre                 Thriller                                       492
  ------------------------------------------------------------------------

These are high-degree examples from the observed results. The assignment
does not specify a numerical threshold for a supernode, so the term is
used for nodes with unusually many relationships relative to typical
nodes of the same type.

## 4.3. Why can supernodes affect performance?

Indexes help Neo4j find a node by an indexed property, but an index does
not reduce the number of relationships connected to that node. Once a
query reaches a high-degree node, it may need to examine many adjacent
relationships and neighboring nodes. This increases traversal work and
can increase the amount of data to filter, aggregate, or return.

Therefore, a query involving a highly connected node can take longer
than one involving an ordinary node, even if both starting nodes are
found through indexed properties. The cost is associated not only with
locating the node, but also with expanding its relationships.

## 4.4. Possible strategy for this dataset

Genre nodes are shared hubs: `Drama` has 1,603 relationships and
`Comedy` has 1,200. One possible optimization is **denormalization for
selected query patterns**: store genre names as a list property on each
Movie as well as retaining separate Genre nodes and `HAS_GENRE`
relationships.

Queries that only need to filter movies by genre could use the list
property and avoid traversing a shared Genre hub. Separate Genre nodes
should remain for queries that analyze genre relationships or traverse
the graph. This duplicates some data, so the list property must be kept
consistent with the relationships.

Another possible strategy is to split a high-degree logical hub into
smaller partitions only when the application has a meaningful
partitioning key and query patterns can use it. This should not be done
arbitrarily, because it can make the graph model and queries more
complicated.

The degree results identify highly connected nodes; they do not by
themselves prove a measured performance bottleneck. A performance claim
would require comparing query plans or execution times.

Screenshots: `screenshots/part4_movies.png`,
`screenshots/part4_genres.png`, and `screenshots/part4_users.png`

------------------------------------------------------------------------

# Part 6 -Analysis and conclusions

## 6.1. Graph database versus SQL

All six Part 3 queries can be expressed in SQL, so it would be
inaccurate to say that they are impossible in a relational database. The
difference is how naturally relationships are represented and traversed.

Queries 1, 2, and 4 are aggregations and filters that are
straightforward in SQL using joins, `GROUP BY`, and `HAVING`. Query 3 is
also a conventional relational join: the ratings table can be joined to
itself on `movieId` to find movies rated highly by both users.

Queries 5 and 6 are more relationship-oriented. Query 5 requires finding
users with overlapping rating histories and then finding unseen movies
they rated highly. SQL can implement this with joins and common table
expressions, but the logic becomes more involved as similarity rules and
relationship hops are added. Query 6 is a path-traversal problem. A
fixed number of hops can be expressed with repeated self-joins in SQL,
while arbitrary-length traversal generally requires recursive queries or
database-specific graph features. Neo4j expresses this kind of traversal
directly with relationship patterns and `shortestPath()`.

For example, the shared high-rated movies in Query 3 can be found in
SQL:

``` sql
SELECT
    m.movieId,
    m.title,
    r1.rating AS user1Rating,
    r2.rating AS user2Rating
FROM ratings AS r1
JOIN ratings AS r2
    ON r1.movieId = r2.movieId
JOIN movies AS m
    ON m.movieId = r1.movieId
WHERE r1.userId = 1
  AND r2.userId = 2
  AND r1.rating >= 4
  AND r2.rating >= 4
ORDER BY m.title;
```

This shows that the query is possible in SQL. The graph model makes the
shared relationship between the two users and the same movie explicit.

## 6.2. Where a graph database is less suitable

A graph database is not automatically the best choice for every
operation in this dataset. Exporting the complete ratings table,
generating routine tabular reports, calculating large-scale grouped
statistics, or processing all ratings in bulk can be more naturally
handled by a relational database or an analytical processing system.

For example, a report containing the total number of ratings per user or
average rating per genre is an aggregation over many records. SQL
databases are designed for such operations, and their reporting and BI
ecosystems are mature. Neo4j can perform these aggregations too, as
demonstrated in Part 3, but graph traversal does not provide a
particular advantage when the task is simply to aggregate a large set of
records.

The graph model is most valuable when a task depends on relationships
and paths: finding shared movies, discovering similar users, exploring
indirect connections, or producing recommendations through multi-hop
patterns. A practical system could use Neo4j for relationship-heavy
recommendation and exploration features while retaining a relational or
analytical store for bulk reporting and exports.

## 6.3. Possible schema improvements

**Improvement 1 -Store precomputed rating aggregates on Movie nodes
(Queries 1 and 4).**

Queries 1 and 4 repeatedly traverse `RATED` relationships and calculate
averages and counts. For a read-heavy application, the graph could
maintain properties such as `averageRating` and `ratingsCount` on each
Movie node. Query 1 could then filter Thriller movies using stored
aggregate values instead of recalculating them from every rating
relationship. The values would need to be updated when ratings are
added, changed, or removed. Genre-level aggregates could also be
maintained separately if genre reporting is frequent.

**Improvement 2 -Materialize user-similarity relationships (Queries 5
and 6).**

Query 5 repeatedly discovers users with overlapping rating histories. A
derived relationship such as `(User)-[:SIMILAR {weight}]->(User)` could
store a similarity score or the number of shared highly rated movies.
The recommendation query could start from the target user's similarity
relationships rather than recomputing all overlaps on every request. The
same relationship could support a user-to-user path query for Query 6.
These relationships are derived data and need a refresh strategy when
ratings change.

**Improvement 3 -Keep genre lookup data on Movie nodes for selected
filters (Queries 1 and 4).**

A list property such as `genreNames` on Movie nodes could support
selected genre filters without traversing a shared Genre node. The
separate Genre nodes and `HAS_GENRE` relationships should remain if
graph traversal and genre-level relationship analysis are required. This
is a denormalization trade-off: some queries may become simpler, while
data consistency becomes an additional responsibility.

## 6.4. Conclusion

The project demonstrates how MovieLens 1M can be represented as a graph
of users, movies, and genres. Neo4j successfully loaded 6,040 users,
3,883 movies, 18 genres, 1,000,209 ratings, and 6,408 movie-genre
relationships.

The Cypher queries covered filtering and aggregation, shared movie
discovery, a basic collaborative-filtering recommendation, and
shortest-path traversal. The supernode analysis showed that popular
movies, active users, and shared genre nodes can have high degree. It
also illustrated why indexing alone does not remove the cost of
traversing many relationships.

The graph model is particularly convenient for relationship-heavy
recommendation and path queries. Relational databases remain a strong
choice for bulk aggregation, tabular reporting, and exports. The choice
depends on the dominant access patterns, and a combined architecture can
use each database for the tasks it handles best.
