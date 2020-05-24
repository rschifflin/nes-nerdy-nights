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
have a representation of the equivalent hardware registers of a channel, and we will hold a flag determining if we're active that can be toggled
by interpreting control bytes in the encoded stream. Beyond that, much is still left to decide.