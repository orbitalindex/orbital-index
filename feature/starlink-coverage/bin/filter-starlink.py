import re
import sys
import os


def filter(file):
    print("Filtering file \"" + file + "\"")

    with open(file, 'r') as active_file:
        active_sats = active_file.read()

        regex = r"^STARLINK-\d+.*\n1.*\n2.*$"

        starlinks = re.findall(regex, active_sats, re.MULTILINE)

        print(str(len(starlinks)) + " Starlink satellite TLEs found.")

        out = "\n".join(starlinks)

        with open('starlink-data.txt', 'w') as f:
          f.write(out)

if __name__ == "__main__":
    try:
        file = sys.argv[1]
    except IndexError:
        print("Usage: " + os.path.basename(__file__) + " <file>")
        sys.exit(1)

    # start the program
    filter(file)
