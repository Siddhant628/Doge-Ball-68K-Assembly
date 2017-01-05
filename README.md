## Doge Ball - Assembly Game in Motorola 68K

A game in Motorola 68000 assembly language (developed in EASy68K IDE) for a project in the Programming-1 curriculum at FIEA, UCF.

**Demo video** - [YouTube](https://youtu.be/2zrnzTrPqpE)

### The project was supposed to have the following features as per instruction:

- User input control of game entity
- Bitmap background with entities moving around over it
- Physics update of game entity, including acceleration (gravity would be good example)
- Fixed point arithmetic
- Collision detection between game entities
- A score indicator as a 7-segment LED
- Randomness

### How To Play:

1. Download EASy68K emulator from the following link - [EASy68K](http://www.easy68k.com/).
2. Clone this repository.
3. Open main.X68 in EAS68K, and execute the program.

### Additional Information:
- main.X68 is the file where the program's execution starts.
- randomizationFunctions.X68 has a subroutine for generating random numbers.
- ledDisplaySubroutine.X68 has a subroutine for displaying a 7-segment LED display for a given number and position as input.
- bmpLoader.X68 has a subroutine for rendering a chunk of a BMP image at a specific position based on input.
