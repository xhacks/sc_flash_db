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

* A value 0x7F indicates that the sector has been erased, but it is the
  last free sector so it shall not be used for data.

* A value 0x5F indicates that the sector has been erased, and it can be
  used for data.

Sectors marked EMPTY should only occur in between sectors that contain
values. If the last sector is empty, it shall be formatted and marked 0x7F.

Ie, there is a series of tags 0x5F 0x5F 0x7F 0x50 0x00 0x54 0x55 0x5F 0x5F
indicating three sectors with data and one sector that is entirely empty,
with three erased sectors before (two of which can be used) and two erased sectors after

A typical sector header life cycle is that the headers is set to 0x7F,
then 0x5F,
then used and set to 0x55, then to 0x54 (possibly to 0x00).
When garbage collected it is erased; becomes
temporarily 0xFF, and is then set to 0x7F again.

Key value pairs
+++++++++++++++

Each key value pair comprises a sequence of N bytes:

#. Bytes 0 and 1 denote the length of this key value pair (including
   the header), N. The two bytes are stored least significant byte first,
   and N shall be smaller than 65280 (ie, the second byte shall not be 0xFF).

#. Byte 2 denotes the length of the key, LK, the length must not be 0 or 0xFF.

#. Bytes 3..LK+2 comprise the key

#. Bytes LK+3..N-2 comprise the value

#. Byte N-1 denotes the validity of the key-value pair. Possible
   values are 0xFF (uninitialised), 0xAA (valid), and 0x00 (no longer
   valid).

Note that if a key-value pair is written one byte at a time from beginning
to end, and the system powers down half-way, then we can establish from the
values as to where the write failed. If Byte 1 is 0xFF, then the length is
invalid; if Byte N-1 is note 0xAA or 0x00 then the key/value pair didn't write.

For a key value pair to be valid, the final byte should contain the value
0xAA. A value 0x00 indicates that this key-value pair is not in use and
should be recycled.

Key value pairs never straddle a sector boundary; if a new one would
straddle the boundary, the last part of the sector is left unused and the
next sector is used.

Searching for a key-value pair
++++++++++++++++++++++++++++++

#. Search for sector 0x55.

#. In this sector, search for the last occurrence of the required key.

#. If the key is not found in this sector, go back to the previous sector,
   and search this sector backwards for the key. Repeat until an
   uninitialised sector or until 0x55 is encountered again.

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

Caching
+++++++

The library caches the location of the newest sector (the head sector), and
the location of the index of the first unwritten byte (the head index).
These are initialised when the library init function is called, and then
kept up-to-date.
