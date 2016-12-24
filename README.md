# disassembler_i8086
Disassembler for Intel 8086 processor instruction set

Created by Martynas Šapalas in 2016-11 for learning purposes as an extra task at the university.

The program works only with .com files

# How does it work? 
One byte is taken from the input buffer. Looking at
the pointers to functions with an offset of that byte, the program jumps
to a specific function where further actions begin. These functions 
disassemble a specific group of commands which have the same or similar
format. Inside these functions it is estimated how many more bytes to read,
the parameters are parsed and finally a name and arguments are printed
