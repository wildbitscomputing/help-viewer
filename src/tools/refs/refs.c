
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

enum {
    MODE_NONE,
    MODE_DESC,
    MODE_EXAMPLE,
};

void print_escaped(FILE* file, char* str) {
    while (*str) {
        if (*str == '\\') {
            fputs("\\\\", file);
        } else if (*str == '"') {
            fputs("\\\"", file);
        } else {
            fputc(*str, file);
        }
        str++;
    }
}

int main(int argc, char* argv[]) {
    if (argc != 5) {
        return 0;
    }

    FILE* input = fopen(argv[1], "r");
    if (input == NULL) {
        fprintf(stderr, "Could not load %s\n", argv[1]);
        goto done;
    }

    FILE* cout = fopen(argv[3], "w");
    if (cout == NULL) {
        fprintf(stderr, "Could not open %s for writing\n", argv[3]);
        goto done;
    }

    FILE* doc = fopen(argv[2], "w");
    if (doc == NULL) {
        fprintf(stderr, "Could not open %s for writing\n", argv[2]);
        goto done;
    }

    // Output header in cout

    bool first = true;

    while (!feof(input)) {
        char line[1024];
        fgets(line, 1024, input);

        int len = strlen(line);

        if (len > 9 && strncmp(line, "KEYWORD: ", 9) == 0) {
            if (line[len - 1] == '\n') {
                line[len - 1] = 0;
            }

            if (!first) {
                fprintf(cout, "},\n");
                fputc(0x00, doc);
            }

            fputs("    {\"", cout);
            print_escaped(cout, line + 9);
            fputs("\"", cout);

            fprintf(cout, ", %s", argv[4]);

            first = true;
        } else {
            // Description
            if (first) {
                int pos = ftell(doc);

                fprintf(cout, ", %d", pos);
            }

            fprintf(doc, "%s", line);
            first = false;
        }
    }

    fputc(0x00, doc);
    fprintf(cout, "},");

done:
    fclose(input);
    fclose(cout);
    return 0;
}
