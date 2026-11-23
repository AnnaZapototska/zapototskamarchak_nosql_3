import csv
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
IMPORT_DIR = BASE_DIR / "import"

IMPORT_DIR.mkdir(exist_ok=True)


def convert_file(input_name, output_name, headers, columns=None):
    input_path = BASE_DIR / input_name
    output_path = IMPORT_DIR / output_name

    with input_path.open(encoding="latin-1") as f_in, \
            output_path.open("w", newline="", encoding="utf-8") as f_out:

        writer = csv.writer(f_out)
        writer.writerow(headers)

        for line in f_in:
            parts = line.rstrip("\n").split("::")

            if columns is not None:
                parts = parts[:columns]

            writer.writerow(parts)

    print(f"Converted {input_name} -> {output_path}")


# Movies: MovieID::Title::Genres
convert_file(
    "movies.dat",
    "movies.csv",
    ["movieId", "title", "genres"]
)

# Ratings: UserID::MovieID::Rating::Timestamp
convert_file(
    "ratings.dat",
    "ratings.csv",
    ["userId", "movieId", "rating", "timestamp"]
)

# Users: UserID::Gender::Age::Occupation::Zip
# We don't need the ZIP code.
convert_file(
    "users.dat",
    "users.csv",
    ["userId", "gender", "age", "occupation"],
    columns=4
)
