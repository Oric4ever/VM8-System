Playing AOC 2021 on the VM8 system...

I'm currently enjoying programming AOC2021's puzzles in Oberon on the VM8 system, 
it helps me verify the platform is perfectly suitable for such a task, even if more and more of these puzzles are designed
for 64-bit systems.

The standard integer type of the VM8 system is 16-bit only, whilst LONGINT is 32 bits. So sometimes a small multiprecision module is required.
Also many puzzles will require some thinking because of the limited memory (about 40 KB free when the system is loaded).

For now, the only hassle has come from the input libraries: other Oberon compiler writers seem to have agreed to base on the "Oakwood guidelines for Oberon-2 compilers writers", but I can't see anything practical to read text files. So I'm using Turbo Modula-2's library (Texts module), and still it has some annoying limitations (most noticeable one being that numbers you read must be separated by white space), so for now I've cheated a little by replacing comma separators by spaces in Advent Of Code puzzle inputs...
