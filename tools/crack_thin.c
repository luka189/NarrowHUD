/* Finds a stand-in name for each 32-bit network id ("thin hash": the upper 32 bits of MurmurHash64A, seed 0, of
 * the name). The engine only compares hashes, so a string with the same thin hash works as the real name in
 * GameSession.game_object_is_type / game_object_field and Network.object_info (research/GAME_OBJECTS.md).
 *
 *   cc -O3 -fopenmp -o crack_thin research/crack_thin.c
 *   ./crack_thin 0x803159b3 0x5d9752f9 ...        (or ids one per line on stdin with -)
 *
 * Tries every string of [a-z0-9_] starting with a letter, length 1 to 7, and prints "0xid name" for the first it
 * finds per id. Length 7 covers ~78 billion strings, so every id gets a hit; most need 6 or 7 letters.
 */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char AL[] = "abcdefghijklmnopqrstuvwxyz0123456789_";
#define NA 37

static inline uint32_t thin(const unsigned char *s, int len) {
    const uint64_t m = 0xC6A4A7935BD1E995ULL;
    uint64_t h = (uint64_t)len * m;   /* seed 0 */
    uint64_t t = 0;
    for (int i = len - 1; i >= 0; i--) t = (t << 8) | s[i];   /* len <= 7: the tail only */
    h ^= t;
    h *= m;
    h ^= h >> 47;
    h *= m;
    h ^= h >> 47;
    return (uint32_t)(h >> 32);
}

static uint32_t *ids;
static char (*found)[16];
static int nids;
static volatile int left;

static int find(uint32_t v) {
    int lo = 0, hi = nids - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (ids[mid] == v) return mid;
        if (ids[mid] < v) lo = mid + 1; else hi = mid - 1;
    }
    return -1;
}

static int cmp(const void *a, const void *b) {
    uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b;
    return x < y ? -1 : x > y;
}

int main(int argc, char **argv) {
    int cap = 1024;
    ids = malloc(sizeof(uint32_t) * cap);
    char line[64];
    for (int a = 1; a < argc; a++) {
        if (strcmp(argv[a], "-") == 0) {
            while (fgets(line, sizeof line, stdin)) {
                if (nids == cap) ids = realloc(ids, sizeof(uint32_t) * (cap *= 2));
                if (line[0] == '0' || (line[0] >= 'a' && line[0] <= 'f') || (line[0] >= '1' && line[0] <= '9'))
                    ids[nids++] = (uint32_t)strtoul(line, NULL, 16);
            }
        } else {
            if (nids == cap) ids = realloc(ids, sizeof(uint32_t) * (cap *= 2));
            ids[nids++] = (uint32_t)strtoul(argv[a], NULL, 16);
        }
    }
    if (nids == 0) { fprintf(stderr, "usage: crack_thin 0xid ... | -\n"); return 1; }
    qsort(ids, nids, sizeof(uint32_t), cmp);
    int u = 0;
    for (int i = 0; i < nids; i++) if (i == 0 || ids[i] != ids[u - 1]) ids[u++] = ids[i];
    nids = u;
    found = calloc(nids, 16);
    left = nids;
    for (int len = 1; len <= 7 && left > 0; len++) {
        long long total = 26;
        for (int i = 1; i < len; i++) total *= NA;
        #pragma omp parallel for schedule(dynamic, 65536)
        for (long long n = 0; n < total; n++) {
            if (left == 0) continue;
            unsigned char s[8];
            long long k = n;
            s[0] = AL[k % 26]; k /= 26;
            for (int i = 1; i < len; i++) { s[i] = AL[k % NA]; k /= NA; }
            int at = find(thin(s, len));
            if (at >= 0 && found[at][0] == 0) {
                #pragma omp critical
                {
                    if (found[at][0] == 0) {
                        memcpy(found[at], s, len); found[at][len] = 0;
                        left--;
                    }
                }
            }
        }
        fprintf(stderr, "length %d done, %d id(s) left\n", len, left);
    }
    for (int i = 0; i < nids; i++) printf("0x%08x %s\n", ids[i], found[i][0] ? found[i] : "(none)");
    return 0;
}
