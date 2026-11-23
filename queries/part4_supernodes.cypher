// PART 4 — FIND SUPERNODES
// Nodes with the highest number of relationships


MATCH (n)
OPTIONAL MATCH (n)-[r]-()
WITH n, count(r) AS degree
RETURN
    labels(n) AS nodeLabels,
    properties(n) AS nodeProperties,
    degree
ORDER BY degree DESC
LIMIT 30;

// GENRE NODES — relationship degree

MATCH (g:Genre)
OPTIONAL MATCH (g)-[r]-()
RETURN
    g.name AS genre,
    count(r) AS degree
ORDER BY degree DESC;

// USER NODES — relationship degree

MATCH (u:User)
OPTIONAL MATCH (u)-[r]-()
RETURN
    u.userId AS userId,
    count(r) AS degree
ORDER BY degree DESC
LIMIT 10;

