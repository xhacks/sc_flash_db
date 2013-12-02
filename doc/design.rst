Design
------

Sectors
+++++++

Key value pairs are stored in a circular series of flash sectors. Each
sector starts with a one-byte header:

* A value 0x54 indicates that the sector is in use and contains valid data.

* A value 0x55 indicates that the sector is in use and it is the newest
  sector containing valid data.

* A value 0x50 indicates that the sector is in use and it is the oldest
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

