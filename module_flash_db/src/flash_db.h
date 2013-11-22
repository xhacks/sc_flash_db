/** Function to initialise the flash database.
 */
extern void flash_db_init();

/** Function that retrieves the value for a given key. Keys are ASCII
 * strings that can be up to 256 characters long, and can contain any
 * character except for '\0'. Values can be up to 65536 bytes long.
 *
 * \param key    key to search for
 * \param buffer value that is retrieved
 * \param n      the maximum number of bytes that can be retrieved
 * \returns      the number of bytes in the value, or -1 if not found
 */
extern int flash_db_get(char key[], unsigned char buffer[n], int n);

/** Function that stores or updates the value for a given key. Keys are ASCII
 * strings that can be up to 256 characters long, and can contain any
 * character except for '\0'. Values can be up to 65536 bytes long.
 *
 * \param key    key to store the value under
 * \param buffer value to store
 * \param n      the number of bytes in the value.
 */
extern void flash_db_put(char key[], unsigned char buffer[n], int n);

/** Function that retrieves keys that are stored in the database. The order
 * in which the keys are retrieved is not specified. Repeated calls to this
 * function retrieve a new key each time. No calls to flash_db_put or
 * flash_db_compress shall be made between calls to iterate.
 *
 * \param key      Output parameter storing the retrieved key
 * \param n        Input parmater specifying the lenght of the key array
 * \param position Set to 0 for the initial call. This parameter holds state between calls.
 * \returns 0 if no more keys are present, or 1 if a key was found.
 */
extern int flash_db_iterate(char key[n], int n, int &position);

/** This call compresses the database. Call this when the program has some
 * time on its hands - not calling this ever will cause occasionaly calls
 * to flash_db_put to compress when required. After compression all
 * key-value pairs are stored in as few sectors of flash as possible, and all other flash sectors will have been erased.
 */
extern void flash_db_compress();

/** This call checks the that the database is consistent. It should be
 * called once on startup if it is not known whether the system was shut
 * down gracefully. If the system was shut down halfway during the update
 * to a key-value pair, then this function will ensure that either the old
 * or the new key-value pair are retrieved.
 */
extern void flash_db_check();
