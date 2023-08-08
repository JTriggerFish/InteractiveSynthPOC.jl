# Julia Audio Live Coding Proof of concept ( maybe )

This package contains some experiments with audio live coding in Julia.
For now all it does is play sine waves using SDL2 as an audio back end, with some primitive "REPL" consisting of user typing some functions
that add, delete or modify sine waves.

*Try typing* 
```
supersaw(110)
```
*in the prompt.*

The goal is to attempt something similar to Gibber [https://gibber.cc/] or Extempore [https://extemporelang.github.io/]

In the current implementation I seem to get away with playing about a thousand sine waves with a buffer of size 512

WHY ?
* I love Gibber but dislike Javascript.
* To learn more about Julia
* Julia can be very fast and has a very rich maths library for ODEs, PDEs, SDEs, and other domains. Some fun stuff could be done.

TODO:
* Integrate a proper REPL such as https://github.com/MasonProtter/ReplMaker.jl
* Experiment more with JIT warmup and precpompiling.
* Start implementing a proper audio graph, probably in the spirit of Genish.js [http://charlie-roberts.com/genish/]
* Experiment with different audio backends
* Experiment with having a 3D canvas for live graphics using shaders or others methods
