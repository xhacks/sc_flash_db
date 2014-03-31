#define SECTOR_VALID          0x54
#define SECTOR_VALID_HEAD     0x55
#define SECTOR_UNINITIALISED  0xFF
#define SECTOR_ERASED_TAIL    0x7F
#define SECTOR_ERASED         0x5F
#define SECTOR_EMPTY          0x00

#define OFFSET_LEN_LSB           0
#define OFFSET_LEN_MSB           1
#define OFFSET_LEN_KEY           2
#define OFFSET_KEY               3
#define OFFSET_RECORD_VALID(N)   (N-1)

#define RECORD_VALID          0xAA
#define RECORD_VINALID        0x00

static int head_sector;
static int head_index;

/** Function that reads one byte from a sector
 *
 * \param sector sector number
 * \param index the number of the byte
 * \returns the byte
 */
static int read_byte(int sector, int index) {
}

/** Function that tests whether the record matches a key
 *
 * \param sector sector number
 * \param index the index into the sector where the record is
 * \param key the key
 * \returns 1 if the key matches.
 */
static int is_key(int sector, int index, char key[]) {
    int len = read_byte(sector, index+OFFSET_LEN_KEY);
    for(int i = 0; i < len; i++) {
        if (read_byte(sector, index + OFFSET_KEY + i) != key[i]) {
            return 0;
        }
    }
    return 1;
}

/** Function that returns the record length
 *
 * \param sector sector number
 * \param index the index into the sector where the record is
 * \returns the length of the record
 */
static int record_length(int sector, int index) {
    return read_byte(sector, index + OFFSET_LEN_LSB) |
           read_byte(sector, index + OFFSET_LEN_MSB) << 8;
}


int flash_db_iterate(char key[n], int n, int &position){

}

/*
Garbage collection
++++++++++++++++++

Garbage collection comprises pushing all the data into the first few
sectors. This process comprises copying all data into fresh sectors:

#. Record the sector that is currently marked as the newest.

#. Find the oldest valid key-value pair in the oldest sector.

#. Write this value.

#. Repeat until all key-value pairs upto and including the records in the
   currently newest sector have been copied.

This should have minimised the number of sectors used.
*/

void flash_db_compress() {
    int sector = head_sector;
    int previous_sector = head_sector;
    for(int i = 0; i < sectors; i++) {
        int sector = (sector + 1) % sectors;
        int sector_tag = read_byte(sector, 0);
        if (sector_tag == SECTOR_VALID || sector_tag == SECTOR_VALID_HEAD) {
            int index = 1;
            while(1) {
                int length = record_length(sector, index);
                record_tag = read_byte(index + length - 1);
                if (record_tag == RECORD_VALID) {
                    if (SECTOR_SIZE - head_index < length) {      // No space in this sector
                        new_head_sector = (head_sector + 1) % sectors;
                        assert (read_byte(new_head_sector, 0) == SECTOR_ERASED); 
                        write_byte(new_head_sector, 0, SECTOR_VALID_HEAD);
                        write_byte(head_sector, 0, SECTOR_VALID);
                        head_sector = new_head_sector;
                        head_index = 1;
                    }
                    for(int j = 0; j <= length; j++) {
                        int byte = read_byte(sector, index + j);
                        write_byte(head_sector, head_index + j, byte);
                    }
                }
                index += length;
            }
            write_byte(previous_sector, 0, SECTOR_ERASED);
            erase_sector(sector);
            write_byte(sector, 0, SECTOR_ERASED_TAIL);
        } else if (sector_tag == SECTOR_EMPTY) {
            write_byte(previous_sector, 0, SECTOR_ERASED);
            erase_sector(sector);
            write_byte(sector, 0, SECTOR_ERASED_TAIL);
        } else {
            // HELP.
        }
        previous_sector = sector;
    }
}
/*
fsck
++++


On initialisation the database is checked for consistency, and fixed if
necessary. The fix only fixes operations that were interrupted (such as
write and erase operations), it does not fix random corruption of flash.

Iterate through the sectors in turn, and check that the sector headers are
a sequence 0x5F*, 0x7F, 0x54, {0,0x54}*, 0x55.

* If 0x7F is missing, erase the first sector after 0x5F and erase it, mark
  it as 0x7F.

* Now check that the newest record in the newest sector is consistent,
  that is, a tag 0xAA at offset N. If not, mark that record as EMPTY
  (0x00), check that the length is sensible.

* If the newest record was sensible, check for any duplicates of it
  anywhere. Erase it if found.

* Now verify that the last sector (post 0x7F) is not empty. If it is, erase
  it, mark it as 0x7F, mark the previous one as 0x5F and repeat.

Now, check if any sector is completely empty, if so mark as empty (0x00),
and check if there are any old empty sectors that can be erased.
*/


void flash_db_check(){

}


void flash_db_init(){
    for(head_sector = 0; head_sector < sectors; head_sector++) {
        if (read_byte(head_sector, 0) == SECTOR_VALID_HEAD) {
            break;
        }
    }

    head_index = 1;
    while(1) {
        int length = record_length(head_sector, head_index);
        if (length == NO_LENGTH) {
            break;
        }
        head_index += length;
    }
}


/*
Searching for a key-value pair
++++++++++++++++++++++++++++++

#. Search for sector 0x55.

#. In this sector, search the required key.

#. If the key is not found in this sector, go back to the previous sector,
   and search. Repeat until an uninitialised sector.
*/

/** Function that finds a key/value pair, returns the index (as the return value)
 * and the sector number (through a pointer)
 */
static int flash_db_find(char key[], int *the_sector) {
    int index = 1;
    int sector = head_sector;
    while(1) {
        while(1) {
            if (is_key(sector, index, key)) {
                *the_sector = sector;
                return index;
            }
            int length = record_length(sector, index);
            if (length == NO_LENGTH) {
                break;
            }
            index += length;
        }
        while(1) {
            sector--;
            if (sector < 0) {
                sector = max_sector;
            }
            int head_byte = read_byte(sector, 0);
            
            if (head_byte == SECTOR_VALID) {
                index = 1;
                break;
            }
            if (head_byte != SECTOR_EMPTY) {
                return -1;
            }
            // Invalid header - skip this sector.
        }
    }
}

int flash_db_get(char key[], unsigned char buffer[n], int n){
    int sector, index;
    index = flash_db_find(key, &sector);
    return record_value(sector, index, buffer, n);
}

/*

Writing a key-value pair
++++++++++++++++++++++++

When a key-value pair is written, the value will overwrite any existing
value belonging to this key. A successful write will mean the value is
overwritten. If the function does not return then the new value may have
taken hold, or the old value may still be there.

Writing a key-value pair first involves finding a location. The location is
normally in the sector marked 0x55, but if this sector does not have enough
space to contain the new key-value pair, then the rest of the sector is
left empty (if there are at least 5 bytes, then an empty key-value record
is created; otherwise all bytes are left 0xff), the sector is marked 0x54,
and the next sector is marked 0x55. If no empty sectors are found, invoke
the garbage collector and try again.

To write the key value pair:

#. First write the length bytes in locations 0/1 and then N-2/N-1.

#. Now write the key length, the key, and the value.

#. Finally write the valid byte to contain 0xAA.

Without requiring any buffering, this can be performed as six write operations.

When the write is completed, search for a previous occurrence of the key,
and if found, overwrite the valid byte to 0x00. If this is found, then
check if this sector is empty, and if so, mark the sector with 0x00. Now
check if this is the last sector, and if so, erase the sector and mark with
0x7F.
*/

int flash_db_put(char key[], unsigned char buffer[n], int n) {
    int sector;
    int index = flash_db_find(key, &sector);
    int length = n + OFFSET_KEY + keylen;

aap:
    if (SECTOR_SIZE - head_index < length) {      // No space in this sector
        new_head_sector = (head_sector + 1) % sectors;
        head_index = 1;                           //now check that there is more than one free
        if (read_byte((new_head_sector + 1) % sectors, 0) == SECTOR_VALID) { 
            // compress
            // if (no space) return -1;
            goto aap;
        }
        write_byte(new_head_sector, 0, SECTOR_VALID_HEAD);
        write_byte(head_sector, 0, SECTOR_VALID);
        head_sector = new_head_sector;
        head_index = 1;
    }

    write_byte(head_sector, head_index + OFFSET_LEN_MSB, length >> 8);
    write_byte(head_sector, head_index + OFFSET_LEN_LSB, length & 0xff);
    write_byte(head_sector, head_index + OFFSET_LEN_KEY, keylen);
    write_bytes(head_sector, head_index + OFFSET_KEY, key, keylen);
    write_bytes(head_sector, head_index + OFFSET_KEY + keylen, buffer, n);
    write_byte(head_sector, head_index + length - 1, RECORD_VALID);
    head_index += length;

// TODO, figure out old length
    write_byte(sector, index + OFFSET_RECORD_VALID, RECORD_INVALID);
    
    index = 1;
    while(1) {
        int length = record_length(sector, index);
        if (read_byte(sector, index + OFFSET_RECORD_VALID) == RECORD_VALID) {
            return 0;
        }
        if (length == NO_LENGTH) {
            break;
        }
        head_index += length;
    }
    write_byte(sector, 0, SECTOR_EMPTY);
    while(read_byte(sector, 0) == SECTOR_EMPTY) {
        int previous_sector = sector-1;
        if (previous_sector < 0) {
            previous_sector = sectors;
        }
        if (read_byte(previous_sector, 0) == SECTOR_ERASED_TAIL) {
            write_byte(previous_sector, 0, SECTOR_ERASED);
            erase_sector(sector);
            write_byte(sector, 0, SECTOR_ERASED_TAIL);
        }
        sector++;
        if (sector == sectors) {
            sector = 0;
        }
    }
    return 0;
}



/*
Design
------

Sectors
+++++++

Key value pairs are stored in a circular series of flash sectors. Each
sector starts with a one-byte header:

* A value 0x54 indicates that the sector is in use and contains valid data.

* A value 0x55 indicates that the sector is in use and it is the newest
  sector containing valid data.

* A byte 0xFF indicates that this sector should be erased before use

* A value 0x00 indicates that this sector is entirely empty and should be
  erased.

* A value 0x7F indicates that the sector has been erased.

Ie, there is a series of tags 0x7F 0x7F 0x7F 0x50 0x00 0x54 0x55 0x7F 0x7F
indicating three sectors with data and one sector that is entirely empty,
with three empty sectors before and two empty sectors after.

A typical sector header life cycle is that all headers are set to 0x7F,
then used and set to 0x55, then to 0x54 (possibly to 0x00).
When garbage collected it is erased; becomes
temporarily 0xFF, and is then set to 0x7F again.

Key value pairs
+++++++++++++++

Each key value pair comprises a sequence of N bytes:

#. two bytes header denoting the length of this key value pair (including
   the header), N. The two bytes are stored most significant byte first,
   and N shall be smaller than 65280 (ie, the first byte shall not be 0xFF).

#. one byte header designating the validity of the key-value pair. Possible
   values are 0xFF (uninitialised), 0xAA (valid), and 0x00 (no longer
   valid).

#. one byte header denoting the length of the key, LK

#. LK bytes comprising the key

#. N-LK-6 bytes comprising the value

#. two bytes trailer denoting the length of this key value pair, N. Here, N
   is written LSB first. Given the aforementioned constraints on N, the
   last byte cannot be 0xFF.

For a key value pair to be valid, the two length fields at the
beginning and the end should be identical, and the header should contain
the value 0xAA. A value 0x00 indicates that this key-value pair is not in use
and should be recycled. 

Key value pairs never straddle a sector boundary; if a new one would
straddle one, the sector is terminated by creating an empty pair to fill
the final sector, before using the next empty sector.


Writing a key-value pair
++++++++++++++++++++++++

When a key-value pair is written, the value will overwrite any existing
value belonging to this key. A successful write will mean the value is
overwritten. If the function does not return then the new value may have
taken hold, or the old value may still be there.

Writing a key-value pair first involves finding a location. The location is
normally in the sector marked 0x55, but if this sector does not have enough
space to contain the new key-value pair, then the rest of the sector is
left empty (if there are at least 5 bytes, then an empty key-value record
is created; otherwise all bytes are left 0xff), the sector is marked 0x54,
and the next sector is marked 0x55. If no empty sectors are found, invoke
the garbage collector and try again.

To write the key value pair:

#. First write the length bytes in locations 0/1 and then N-2/N-1.

#. Now write the key length, the key, and the value.

#. Finally write the valid byte to contain 0xAA.

Without requiring any buffering, this can be performed as six write operations.

When the write is completed, search for a previous occurrence of the key,
and if found, overwrite the valid byte to 0x00. If this is found, then
check if this sector is empty, and if so, mark the sector with 0x00. Now
check if this is the last sector, and if so, erase the sector and mark with
0x7F.

Garbage collection
++++++++++++++++++

Garbage collection comprises pushing all the data into the first few
sectors. This process comprises copying all data into fresh sectors:

#. Record the sector that is currently marked as the newest.

#. Find the oldest valid key-value pair in the oldest sector.

#. Write this value.

#. Repeat until all key-value pairs upto and including the records in the
   currently newest sector have been copied.

This should have minimised the number of sectors used.

fsck
++++

On initialisation the database is checked for consistency, and fixed if
necessary. The fix only fixes operations that were interrupted (such as
write and erase operations), it does not fix random corruption of flash.

Iterate through the sectors in turn, and find any sectors with a mark
different from 0x7F, 0x55, and 0x00 and erase this sector. Inside the first
and the last sector we must check that the records are consistent; that is,
the bytes at location N-1 and N-2 must be the length N.

* In the last sector, check all records for inconsistencies in the length
  bytes. If any inconsitency is found, then erase the sector.

* In the first sector, find the first element and check for any
  inconsistenct length bytes; if found, then make the length bytes
  consistent by writing N into N-1 and N-2. It maybe that the first write
  of N was interrupted, in which case the lenght will be a random number,
  therefore verify that the rest of the sector is empty (0xFF), before
  making the length byte a small number, and creating an empty record of
  that length.

Finally, we must check that there isn't a duplicate record. This can only
be the last record that was written. So search for an old value of the
newest record, and delete that if found.

Now, check if any sector is completely empty, if so mark as empty (0x00),
and check if there are any old empty sectors that can be erased.

Caching
+++++++

The library caches the head sector. This is initialised when the library
init function is called, and then kept up-to-date.
*/
