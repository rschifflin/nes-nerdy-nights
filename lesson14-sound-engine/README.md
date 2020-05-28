**Sound engine design**

The goal is to provide an API for playing music and sound effects concurrently, with correct priority.
Additional goals are the ability to make per-channel or per-track modifications like pitch adjustment,
speed changes, looping, etc

***Concepts***

There is some vocabulary and some concepts that need introduction and explanation.
At the top level, we have our hardware _channels_. These are Square1, Square2, Triangle and Noise.
We're ignoring DPCM for this engine for now. Any sound we want to play must be mapped to these channels.
We multiplex many logical channels onto these 4 hardware channels.
We use 3 logical channel sets, called _tracks_. These are the BGM track and two SFX tracks.
Each track has its own set of 4 logical channels, and are organized by priority so that when multiplexing,
the highest priority track takes precedence in which logical channel gets mapped to hardware.

Logical channel state is set by providing an audio stream to its track. Each track uses an audio stream decoder
per logical channel, and that decoder holds the channel state, such as current note, volume, duty cycle, etc.
When asked to decode, the decoder will read bytes from the audio stream and interpret them as state changes.
When a logical channel represented by a decoder is mapped to hardware, this state is written to the equivalent hardware
registers.

Lastly, tracks also monitor which of its logical channels are currently _active_. An active channel is one whose
decoder has the active state, which is set by the audio stream. When a channel is not active, it is not mapped to hardware
even if its part of a high priority track- the priority list provides the highest priority _active_ logical channel to map to each
physical channel in hw.

Decoders operate by reading the audio stream in atomic operations called _ticks_. Each tick for a decoder means reading bytes from
the audio stream until it interprets a byte as a note to play. For instance, the stream head might contain several instructions for
setting the volume, the duty cycle, looping, indicating length or an envelope or instrument, etc. Each tick consumes as many of these
non-actions as there are, until it finally consumes an action- a note to play for the smallest unit of time.

Sound engine usage has the following workflow:

1.  Load sounds in the form of audio streams into the BGM, SFX0 and SFX1 tracks.
    This sets their corresponding decoders to the initial state as specified by the audio stream.
2.  'Tick' each active channel in each track to represent one unit of time elapsing in the audio stream.
3.  Update each track to keep an accurate count of which of its channels are still active after the last tick.
4.  Multiplex the active channels of the tracks together in priority order to form a channel set.
5.  Write the hardware channels from the corresponding constructed channels.

***Audio Stream***
But what _is_ an audio stream? It definitely contains a header, specifying which channels are used and holding addresses of the channel byte streams.
Beyond that, much is still left to decide.

***Decoders***
Since we're not sure what the _encoding_ of an audio stream is yet, we're not sure how to _decode_ it yet either. We do know our internal state will
have a representation of the equivalent hardware registers of a channel, and we will return a bit determining if we're active that can be toggled
by interpreting an eof byte in the encoded stream. Beyond that, much is still left to decide.

***Encoding***
Audio byte streams are encoded by the following:
byte 0-191: Music note index, from 0 = A octave0 to 191 = G# octave 7
byte 192: silence
byte 193: stream eof
byte 194: future notes are length n, where n is the next byte
byte 195: future notes have instrument n, where n is the next byte
byte 196: loop to start of stream

In the future, we could have "loop back m times, distance n_hi,n_lo", where m is the next byte, n is the next further word
In the future, we could have a "length 1" literal to reduce encoding size
In the future, we could have a "length 2" literal to reduce encoding size

Audio byte streams are accompanied by volume byte streams, which control the volume of the channel and are read for each note.
Volume byte streams have their own encoding:
  when the high bit (bit 7) is 0, interpret as a volume value.
    byte 0-15 ($00 - $0F): volume value, set the channel to this volume
  when the high bit (bit 7) is 1, interpret as a hold command.
    byte 128-254 ($80 - $FE): hold this volume for n frames, where n is the lower 7-bit number
    For example, %10001010 = hold volume for %00001010 frames
                 %11100001 = hold volume for %01100001 frames
                 %10011100 = hold volume for %00011100 frames
                 etc...
    byte 255 = hold this volume forever, end of stream

Since decoder state should be initialized to volume $0F, the simplest volume stream is just [$FF], which would hold the initial volume forever.

Audio byte streams hold an instrument pattern table in the audio stream header.
The instrument pattern table represents, for each instrument, how each frame of a held note should change in volume
Individual patterns are of variable length and don't share a common offset. The audio header instead contains a list of pointers to where each pattern begins.
Patterns do not have a header. Since volume information only takes up 4 bits, the other 4 bits are used for next, stop and loop information.
A pattern byte has the following format: nnnn-vvvv, where n is the byte offset from base of the next element of the pattern, and v is the volume at this frame.
So a pattern of A-A-A-E-9-3-2-1 meant to hold the 1 until finished would look like:
  [$1A,$2A,$3A,$4E,$59,$63,$72,$71] - note the high nibble of the last byte will loop on itself
A pattern of 9-A-B-A meant to repeat for however long the note is held would look like:
  [$19,$2A,$3B,$0A]
A pattern of 1-6-F-A-B meant to attack to F before sustaining in a loop of A-B would look like:
  [$11,$26,$3F,$4A,$3B]
In essence, each byte is a cell in a linked list. With 4 bits for next, patterns have a max length of 16


