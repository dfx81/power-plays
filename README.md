# power-plays

## overview

A multiplayer edutainment game where player try to earn the highest score by
forming equations using random tiles in hand.

## usage

The game need to be played by two players. Each device must be connected to the
same wifi network to play together.

The host need to share the host code, while the other player need to input the
host code to play with the host.

The host always starts on the first turn.

## gameplay

- Players have limited moves & discards
- Select tiles in hand to form equations
    - Equations must include indices tile & equal sign
- Once submitted, opponent can challenge the equation if needed.
    - Depending on the result, rewards will be given to the correct player.
- Player can consume 1 discard to swap as many tiles they wanted.
    - This doesn't end your turn. You can discard multiple times as long as you
    still have discards remaining
- If you cannot form any equations, submit an empty equation to consume 1 move
and end your turn, but 1 discard will be given.
- The game ends once both players used all of their moves.
    - Unused discards are converted into extra points.
    - Player with higher score wins.