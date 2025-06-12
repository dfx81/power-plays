# I.N.D.E.X

## OVERVIEW

I.N.D.E.X (working title: Power Plays) is a puzzle multiplayer game
developed in [Godot Engine 4.4](https://godotengine.org), a free and open-source game engine. The
game is available on [Android and Windows PC](https://drive.google.com/file/d/1CUdaJL8Uj8POkha2xiO1-O7Bfyhwb84u/view?usp=drive_link).

## GAMEPLAY

The gameplay is inspired by a recent popular indie game called [Balatro](https://store.steampowered.com/app/2379780/Balatro/), where players try to beat a target score by forming poker hands using limited amount of moves and discards. In I.N.D.E.X, the concept remains the same, except the players try to form index equations to score higher total score than their opponent.

## MECHANICS

On each players' turn, they need to score points by forming a valid index equation with a valid solution using the tiles in their hands. They can consume a discard to redraw as many tiles as they want. When the player submits an equation (or none), they will consume a move and the player will draw new tiles until they have a full hand. The game ends when both players ran out of moves, and the player with the higher score wins.

If an equation was submitted, the opponent has the option to challenge the equation if they deemed it to be invalid. The owner of the equation will have to prove the validity of the equation by submitting a valid value of the ```x``` variable. If the player cannot submit a valid value for ```x```, the opponent will gain an extra discard and the score that would be obtained from the equation will be nullified. If the player managed to prove the equation to be valid, the player will be rewarded by an extra 10 points. This opens up opportunities for bluffing as the players can submit invalid equations if they managed to trick and prevent their opponent from challenging the submission, or even tricking the opponent to challenge a complex, but valid equation for the 10 extra points.

Each tiles have a value and a multiplier, which affects the equation score when used. All tiles have differing base value (harder to use tiles have higher base value while easier to use tiles have lower base value), and a base multiplier of 1X. The equation score is calculated with a simple formula:

	Equation Score = (Sum of all tile values) X (Product of all tile multipliers)

Additionally, submitting an equation that managed to use ALL of the tiles in the player's hand will grant the equation a BINGO bonus, where the equation score will be doubled. Unused discards when the game ends will also be converted into points, with 10 points per discard, making way for a potential clutch win.

On subsequent turns, the random tiles in the player's hand will be enhanced which can either be double/triple value (base value of the tile will be doubled/tripled) or double/triple multiplier (multiplier of the tile will be 2X/3X), which ramps up the scoring opportunities and opens up various strategies, considering unused tiles remain in player's hand (use the bonus tiles now, or stockpile for a big scoring equation with multiple bonus tiles later).


## MULTIPLAYER

The game is played by two players in the same local area network (LAN). The game is entirely played over peer-to-peer (P2P) connection hence no internet connection is needed. The game host can customize the game by setting the amount of moves and discards each player will have when starting the game. The game will generate a lobby code that the host can share to their desired opponent. The opponent can join the game by entering the same lobby code, as long as both players are on the same local network. As for the actual implementation, the lobby code are just simple abstraction of IPv4 address into zero-padded, hex-based form. The host starts a game server in the background and waits for a peer to connect to it. When a lobby code is entered by a peer, it is translated back into a proper IPv4 address, allowing the peer to connect to the server without entering an IPv4 address. Communications between both the host and the peer are handled using remote procedural calls (RPC) provided by Godot's [high-level multiplayer API](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html).

## DESIGN

The presentation of the game is to mimic the player inviting their friend to play at their home. The Customization screen where the player can change their name and player model, is designed to be like the player choosing their clothes at a cupboard.

## ASSETS

All of the 3D models used in the game, as well as a few sound effects, are sourced from [Kenney's](https://kenney.nl) free and royalty free (CC0) asset packs. Most of the 2D assets in the game (tile graphics, icons, etc) are created using [Krita](https://krita.org), an open-source art program. The majority of the sound effects and music, are sourced from [DOVA-SYNDROME](https://dova-s.jp/EN/), which are free and royalty free. Fonts used are sourced from [Google Fonts](https://fonts.google.com), which are free to use. No generative AI was used in the making of this game, either for assets or programming.